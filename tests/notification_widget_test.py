import os,sys,tempfile,shutil,time
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen'
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
package=Path(__file__).resolve().parent.parent
src=(package/'contents/ui/main.qml').read_text()
src=src.replace('import org.kde.plasma.plasmoid\n','').replace('PlasmoidItem {','Item {\n property QtObject configuration: QtObject { property string language: "sc"; property int bufferMinutes: 0; property bool notifyEnabled: true }',1).replace('    Plasmoid.icon: Qt.resolvedUrl("../icons/transit.svg")\n','').replace('Plasmoid.configuration.','configuration.').replace('    fullRepresentation: Item {','    property Component fullRepresentation: Component { Item {',1)
# The full visual representation is not needed for this isolated notification test.
pos=src.index('    property Component fullRepresentation: Component { Item {')
src=src[:pos]+'}\n'
src=src.replace('Component.onCompleted: { nowMs = Date.now(); loadBuses(); loadRail(); refreshRouteNames(); refreshStopNames(); refresh(); refreshRail() }','''Component.onCompleted: {
 nowMs = Date.now();
 busEntries = [{co:"CTB",route:"A11",dir:"O",service:"1",stop:"001033",stopName:"Test stop",seq:14,walk:10,fresh:true,failed:false,sourceAt:nowMs,arrivals:[{eta:new Date(nowMs + 630000).toISOString()}]}];
 checkNotifications(); checkNotifications();
 }''')
scratch=tempfile.TemporaryDirectory();base=Path(scratch.name)/'contents';(base/'ui').mkdir(parents=True);shutil.copytree(package/'contents/code',base/'code');(base/'ui/main.qml').write_text(src)
app=QGuiApplication([]);engine=QQmlApplicationEngine();engine.load(QUrl.fromLocalFile(str(base/'ui/main.qml')))
if not engine.rootObjects():sys.exit('failed to load')
end=time.monotonic()+3
while time.monotonic()<end:app.processEvents();time.sleep(.02)
