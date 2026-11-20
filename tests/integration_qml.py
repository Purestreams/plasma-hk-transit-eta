import os,sys,tempfile,shutil,time
os.environ['QT_QPA_PLATFORM']='offscreen'
from pathlib import Path
from PySide6.QtCore import QUrl,QObject,QEventLoop,QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
package=Path(__file__).resolve().parent.parent
src=(package/'contents/ui/main.qml').read_text()
src=src.replace('import org.kde.plasma.plasmoid\n','')
src=src.replace('PlasmoidItem {','Item {\n    property QtObject configuration: QtObject { property string selection: JSON.stringify({co:"CTB",route:"A11",dir:"O",service:"1",stop:"001033",stopName:"皇后像廣場",seq:14}); property string busRoutes: ""; property string railRoutes: ""; property string language: "sc"; property int busWalk: 10; property int railWalk: 15; property int bufferMinutes: 0; property bool notifyEnabled: false }',1)
src=src.replace('    Plasmoid.icon: Qt.resolvedUrl("../icons/transit.svg")\n','').replace('Plasmoid.configuration.','configuration.')
src=src.replace('    fullRepresentation: Item {','    Item {\n        anchors.fill: parent',1)
src=src.replace('id: routeInput;', 'id: routeInput; objectName: "routeInput";')
src=src.replace('PlasmaComponents.Button { text: root.tr("search");', 'PlasmaComponents.Button { objectName: "searchButton"; text: root.tr("search");')
src=src.replace('ListView { model: root.routeRows;', 'ListView { objectName: "routeList"; model: root.routeRows;')
src=src.replace('ListView { model: root.stops.filter', 'ListView { objectName: "stopList"; model: root.stops.filter')
src=src.replace('width: ListView.view.width; text: modelData.label;', 'objectName: "routeDelegate"; width: ListView.view.width; text: modelData.label;')
src=src.replace('width: ListView.view.width; text: modelData.seq +', 'objectName: "stopDelegate"; width: ListView.view.width; text: modelData.seq +')
scratch=tempfile.TemporaryDirectory(prefix='hk-transit-qml-'); base=Path(scratch.name)/'contents';(base/'ui').mkdir(parents=True,exist_ok=True);shutil.copytree(package/'contents/code',base/'code',dirs_exist_ok=True);(base/'ui/main.qml').write_text(src)
app=QGuiApplication([]);engine=QQmlApplicationEngine();engine.load(QUrl.fromLocalFile(str((base/'ui/main.qml').resolve())))
if not engine.rootObjects(): sys.exit('QML failed to load')
root=engine.rootObjects()[0]
window=QQuickWindow(); window.resize(420,600); root.setParentItem(window.contentItem()); window.show(); app.processEvents()
def wait_for(fn,sec=35):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  app.processEvents(); result=fn()
  if result:return result
  time.sleep(.02)
 raise TimeoutError('status='+str(root.property('status')))
root.setProperty('editing',True); app.processEvents()
route=root.findChild(QObject,'routeInput');button=root.findChild(QObject,'searchButton'); assert route and button
route.setProperty('text','A12');button.clicked.emit()
route_list=root.findChild(QObject,'routeList')
wait_for(lambda: route_list.property('count') > 0)
print('A12 route count:',route_list.property('count'),'status:',root.property('status'),flush=True)
print('list geometry:',route_list.property('width'),route_list.property('height'),route_list.property('visible'), 'children',len(route_list.childItems()),flush=True)
r=wait_for(lambda: next((x for x in route_list.childItems()[0].childItems() if x.objectName() == 'routeDelegate' and '小西湾' in str(x.property('text')) and str(x.property('text')).index('小西湾') < str(x.property('text')).index('→')),None),5)
print('Select route:',r.property('text'),flush=True);r.clicked.emit()
stop_list=root.findChild(QObject,'stopList')
wait_for(lambda: stop_list.property('count') > 0,90)
print('Stop count:',stop_list.property('count'),'status:',root.property('status'),flush=True)
stop=wait_for(lambda: next((x for x in stop_list.childItems()[0].childItems() if x.objectName() == 'stopDelegate'),None))
print('Select stop:',stop.property('text'),flush=True);stop.clicked.emit()
import json
conf=root.property('configuration')
saved=json.loads(conf.property('busRoutes'))
print('Saved routes:',[(x['route'],x['stopName'],x['walk']) for x in saved],flush=True)
assert len(saved)==2 and saved[0]['route']=='A11' and saved[0]['walk']==10
assert saved[1]['route']=='A12' and saved[1]['walk']==-1
key='|'.join(str(saved[1][x]) for x in ('co','route','dir','service','stop','seq'))
def visual_find(item, name):
 if item.objectName()==name: return item
 for child in item.childItems():
  result=visual_find(child,name)
  if result: return result
 return None
spin=wait_for(lambda: visual_find(root,'busWalk_'+key))
spin.setProperty('value',18); spin.valueModified.emit(); app.processEvents()
saved=json.loads(conf.property('busRoutes'))
assert saved[0]['walk']==10 and saved[1]['walk']==18
print('Two independent walking times preserved:', [(x['route'],x['walk']) for x in saved],flush=True)
rail=json.loads(conf.property('railRoutes'))
assert len(rail)==2 and all(x['walk']==15 for x in rail)
rail_spin=wait_for(lambda: visual_find(root,'railWalk_AEL|HOK|UP'))
rail_spin.setProperty('value',12);rail_spin.valueModified.emit();app.processEvents()
rail=json.loads(conf.property('railRoutes'))
assert rail[0]['walk']==12 and rail[1]['walk']==15
print('MTR migration and independent walking times passed',flush=True)
dest=wait_for(lambda: visual_find(root,'railDestination_TCL|HOK|UP'))
codes=dest.property('codes');codes=codes.toVariant() if hasattr(codes,'toVariant') else codes
assert 'TUC' in codes
i=codes.index('TUC');dest.setProperty('currentIndex',i);dest.activated.emit(i);app.processEvents()
rail=json.loads(conf.property('railRoutes'));assert next(x for x in rail if x['line']=='TCL')['destination']=='TUC'
print('MTR intended destination selected and persisted',flush=True)
line=root.findChild(QObject,'railLine'); station=root.findChild(QObject,'railStation'); direction=root.findChild(QObject,'railDirection'); add=root.findChild(QObject,'addRailButton')
line.setProperty('currentIndex',1);app.processEvents();station.setProperty('currentIndex',7);app.processEvents()
assert station.property('code')=='TUC' and direction.property('code')=='DOWN'
add.clicked.emit();app.processEvents()
rail=json.loads(conf.property('railRoutes'))
assert len(rail)==3 and rail[-1]['line']=='TCL' and rail[-1]['station']=='TUC' and rail[-1]['direction']=='DOWN' and rail[-1]['walk']==-1
print('Added Tung Chung station towards Hong Kong from UI controls',flush=True)
wait_for(lambda: any(x.get('station')=='TUC' and (x.get('fresh') or x.get('failed')) for x in root.property('railEntries').toVariant()),25)
assert next(x for x in root.property('railEntries').toVariant() if x['station']=='TUC')['fresh']
print('Tung Chung station live MTR request succeeded',flush=True)
line.setProperty('currentIndex',2);app.processEvents();station.setProperty('currentIndex',0);app.processEvents()
assert station.property('code')=='CEN' and direction.property('code')=='UP'
add.clicked.emit();app.processEvents();rail_spin=wait_for(lambda: visual_find(root,'railWalk_TWL|CEN|UP'));rail_spin.setProperty('value',8);rail_spin.valueModified.emit();app.processEvents()
line.setProperty('currentIndex',3);app.processEvents();station.setProperty('currentIndex',4);app.processEvents()
assert station.property('code')=='CEN' and direction.property('code')=='UP';add.clicked.emit();app.processEvents()
rail_spin=wait_for(lambda: visual_find(root,'railWalk_ISL|CEN|UP'));rail_spin.setProperty('value',12);rail_spin.valueModified.emit();app.processEvents()
rail=json.loads(conf.property('railRoutes'));assert next(x for x in rail if x['line']=='TWL')['walk']==8 and next(x for x in rail if x['line']=='ISL')['walk']==12
print('Central station TWL 8 min and ISL 12 min configured via UI controls',flush=True)
wait_for(lambda: any(x.get('route')=='A12' and (x.get('fresh') or x.get('failed')) for x in root.property('busEntries').toVariant()),25)
entries=root.property('busEntries').toVariant(); assert next(x for x in entries if x['route']=='A12')['fresh']
print('A12 live ETA request succeeded',flush=True)
wait_for(lambda: next((x for x in root.property('busEntries').toVariant() if x['route']=='A11' and x.get('route_en') and x.get('route_sc') and x.get('route_tc') and x.get('name_en')),None),25)
legacy=next(x for x in root.property('busEntries').toVariant() if x['route']=='A11')
print('Legacy A11 three-language route and stop names:', legacy['route_sc'], '/', legacy['route_en'],flush=True)
remove_bus=wait_for(lambda: visual_find(root,'removeBus_'+key))
remove_bus.clicked.emit();app.processEvents()
saved=json.loads(conf.property('busRoutes'));assert len(saved)==1 and saved[0]['route']=='A11' and saved[0]['walk']==10
remove_rail=wait_for(lambda: visual_find(root,'removeRail_ISL|CEN|UP'))
remove_rail.clicked.emit();app.processEvents()
rail=json.loads(conf.property('railRoutes'));assert not any(x['line']=='ISL' for x in rail)
root.loadBuses();root.loadRail();app.processEvents()
assert len(root.property('busEntries').toVariant())==1
assert not any(x['line']=='ISL' for x in root.property('railEntries').toVariant())
print('UI removal persisted across reload for buses and MTR, preserving other entries',flush=True)
print('REAL QML SEARCH/ROUTE/STOP TEST PASSED',flush=True)
