
# --- Koding Backend ------------------------ 8< ------    

class KiteHelper extends KDController
  
  constructor:(options = {}, data)->
    super
  
  getReady:->
  
    new Promise (resolve, reject) =>
    
      {JVM} = KD.remote.api
      JVM.fetchVms (err, vms)=>

        console.warn err  if err
        return unless vms
      
        @_vms = vms        
        @_kites = {}
      
        kiteController = KD.getSingleton 'kiteController'

        for vm in vms
          alias = vm.hostnameAlias
          @_kites[alias] = kiteController
            .getKite "os-#{ vm.region }", alias, 'os'

        @emit 'ready'
        resolve()
  
  getVm:->
    @_vm or= @_vms.first
    return @_vm
  
  getKite:->
    
    new Promise (resolve, reject)=>

      @getReady().then =>
      
        vm = @getVm().hostnameAlias

        unless kite = @_kites[vm]
          return reject {
            message: "No such kite for #{vm}"
          }
        
        kite.vmOn().then -> resolve kite
      
  run:(cmd, timeout, callback)->
    
    unless callback
      [timeout, callback] = [callback, timeout]
      
    # Set it to 10 min if not given
    timeout ?= 10 * 60 * 1000
    @getKite().then (kite)->
      kite.options.timeout = timeout
      kite.exec(command: cmd)
      .then (result)->
        callback null, result
    .catch (err)->
      callback
        message : "Failed to run #{cmd}"
        details : err
    
# --- Koding Backend ------------------------ 8< ------    






# --- Dropbox Backend ----------------------- 8< ------    

class DropboxClientController extends KDController
  
  HELPER_SCRIPT = "https://rest.kd.io/gokmen/Dropbox.kdapp/master/resources/dropbox.py"
  DROPBOX = "/tmp/_dropbox.py"
  HELPER  = "python #{DROPBOX}"
  
  constructor:(options = {}, data)->
    super options, data
    
    @kiteHelper = new KiteHelper
    @kiteHelper.ready @lazyBound 'emit', 'ready'
    
    @registerSingleton "dropboxController", this, yes
  
  announce:(m, b)->
    @emit "status-update", m, b
  
  init:->
    
    @_lastState = 0
    @kiteHelper.getKite()
    .then (kite)=>
      
      kite.fsExists(path : DROPBOX)
      .then (state)=>
        if not state
          @announce "Dropbox helper is not available, fixing...", yes
          @installHelper (err, state)=>
            if err or not state
              @announce "Failed to install helper, please try again"
            else
              @init()
        else
          @kiteHelper.run "#{HELPER} init", =>
            @updateStatus()
  
  install:(callback)->

    # @_lastState = 7
    @announce "Installing Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} install", (err, res)=>
      message = "Failed to install Dropbox, please try again."
      unless err
        message = "Dropbox installed successfully, you can start the daemon now"
        @_lastState = 0
      @announce message

  start:->
    
    @announce "Starting Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} start", 7000, @bound 'updateStatus'

  stop:->
    
    @announce "Stoping Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} stop", @bound 'updateStatus'

  getAuthLink:(callback)->
      
    @kiteHelper.run "#{HELPER} link", (err, res)->
      if not err and res.exitStatus is 5
        callback null, res.stdout.match /https\S+/
      else
        callback {message: "Failed to fetch auth link."}
        
  installHelper:(callback)->

    @kiteHelper.run \
      "wget #{HELPER_SCRIPT} -O #{DROPBOX}", callback
  
  updateStatus:->
  
    return  if @_locked or @_stopped
    
    @_locked = yes
    @announce null, yes
    @kiteHelper.run "#{HELPER} status", (err, res)=>
      log {err, res}
      message = "Failed to fetch state."
      
      unless err
        message = res.stdout
        @_lastState = res.exitStatus
      
      @announce message, res.exitStatus is 7
      @_locked = no

  isInstalled: (cb)->
    
    @kiteHelper.run "#{HELPER} installed", (err, res)->
      if err or not res
      then cb no
      else cb result.exitStatus is 1
        
  createDropboxDirectory:(path, cb)->
    @kiteHelper.run "mkdir -p #{path}", cb

# --- Dropbox Backend ----------------------- 8< ------    






# --- Dropbox UI ---------------------------- 8< ------    

class DropboxMainView extends KDView

  constructor:(options = {}, data)->
    options.cssClass = 'dropbox main-view'
    super options, data

    # Comment-out this before deploy ~ GG
    # unless KD.singletons.dropboxController
    new DropboxClientController

  viewAppended:->
    
    dbc = KD.singletons.dropboxController
    
    @addSubView container = new KDView
      cssClass : 'container'
  
    @addSubView @logger = new AppLogger
    @logger.info "Logger initialized."
             
    container.addSubView new KDView
      cssClass : "dropbox-logo"
      click : dbc.bound 'updateStatus'

    container.addSubView mcontainer = new KDView
      cssClass : "status-message"
      
    mcontainer.addSubView @loader = new KDLoaderView
      showLoader : yes
      size       : width : 20
      
    mcontainer.addSubView @message = new KDView
      cssClass : 'message'
      partial : "Checking state..."
      
    container.addSubView @details = new KDView
      cssClass : 'details hidden'
      click: (e)->
        dbc.updateStatus()  if $(e.target).is 'cite'
        
    container.addSubView @toggle = new KDToggleButton
      style           : "solid green db-toggle hidden"
      defaultState    : "Start Dropbox"
      loader          :
        color         : "#666"
        diameter      : 16
      states          : [
        title         : "Start Dropbox"
        callback      : -> this.hide(); dbc.start()
      ,
        title         : "Stop Dropbox"
        callback      : -> this.hide(); dbc.stop()
      ]    
    
    container.addSubView @installButton = new KDButtonView
      title    : "Install Dropbox"
      cssClass : "solid green db-install hidden"
      callback : ->
        @hide(); dbc.install()

    @finderController = new NFinderController
      
    # Temporary fix, until its fixed in upstream ~ GG
    @finderController.isNodesHiddenFor = -> yes
    @addSubView @finder = @finderController.getView()
    @finder.hide()
    
    dbc.on "status-update", (message, busy)=>
      
      @loader[if busy then "show" else "hide"]()
      @message.updatePartial message  if message
      
      @logger.info message  if message
      @logger.info dbc._lastState

      @toggle.hideLoader()
      
      return  if busy
      
      if dbc._lastState is 0 then @toggle.show()
      
      if dbc._lastState in [1, 3]
        @toggle.setState "Stop Dropbox"
        if dbc._lastState is 1
          @finder.show()
          KD.utils.defer ->
            KD.utils.killWait dbc._timer
            dbc._timer = KD.utils.wait 25000, dbc.bound 'updateStatus'
      else
        @toggle.setState "Start Dropbox"
        @finder.hide()
      
      # not installed
      if dbc._lastState is 4
        @installButton.show()
        @finder.hide()
        @toggle.hide()
      else
        @installButton.hide()
        @finder.show()
        @toggle.show()
        
      if dbc._lastState is 3
        
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

    
    dbc.ready =>
      vm = dbc.kiteHelper.getVm()
      vm.path = "/home/#{KD.nick()}/Dropbox"

      dbc.createDropboxDirectory vm.path, =>
        @finderController.mountVm vm
      
    KD.utils.defer -> dbc.init()

class DropboxController extends AppController

  constructor:(options = {}, data)->
    options.view    = new DropboxMainView
    options.appInfo =
      name : "Dropbox"
      type : "application"

    super options, data

    {dropboxController} = KD.singletons

    updateStatus = (state)->
      dropboxController._stopped = !state
      dropboxController.updateStatus()  if state

    {windowController, appManager} = KD.singletons
    
    appManager.on 'AppIsBeingShown', (app)=>
      updateStatus app.getId() is @getId()

    windowController.addFocusListener (state)=>
      if appManager.frontApp.getId() is @getId()
        updateStatus state

# --- Dropbox UI ---------------------------- 8< ------    
    
    
    
    
    
    
    
    
# --- App Logger ---------------------------- 8< ------    

class AppLogItem extends KDListItemView
  
  constructor:(options = {}, data)->
    options.cssClass = "app-log-item #{options.type}"
    super options, data
  
  viewAppended: JView::viewAppended
  
  pistachio:->
    
    {message} = @getData()

    content = ""
    for part in message
      if (typeof part) is 'object'
        part = "<pre>#{JSON.stringify part, null, 2}</pre>"
      content += "#{part} "
  
    "<span>#{(new Date).format('HH:MM:ss')} : #{content}</span>"
  
class AppLogger extends KDView
  
  constructor:(options = {}, data)->
    options.cssClass = 'app-logger'

    super options, data

    @list          = new KDListViewController
      view         : new KDListView
        itemClass  : AppLogItem
        autoScroll : yes
      scrollView   : yes
    
    ['log', 'warn', 'info', 'error'].forEach (mtype)=>
      this[mtype] = (rest...) =>
        @list.addItem {message: rest}, {type:mtype}
        console[mtype] rest
        
  viewAppended:->
    
    view = @list.getView()
    # view.toggleClass 'in'
    @addSubView new KDHeaderView
      title : "Logs"
      type  : "small"
      click : -> view.toggleClass 'in'
        
    @addSubView view

# --- App Logger ---------------------------- 8< ------    




# --- KDApp Stuff --------------------------- 8< ------    

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
        "/:name?/gokmen/Apps/Dropbox" : null
      dockPath : "/gokmen/Apps/Dropbox"
      behavior : "application"

# --- KDApp Stuff --------------------------- 8< ------    
