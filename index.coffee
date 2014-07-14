
# Dropbox Installer for Koding
# 2014 - Brian Vallelunga <bvallelunga@koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

do ->

  # In live mode you can add your App view to window's appView
  if appView?
    view = new DropboxMainView
    appView.addSubView view
  
  else
    KD.registerAppClass DropboxController,
      name     : "Dropbox"
      routes   :
        "/:name?/Dropbox" : null
        "/:name?/bvallelunga/Apps/Dropbox" : null
      dockPath : "/bvallelunga/Apps/Dropbox"
      behavior : "application"
