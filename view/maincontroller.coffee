
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxController extends AppController

  constructor:(options = {}, data)->
    options.view    = new DropboxMainView
    options.appInfo =
      name : "Dropbox"
      type : "application"

    super options, data

    {@logger} = @getView()
    {dropboxController} = KD.singletons

    updateStatus = (state)=>
      dropboxController._stopped = !state
      if state
        @logger.info "Dropbox app is active now, check status."
        dropboxController.updateStatus()
      else
        @logger.info "Dropbox app lost the focus, stop polling."

    {windowController, appManager} = KD.singletons

    appManager.on 'AppIsBeingShown', (app)=>
      updateStatus app.getId() is @getId()

    windowController.addFocusListener (state)=>
      if appManager.frontApp.getId() is @getId()
        updateStatus state

  enableLogs:->
    view = @getView()
    return  if view.logger.parentIsInDom
    view.addSubView view.logger
