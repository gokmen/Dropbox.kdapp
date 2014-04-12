/* Compiled by kdc on Sat Apr 12 2014 02:11:04 GMT+0000 (UTC) */
(function() {
/* KDAPP STARTS */
/* BLOCK STARTS: index.coffee */
var AppLogItem, AppLogger, DropboxClientController, DropboxController, DropboxMainView, KiteHelper, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

KiteHelper = (function(_super) {
  __extends(KiteHelper, _super);

  function KiteHelper() {
    _ref = KiteHelper.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  KiteHelper.prototype.getReady = function() {
    var _this = this;
    return new Promise(function(resolve, reject) {
      var JVM;
      JVM = KD.remote.api.JVM;
      return JVM.fetchVms(function(err, vms) {
        var alias, kiteController, vm, _i, _len;
        if (err) {
          console.warn(err);
        }
        if (!vms) {
          return;
        }
        _this._vms = vms;
        _this._kites = {};
        kiteController = KD.getSingleton('kiteController');
        for (_i = 0, _len = vms.length; _i < _len; _i++) {
          vm = vms[_i];
          alias = vm.hostnameAlias;
          _this._kites[alias] = kiteController.getKite("os-" + vm.region, alias, 'os');
        }
        _this.emit('ready');
        return resolve();
      });
    });
  };

  KiteHelper.prototype.getVm = function() {
    this._vm || (this._vm = this._vms.first);
    return this._vm;
  };

  KiteHelper.prototype.getKite = function() {
    var _this = this;
    return new Promise(function(resolve, reject) {
      return _this.getReady().then(function() {
        var kite, vm;
        vm = _this.getVm().hostnameAlias;
        if (!(kite = _this._kites[vm])) {
          return reject({
            message: "No such kite for " + vm
          });
        }
        return kite.vmOn().then(function() {
          return resolve(kite);
        });
      });
    });
  };

  KiteHelper.prototype.run = function(cmd, timeout, callback) {
    var _ref1;
    if (!callback) {
      _ref1 = [callback, timeout], timeout = _ref1[0], callback = _ref1[1];
    }
    if (timeout == null) {
      timeout = 10 * 60 * 1000;
    }
    return this.getKite().then(function(kite) {
      kite.options.timeout = timeout;
      return kite.exec({
        command: cmd
      }).then(function(result) {
        return callback(null, result);
      });
    })["catch"](function(err) {
      return callback({
        message: "Failed to run " + cmd,
        details: err
      });
    });
  };

  return KiteHelper;

})(KDController);

DropboxClientController = (function(_super) {
  var AUTH_LINK_FOUND, DROPBOX, HELPER, HELPER_FAILED, HELPER_SCRIPT, IDLE, NOT_INSTALLED, RUNNING, WAITING_FOR_REGISTER, _ref1;

  __extends(DropboxClientController, _super);

  HELPER_SCRIPT = "https://rest.kd.io/gokmen/Dropbox.kdapp/master/resources/dropbox.py";

  DROPBOX = "/tmp/_dropbox.py";

  HELPER = "python " + DROPBOX;

  _ref1 = [0, 1, 2, 3, 4, 5], IDLE = _ref1[0], RUNNING = _ref1[1], HELPER_FAILED = _ref1[2], WAITING_FOR_REGISTER = _ref1[3], NOT_INSTALLED = _ref1[4], AUTH_LINK_FOUND = _ref1[5];

  function DropboxClientController(options, data) {
    if (options == null) {
      options = {};
    }
    DropboxClientController.__super__.constructor.call(this, options, data);
    this.kiteHelper = new KiteHelper;
    this.kiteHelper.ready(this.lazyBound('emit', 'ready'));
    this.registerSingleton("dropboxController", this, true);
  }

  DropboxClientController.prototype.announce = function(message, busy) {
    return this.emit("status-update", message, busy);
  };

  DropboxClientController.prototype.init = function() {
    var _this = this;
    this._lastState = IDLE;
    return this.kiteHelper.getKite().then(function(kite) {
      return kite.fsExists({
        path: DROPBOX
      }).then(function(state) {
        if (!state) {
          _this._lastState = HELPER_FAILED;
          _this.announce("Dropbox helper is not available, fixing...", true);
          return _this.installHelper(function(err, state) {
            if (err || !state) {
              return _this.announce("Failed to install helper, please try again");
            } else {
              return _this.init();
            }
          });
        } else {
          return _this.updateStatus(true);
        }
      });
    });
  };

  DropboxClientController.prototype.install = function(callback) {
    var _this = this;
    this.announce("Installing Dropbox daemon...", true);
    return this.kiteHelper.run("" + HELPER + " install", function(err, res) {
      if (err) {
        return _this.announce("Failed to install Dropbox, please try again.");
      } else {
        return KD.utils.wait(2000, function() {
          _this._lastState = IDLE;
          return _this.announce("Dropbox installed successfully, you can start the daemon now");
        });
      }
    });
  };

  DropboxClientController.prototype.start = function() {
    this.announce("Starting Dropbox daemon...", true);
    return this.kiteHelper.run("" + HELPER + " start", 7000, this.bound('updateStatus'));
  };

  DropboxClientController.prototype.stop = function() {
    this.announce("Stoping Dropbox daemon...", true);
    return this.kiteHelper.run("" + HELPER + " stop", this.bound('updateStatus'));
  };

  DropboxClientController.prototype.getAuthLink = function(callback) {
    return this.kiteHelper.run("" + HELPER + " link", function(err, res) {
      if (!err && res.exitStatus === AUTH_LINK_FOUND) {
        return callback(null, res.stdout.match(/https\S+/));
      } else {
        return callback({
          message: "Failed to fetch auth link."
        });
      }
    });
  };

  DropboxClientController.prototype.installHelper = function(callback) {
    return this.kiteHelper.run("wget " + HELPER_SCRIPT + " -O " + DROPBOX, callback);
  };

  DropboxClientController.prototype.updateStatus = function(keepCurrentState) {
    var _this = this;
    if (keepCurrentState == null) {
      keepCurrentState = false;
    }
    if (this._locked || this._stopped) {
      return;
    }
    this._locked = true;
    if (!keepCurrentState) {
      this.announce(null, true);
    }
    return this.kiteHelper.run("" + HELPER + " status", function(err, res) {
      var message;
      message = "Failed to fetch state.";
      if (!err) {
        message = res.stdout;
        _this._lastState = res.exitStatus;
      }
      _this.announce(message);
      return _this._locked = false;
    });
  };

  DropboxClientController.prototype.createDropboxDirectory = function(path, cb) {
    return this.kiteHelper.run("mkdir -p " + path, cb);
  };

  return DropboxClientController;

})(KDController);

DropboxMainView = (function(_super) {
  var AUTH_LINK_FOUND, HELPER_FAILED, IDLE, NOT_INSTALLED, RUNNING, WAITING_FOR_REGISTER, _ref1;

  __extends(DropboxMainView, _super);

  _ref1 = [0, 1, 2, 3, 4, 5], IDLE = _ref1[0], RUNNING = _ref1[1], HELPER_FAILED = _ref1[2], WAITING_FOR_REGISTER = _ref1[3], NOT_INSTALLED = _ref1[4], AUTH_LINK_FOUND = _ref1[5];

  function DropboxMainView(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = 'dropbox main-view';
    DropboxMainView.__super__.constructor.call(this, options, data);
    new DropboxClientController;
    this.logger = new AppLogger;
    this.logger.info("Logger initialized.");
  }

  DropboxMainView.prototype.viewAppended = function() {
    var container, dbc, mcontainer,
      _this = this;
    dbc = KD.singletons.dropboxController;
    this.addSubView(container = new KDView({
      cssClass: 'container'
    }));
    container.addSubView(new KDView({
      cssClass: "dropbox-logo",
      click: dbc.bound('updateStatus')
    }));
    container.addSubView(mcontainer = new KDView({
      cssClass: "status-message"
    }));
    mcontainer.addSubView(this.loader = new KDLoaderView({
      showLoader: true,
      size: {
        width: 20
      }
    }));
    mcontainer.addSubView(this.message = new KDView({
      cssClass: 'message',
      partial: "Checking state..."
    }));
    container.addSubView(this.details = new KDView({
      cssClass: 'details hidden',
      click: function(e) {
        if ($(e.target).is('cite')) {
          return dbc.updateStatus();
        }
      }
    }));
    container.addSubView(this.toggle = new KDToggleButton({
      style: "solid green db-toggle hidden",
      defaultState: "Start Dropbox",
      loader: {
        color: "#666",
        diameter: 16
      },
      states: [
        {
          title: "Start Dropbox",
          callback: function() {
            this.hide();
            return dbc.start();
          }
        }, {
          title: "Stop Dropbox",
          callback: function() {
            this.hide();
            return dbc.stop();
          }
        }
      ]
    }));
    container.addSubView(this.installButton = new KDButtonView({
      title: "Install Dropbox",
      cssClass: "solid green db-install hidden",
      callback: function() {
        this.hide();
        return dbc.install();
      }
    }));
    this.finderController = new NFinderController;
    this.finderController.isNodesHiddenFor = function() {
      return true;
    };
    this.addSubView(this.finder = this.finderController.getView());
    this.finder.show = function() {
      this.unsetClass('hidden');
      this.setClass('filemode');
      return container.setClass('filemode');
    };
    this.finder.hide = function() {
      if (this.hasClass('hidden')) {
        return;
      }
      this.unsetClass('filemode');
      container.unsetClass('filemode');
      return this.setClass('hidden');
    };
    dbc.on("status-update", function(message, busy) {
      var _ref2;
      _this.loader[busy ? "show" : "hide"]();
      if (message) {
        _this.message.updatePartial(message);
      }
      if (message) {
        _this.logger.info(message, "| State:", dbc._lastState);
      }
      _this.toggle.hideLoader();
      if (busy) {
        return;
      }
      if (dbc._lastState === IDLE) {
        _this.toggle.show();
      }
      if ((_ref2 = dbc._lastState) === RUNNING || _ref2 === WAITING_FOR_REGISTER) {
        _this.toggle.setState("Stop Dropbox");
        if (dbc._lastState === RUNNING) {
          KD.utils.defer(function() {
            KD.utils.killWait(dbc._timer);
            return dbc._timer = KD.utils.wait(4000, dbc.bound('updateStatus'));
          });
        }
      } else {
        _this.toggle.setState("Start Dropbox");
      }
      if (dbc._lastState === NOT_INSTALLED) {
        _this.installButton.show();
        _this.finder.hide();
        _this.toggle.hide();
      } else {
        _this.installButton.hide();
        _this.finder.show();
        _this.toggle.show();
      }
      if (dbc._lastState === WAITING_FOR_REGISTER) {
        return dbc.getAuthLink(function(err, link) {
          if (err) {
            message = err.message;
            message = "" + err.message + " <cite>Retry</cite>";
          } else {
            message = "Please visit <a href=\"" + link + "\" target=_blank>" + link + "</a> to link\nyour Koding VM with your Dropbox account.";
            KD.utils.wait(2500, dbc.bound('updateStatus'));
          }
          _this.details.updatePartial(message);
          return _this.details.show();
        });
      } else {
        return _this.details.hide();
      }
    });
    dbc.ready(function() {
      var vm;
      vm = dbc.kiteHelper.getVm();
      vm.path = "/home/" + (KD.nick()) + "/Dropbox";
      return dbc.createDropboxDirectory(vm.path, function() {
        return _this.finderController.mountVm(vm);
      });
    });
    return KD.utils.defer(function() {
      return dbc.init();
    });
  };

  return DropboxMainView;

})(KDView);

DropboxController = (function(_super) {
  __extends(DropboxController, _super);

  function DropboxController(options, data) {
    var appManager, dropboxController, updateStatus, windowController, _ref1,
      _this = this;
    if (options == null) {
      options = {};
    }
    options.view = new DropboxMainView;
    options.appInfo = {
      name: "Dropbox",
      type: "application"
    };
    DropboxController.__super__.constructor.call(this, options, data);
    this.logger = this.getView().logger;
    dropboxController = KD.singletons.dropboxController;
    updateStatus = function(state) {
      dropboxController._stopped = !state;
      if (state) {
        _this.logger.info("Dropbox app is active now, check status.");
        return dropboxController.updateStatus();
      } else {
        return _this.logger.info("Dropbox app lost the focus, stop polling.");
      }
    };
    _ref1 = KD.singletons, windowController = _ref1.windowController, appManager = _ref1.appManager;
    appManager.on('AppIsBeingShown', function(app) {
      return updateStatus(app.getId() === _this.getId());
    });
    windowController.addFocusListener(function(state) {
      if (appManager.frontApp.getId() === _this.getId()) {
        return updateStatus(state);
      }
    });
  }

  DropboxController.prototype.enableLogs = function() {
    var view;
    view = this.getView();
    if (view.logger.parentIsInDom) {
      return;
    }
    return view.addSubView(view.logger);
  };

  return DropboxController;

})(AppController);

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
    var content, message, part, _i, _len;
    message = this.getData().message;
    content = "";
    for (_i = 0, _len = message.length; _i < _len; _i++) {
      part = message[_i];
      if ((typeof part) === 'object') {
        part = "<pre>" + (JSON.stringify(part, null, 2)) + "</pre>";
      }
      content += "" + part + " ";
    }
    return "<span>" + ((new Date).format('HH:MM:ss')) + " : " + content + "</span>";
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
      return _this[mtype] = function() {
        var rest;
        rest = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        _this.list.addItem({
          message: rest
        }, {
          type: mtype
        });
        if (_this.parentIsInDom) {
          return console[mtype](rest);
        }
      };
    });
  }

  AppLogger.prototype.viewAppended = function() {
    var view;
    view = this.list.getView();
    this.addSubView(new KDHeaderView({
      title: "Logs",
      type: "small",
      click: function() {
        return view.toggleClass('in');
      }
    }));
    this.addSubView(view);
    return KD.utils.wait(500, function() {
      return view.toggleClass('in');
    });
  };

  return AppLogger;

})(KDView);

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