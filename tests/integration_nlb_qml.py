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
route.setProperty('text','B6');button.clicked.emit()
route_list=root.findChild(QObject,'routeList')
wait_for(lambda: route_list.property('count') > 0)
print('B6 route count:',route_list.property('count'),'status:',root.property('status'),flush=True)
print('list geometry:',route_list.property('width'),route_list.property('height'),route_list.property('visible'), 'children',len(route_list.childItems()),flush=True)
r=wait_for(lambda: next((x for x in route_list.childItems()[0].childItems() if x.objectName() == 'routeDelegate' and '满东邨' in str(x.property('text')) and str(x.property('text')).index('满东邨') < str(x.property('text')).index('>')),None),5)
print('Select route:',r.property('text'),flush=True);r.clicked.emit()
stop_list=root.findChild(QObject,'stopList')
wait_for(lambda: stop_list.property('count') > 0,90)
print('Stop count:',stop_list.property('count'),'status:',root.property('status'),flush=True)
stop=wait_for(lambda: next((x for x in stop_list.childItems()[0].childItems() if x.objectName() == 'stopDelegate' and '东涌达东路' in str(x.property('text'))),None))
print('Select stop:',stop.property('text'),flush=True);stop.clicked.emit()
import json
conf=root.property('configuration')
saved=json.loads(conf.property('busRoutes'))
print('Saved routes:',[(x['route'],x['stopName'],x['walk']) for x in saved],flush=True)
assert len(saved)==2 and saved[0]['route']=='A11' and saved[0]['walk']==10
assert saved[1]['route']=='B6' and saved[1]['walk']==-1
key='|'.join(str(saved[1][x]) for x in ('co','route','dir','service','stop','seq'))
def visual_find(item, name):
 if item.objectName()==name: return item
 for child in item.childItems():
  result=visual_find(child,name)
  if result: return result
 return None
spin=wait_for(lambda: visual_find(root,'busWalk_'+key))
spin.setProperty('value',45); spin.valueModified.emit(); app.processEvents()
saved=json.loads(conf.property('busRoutes'))
assert saved[0]['walk']==10 and saved[1]['walk']==45
print('Two independent walking times preserved:', [(x['route'],x['walk']) for x in saved],flush=True)
rail=json.loads(conf.property('railRoutes'))
assert len(rail)==2 and all(x['walk']==15 for x in rail)
rail_spin=wait_for(lambda: visual_find(root,'railWalk_AEL|HOK|UP'))
rail_spin.setProperty('value',12);rail_spin.valueModified.emit();app.processEvents()
rail=json.loads(conf.property('railRoutes'))
assert rail[0]['walk']==12 and rail[1]['walk']==15
print('MTR migration and independent walking times passed',flush=True)
wait_for(lambda: any(x.get('route')=='B6' and (x.get('fresh') or x.get('failed')) for x in root.property('busEntries').toVariant()),25)
entries=root.property('busEntries').toVariant(); assert next(x for x in entries if x['route']=='B6')['fresh']
b6=next(x for x in entries if x['route']=='B6')
assert b6.get('sourceAt',0)>0
print('NLB source timestamp:',b6['sourceAt'],'arrival remarks:',[x.get('remark') for x in b6.get('arrivals',[])],flush=True)
print('B6 live ETA request succeeded',flush=True)
print('REAL QML B6 SEARCH/ROUTE/STOP TEST PASSED',flush=True)
