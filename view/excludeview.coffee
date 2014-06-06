
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxExcludeView extends KDView

  JView.mixin @prototype
  
  constructor:(options = {}, data)->
    options.cssClass = \
      KD.utils.curry 'dropbox-exclude-view', options.cssClass
    super options, data

    @header = new KDHeaderView
      title : "Sync following folders"
      type  : "medium"

    @reloadButton = new KDButtonView
      callback : @bound 'reload'
      iconOnly : yes
      cssClass : "reload-button"

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

  pistachio:->
    """
      {{> this.header}} {{> this.reloadButton}}
      {{> this.excludeList}}
    """
