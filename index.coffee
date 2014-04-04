
class AppLogItem extends KDListItemView
  
  constructor:(options = {}, data)->
    options.cssClass = "app-log-item #{options.type}"
    super options, data
    
  viewAppended: JView::viewAppended
  
  pistachio:->
    "<span>#{(new Date).format('HH:MM:ss')} : {{#(message)}}</span>"
  
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
      this[mtype] = (message)=>
        @list.addItem {message}, {type:mtype}
        
  viewAppended:->
    @addSubView new KDHeaderView
      title : "Logs:"
      type  : "small"
      click : =>
        log "sdfsdf"
        @list.getView().toggleClass 'in'
        
    @addSubView @list.getView()

class DropboxController extends KDController
 
  constructor:(options = {}, data)->
    super options, data
    @fetchVMList()
    
  fetchVMList:(callback = ->)->
    
    if @_vms
      return callback null, @_vms
    
    {JVM} = KD.remote.api
    JVM.fetchVms (err, vms = [])=>
      if err
        callback err 
      else
        @_vms = vms
        callback null, vms

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

  viewAppended:->
    
    @addSubView container = new KDView
      cssClass : 'container'
  
    @addSubView @logger = new AppLogger
    
    @logger.info "Logger initialized."
      
    container.addSubView new KDView
      cssClass : "dropbox-logo"
      
    container.addSubView loader = new KDLoaderView
      showLoader : no
      size       : width : 40

class DropboxController extends AppController

  constructor:(options = {}, data)->
    options.view    = new DropboxMainView
    options.appInfo =
      name : "Dropbox"
      type : "application"

    super options, data

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
      