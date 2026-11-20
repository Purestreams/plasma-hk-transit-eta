import os,time,tempfile,shutil,sys
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen'
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication,QColor,QPalette
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
pkg=Path(__file__).resolve().parent.parent; language=sys.argv[1]; out=Path(sys.argv[2]).resolve()
s=(pkg/'contents/ui/main.qml').read_text()
s=s.replace('import org.kde.plasma.plasmoid\n','').replace('PlasmoidItem {', 'Item {\n property QtObject configuration: QtObject { property string language: "'+language+'"; property int bufferMinutes: 0; property bool notifyEnabled: false }',1)
s=s.replace('    Plasmoid.icon: Qt.resolvedUrl("../icons/transit.svg")\n','').replace('Plasmoid.configuration.','configuration.').replace('    fullRepresentation: Item {','    Item { anchors.fill: parent',1)
s=s.replace('PlasmaComponents.Button { text: root.editing ? root.tr("done") : root.tr("settings");', 'PlasmaComponents.Button { contentItem: PlasmaComponents.Label { text: root.editing ? root.tr("done") : root.tr("settings"); color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } text: root.editing ? root.tr("done") : root.tr("settings");', 1)
s=s.replace('Component.onCompleted: { nowMs = Date.now(); loadBuses(); loadRail(); refreshRouteNames(); refreshStopNames(); refresh(); refreshRail() }','''Component.onCompleted: {
 nowMs=Date.now(); let x=nowMs;
 let b1=[{eta:new Date(x+720000).toISOString()},{eta:new Date(x+1740000).toISOString()}];
 let b2=[{eta:new Date(x+600000).toISOString()},{eta:new Date(x+1800000).toISOString()},{eta:new Date(x+2700000).toISOString()}];
 let r1=[{eta:new Date(x+480000).toISOString(),dest:"AWE",suppressDestination:true},{eta:new Date(x+1080000).toISOString(),dest:"AWE",suppressDestination:true},{eta:new Date(x+1680000).toISOString(),dest:"AWE",suppressDestination:true}];
 let r2=[{eta:new Date(x+360000).toISOString(),dest:"TUC",suppressDestination:true},{eta:new Date(x+840000).toISOString(),dest:"TUC",suppressDestination:true},{eta:new Date(x+1260000).toISOString(),dest:"TUC",suppressDestination:true}];
 busEntries=[{co:"CTB",route:"A11",dir:"O",stop:"001033",seq:14,service:"1",name_en:"Statue Square, Connaught Road Central",name_sc:"皇后像广场，干诺道中",name_tc:"皇后像廣場，干諾道中",route_en:"North Point Ferry Pier → Airport",route_sc:"北角码头 → 机场",route_tc:"北角碼頭 → 機場",walk:10,fresh:true,sourceAt:x,arrivals:b1},{co:"NLB",route:"B6",dir:"",stop:"317",seq:5,service:"89",name_en:"Tung Chung Tat Tung Road Bus Terminus",name_sc:"东涌达东路巴士总站",name_tc:"東涌達東路巴士總站",route_en:"Mun Tung Estate → HZMB Hong Kong Port",route_sc:"满东邨 → 大桥香港口岸",route_tc:"滿東邨 → 大橋香港口岸",walk:25,fresh:true,sourceAt:x,arrivals:b2}];
 railEntries=[{line:"AEL",station:"HOK",direction:"UP",walk:15,fresh:true,sourceAt:x,arrivals:r1},{line:"TCL",station:"HOK",direction:"UP",walk:15,fresh:true,sourceAt:x,arrivals:r2}];
 }''')
t=tempfile.TemporaryDirectory();base=Path(t.name)/'contents';(base/'ui').mkdir(parents=True);shutil.copytree(pkg/'contents/code',base/'code');(base/'ui/main.qml').write_text(s)
app=QGuiApplication([])
palette=app.palette()
for role,color in [(QPalette.Window,'#f4f6f8'),(QPalette.WindowText,'#22262b'),(QPalette.Base,'#ffffff'),(QPalette.Text,'#22262b'),(QPalette.Button,'#e1e5e9'),(QPalette.ButtonText,'#22262b')]: palette.setColor(role,QColor(color))
app.setPalette(palette)
engine=QQmlApplicationEngine();engine.load(QUrl.fromLocalFile(str(base/'ui/main.qml')))
if not engine.rootObjects():raise RuntimeError('QML load failed')
root=engine.rootObjects()[0];window=QQuickWindow();window.resize(420,600);window.setColor(QColor('#f4f6f8'));root.setParentItem(window.contentItem());window.show()
for i in range(100):app.processEvents();time.sleep(.01)
img=window.grabWindow()
if img.isNull() or not img.save(str(out)):raise RuntimeError('Could not save screenshot')
print(language, out, img.width(), img.height())
