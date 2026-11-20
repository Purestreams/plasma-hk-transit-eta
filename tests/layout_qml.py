import os,time,tempfile,shutil
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen'
from PySide6.QtCore import QUrl,QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
pkg=Path(__file__).resolve().parent.parent;s=(pkg/'contents/ui/main.qml').read_text()
s=s.replace('import org.kde.plasma.plasmoid\n','').replace('PlasmoidItem {','Item {\n property QtObject configuration: QtObject { property string language: "sc"; property int bufferMinutes: 0; property bool notifyEnabled: false }',1).replace('    Plasmoid.icon: Qt.resolvedUrl("../icons/transit.svg")\n','').replace('Plasmoid.configuration.','configuration.').replace('    fullRepresentation: Item {','    Item { anchors.fill: parent',1)
s=s.replace('Component.onCompleted: { nowMs = Date.now(); loadBuses(); loadRail(); refreshRouteNames(); refreshStopNames(); refresh(); refreshRail() }','''Component.onCompleted: {
 nowMs=Date.now(); let x=nowMs; let a=[{eta:new Date(x+600000).toISOString()},{eta:new Date(x+1200000).toISOString()}];
 busEntries=[{co:"CTB",route:"A11",dir:"O",stop:"001033",seq:14,service:"1",name_sc:"皇后像广场, 干诺道中",route_sc:"北角码头 → 机场 (经港珠澳大桥香港口岸)",walk:10,fresh:true,sourceAt:x,arrivals:a},{co:"NLB",route:"B6",dir:"",stop:"317",seq:5,service:"89",name_sc:"东涌达东路巴士总站",route_sc:"满东邨 → 大桥香港口岸",walk:45,fresh:true,sourceAt:x,arrivals:a}];
 railEntries=[{line:"AEL",station:"HOK",direction:"UP",walk:15,fresh:true,sourceAt:x,arrivals:a},{line:"TCL",station:"HOK",direction:"UP",walk:15,fresh:true,sourceAt:x,arrivals:a}]
 }''')
t=tempfile.TemporaryDirectory();base=Path(t.name)/'contents';(base/'ui').mkdir(parents=True);shutil.copytree(pkg/'contents/code',base/'code');(base/'ui/main.qml').write_text(s)
app=QGuiApplication([]);engine=QQmlApplicationEngine();engine.load(QUrl.fromLocalFile(str(base/'ui/main.qml')));assert engine.rootObjects(); root=engine.rootObjects()[0]; window=QQuickWindow();window.resize(420,600);root.setParentItem(window.contentItem());window.show()
for i in range(25):app.processEvents();time.sleep(.01)
v=root.findChild(QObject,'dashboardScroll');print('Dashboard viewport:',v.property('height'),'content height:',v.property('contentHeight'));assert v.property('contentHeight')<=v.property('height'), 'Four entries do not fit';print('Four representative entries fit')
