import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.notification as Notifications
import "../code/i18n.js" as I18n
import "../code/logic.js" as Logic
import "../code/stations.js" as Stations

PlasmoidItem {
    id: root
    Plasmoid.icon: Qt.resolvedUrl("../icons/transit.svg")
    width: 420
    height: 600
    Layout.minimumWidth: 300
    Layout.minimumHeight: 280
    property string kmb: "https://data.etabus.gov.hk/v1/transport/kmb/"
    property string nlb: "https://rt.data.gov.hk/v2/transport/nlb/"
    property string ctb: "https://rt.data.gov.hk/v2/transport/citybus/"
    property var busEntries: []
    property int busGeneration: 0
    property var routeRows: []
    property var stops: []
    property string lang: Plasmoid.configuration.language === "auto" ? (Qt.locale().name.toLowerCase().indexOf("zh") === 0 ? (Qt.locale().name.toLowerCase().match(/tw|hk|mo|hant/) ? "tc" : "sc") : "en") : Plasmoid.configuration.language
    function tr(key) { return I18n.text(lang, key) }
    function fmt(key, args) { return I18n.format(tr(key), args) }
    function localizedName(obj, prefix) { if (!obj) return ""; return obj[prefix + "_" + lang] || obj[prefix] || "" }
    function routeNames(data, operator, direction) {
        if (!data) return {}
        if (operator === "NLB") return {route_en:data.routeName_e || "", route_sc:data.routeName_s || "", route_tc:data.routeName_c || ""}
        let from = operator === "CTB" && direction === "I" ? "dest" : "orig"
        let to = operator === "CTB" && direction === "I" ? "orig" : "dest"
        function pair(l) { let a=data[from+"_"+l], b=data[to+"_"+l]; return a && b ? a + " → " + b : "" }
        return {route_en:pair("en"),route_sc:pair("sc"),route_tc:pair("tc")}
    }
    function routeDescription(entry) { return entry && entry["route_"+lang] || "" }
    function stopDescription(entry) { return localizedName(entry,"name") || tr("stop") + " " + entry.stop }
    property string status: ""
    property bool editing: false
    property var railEntries: []
    property int railGeneration: 0
    property int requestGeneration: 0
    property double nowMs: 0
    property var notificationTimes: ({})
    property int freshnessMs: 150000

    function get(url, callback) {
        let attempts = 0
        function send() {
            attempts++
            let xhr = new XMLHttpRequest(), finished = false
            let timeout = Qt.createQmlObject('import QtQuick; Timer { interval: 8000; repeat: false }', root)
            function complete(data, error, response, retryable) {
                if (finished) return
                finished = true; timeout.stop(); timeout.destroy()
                if (retryable && attempts < 2) { send(); return }
                callback(data, error, response)
            }
            timeout.triggered.connect(function() {
                if (finished) return
                complete(null, tr("timeout"), {httpStatus: 0}, true)
                xhr.abort()
            })
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE || finished) return
                if (xhr.status !== 200) {
                    let code = xhr.status
                    complete(null, tr("network") + " (" + code + ")", {httpStatus: code}, code === 0 || code === 429 || code >= 500)
                    return
                }
                let obj
                try { obj = JSON.parse(xhr.responseText) }
                catch (e) { complete(null, tr("invalid"), null, false); return }
                let payload = obj.data !== undefined ? obj.data : (obj.routes !== undefined ? obj.routes : (obj.stops !== undefined ? obj.stops : obj.estimatedArrivals))
                if (payload === undefined && Number(obj.status) !== 0) complete(null, tr("invalid"), null, false)
                else complete(payload, "", obj, false)
            }
            xhr.open("GET", url); xhr.send(); timeout.start()
        }
        send()
    }
    function searchRoutes(query) {
        let q = query.trim().toUpperCase()
        if (!q) { ++requestGeneration; routeRows = []; stops = []; status = tr("enterRoute"); return }
        let gen = ++requestGeneration
        routeRows = []; stops = []; currentRoute = null; status = tr("searching")
        let pending = 3, failures = [], found = []
        function finish(operator, rows, failed) {
            if (gen !== requestGeneration) return
            if (failed) failures.push(operator)
            found = found.concat(rows)
            pending--
            found.sort(function(a,b) {
                let ax = a.route.toUpperCase() === q ? 0 : 1, bx = b.route.toUpperCase() === q ? 0 : 1
                return ax - bx || a.route.localeCompare(b.route) || a.co.localeCompare(b.co) || a.dir.localeCompare(b.dir)
            })
            routeRows = found
            if (pending) status = tr("searching")
            else if (failures.length) status = tr("partialSearch") + ": " + failures.join(", ")
            else status = found.length ? tr("chooseRoute") : tr("noRoute")
        }
        get(kmb + "route/", function(data, err) {
            if (gen !== requestGeneration) return
            if (err || !Array.isArray(data)) { finish(tr("kmb"), [], true); return }
            let rows = data.filter(x => x.route && x.route.toUpperCase().indexOf(q) >= 0).slice(0, 100)
            finish(tr("kmb"), rows.map(x => Object.assign({co:"KMB", route:x.route, dir:x.bound, service:String(x.service_type), label:tr("kmb") + "  " + x.route + "  " + localizedName(x, "orig") + " → " + localizedName(x, "dest") + (String(x.service_type) !== "1" ? " · " + tr("service") + " " + x.service_type : "")}, routeNames(x,"KMB",x.bound))), false)
        })
        get(nlb + "route.php?action=list", function(data, err) {
            if (gen !== requestGeneration) return
            if (err || !Array.isArray(data)) { finish(tr("nlb"), [], true); return }
            let rows = data.filter(x => x.routeNo && x.routeNo.toUpperCase().indexOf(q) >= 0).slice(0, 100)
            finish(tr("nlb"), rows.map(x => Object.assign({co:"NLB",route:x.routeNo,dir:"",service:String(x.routeId),label:tr("nlb") + "  " + x.routeNo + "  " + (lang === "en" ? x.routeName_e : lang === "sc" ? x.routeName_s : x.routeName_c)}, routeNames(x,"NLB",""))), false)
        })
        get(ctb + "route/CTB", function(data, err) {
            if (gen !== requestGeneration) return
            if (err || !Array.isArray(data)) { finish(tr("citybus"), [], true); return }
            let matches = data.filter(x => x.route && x.route.toUpperCase().indexOf(q) >= 0).slice(0,100)
            let rows = []
            matches.forEach(function(x) {
                let prefix = tr("citybus") + "  " + x.route + "  "
                rows.push(Object.assign({co:"CTB",route:x.route,dir:"O",service:"1",label:prefix + localizedName(x, "orig") + " → " + localizedName(x, "dest")}, routeNames(x,"CTB","O")))
                rows.push(Object.assign({co:"CTB",route:x.route,dir:"I",service:"1",label:prefix + localizedName(x, "dest") + " → " + localizedName(x, "orig")}, routeNames(x,"CTB","I")))
            })
            finish(tr("citybus"), rows, false)
        })
    }
    function selectRoute(row) {
        let gen = ++requestGeneration
        stops = []; status = tr("loadingStops")
        if (row.co === "NLB") {
            get(nlb + "stop.php?action=list&routeId=" + encodeURIComponent(row.service), function(data, err) {
                if (gen !== requestGeneration) return
                if (err || !Array.isArray(data)) { status = tr("stopFailure") + ": " + err; return }
                currentRoute = row
                stops = data.map((x,i) => ({id:String(x.stopId),seq:i+1,name_en:x.stopName_e,name_sc:x.stopName_s,name_tc:x.stopName_c,name:lang === "en" ? x.stopName_e : lang === "sc" ? x.stopName_s : x.stopName_c}))
                status = stops.length ? tr("chooseStop") : tr("noStops")
            })
            return
        }
        let isKmb = row.co === "KMB"
        let direction = row.dir === "O" ? "outbound" : "inbound"
        let url = isKmb ? kmb + "route-stop/" + encodeURIComponent(row.route) + "/" + direction + "/" + row.service : ctb + "route-stop/CTB/" + encodeURIComponent(row.route) + "/" + direction
        get(url, function(data, err) {
            if (gen !== requestGeneration) return
            if (err || !Array.isArray(data)) { status = tr("stopFailure") + ": " + err; return }
            if (!data.length) { status = tr("noStops"); return }
            let list = data.slice().sort((a,b) => Number(a.seq)-Number(b.seq)); let pending = 0; let next = 0; let complete = 0; let results = []; let failures = 0
            function launch() {
                if (gen !== requestGeneration) return
                while (pending < 5 && next < list.length) {
                    let item = list[next++]; pending++
                    get((isKmb ? kmb : ctb) + "stop/" + encodeURIComponent(item.stop), function(stop, e) {
                        if (gen !== requestGeneration) return
                        pending--; complete++
                        if (e || !stop) failures++
                        results.push({id:item.stop, seq:Number(item.seq), name:stop ? localizedName(stop, "name") : tr("stop") + " " + item.stop, name_en:stop && stop.name_en, name_sc:stop && stop.name_sc, name_tc:stop && stop.name_tc})
                        if (complete === list.length) {
                            results.sort((a,b)=>a.seq-b.seq); stops = results
                            status = failures ? tr("stopPartial") : tr("chooseStop")
                        } else { status = tr("loadingStops") + " " + complete + "/" + list.length; launch() }
                    })
                }
            }
            root.currentRoute = row; launch()
        })
    }
    property var currentRoute: null
    function entryKey(e) { return [e.co,e.route,e.dir,e.service,e.stop,e.seq].join("|") }
    function persistBuses() {
        let records = busEntries.map(e => ({co:e.co,route:e.route,dir:e.dir,service:e.service,routeLabel:e.routeLabel,route_en:e.route_en,route_sc:e.route_sc,route_tc:e.route_tc,stop:e.stop,stopName:e.stopName,name_en:e.name_en,name_sc:e.name_sc,name_tc:e.name_tc,seq:e.seq,walk:e.walk}))
        Plasmoid.configuration.busRoutes = JSON.stringify(records)
    }
    function loadBuses() {
        let stored = Plasmoid.configuration.busRoutes
        try {
            if (stored !== "") {
                let parsed = JSON.parse(stored)
                busEntries = Array.isArray(parsed) ? parsed : []
                return
            }
            let legacy = Plasmoid.configuration.selection ? JSON.parse(Plasmoid.configuration.selection) : null
            if (legacy && legacy.route && legacy.stop) {
                legacy.walk = Plasmoid.configuration.busWalk
                busEntries = [legacy]
            }
            persistBuses()
        } catch (e) { busEntries = []; status = tr("invalid") }
    }
    function refreshRouteNames() {
        busEntries.forEach(function(entry) {
            if (entry.route_en && entry.route_sc && entry.route_tc) return
            let key=entryKey(entry), url = entry.co === "NLB" ? nlb + "route.php?action=list" : entry.co === "KMB" ? kmb + "route/" + encodeURIComponent(entry.route) + "/" + (entry.dir === "O" ? "outbound" : "inbound") + "/" + encodeURIComponent(entry.service) : ctb + "route/CTB/" + encodeURIComponent(entry.route)
            get(url, function(data, err) {
                if (err || !data) return
                let detail = entry.co === "NLB" && Array.isArray(data) ? data.find(x => String(x.routeId) === String(entry.service)) : data
                if (!detail) return
                let names=routeNames(detail, entry.co, entry.dir)
                if (!names.route_en && !names.route_sc && !names.route_tc) return
                let changed=false
                busEntries=busEntries.map(function(e) { if (entryKey(e)!==key) return e; changed=true; return Object.assign({},e,names) })
                if (changed) persistBuses()
            })
        })
    }
    function refreshStopNames() {
        busEntries.forEach(function(entry) {
            if (entry.name_en && entry.name_sc && entry.name_tc) return
            let key=entryKey(entry), url=entry.co === "NLB" ? nlb + "stop.php?action=list&routeId=" + encodeURIComponent(entry.service) : (entry.co === "KMB" ? kmb : ctb) + "stop/" + encodeURIComponent(entry.stop)
            get(url,function(data,err) {
                if (err || !data) return
                let detail=entry.co === "NLB" && Array.isArray(data) ? data.find(x=>String(x.stopId) === String(entry.stop)) : data
                if (!detail) return
                let names = entry.co === "NLB" ? {name_en:detail.stopName_e,name_sc:detail.stopName_s,name_tc:detail.stopName_c} : {name_en:detail.name_en,name_sc:detail.name_sc,name_tc:detail.name_tc}
                if (!names.name_en && !names.name_sc && !names.name_tc) return
                let changed=false
                busEntries=busEntries.map(function(e) { if (entryKey(e)!==key) return e; changed=true; return Object.assign({},e,names) })
                if (changed) persistBuses()
            })
        })
    }
    function chooseStop(stop) {
        if (!currentRoute) return
        let e = {co:currentRoute.co,route:currentRoute.route,dir:currentRoute.dir,service:currentRoute.service,routeLabel:currentRoute.label,route_en:currentRoute.route_en,route_sc:currentRoute.route_sc,route_tc:currentRoute.route_tc,stop:stop.id,stopName:stop.name,name_en:stop.name_en,name_sc:stop.name_sc,name_tc:stop.name_tc,seq:stop.seq,walk:-1,arrivals:[],fresh:false,failed:false}
        if (busEntries.some(x => entryKey(x) === entryKey(e))) { status = tr("alreadyAdded"); return }
        busEntries = busEntries.concat([e]); persistBuses()
        routeRows = []; stops = []; currentRoute = null; status = tr("addedSetWalk")
        refresh()
    }
    function setBusWalk(key, walk) {
        busEntries = busEntries.map(e => entryKey(e) === key ? Object.assign({}, e, {walk:walk}) : e)
        persistBuses()
    }
    function removeBus(key) {
        busEntries = busEntries.filter(e => entryKey(e) !== key)
        persistBuses()
    }
    function parseSourceTime(value) {
        if (!value) return NaN
        let v = String(value)
        if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(v)) v = v.replace(" ", "T") + "+08:00"
        return Date.parse(v)
    }
    function sourceTime(data, response, co) {
        let stamps = []
        if (Array.isArray(data)) data.forEach(function(x) {
            let t = parseSourceTime(co === "NLB" ? x.generateTime : x.data_timestamp)
            if (isFinite(t)) stamps.push(t)
        })
        if (stamps.length) return Math.min.apply(null, stamps)
        return parseSourceTime(response && (response.generated_timestamp || response.curr_time))
    }
    function isReliable(entry) {
        return !!entry.fresh && isFinite(entry.sourceAt) && entry.sourceAt > 0 && nowMs - entry.sourceAt <= freshnessMs && entry.sourceAt - nowMs < 60000
    }
    function dataLabel(entry) {
        return isReliable(entry) ? fmt("dataTime", [Qt.formatTime(new Date(entry.sourceAt), "HH:mm:ss")]) : (entry.fresh ? tr("stale") : "")
    }
    function isRoutineRemark(value) {
        let text = String(value || "").trim().toLowerCase()
        return ["scheduled bus", "scheduled", "scheduled departure", "原定班次", "预定班次", "預定班次", "预订班次", "預訂班次", "尚未从总站开出", "尚未從總站開出", "尚未从本站开出", "尚未從本站開出", "not yet departed"].indexOf(text) >= 0
    }
    function displayRemark(row) {
        if (row.remarkKey === "scheduled" || row.remarkKey === "notDeparted") return ""
        let note = row.remarkKey ? tr(row.remarkKey) : localizedName(row, "rmk")
        if (isRoutineRemark(note)) return ""
        if (!note && [row.rmk_en, row.rmk_sc, row.rmk_tc].some(x => x && !isRoutineRemark(x))) return tr("noteUnavailable")
        return note || ""
    }
    function rowLabel(row) {
        let details = []
        if (row.dest && !row.suppressDestination) details.push(railStationName(row.dest))
        let note = displayRemark(row)
        if (note) details.push(note)
        return minutes(row.eta) + (details.length ? " (" + details.join(", ") + ")" : "")
    }
    function refresh() {
        let gen = ++busGeneration
        busEntries.forEach(function(s) {
            let key = entryKey(s)
            let url = s.co === "KMB" ? kmb + "eta/" + encodeURIComponent(s.stop) + "/" + encodeURIComponent(s.route) + "/" + encodeURIComponent(s.service) : s.co === "NLB" ? nlb + "stop.php?action=estimatedArrivals&language=zh&routeId=" + encodeURIComponent(s.service) + "&stopId=" + encodeURIComponent(s.stop) : ctb + "eta/CTB/" + encodeURIComponent(s.stop) + "/" + encodeURIComponent(s.route)
            get(url, function(data, err, response) {
                if (gen !== busGeneration) return
                busEntries = busEntries.map(function(e) {
                    if (entryKey(e) !== key) return e
                    if (err || !Array.isArray(data)) return Object.assign({}, e, {fresh:false,failed:true})
                    let rows = e.co === "NLB" ? data.map(x => ({eta: x.estimatedArrivalTime ? x.estimatedArrivalTime.replace(" ", "T") + "+08:00" : "", remarkKey: Number(x.noGPS) === 1 ? "scheduled" : x.departed !== null && x.departed !== undefined && Number(x.departed) === 0 ? "notDeparted" : ""})) : data.filter(x => x.dir === e.dir && (!x.seq || Number(x.seq) === Number(e.seq)) && (e.co !== "KMB" || x.service_type === undefined || String(x.service_type) === String(e.service)))
                    let arrivals = rows.filter(x => x.eta && isFinite(Date.parse(x.eta))).sort((a,b) => Date.parse(a.eta)-Date.parse(b.eta)).slice(0,3)
                    let remarks = rows.map(x => displayRemark(x)).filter(x=>x)
                    return Object.assign({}, e, {fresh:true,failed:false,sourceAt:sourceTime(data, response, e.co),arrivals:arrivals,remark:remarks[0] || tr("noEta")})
                })
                nowMs = Date.now()

            })
        })
    }
    function railKey(e) { return [e.line, e.station, e.direction].join("|") }
    function railLineName(line) { return line === "AEL" ? tr("airportLine") : line === "TCL" ? tr("tungLine") : line === "TWL" ? tr("tsuenLine") : tr("islandLine") }
    function railStationName(station) { return Stations.stationName(station, lang) }
    function railDirectionName(line, direction) {
        return line === "AEL" && direction === "UP" ? tr("airportDir") : fmt("toward", [railStationName(Stations.terminal(line, direction))])
    }
    function persistRail() {
        Plasmoid.configuration.railRoutes = JSON.stringify(railEntries.map(e => ({line:e.line,station:e.station,direction:e.direction,walk:e.walk,destination:e.destination || ""})))
    }
    function loadRail() {
        let stored = Plasmoid.configuration.railRoutes
        try {
            if (stored !== "") { let parsed = JSON.parse(stored); railEntries = Array.isArray(parsed) ? parsed : []; return }
            let walk = Plasmoid.configuration.railWalk
            railEntries = [{line:"AEL",station:"HOK",direction:"UP",walk:walk}, {line:"TCL",station:"HOK",direction:"UP",walk:walk}]
            persistRail()
        } catch(e) { railEntries = []; status = tr("invalid") }
    }
    function addRail(line, station, direction) {
        if (Stations.directions(line, station).indexOf(direction) < 0) return
        let entry = {line:line,station:station,direction:direction,walk:-1,arrivals:[],fresh:false,failed:false,delayed:false}
        if (railEntries.some(x => railKey(x) === railKey(entry))) { status = tr("alreadyAdded"); return }
        railEntries = railEntries.concat([entry]); persistRail(); status = tr("railAdded"); refreshRail()
    }
    function setRailWalk(key, walk) {
        railEntries = railEntries.map(e => railKey(e) === key ? Object.assign({}, e, {walk:walk}) : e); persistRail()
    }
    function setRailDestination(key, destination) {
        railEntries = railEntries.map(e => railKey(e) === key ? Object.assign({},e,{destination:destination, arrivals:[],fresh:false,failed:false}) : e); persistRail(); refreshRail()
    }
    function removeRail(key) { railEntries = railEntries.filter(e => railKey(e) !== key); persistRail() }
    function refreshRail() {
        let gen = ++railGeneration
        railEntries.forEach(function(entry) {
            let key = railKey(entry)
            get("https://rt.data.gov.hk/v1/transport/mtr/getSchedule.php?line=" + encodeURIComponent(entry.line) + "&sta=" + encodeURIComponent(entry.station) + "&lang=TC", function(data, err, response) {
                if (gen !== railGeneration) return
                let failed = !!err || !response || Number(response.status) !== 1
                railEntries = railEntries.map(function(e) {
                    if (railKey(e) !== key) return e
                    if (failed) return Object.assign({}, e, {failed:true,fresh:false})
                    let station = data && data[e.line + "-" + e.station]
                    let list = station && Array.isArray(station[e.direction]) ? station[e.direction] : []
                    let rows = list.slice(0,4).filter(x => x.time && Stations.serves(e.line,e.station,e.direction,x.dest,e.destination || "")).map(x => ({eta:x.time.replace(" ", "T") + "+08:00", dest:x.dest || "?", suppressDestination:!!x.dest && x.dest === Stations.terminal(e.line,e.direction), plat:x.plat}))
                    return Object.assign({}, e, {arrivals:rows,fresh:true,failed:false,sourceAt:parseSourceTime((station && station.curr_time) || response.curr_time),delayed:response.isdelay === "Y",remark:rows.length ? "" : tr("noRail")})
                })
            })
        })
    }
    function minutes(eta) {
        let diff = Date.parse(eta) - nowMs
        if (!isFinite(diff)) return "—"
        return diff <= 0 ? tr("now") : Math.ceil(diff / 60000) + (lang === "en" ? " min" : " 分")
    }
    function activeRows(rows) {
        return rows.filter(x => isFinite(Date.parse(x.eta)) && Date.parse(x.eta) >= nowMs)
                   .sort((a, b) => Date.parse(a.eta) - Date.parse(b.eta))
    }
    function timesText(rows, emptyMessage) {
        let active = activeRows(rows)
        return active.length ? active.slice(0, 4).map(x => rowLabel(x)).join("  ·  ") : emptyMessage
    }
    function departureAdvice(rows, walk, usable, allowEstimate) {
        if (!usable) return tr("notReady")
        if (walk < 0) return tr("setWalk")
        walk += Plasmoid.configuration.bufferMinutes
        let active = activeRows(rows)
        if (!active.length) return tr("noTimes")
        let missed = 0
        for (let i = 0; i < active.length; i++) {
            let remaining = Date.parse(active[i].eta) - nowMs - walk * 60000
            if (remaining < 0) { missed++; continue }
            let available = Math.floor(remaining / 60000)
            let deadline = available === 0 ? tr("leaveNow") : fmt("leaveWithin", [available])
            return fmt("catch", [rowLabel(active[i]), deadline])
        }
        if (allowEstimate) {
            let projected = Logic.estimate(active, nowMs, walk)
            if (projected) {
                let available = Math.floor((projected.eta - nowMs - walk * 60000) / 60000)
                let deadline = available <= 0 ? tr("leaveNow") : fmt("leaveWithin", [available])
                let last = active[active.length - 1]
                let target = last.dest && !last.suppressDestination ? " (" + railStationName(last.dest) + ")" : ""
                return fmt("estimate", [minutes(new Date(projected.eta).toISOString()) + target, deadline])
            }
        }
        return tr("noEstimate")
    }
    Component {
        id: notificationFactory
        Notifications.Notification { componentName: "plasma_workspace"; eventId: "notification"; iconName: "directions-bus"; autoDelete: true }
    }
    function checkNotifications() {
        if (!Plasmoid.configuration.notifyEnabled) return
        let all = busEntries.map(e => ({entry:e,key:"bus:"+entryKey(e),label:(e.route + " · " + stopDescription(e))})).concat(
            railEntries.map(e => ({entry:e,key:"rail:"+railKey(e),label:(railLineName(e.line) + " · " + railStationName(e.station))})) )
        all.forEach(function(item) {
            let e = item.entry
            if (!isReliable(e) || e.failed || e.delayed || e.walk === undefined || e.walk < 0) return
            let rows = activeRows(e.arrivals || [])
            for (let i=0; i<rows.length; i++) {
                let remain = Date.parse(rows[i].eta) - nowMs - (e.walk + Plasmoid.configuration.bufferMinutes)*60000
                if (remain < 0) continue
                if (remain <= 60000 && (!notificationTimes[item.key] || nowMs-notificationTimes[item.key] > 300000)) {
                    let n = notificationFactory.createObject(root, {title:tr("title"), text:fmt("notifySoon",[item.label + (rows[i].dest && !rows[i].suppressDestination ? " · " + railStationName(rows[i].dest) : "")])})
                    if (n) { n.sendEvent(); notificationTimes[item.key] = nowMs }
                }
                break
            }
        })
    }
    Component.onCompleted: { nowMs = Date.now(); loadBuses(); loadRail(); refreshRouteNames(); refreshStopNames(); refresh(); refreshRail() }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: { root.nowMs = Date.now(); root.checkNotifications() } }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: { if (!root.editing) root.refresh(); root.refreshRail() } }
    fullRepresentation: Item {
        implicitWidth: 420; implicitHeight: 600
        clip: true
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 3
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: root.tr("title"); font.bold: true; font.pixelSize: 16; Layout.fillWidth: true }
                PlasmaComponents.Button { text: root.editing ? root.tr("done") : root.tr("settings"); onClicked: { root.requestGeneration++; root.editing = !root.editing; if (!root.editing) { root.refresh(); root.refreshRail() } } }
            }
            Controls.ScrollView {
                id: settingsScroll
                visible: root.editing; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0; clip: true
                contentWidth: availableWidth
                ColumnLayout {
                width: settingsScroll.availableWidth
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("language"); Layout.fillWidth: true }
                    Controls.ComboBox {
                        model: [root.tr("systemLanguage"), "English", "简体中文", "繁體中文"]
                        currentIndex: ["auto", "en", "sc", "tc"].indexOf(Plasmoid.configuration.language)
                        onActivated: { Plasmoid.configuration.language = ["auto", "en", "sc", "tc"][currentIndex]; root.status = ""; root.routeRows = []; root.stops = []; root.requestGeneration++; root.refresh(); root.refreshRail(); root.refreshRouteNames(); root.refreshStopNames() }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("buffer"); Layout.fillWidth: true }
                    Controls.SpinBox { from: 0; to: 60; editable: true; value: Plasmoid.configuration.bufferMinutes; onValueModified: Plasmoid.configuration.bufferMinutes = value }
                }
                Controls.CheckBox { Layout.fillWidth: true; text: root.tr("notify"); checked: Plasmoid.configuration.notifyEnabled; onToggled: Plasmoid.configuration.notifyEnabled = checked }
                PlasmaComponents.Label { text: root.tr("savedBuses"); font.bold: true; Layout.fillWidth: true }
                PlasmaComponents.Label { visible: root.busEntries.length === 0; text: root.tr("noBuses"); Layout.fillWidth: true; wrapMode: Text.Wrap }
                Repeater {
                    model: root.busEntries
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            PlasmaComponents.Label { Layout.fillWidth: true; text: modelData.route + " · " + root.stopDescription(modelData); wrapMode: Text.Wrap; font.bold: true }
                            PlasmaComponents.Label { Layout.fillWidth: true; visible: root.routeDescription(modelData) !== ""; text: root.routeDescription(modelData); wrapMode: Text.Wrap; font.pixelSize: 11; opacity: 0.7 }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.tr("busWalk"); font.pixelSize: 12; opacity: 0.8 }
                        }
                        Controls.SpinBox {
                            objectName: "busWalk_" + root.entryKey(modelData)
                            from: -1; to: 120; editable: true; value: modelData.walk === undefined ? -1 : modelData.walk
                            textFromValue: function(v) { return v < 0 ? root.tr("unset") : v + " " + root.tr("minutes") }
                            valueFromText: function(text) { let n = parseInt(text); return isNaN(n) ? -1 : n }
                            onValueModified: root.setBusWalk(root.entryKey(modelData), value)
                        }
                        PlasmaComponents.Button { objectName: "removeBus_" + root.entryKey(modelData); text: root.tr("remove"); onClicked: root.removeBus(root.entryKey(modelData)) }
                    }
                }
                PlasmaComponents.Label { text: root.tr("savedRail"); font.bold: true; Layout.fillWidth: true }
                PlasmaComponents.Label { visible: root.railEntries.length === 0; text: root.tr("noRailSaved"); Layout.fillWidth: true }
                Repeater {
                    model: root.railEntries
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.railLineName(modelData.line) + " · " + root.railStationName(modelData.station); wrapMode: Text.Wrap; font.bold: true }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.railDirectionName(modelData.line, modelData.direction); wrapMode: Text.Wrap; font.pixelSize: 11; opacity: 0.7 }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.tr("walkToStation"); font.pixelSize: 12; opacity: 0.8 }
                            Controls.ComboBox {
                                objectName: "railDestination_" + root.railKey(modelData)
                                Layout.fillWidth: true
                                property var codes: [""].concat(Stations.destinations(modelData.line,modelData.station,modelData.direction))
                                model: codes.map(x => x ? root.railStationName(x) : root.tr("anyDestination"))
                                currentIndex: Math.max(0, codes.indexOf(modelData.destination || ""))
                                onActivated: root.setRailDestination(root.railKey(modelData), codes[currentIndex])
                            }
                        }
                        Controls.SpinBox {
                            objectName: "railWalk_" + root.railKey(modelData)
                            from: -1; to: 120; editable: true; value: modelData.walk === undefined ? -1 : modelData.walk
                            textFromValue: function(v) { return v < 0 ? root.tr("unset") : v + " " + root.tr("minutes") }
                            valueFromText: function(text) { let n = parseInt(text); return isNaN(n) ? -1 : n }
                            onValueModified: root.setRailWalk(root.railKey(modelData), value)
                        }
                        PlasmaComponents.Button { objectName: "removeRail_" + root.railKey(modelData); text: root.tr("remove"); onClicked: root.removeRail(root.railKey(modelData)) }
                    }
                }
                PlasmaComponents.Label { text: root.tr("addRail"); font.bold: true; Layout.fillWidth: true }
                Controls.ComboBox { id: railLine; objectName: "railLine"; Layout.fillWidth: true; model: [root.tr("airportLine"),root.tr("tungLine"),root.tr("tsuenLine"),root.tr("islandLine")]; property string code: ["AEL", "TCL", "TWL", "ISL"][currentIndex] || "AEL" }
                Controls.ComboBox {
                    id: railStation; objectName: "railStation"; Layout.fillWidth: true
                    property var stationCodes: Stations.routes[railLine.code] || []
                    model: stationCodes.map(x => root.railStationName(x))
                    property string code: currentIndex >= 0 && currentIndex < stationCodes.length ? stationCodes[currentIndex] : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    Controls.ComboBox {
                        id: railDirection; objectName: "railDirection"; Layout.fillWidth: true
                        property var codes: Stations.directions(railLine.code, railStation.code)
                        model: codes.map(x => root.railDirectionName(railLine.code,x))
                        property string code: currentIndex >= 0 && currentIndex < codes.length ? codes[currentIndex] : ""
                    }
                    PlasmaComponents.Button { objectName: "addRailButton"; text: root.tr("add"); enabled: railDirection.code !== ""; onClicked: root.addRail(railLine.code, railStation.code, railDirection.code) }
                }
                PlasmaComponents.Label { text: root.tr("addBus"); font.bold: true; Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.TextField { id: routeInput; Layout.fillWidth: true; placeholderText: root.tr("routePlaceholder"); onAccepted: root.searchRoutes(routeInput.text) }
                    PlasmaComponents.Button { text: root.tr("search"); onClicked: root.searchRoutes(routeInput.text) }
                }
                PlasmaComponents.Label { visible: root.routeRows.length > 0; text: root.tr("chooseRoute"); font.bold: true }
                Controls.ScrollView {
                    Layout.fillWidth: true; Layout.preferredHeight: root.stops.length ? 60 : 90; Layout.minimumHeight: 0; clip: true
                    ListView { model: root.routeRows; delegate: Controls.ItemDelegate { required property var modelData; width: ListView.view.width; text: modelData.label; onClicked: { stopInput.text = ""; root.selectRoute(modelData) } } }
                }
                PlasmaComponents.TextField { id: stopInput; visible: root.stops.length > 0; Layout.fillWidth: true; placeholderText: root.tr("stopPlaceholder") }
                Controls.ScrollView {
                    visible: root.stops.length > 0; Layout.fillWidth: true; Layout.preferredHeight: 160; clip: true
                    ListView { model: root.stops.filter(x => !stopInput.text || (x.name + " " + x.id).toLowerCase().indexOf(stopInput.text.toLowerCase()) >= 0); delegate: Controls.ItemDelegate { required property var modelData; width: ListView.view.width; text: modelData.seq + ". " + modelData.name; onClicked: root.chooseStop(modelData) } }
                }
                }
            }
            Controls.ScrollView {
                id: dashboardScroll
                objectName: "dashboardScroll"
                visible: !root.editing
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0; clip: true
                contentWidth: availableWidth
                ColumnLayout {
                width: dashboardScroll.availableWidth; spacing: 2
                PlasmaComponents.Label { visible: root.busEntries.length === 0; text: root.tr("noBuses"); Layout.fillWidth: true }
                Repeater {
                    model: root.busEntries
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: (modelData.co === "KMB" ? root.tr("kmb") + " " : modelData.co === "NLB" ? root.tr("nlb") + " " : root.tr("citybus") + " ") + modelData.route; font.bold: true; font.pixelSize: 15 }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.stopDescription(modelData); elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; opacity: 0.8 }
                        }
                        PlasmaComponents.Label { Layout.fillWidth: true; visible: root.routeDescription(modelData) !== ""; text: root.routeDescription(modelData); font.pixelSize: 10; opacity: 0.7; wrapMode: Text.Wrap }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: root.timesText(modelData.arrivals || [], modelData.remark || root.tr("loading")); wrapMode: Text.Wrap; font.bold: true; font.pixelSize: 14 }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: modelData.failed ? root.tr("failed") : !root.isReliable(modelData) && modelData.fresh ? root.tr("stale") : root.departureAdvice(modelData.arrivals || [], modelData.walk === undefined ? -1 : modelData.walk, root.isReliable(modelData), modelData.co === "NLB"); wrapMode: Text.Wrap; font.pixelSize: 12; opacity: 0.9 }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: root.dataLabel(modelData); visible: text !== ""; font.pixelSize: 10; opacity: 0.65; elide: Text.ElideRight }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; opacity: 0.18; color: "gray" }
                    }
                }
                Repeater {
                    model: root.railEntries
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: (modelData.delayed ? "⚠ " : "") + root.railLineName(modelData.line) + " · " + root.railStationName(modelData.station); font.bold: true; font.pixelSize: 14 }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: root.railDirectionName(modelData.line,modelData.direction); horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; opacity: 0.8 }
                        }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: root.timesText(modelData.arrivals || [], modelData.remark || root.tr("loading")); wrapMode: Text.Wrap; font.bold: true; font.pixelSize: 14 }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: modelData.failed ? root.tr("failed") : !root.isReliable(modelData) && modelData.fresh ? root.tr("stale") : root.departureAdvice(modelData.arrivals || [], modelData.walk === undefined ? -1 : modelData.walk, root.isReliable(modelData), !modelData.delayed); wrapMode: Text.Wrap; font.pixelSize: 12; opacity: 0.9 }
                        PlasmaComponents.Label { Layout.fillWidth: true; text: root.dataLabel(modelData); visible: text !== ""; font.pixelSize: 10; opacity: 0.65; elide: Text.ElideRight }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; opacity: 0.18; color: "gray" }
                    }
                }
                }
            }
            PlasmaComponents.Label { Layout.fillWidth: true; text: root.editing ? root.status : ""; visible: text !== ""; elide: Text.ElideRight; maximumLineCount: 1; opacity: 0.8 }
        }
    }
}
