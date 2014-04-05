
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
  
  getKite:->
    
    new Promise (resolve, reject)=>

      @getReady().then =>
      
        vm = @_vm or @_vms.first.hostnameAlias

        unless kite = @_kites[vm]
          return reject {
            message: "No such kite for #{vm}"
          }
    
        kite.vmOn().then -> resolve kite
    
# --- Koding Backend ------------------------ 8< ------    






# --- Dropbox Backend ----------------------- 8< ------    

class DropboxClientController extends KDController
  
  DROPBOX = "/tmp/_dropbox.py"
  HELPER  = "python #{DROPBOX}"
  
  constructor:(options = {}, data)->
    super options, data
    
    @kiteHelper = new KiteHelper
    @kiteHelper.ready @lazyBound 'emit', 'ready'
    
    @registerSingleton "dropboxController", this, yes
  
  stop: (cb)->
    
    @kiteHelper.getKite()
    .then (kite)->
      kite.exec("#{HELPER} start")
      .then (result)->
        cb result.stdout
    .catch (err)->
      cb "failed"

  isInstalled: (cb)->
    
    @kiteHelper.getKite()
    .then (kite)->
      kite.exec("#{HELPER} installed")
      .then (result)->
        cb result.exitStatus is 1
    .catch (err)->
      cb no

  isRunning: (cb) ->
  
    @kiteHelper.getKite()
    .then (kite)->
      kite.exec("#{HELPER} running")
      .then (result)->
        cb result.exitStatus is 1
    .catch (err)->
      cb no


# --- Dropbox Backend ----------------------- 8< ------    






# --- Dropbox UI ---------------------------- 8< ------    

class DropboxInstaller extends KDView
  
  constructor:(options = {}, data)->
    options.cssClass = 'dropbox installer'
    super options, data

  viewAppended:->
    @addSubView new KDButtonView
      title : "Install Dropbox"
      cssClass : "solid green"
      callback : -> alert "install"
      
class DropboxMainView extends KDView

  constructor:(options = {}, data)->
    options.cssClass = 'dropbox main-view'
    super options, data

    # Comment-out this before deploy ~ GG
    # unless KD.singletons.dropboxController
    new DropboxClientController

  viewAppended:->
    
    @addSubView container = new KDView
      cssClass : 'container'
  
    @addSubView @logger = new AppLogger
    @logger.info "Logger initialized."
          
    container.addSubView new KDView
      cssClass : "dropbox-logo"
      
    container.addSubView @loader = new KDLoaderView
      showLoader : no
      size       : width : 40
    
    dbc = KD.singletons.dropboxController
    dbc.isInstalled (state)=>
      @logger.info "Installed, ", state
    dbc.isRunning (state)=>
      @logger.info "Running, ", state
    dbc.stop (state)=>
      @logger.info "Stop: ", state

      

class DropboxController extends AppController

  constructor:(options = {}, data)->
    options.view    = new DropboxMainView
    options.appInfo =
      name : "Dropbox"
      type : "application"

    super options, data

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
    view.toggleClass 'in'
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
