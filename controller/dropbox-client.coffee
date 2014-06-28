
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxClientController extends KDController

  HELPER_SCRIPT = "https://rest.kd.io/gokmen/Dropbox.kdapp/master/resources/dropbox.py"
  DROPBOX = "/tmp/_dropbox.py"
  DROPBOX_FOLDER = "/home/#{KD.nick()}/Dropbox"
  HELPER  = "python #{DROPBOX}"
  [IDLE, RUNNING, HELPER_FAILED, WAITING_FOR_REGISTER,
   NOT_INSTALLED, AUTH_LINK_FOUND, NO_FOLDER_EXCLUDED,
   LIST_OF_EXCLUDED, EXCLUDE_SUCCEED] = [0..8]

  constructor:(options = {}, data)->

    {dropboxController} = KD.singletons
    return dropboxController if dropboxController

    super options, data

    @kiteHelper = new KiteHelper
    @kiteHelper.ready =>
      @createDropboxDirectory @lazyBound 'emit', 'ready'

    @registerSingleton "dropboxController", this, yes

  announce:(message, busy)->
    @emit "status-update", message, busy

  init:->

    @_lastState = IDLE
    @kiteHelper.getKite().then (kite)=>
      kite.fsExists(path : DROPBOX).then (state)=>
        if not state
          @_lastState = HELPER_FAILED
          @announce "Dropbox helper is not available, fixing...", yes
          @installHelper (err, state)=>
            if err or not state
              @announce "Failed to install helper, please try again"
            else
              @init()
        else
          @updateStatus yes

  install:(callback)->

    @announce "Installing Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} install", (err, res)=>
      if err
        @announce "Failed to install Dropbox, please try again."
      else
        KD.utils.wait 2000, =>
          @_lastState = IDLE
          @announce "Dropbox installed successfully, you can start the daemon now"

  start:->
 
    @announce "Starting Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} start;", 10000, @bound 'updateStatus'
    
  stop:->

    @announce "Stoping Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} stop", 10000, @bound 'updateStatus'

  getAuthLink:(callback)->
    @kiteHelper.run "#{HELPER} link", (err, res)->
      if not err and res.exitStatus is AUTH_LINK_FOUND
        callback null, res.stdout.match /https\S+/
      else
        callback {message: "Failed to fetch auth link."}

  installHelper:(callback)->

    @kiteHelper.run \
      "wget #{HELPER_SCRIPT} -O #{DROPBOX}", callback

  updateStatus:(keepCurrentState = no)->

    return  if @_locked or @_stopped

    @_locked = yes
    unless keepCurrentState
      @announce null, yes

    @kiteHelper.run "#{HELPER} status", (err, res)=>
      message = "Failed to fetch state."

      unless err
        message = res.stdout
        @_previousLastState = @_lastState
        @_lastState = res.exitStatus

      @announce message
      @_locked = no

  createDropboxDirectory:(cb)->
    @kiteHelper.run """
      mkdir -p #{DROPBOX_FOLDER};
      mkdir -p #{DROPBOX_FOLDER}/Koding;
    """, cb
  
  excludeFolders: ->
    @kiteHelper.run "#{HELPER} exclude add #{DROPBOX_FOLDER}/*;", 5000, log

  excludeButKoding: ->
      @excludeFolders()
      interval = KD.utils.repeat 6000, @excludeFolders.bind this
      
      KD.utils.wait 60000, =>
          KD.utils.killRepeat interval
          
          @kiteHelper.run "#{HELPER} exclude remove #{DROPBOX_FOLDER}/Koding;", 5000, log