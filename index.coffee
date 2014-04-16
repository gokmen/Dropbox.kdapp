
# --- Koding Backend ------------------------ 8< ------

class KiteHelper extends KDController

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
          return reject
            message: "No such kite for #{vm}"

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
  DROPBOX_FOLDER = "/home/#{KD.nick()}/Dropbox"
  HELPER  = "python #{DROPBOX}"
  [IDLE, RUNNING, HELPER_FAILED, WAITING_FOR_REGISTER,
   NOT_INSTALLED, AUTH_LINK_FOUND, NO_FOLDER_EXCLUDED,
   LIST_OF_EXCLUDED, EXCLUDE_SUCCEED] = [0..8]

  constructor:(options = {}, data)->

    # Uncomment these before deploy
    # {dropboxController} = KD.singletons
    # return dropboxController if dropboxController

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
    @kiteHelper.run "#{HELPER} start", 7000, @bound 'updateStatus'

  stop:->

    @announce "Stoping Dropbox daemon...", yes
    @kiteHelper.run "#{HELPER} stop", @bound 'updateStatus'

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
        @_lastState = res.exitStatus

      @announce message
      @_locked = no

  createDropboxDirectory:(cb)->
    @kiteHelper.run "mkdir -p #{DROPBOX_FOLDER}", cb

  excludeFolder:(folder, state, cb)->
    arg = if state then "add" else "remove"
    @kiteHelper.run "#{HELPER} exclude #{arg} #{folder}", cb

  getExcludeList:(cb)->

    _kite = null
    folders = []

    @kiteHelper.getKite()

    .then (kite) ->

      _kite = kite
      kite.fsReadDirectory
        path : DROPBOX_FOLDER

    .then (response) ->

      folders = if response?.files? then response.files else []
      folders = folders
        .filter( (folder)-> folder.isDir and not /^\./.test folder.name )
        .map( (folder)-> {
           path: folder.fullPath.replace ///^\/home\/#{KD.nick()}\/ ///, ""
           excluded: no
        } )

      _kite.exec command: "#{HELPER} exclude"

    .then (res) ->

      if res.exitStatus is 0
        throw new Error res.stdout

      if res.exitStatus is LIST_OF_EXCLUDED
        excluded = res.stdout.split "\n"
        excluded = ({path: folder, excluded: yes} \
          for folder in excluded when folder)
        folders = folders.concat excluded
      else
        folders

    .nodeify cb

# --- Dropbox Backend ----------------------- 8< ------






# --- Dropbox UI ---------------------------- 8< ------

class DropboxMainView extends KDView

  DROPBOX_FOLDER = "/home/#{KD.nick()}/Dropbox"
  [IDLE, RUNNING, HELPER_FAILED, WAITING_FOR_REGISTER,
   NOT_INSTALLED, AUTH_LINK_FOUND, NO_FOLDER_EXCLUDED,
   LIST_OF_EXCLUDED, EXCLUDE_SUCCEED] = [0..8]

  constructor:(options = {}, data)->
    options.cssClass = 'dropbox main-view'
    super options, data

    new DropboxClientController
    @logger = new AppLogger
    @logger.info "Logger initialized."

  viewAppended:->

    dbc = KD.singletons.dropboxController

    @addSubView container = new KDView
      cssClass : 'container'

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
        callback   : -> this.hide(); dbc.stop()
      ]

    container.addSubView @installButton = new KDButtonView
      title    : "Install Dropbox"
      cssClass : "solid green db-install hidden"
      callback : ->
        @hide(); dbc.install()

    container.addSubView @excludeView = new DropboxExcludeView
    @excludeView.hide()

    @finderController = new NFinderController

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
      @message.updatePartial message  if message

      if message
        @logger.info message, "| State:", dbc._lastState

      @toggle.hideLoader()

      return  if busy

      if dbc._lastState is IDLE then @toggle.show()

      if dbc._lastState in [RUNNING, WAITING_FOR_REGISTER]
        @toggle.setState "Stop Dropbox"
        if dbc._lastState is RUNNING
          KD.utils.defer ->
            KD.utils.killWait dbc._timer
            dbc._timer = KD.utils.wait 4000, dbc.bound 'updateStatus'
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

      if dbc._lastState is RUNNING

        if @excludeView.hasClass 'hidden'
          KD.utils.wait 2000, @excludeView.bound 'reload'

        @finder.show(); @excludeView.show()
      else
        @finder.hide(); @excludeView.hide()

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


    dbc.ready =>
      vm = dbc.kiteHelper.getVm()
      vm.path = DROPBOX_FOLDER
      @finderController.mountVm vm

    KD.utils.defer -> dbc.init()

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

class DropboxExcludeView extends KDView

  constructor:(options = {}, data)->
    options.cssClass = \
      KD.utils.curry 'dropbox-exclude-view', options.cssClass
    super options, data

    @header = new KDHeaderView
      title : "Sync following folders"
      type  : "medium"

    @reloadButton = new KDButtonView
      title    : "Reload"
      cssClass : "solid"
      callback : @bound 'reload'

    @controller = new KDListViewController
      viewOptions       :
        type            : 'folder'
        wrapper         : yes
        itemClass       : DropboxExcludeItemView
      noItemFoundWidget : new KDView
        cssClass        : 'noitem-warning'
        partial         : "Dropbox is not running"

    @excludeList = @controller.getView()
    @excludeListView = @controller.getListView()

    @reload()

  reload:->
    dbc = KD.singletons.dropboxController
    dbc.getExcludeList (err, folders=[])=>
      if err and err.message?
        @controller.removeAllItems()
        @controller.noItemView.updatePartial err.message
      else
        @controller.replaceAllItems folders

  viewAppended: JView::viewAppended

  pistachio:->
    """
      {{> this.header}} {{> this.reloadButton}}
      {{> this.excludeList}}
    """

class DropboxExcludeItemView extends KDListItemView

  EXCLUDE_SUCCEED = 8

  constructor:(options = {}, data)->
    options.cssClass = 'dropbox-exclude-item-view'
    super options, data

    {@excluded} = @getData()
    delegate = @getDelegate()

    @check = new KodingSwitch
      cssClass     : "tiny"
      defaultValue : !@excluded
      callback     : (state)=>
        delegate.emit "WorkInProgress"
        @loader.show(); @check.hide()
        dbc = KD.singletons.dropboxController
        dbc.excludeFolder this.data.path, !state, (err, res)=>
          @loader.hide(); @check.show()
          warn err  if err
          if err or res.exitStatus is not EXCLUDE_SUCCEED
            @check.setValue state, no
          delegate.emit "Idle"
          log err, res

    @loader = new KDLoaderView
      showLoader : no
      size       : width : 20

    delegate.on "WorkInProgress", =>
      @check.setOption 'disabled', yes

    delegate.on "Idle", =>
      @check.setOption 'disabled', no

  viewAppended: JView::viewAppended

  pistachio:->
   """{p{#(path)}}{{> this.check}}{{> this.loader}}"""

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
        console[mtype] rest  if @parentIsInDom

  viewAppended:->

    view = @list.getView()
    @addSubView new KDHeaderView
      title : "Logs"
      type  : "small"
      click : -> view.toggleClass 'in'

    @addSubView view
    KD.utils.wait 500, -> view.toggleClass 'in'

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
