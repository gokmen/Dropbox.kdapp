/* Compiled by kdc on Fri Apr 04 2014 21:06:11 GMT+0000 (UTC) */
(function() {
/* KDAPP STARTS */
/* BLOCK STARTS: index.coffee */
var AppLogItem, AppLogger, DropboxController, DropboxInstaller, DropboxMainView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

AppLogItem = (function(_super) {
  __extends(AppLogItem, _super);

  function AppLogItem(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = "app-log-item " + options.type;
    AppLogItem.__super__.constructor.call(this, options, data);
  }

  AppLogItem.prototype.viewAppended = JView.prototype.viewAppended;

  AppLogItem.prototype.pistachio = function() {
    return "<span>{{#(message)}}</span>";
  };

  return AppLogItem;

})(KDListItemView);

AppLogger = (function(_super) {
  __extends(AppLogger, _super);

  function AppLogger(options, data) {
    var _this = this;
    if (options == null) {
      options = {};
    }
    options.cssClass = 'app-logger';
    AppLogger.__super__.constructor.call(this, options, data);
    this.list = new KDListViewController({
      view: new KDListView({
        itemClass: AppLogItem,
        autoScroll: true
      }),
      scrollView: true
    });
    ['log', 'warn', 'info', 'error'].forEach(function(mtype) {
      return _this[mtype] = function(message) {
        return _this.list.addItem({
          message: message
        }, {
          type: mtype
        });
      };
    });
  }

  AppLogger.prototype.viewAppended = function() {
    var _this = this;
    this.addSubView(new KDHeaderView({
      title: "Logs:",
      type: "small",
      click: function() {
        log("sdfsdf");
        return _this.list.getView().toggleClass('in');
      }
    }));
    return this.addSubView(this.list.getView());
  };

  return AppLogger;

})(KDView);

DropboxController = (function(_super) {
  __extends(DropboxController, _super);

  function DropboxController(options, data) {
    if (options == null) {
      options = {};
    }
    DropboxController.__super__.constructor.call(this, options, data);
    this.fetchVMList();
  }

  DropboxController.prototype.fetchVMList = function(callback) {
    var JVM,
      _this = this;
    if (callback == null) {
      callback = function() {};
    }
    if (this._vms) {
      return callback(null, this._vms);
    }
    JVM = KD.remote.api.JVM;
    return JVM.fetchVms(function(err, vms) {
      if (vms == null) {
        vms = [];
      }
      if (err) {
        return callback(err);
      } else {
        _this._vms = vms;
        return callback(null, vms);
      }
    });
  };

  return DropboxController;

})(KDController);

DropboxInstaller = (function(_super) {
  __extends(DropboxInstaller, _super);

  function DropboxInstaller(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = 'dropbox installer';
    DropboxInstaller.__super__.constructor.call(this, options, data);
  }

  DropboxInstaller.prototype.viewAppended = function() {
    return this.addSubView(new KDButtonView({
      title: "Install Dropbox",
      cssClass: "solid green",
      callback: function() {
        return alert("install");
      }
    }));
  };

  return DropboxInstaller;

})(KDView);

DropboxMainView = (function(_super) {
  __extends(DropboxMainView, _super);

  function DropboxMainView(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = 'dropbox main-view';
    DropboxMainView.__super__.constructor.call(this, options, data);
  }

  DropboxMainView.prototype.viewAppended = function() {
    var container, loader;
    this.addSubView(container = new KDView({
      cssClass: 'container'
    }));
    this.addSubView(this.logger = new AppLogger);
    this.logger.info("Logger initialized.");
    container.addSubView(new KDView({
      cssClass: "dropbox-logo"
    }));
    return container.addSubView(loader = new KDLoaderView({
      showLoader: false,
      size: {
        width: 40
      }
    }));
  };

  return DropboxMainView;

})(KDView);

DropboxController = (function(_super) {
  __extends(DropboxController, _super);

  function DropboxController(options, data) {
    if (options == null) {
      options = {};
    }
    options.view = new DropboxMainView;
    options.appInfo = {
      name: "Dropbox",
      type: "application"
    };
    DropboxController.__super__.constructor.call(this, options, data);
  }

  return DropboxController;

})(AppController);

(function() {
  var view;
  if (typeof appView !== "undefined" && appView !== null) {
    view = new DropboxMainView;
    return appView.addSubView(view);
  } else {
    return KD.registerAppClass(DropboxController, {
      name: "Dropbox",
      routes: {
        "/:name?/Dropbox": null,
        "/:name?/gokmen/Apps/Dropbox": null
      },
      dockPath: "/gokmen/Apps/Dropbox",
      behavior: "application"
    });
  }
})();

/* KDAPP ENDS */
}).call();