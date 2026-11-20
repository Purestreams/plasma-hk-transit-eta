.pragma library
// Extrapolation is a heuristic, not a timetable or a guarantee of service.
function estimate(rows, now, walk) {
    if (walk < 0 || !Array.isArray(rows) || rows.length < 2) return null;
    // Only extrapolate a train series if every returned service has the same terminus.
    var destinations = rows.map(function(r){return r.dest || "";}).filter(function(x){return x;});
    if (destinations.length && (destinations.length !== rows.length || destinations.some(function(x){return x !== destinations[0];}))) return null;
    var times = rows.map(function(r) { return Date.parse(r.eta); }).filter(function(t) { return isFinite(t); }).sort(function(a,b) { return a-b; });
    if (times.length < 2) return null;
    var hkt = new Date(now + 8*3600000), hour = hkt.getUTCHours();
    // Avoid projecting around first/last trains, when normal headways are misleading.
    if (hour < 6 || hour >= 23) return null;
    var gaps = [];
    for (var i = 1; i < times.length; i++) { var d = times[i]-times[i-1]; if (d < 120000 || d > 1800000) return null; gaps.push(d); }
    gaps.sort(function(a,b){return a-b;});
    var mid = Math.floor(gaps.length/2);
    var interval = gaps.length % 2 ? gaps[mid] : (gaps[mid-1]+gaps[mid])/2;
    var last = times[times.length-1], threshold = now + walk*60000;
    if (last < now-120000 || last >= threshold) return null;
    var n = Math.max(1, Math.ceil((threshold-last)/interval));
    var eta = last + n*interval;
    if (eta-now > 90*60000 || new Date(eta+8*3600000).getUTCHours() >= 23) return null;
    return {eta:eta, interval:interval};
}
