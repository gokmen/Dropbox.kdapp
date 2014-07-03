
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxClientController extends KDController

  USER                = KD.nick()
  HELPER_SCRIPT       = "https://rest.kd.io/bvallelunga/Dropbox.kdapp/master/resources/dropbox.py"
  CRON_SCRIPT         = "https://rest.kd.io/bvallelunga/Dropbox.kdapp/master/resources/dropbox.sh"
  DROPBOX_APP_FOLDER  = "/home/#{USER}/.dropbox-app"
  DROPBOX             = "#{DROPBOX_APP_FOLDER}/dropbox.py"
  CRON                = "#{DROPBOX_APP_FOLDER}/dropbox.sh"
  DROPBOX_FOLDER      = "/home/#{USER}/Dropbox"
  HELPER              = "python #{DROPBOX}"
  CRON_HELPER         = "bash #{CRON}" 
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
    @kiteHelper.run " #{HELPER} start;", 10000, @bound 'updateStatus'
    
  stop:->

    @announce "Stoping Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} stop", 10000, @bound 'updateStatus'

  getAuthLink:(callback)->
    
    @kiteHelper.run "#{HELPER} link", (err, res)->
      if not err and res.exitStatus is AUTH_LINK_FOUND
        callback null, res.stdout.match /https\S+/
      else
        callback {message: "Failed to fetch auth link."}
  
  installHelper:(cb)->
    
    @kiteHelper.run """
      mkdir -p #{DROPBOX_APP_FOLDER};
      wget #{HELPER_SCRIPT} -O #{DROPBOX};
      wget #{CRON_SCRIPT} -O #{CRON};
      crontab -l | grep -v "bash #{CRON} #{USER}" | { cat; echo '*/5 * * * * bash #{CRON} #{USER}'; } | crontab -;
    """, 10000, cb

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
    
  excludeButKoding:->
    # Runs every 5 seconds for 2 minutes
    # This will immediately start to exclude
    # unnecessary files who are not in the Koding folder
    
    interval = KD.utils.repeat 5000, @bound "excuteCronScript"
    
    KD.utils.wait 120000, =>
        KD.utils.killRepeat interval
    
    @excuteCronScript()
    
  excuteCronScript:->
    @kiteHelper.run "#{CRON_HELPER} #{USER}"