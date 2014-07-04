
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxMainView extends KDView

  DROPBOX_FOLDER = "/home/#{KD.nick()}/Dropbox"
  [IDLE, RUNNING, HELPER_FAILED, WAITING_FOR_REGISTER,
   NOT_INSTALLED, AUTH_LINK_FOUND, NO_FOLDER_EXCLUDED,
   LIST_OF_EXCLUDED, EXCLUDE_SUCCEED] = [0..8]

  constructor:(options = {}, data)->
    options.cssClass = 'dropbox'
    super options, data

    new DropboxClientController
    @logger = new AppLogger
    @logger.info "Logger initialized."

  viewAppended:->

    dbc = KD.singletons.dropboxController
    
    # @addSubView @logger
    @addSubView container = new KDView
      cssClass : 'container'

    container.addSubView new KDView
      cssClass : "dropbox-logo"

    container.addSubView @reloadButton = new KDButtonView
      cssClass : 'reload-button hidden'
      iconOnly : yes
      callback : ->
        dbc.announce "Checking state...", yes
        dbc.updateStatus yes

    container.addSubView mcontainer = new KDView
      cssClass : "status-message"

    mcontainer.addSubView @loader = new KDLoaderView
      showLoader : yes
      size       : width : 20

    mcontainer.addSubView @message = new KDView
      cssClass : 'message'
      partial  : "Please wait while your vm turns on..."

    container.addSubView @details = new KDView
      cssClass : 'details hidden'
      click: (e)->
        dbc.updateStatus()  if $(e.target).is 'cite'

    container.addSubView @toggle = new KDToggleButton
      style        : "solid green db-toggle hidden"
      defaultState : "Start Dropbox"
      loader       :
        color      : "#666"
        diameter   : 16
      states       : [
        title      : "Start Dropbox"
        callback   : -> this.hide(); dbc.start()
      ,
        title      : "Stop Dropbox"
        callback   : =>
          @toggle.hide(); dbc.stop();
          @finder.hide()
      ]

    container.addSubView @installButton = new KDButtonView
      title    : "Install Dropbox"
      cssClass : "solid green db-install hidden"
      callback : ->
        @hide(); dbc.install()


    @finderController = new NFinderController

    @finderController.on "FileNeedsToBeOpened", (file) =>
      {appManager, router} = KD.singletons
      appManager.openFile file
      KD.utils.wait 100, -> router.handleRoute "/Ace"

    # Temporary fix, until its fixed in upstream ~ GG
    @finderController.isNodesHiddenFor = -> yes
    @addSubView @finder = @finderController.getView()

    @finder.show = ->
      @unsetClass 'hidden'
      @setClass 'filemode'
      container.setClass 'filemode'

    @finder.hide = ->
      return  if @hasClass 'hidden'
      @unsetClass 'filemode'
      container.unsetClass 'filemode'
      @setClass 'hidden'

    dbc.on "status-update", (message, busy)=>

      @loader[if busy then "show" else "hide"]()
      @reloadButton[if busy then "hide" else "show"]()

      @message.updatePartial message  if message

      if message
        @logger.info message, "| State:", dbc._lastState

      @toggle.hideLoader()

      return  if busy

      if dbc._lastState is IDLE then @toggle.show()

      if dbc._lastState in [RUNNING, WAITING_FOR_REGISTER]
        @toggle.setState "Stop Dropbox"
        # if dbc._lastState is RUNNING
        #   KD.utils.defer ->
        #     KD.utils.killWait dbc._timer
        #     dbc._timer = KD.utils.wait 4000, dbc.bound 'updateStatus'
      else
        @toggle.setState "Start Dropbox"

      if dbc._lastState is NOT_INSTALLED
        @installButton.show()
        @toggle.hide()
      else
        @installButton.hide()
        if dbc._lastState is HELPER_FAILED
        then @loader.show()
        else @toggle.show()

      @finder[if dbc._lastState is RUNNING then "show" else "hide"]()

      if dbc._lastState is WAITING_FOR_REGISTER
        
        dbc.getAuthLink (err, link)=>

          if err
            {message} = err
            message = """#{err.message} <cite>Retry</cite>"""
          else
            message = """
              Please visit <a href="#{link}" target=_blank>#{link}</a> to link
              your Koding VM with your Dropbox account."""
            KD.utils.wait 2500, dbc.bound 'updateStatus'
          
          @details.updatePartial message
          @details.show()

      else
        @details.hide()
        
      if dbc._previousLastState is WAITING_FOR_REGISTER and dbc._lastState is RUNNING
        dbc.excludeButKoding()

    dbc.ready =>
      vm = dbc.kiteHelper.getVm()
      vm.path = DROPBOX_FOLDER + "/Koding"
      @finderController.mountVm vm

    KD.utils.defer -> dbc.init()
