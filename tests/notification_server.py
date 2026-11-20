import dbus,dbus.service,dbus.mainloop.glib
from gi.repository import GLib
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus=dbus.SessionBus();name=dbus.service.BusName('org.freedesktop.Notifications',bus)
class Service(dbus.service.Object):
 @dbus.service.method('org.freedesktop.Notifications',in_signature='susssasa{sv}i',out_signature='u')
 def Notify(self,app,replace,icon,summary,body,actions,hints,timeout):
  print('NOTIFICATION',summary,body,flush=True);return dbus.UInt32(1)
 @dbus.service.method('org.freedesktop.Notifications',in_signature='',out_signature='as')
 def GetCapabilities(self):return ['body']
 @dbus.service.method('org.freedesktop.Notifications',in_signature='',out_signature='ssss')
 def GetServerInformation(self):return ('Test','Test','1','1.2')
Service(name,'/org/freedesktop/Notifications');print('READY',flush=True);GLib.MainLoop().run()
