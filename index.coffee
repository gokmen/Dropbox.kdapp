
# --- Koding Backend ------------------------ 8< ------    

class VMHelper extends KDController
  
  constructor:(options = {}, data)->
    super
      
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

# --- Koding Backend ------------------------ 8< ------    






# --- Dropbox Backend ----------------------- 8< ------    

class DropboxClientController extends KDController
  
  constructor:(options = {}, data)->
    super options, data
    
    @vmHelper = new VMHelper
    @vmHelper.ready @lazyBound 'emit', 'ready'
    
    @registerSingleton "dropboxController", this, yes
    
  checkInstallation:->
    # pass

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
      showLoader : yes
      size       : width : 40
    
    dbc = KD.singletons.dropboxController
    dbc.ready =>
      @logger.log "VMS are ready:", dbc.vmHelper._vms, "Kites are ready:", dbc.vmHelper._kites


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
