
# Dropbox Installer for Koding
# 2014 - Gokmen Goksel <gokmen:koding.com>

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.

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
