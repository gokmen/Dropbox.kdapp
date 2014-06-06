
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

class DropboxExcludeItemView extends KDListItemView

  EXCLUDE_SUCCEED = 8
  JView.mixin @prototype
  
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

    @loader = new KDLoaderView
      showLoader : no
      size       : width : 20

    delegate.on "WorkInProgress", =>
      @check.setOption 'disabled', yes

    delegate.on "Idle", =>
      @check.setOption 'disabled', no

  pistachio:->
   """{p{#(path)}}{{> this.check}}{{> this.loader}}"""
