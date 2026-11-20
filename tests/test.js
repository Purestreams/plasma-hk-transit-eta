// Run with: node tests/test.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
function loadScript(file) {
    const context = { Date, Math, isFinite }; vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\.pragma library\s*/, ''), context);
    return context;
}
const logic = loadScript('contents/code/logic.js');
const i18n = loadScript('contents/code/i18n.js');
const now = Date.parse('2026-11-20T10:00:00+08:00');
const rows = (...m) => m.map(n => ({eta: new Date(now+n*60000).toISOString()}));
assert.equal(logic.estimate(rows(2, 8, 14), now, 15).eta, now+20*60000);
assert.equal(logic.estimate(rows(2, 8, 14), now, 30).eta, now+32*60000);
assert.equal(logic.estimate(rows(2), now, 15), null);
assert.equal(logic.estimate(rows(2, 3), now, 15), null);
assert.equal(logic.estimate(rows(2, 33), now, 40), null);
assert.equal(logic.estimate(rows(2, 8, 14), now, -1), null);
assert.equal(logic.estimate(rows(2, 8, 14), now, 13), null);
const late = Date.parse('2026-11-20T23:01:00+08:00');
assert.equal(logic.estimate([{eta:new Date(late+60000).toISOString()},{eta:new Date(late+420000).toISOString()}],late,15), null);
const keys = Object.keys(i18n.dict.en).sort();
for (const lang of ['sc','tc']) assert.deepEqual(Object.keys(i18n.dict[lang]).sort(), keys);
for (const lang of ['en','sc','tc']) for (const key of keys) assert.ok(i18n.text(lang,key));
const src = fs.readFileSync(path.join(root, 'contents/ui/main.qml'), 'utf8');
function extract(name) { const m = src.match(new RegExp('    function ' + name + '\\([^]*?\\n    }')); assert(m); return m[0]; }
const ctx = {nowMs:now,lang:'en',Date,Math,isFinite,Logic:logic,Plasmoid:{configuration:{bufferMinutes:0}},railStationName:x=>x,localizedName:(o,p)=>o[p+'_en'] || '',tr:k=>i18n.text('en',k),fmt:(k,args)=>i18n.format(i18n.text('en',k),args)};
vm.createContext(ctx); vm.runInContext(['minutes','activeRows','isRoutineRemark','displayRemark','rowLabel','departureAdvice'].map(extract).join('\n'),ctx);
assert.equal(ctx.departureAdvice(rows(2,8,14),15,true,true),'EST. 20 min · leave within 5 min');
assert.equal(ctx.departureAdvice(rows(2,8,14,21),15,true,true),'Catch in 21 min · leave within 6 min');
assert.equal(ctx.departureAdvice(rows(2,8,14),15,true,false),'No estimate · updating shortly');
assert.equal(ctx.departureAdvice(rows(2,8,14),15,false,true),'Waiting for data');
assert.equal(ctx.departureAdvice(rows(2,8,14),-1,true,true),'Set walking time in Settings');
console.log('Estimate, boundary conditions, live precedence, and 3-language coverage: passed');
// Route search queries both operators and merges the results, regardless of response order.
const requests = [];
const search = {
  routeInput:{text:'a12'}, requestGeneration:0, routeRows:[], stops:[], currentRoute:null, status:'',
  kmb:'kmb/',ctb:'ctb/',nlb:'nlb/',lang:'en', get:(url,cb)=>requests.push({url,cb}),
  tr:k=>i18n.text('en',k), localizedName:(obj,prefix)=>obj[prefix+'_en'] || '', routeNames:()=>({})
};
vm.createContext(search); vm.runInContext(extract('searchRoutes'),search); search.searchRoutes(search.routeInput.text);
assert.equal(requests.length,3); assert.equal(requests[2].url,'ctb/route/CTB');
requests[2].cb([{route:'A12',orig_en:'Start',dest_en:'End'}],'',{});
assert.equal(search.routeRows.length,2);
requests[1].cb([], '');
requests[0].cb([{route:'A12',bound:'O',service_type:'1',orig_en:'Other',dest_en:'End'}],'');
assert.equal(search.routeRows.length,3);
assert.ok(search.routeRows.some(x=>x.co==='KMB')); assert.ok(search.routeRows.some(x=>x.co==='CTB'));
requests.length=0; search.searchRoutes(search.routeInput.text); requests[2].cb([], '',{}); requests[1].cb([], ''); requests[0].cb([], 'offline');
assert.equal(search.routeRows.length,0); assert.match(search.status,/incomplete/);
requests.length=0; search.searchRoutes(search.routeInput.text); const obsolete=requests.slice(); search.routeInput.text='1A'; search.searchRoutes(search.routeInput.text);
obsolete[0].cb([{route:'A12',bound:'O',service_type:'1'}],''); obsolete[1].cb([], ''); obsolete[2].cb([{route:'A12'}],'',{});
assert.equal(search.routeRows.length,0);
console.log('Unified operator search, partial failure, and stale-response handling: passed');
// Each bus has independent refresh state: one failed operator must not invalidate another.
const pending = [];
const buses = {busGeneration:0,editing:true,nowMs:now,Date,Math,Array,Object,isFinite,
  busEntries:[{co:'CTB',route:'A11',dir:'O',service:'1',stop:'001033',seq:14,walk:10}, {co:'CTB',route:'A12',dir:'O',service:'1',stop:'001382',seq:1,walk:18}],
  kmb:'kmb/',ctb:'ctb/', get:(url,cb)=>pending.push({url,cb}), localizedName:()=>'', displayRemark:()=>'', tr:k=>i18n.text('en',k)};
vm.createContext(buses);vm.runInContext([extract('entryKey'),extract('parseSourceTime'),extract('sourceTime'),extract('refresh')].join('\n'),buses);buses.refresh();
pending[1].cb([{dir:'O',seq:1,eta:new Date(now+20*60000).toISOString()}],'');
pending[0].cb(null,'network failure');
assert.equal(buses.busEntries[0].failed,true); assert.equal(buses.busEntries[1].fresh,true);
assert.equal(buses.busEntries[0].walk,10); assert.equal(buses.busEntries[1].walk,18);
console.log('Multiple bus routes: independent walking times and failure state passed');
// Adding, persisting, removing and reloading must preserve distinct settings, including an empty list.
const cfg={selection:JSON.stringify({co:'CTB',route:'A11',dir:'O',service:'1',stop:'001033',seq:14}),busWalk:10,busRoutes:''};
const state={Plasmoid:{configuration:cfg},busEntries:[],currentRoute:{co:'CTB',route:'A12',dir:'O',service:'1'},routeRows:[],stops:[],status:'',tr:k=>i18n.text('en',k),refresh:()=>{},JSON,Object,Array};
vm.createContext(state);vm.runInContext(['entryKey','persistBuses','loadBuses','chooseStop','setBusWalk','removeBus'].map(extract).join('\n'),state);
state.loadBuses(); assert.equal(state.busEntries[0].walk,10);
state.chooseStop({id:'001382',name:'Siu Sai Wan',seq:1});const a12=state.entryKey(state.busEntries[1]);state.setBusWalk(a12,18);
state.loadBuses(); assert.equal(state.busEntries.length,2);assert.equal(state.busEntries[0].walk,10);assert.equal(state.busEntries[1].walk,18);
state.removeBus(a12);const a11=state.entryKey(state.busEntries[0]);state.removeBus(a11);state.loadBuses();assert.equal(state.busEntries.length,0);
console.log('Legacy migration, separate settings, removal and empty-list persistence passed');
const nlbPending=[];
const nlbCtx={busGeneration:0,editing:true,nowMs:now,Date,Math,Array,Object,isFinite,nlb:'nlb/',kmb:'kmb/',ctb:'ctb/',
 busEntries:[{co:'NLB',route:'B6',dir:'',service:'89',stop:'317',seq:5,walk:45}],get:(url,cb)=>nlbPending.push({url,cb}),localizedName:()=>'',displayRemark:()=>'',tr:k=>i18n.text('en',k)};
vm.createContext(nlbCtx);vm.runInContext([extract('entryKey'),extract('parseSourceTime'),extract('sourceTime'),extract('refresh')].join('\n'),nlbCtx);nlbCtx.refresh();
assert.match(nlbPending[0].url,/routeId=89&stopId=317/);nlbPending[0].cb([{estimatedArrivalTime:'2026-11-20 11:00:00',noGPS:1,departed:0,generateTime:'2026-11-20 10:00:00'}],'');
assert.equal(nlbCtx.busEntries[0].arrivals[0].remarkKey,'scheduled');assert.equal(nlbCtx.busEntries[0].sourceAt,now);
assert.equal(nlbCtx.busEntries[0].arrivals[0].eta,'2026-11-20T11:00:00+08:00');assert.equal(nlbCtx.busEntries[0].walk,45);
console.log('NLB B6 route, stop and Hong Kong time conversion passed');
const stationData=loadScript('contents/code/stations.js');
assert.deepEqual(Array.from(stationData.directions('TCL','HOK')),['UP']);
assert.deepEqual(Array.from(stationData.directions('TCL','TUC')),['DOWN']);
assert.deepEqual(Array.from(stationData.directions('TCL','KOW')),['UP','DOWN']);
const rcfg={railRoutes:'',railWalk:15};
const railState={Plasmoid:{configuration:rcfg},railEntries:[],status:'',Stations:stationData,JSON,Array,Object,tr:k=>i18n.text('en',k),refreshRail:()=>{}};
vm.createContext(railState);vm.runInContext(['railKey','persistRail','loadRail','addRail','setRailWalk','removeRail'].map(extract).join('\n'),railState); railState.refreshRail=()=>{};
railState.loadRail();assert.equal(railState.railEntries.length,2);assert.equal(railState.railEntries[0].walk,15);assert.equal(railState.railEntries[1].walk,15);
railState.setRailWalk('AEL|HOK|UP',12);railState.addRail('TCL','TUC','DOWN');railState.setRailWalk('TCL|TUC|DOWN',25);railState.loadRail();
assert.equal(railState.railEntries[0].walk,12);assert.equal(railState.railEntries[1].walk,15);assert.equal(railState.railEntries[2].walk,25);
railState.removeRail('TCL|TUC|DOWN');railState.removeRail('AEL|HOK|UP');railState.removeRail('TCL|HOK|UP');railState.loadRail();assert.equal(railState.railEntries.length,0);
console.log('MTR per-station migration, separate walking times, directions and persistence passed');
assert.deepEqual(Array.from(stationData.directions('TWL','CEN')),['UP']);
assert.deepEqual(Array.from(stationData.directions('ISL','CEN')),['UP','DOWN']);
assert.equal(stationData.terminal('TWL','UP'),'TSW');
assert.equal(stationData.terminal('ISL','DOWN'),'KET');
console.log('Central station Tsuen Wan and Island line direction mapping passed');
// Destination filtering must reject short-turn services, but include trains that continue beyond the requested stop.
assert.equal(stationData.serves('TCL','HOK','UP','TSY','TUC'),false);
assert.equal(stationData.serves('TCL','HOK','UP','TUC','TSY'),true);
assert.equal(stationData.serves('ISL','CEN','DOWN','KET','SHW'),true);
assert.equal(stationData.serves('ISL','CEN','DOWN','SYP','KET'),false);
const mixed=rows(2,8,14).map((x,i)=>({...x,dest:i===0?'TSY':'TUC'}));
assert.equal(logic.estimate(mixed,now,20),null);
ctx.Plasmoid.configuration.bufferMinutes=3;
assert.equal(ctx.departureAdvice(rows(20),15,true,true),'Catch in 20 min · leave within 2 min');
ctx.Plasmoid.configuration.bufferMinutes=0;
const ageCtx={nowMs:now, freshnessMs:150000, isFinite, Date, Math};vm.createContext(ageCtx);vm.runInContext(['parseSourceTime','sourceTime','isReliable'].map(extract).join('\n'),ageCtx);
assert.equal(ageCtx.isReliable({fresh:true,sourceAt:now-149000}),true);
assert.equal(ageCtx.isReliable({fresh:true,sourceAt:now-151000}),false);
assert.equal(ageCtx.isReliable({fresh:true,sourceAt:NaN}),false);
assert.equal(ageCtx.isReliable({fresh:true,sourceAt:now+61000}),false);
assert.equal(ageCtx.parseSourceTime('2026-11-20 10:00:00'),now);
assert.equal(ageCtx.sourceTime([{data_timestamp:new Date(now-30000).toISOString()},{data_timestamp:new Date(now-60000).toISOString()}],{},'CTB'),now-60000);
console.log('Destination filtering, mixed-terminus estimates, buffer and source age passed');
const railRequests=[];
const railLive={railGeneration:0,railEntries:[{line:'TCL',station:'HOK',direction:'UP',destination:'TUC',walk:15}],Stations:stationData,Date,Array,Object,isFinite,tr:k=>i18n.text('en',k),get:(url,cb)=>railRequests.push({url,cb})};
vm.createContext(railLive);vm.runInContext(['railKey','parseSourceTime','refreshRail'].map(extract).join('\n'),railLive);railLive.refreshRail();
railRequests[0].cb({'TCL-HOK':{curr_time:'2026-11-20 10:00:00',UP:[{time:'2026-11-20 10:10:00',dest:'TSY'},{time:'2026-11-20 10:20:00',dest:'TUC'}]}},'',{status:1,curr_time:'2026-11-20 10:00:00'});
assert.equal(railLive.railEntries[0].arrivals.length,1);assert.equal(railLive.railEntries[0].arrivals[0].dest,'TUC');assert.equal(railLive.railEntries[0].sourceAt,now);
console.log('MTR response excludes a short-turn train and preserves source time');
const routeCtx={};vm.createContext(routeCtx);vm.runInContext(extract('routeNames'),routeCtx);
const city={orig_en:'North Point',dest_en:'Airport',orig_sc:'北角',dest_sc:'机场',orig_tc:'北角',dest_tc:'機場'};
assert.equal(routeCtx.routeNames(city,'CTB','O').route_sc,'北角 → 机场');
assert.equal(routeCtx.routeNames(city,'CTB','I').route_en,'Airport → North Point');
assert.equal(routeCtx.routeNames({routeName_e:'Mun Tung > Port',routeName_s:'满东邨 > 口岸',routeName_c:'滿東邨 > 口岸'},'NLB','').route_tc,'滿東邨 > 口岸');
assert.equal(ctx.rowLabel({...rows(5)[0],dest:'TUC',suppressDestination:true}),'5 min');
assert.equal(ctx.rowLabel({...rows(5)[0],dest:'TSY',suppressDestination:false}),'5 min (TSY)');
assert.equal(ctx.rowLabel({...rows(5)[0],remarkKey:'scheduled'}),'5 min');
assert.equal(ctx.rowLabel({...rows(5)[0],rmk_en:'Scheduled Bus'}),'5 min');
assert.equal(ctx.rowLabel({...rows(5)[0],rmk_en:'Diversion'}),'5 min (Diversion)');
console.log('Localized route names, per-language remarks and short-turn labels passed');
