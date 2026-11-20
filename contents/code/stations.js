.pragma library
var routes = {
 AEL: ['HOK','KOW','TSY','AIR','AWE'],
 TCL: ['HOK','KOW','OLY','NAC','LAK','TSY','SUN','TUC'],
 TWL: ['CEN','ADM','TST','JOR','YMT','MOK','PRE','SSP','CSW','LCK','MEF','LAK','KWF','KWH','TWH','TSW'],
 ISL: ['KET','HKU','SYP','SHW','CEN','ADM','WAC','CAB','TIH','FOH','NOP','QUB','TAK','SWH','SKW','HFC','CHW']
};
var names = {
 HOK:['Hong Kong','香港','香港'], KOW:['Kowloon','九龙','九龍'], TSY:['Tsing Yi','青衣','青衣'], AIR:['Airport','机场','機場'], AWE:['AsiaWorld-Expo','博览馆','博覽館'],
 OLY:['Olympic','奥运','奧運'], NAC:['Nam Cheong','南昌','南昌'], LAK:['Lai King','荔景','荔景'], SUN:['Sunny Bay','欣澳','欣澳'], TUC:['Tung Chung','东涌','東涌'],
 CEN:['Central','中环','中環'], ADM:['Admiralty','金钟','金鐘'], TST:['Tsim Sha Tsui','尖沙咀','尖沙咀'], JOR:['Jordan','佐敦','佐敦'], YMT:['Yau Ma Tei','油麻地','油麻地'], MOK:['Mong Kok','旺角','旺角'], PRE:['Prince Edward','太子','太子'], SSP:['Sham Shui Po','深水埗','深水埗'], CSW:['Cheung Sha Wan','长沙湾','長沙灣'], LCK:['Lai Chi Kok','荔枝角','荔枝角'], MEF:['Mei Foo','美孚','美孚'], KWF:['Kwai Fong','葵芳','葵芳'], KWH:['Kwai Hing','葵兴','葵興'], TWH:['Tai Wo Hau','大窝口','大窩口'], TSW:['Tsuen Wan','荃湾','荃灣'],
 KET:['Kennedy Town','坚尼地城','堅尼地城'], HKU:['HKU','香港大学','香港大學'], SYP:['Sai Ying Pun','西营盘','西營盤'], SHW:['Sheung Wan','上环','上環'], WAC:['Wan Chai','湾仔','灣仔'], CAB:['Causeway Bay','铜锣湾','銅鑼灣'], TIH:['Tin Hau','天后','天后'], FOH:['Fortress Hill','炮台山','炮台山'], NOP:['North Point','北角','北角'], QUB:['Quarry Bay','鲗鱼涌','鰂魚涌'], TAK:['Tai Koo','太古','太古'], SWH:['Sai Wan Ho','西湾河','西灣河'], SKW:['Shau Kei Wan','筲箕湾','筲箕灣'], HFC:['Heng Fa Chuen','杏花邨','杏花邨'], CHW:['Chai Wan','柴湾','柴灣']
};
function stationName(code, lang) { var row=names[code]; return row ? row[lang==='en'?0:lang==='sc'?1:2] : code; }
function directions(line, station) {
 var list=routes[line] || [], index=list.indexOf(station), result=[];
 if (index < 0) return result;
 if (index < list.length-1) result.push('UP');
 if (index > 0) result.push('DOWN');
 return result;
}
function terminal(line, direction) { var a=routes[line] || []; return a.length ? (direction === 'UP' ? a[a.length-1] : a[0]) : ''; }
function destinations(line, station, direction) {
 var a=routes[line] || [], i=a.indexOf(station); if (i<0) return [];
 return direction==='UP' ? a.slice(i+1) : a.slice(0,i).reverse();
}
function serves(line, station, direction, terminalCode, target) {
 if (!target) return true;
 var a=routes[line] || [], origin=a.indexOf(station), terminal=a.indexOf(terminalCode), goal=a.indexOf(target);
 if (origin<0 || terminal<0 || goal<0) return false;
 return direction==='UP' ? terminal>=goal && goal>origin : terminal<=goal && goal<origin;
}
