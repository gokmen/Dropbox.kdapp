
# Dropbox Installer for Koding
# 2014 - Brian Vallelunga <bvallelunga:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.


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
