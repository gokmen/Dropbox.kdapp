/* Compiled by kdc on Tue Jul 22 2014 22:24:52 GMT+0000 (UTC) */
(function() {
/* KDAPP STARTS */
if (typeof window.appPreview !== "undefined" && window.appPreview !== null) {
  var appView = window.appPreview
}
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/controller/kitehelper.coffee */
var KiteHelper,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

KiteHelper = (function(_super) {
  __extends(KiteHelper, _super);

  function KiteHelper() {
    return KiteHelper.__super__.constructor.apply(this, arguments);
  }

  KiteHelper.prototype.mvIsStarting = false;

  KiteHelper.prototype.getReady = function() {
    return new Promise((function(_this) {
      return function(resolve, reject) {
        var JVM;
        JVM = KD.remote.api.JVM;
        return JVM.fetchVmsByContext(function(err, vms) {
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
      };
    })(this));
  };

  KiteHelper.prototype.getVm = function() {
    this._vm || (this._vm = this._vms.first);
    return this._vm;
  };

  KiteHelper.prototype.getKite = function() {
    return new Promise((function(_this) {
      return function(resolve, reject) {
        return _this.getReady().then(function() {
          var kite, vm, vmController;
          vm = _this.getVm().hostnameAlias;
          vmController = KD.singletons.vmController;
          if (!(kite = _this._kites[vm])) {
            return reject({
              message: "No such kite for " + vm
            });
          }
          return vmController.info(vm, function(err, vmn, info) {
            var timeout;
            if (!_this.mvIsStarting && info.state === "STOPPED") {
              _this.mvIsStarting = true;
              timeout = 10 * 60 * 1000;
              kite.options.timeout = timeout;
              return kite.vmOn().then(function() {
                return resolve(kite);
              }).timeout(timeout)["catch"](function(err) {
                return reject(err);
              });
            } else {
              return resolve(kite);
            }
          });
        });
      };
    })(this));
  };

  KiteHelper.prototype.run = function(cmd, timeout, callback) {
    var _ref;
    if (!callback) {
      _ref = [callback, timeout], timeout = _ref[0], callback = _ref[1];
    }
    if (timeout == null) {
      timeout = 10 * 60 * 1000;
    }
    return this.getKite().then(function(kite) {
      kite.options.timeout = timeout;
      return kite.exec({
        command: cmd
      }).then(function(result) {
        if (callback) {
          return callback(null, result);
        }
      })["catch"](function(err) {
        if (callback) {
          return callback({
            message: "Failed to run " + cmd,
            details: err
          });
        } else {
          return console.error(err);
        }
      });
    })["catch"](function(err) {
      if (callback) {
        return callback({
          message: "Failed to run " + cmd,
          details: err
        });
      } else {
        return console.error(err);
      }
    });
  };

  return KiteHelper;

})(KDController);
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/controller/dropbox-client.coffee */
var DropboxClientController,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

DropboxClientController = (function(_super) {
  var AUTH_LINK_FOUND, CRON, CRON_HELPER, CRON_SCRIPT, DROPBOX, DROPBOX_APP_FOLDER, DROPBOX_FOLDER, EXCLUDE_SUCCEED, HELPER, HELPER_FAILED, HELPER_SCRIPT, IDLE, LIST_OF_EXCLUDED, NOT_INSTALLED, NO_FOLDER_EXCLUDED, RUNNING, USER, WAITING_FOR_REGISTER, _ref;

  __extends(DropboxClientController, _super);

  USER = KD.nick();

  HELPER_SCRIPT = "https://rest.kd.io/bvallelunga/Dropbox.kdapp/master/resources/dropbox.py";

  CRON_SCRIPT = "https://rest.kd.io/bvallelunga/Dropbox.kdapp/master/resources/dropbox.sh";

  DROPBOX_APP_FOLDER = "/home/" + USER + "/.dropbox-app";

  DROPBOX = "" + DROPBOX_APP_FOLDER + "/dropbox.py";

  CRON = "" + DROPBOX_APP_FOLDER + "/dropbox.sh";

  DROPBOX_FOLDER = "/home/" + USER + "/Dropbox";

  HELPER = "python " + DROPBOX;

  CRON_HELPER = "bash " + CRON;

  _ref = [0, 1, 2, 3, 4, 5, 6, 7, 8], IDLE = _ref[0], RUNNING = _ref[1], HELPER_FAILED = _ref[2], WAITING_FOR_REGISTER = _ref[3], NOT_INSTALLED = _ref[4], AUTH_LINK_FOUND = _ref[5], NO_FOLDER_EXCLUDED = _ref[6], LIST_OF_EXCLUDED = _ref[7], EXCLUDE_SUCCEED = _ref[8];

  function DropboxClientController(options, data) {
    var dropboxController;
    if (options == null) {
      options = {};
    }
    dropboxController = KD.singletons.dropboxController;
    if (dropboxController) {
      return dropboxController;
    }
    DropboxClientController.__super__.constructor.call(this, options, data);
    this.kiteHelper = new KiteHelper;
    this.kiteHelper.ready((function(_this) {
      return function() {
        return _this.createDropboxDirectory(_this.lazyBound('emit', 'ready'));
      };
    })(this));
    this.registerSingleton("dropboxController", this, true);
  }

  DropboxClientController.prototype.announce = function(message, busy) {
    return this.emit("status-update", message, busy);
  };

  DropboxClientController.prototype.init = function() {
    this._lastState = IDLE;
    return this.kiteHelper.getKite().then((function(_this) {
      return function(kite) {
        return kite.fsExists({
          path: DROPBOX
        }).then(function(state) {
          if (!state) {
            _this._lastState = HELPER_FAILED;
            return _this.announce("Dropbox helper is not available, fixing...");
          } else {
            return _this.updateStatus(true);
          }
        });
      };
    })(this));
  };

  DropboxClientController.prototype.install = function() {
    this.announce("Installing the Dropbox daemon...", true);
    return this.kiteHelper.run("" + HELPER + " install", (function(_this) {
      return function(err, res) {
        if (err) {
          return _this.announce("Failed to install Dropbox, please try again.");
        } else {
          return KD.utils.wait(2000, function() {
            _this._lastState = IDLE;
            _this.announce("Dropbox installed successfully, you can start the daemon now");
            return _this.addReadMe();
          });
        }
      };
    })(this));
  };

  DropboxClientController.prototype.uninstall = function() {
    this.announce("Uninstalling the Dropbox daemon...", true);
    return this.kiteHelper.run("rm -r .dropbox .dropbox-dist Dropbox;\ncrontab -l | grep -v \"bash " + CRON + " " + USER + "\" | crontab -;", (function(_this) {
      return function(err, res) {
        if (err) {
          return _this.announce("Failed to uninstall Dropbox, please try again.");
        } else {
          return KD.utils.wait(2000, function() {
            _this._lastState = NOT_INSTALLED;
            return _this.announce("Dropbox has been successfully uninstalled.");
          });
        }
      };
    })(this));
  };

  DropboxClientController.prototype.start = function() {
    this.announce("Starting the Dropbox daemon...", true);
    return this.kiteHelper.run(" " + HELPER + " start;", 10000, this.bound('updateStatus'));
  };

  DropboxClientController.prototype.stop = function() {
    this.announce("Stoping the Dropbox daemon...", true);
    return this.kiteHelper.run("" + HELPER + " stop", 10000, this.bound('updateStatus'));
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

  DropboxClientController.prototype.installHelper = function(password) {
    return this.kiteHelper.run("mkdir -p " + DROPBOX_APP_FOLDER + ";\nwget " + HELPER_SCRIPT + " -O " + DROPBOX + ";\nwget " + CRON_SCRIPT + " -O " + CRON + ";\n\nrm /etc/init/cron.override;\necho \"" + password + "\" | sudo -S service cron start;\ncrontab -l | grep -v \"bash " + CRON + " " + USER + "\" | { cat; echo \"*/5 * * * * bash " + CRON + " " + USER + "\"; } | crontab -;", 10000, (function(_this) {
      return function(err, state) {
        if (err || !state) {
          return _this.announce("Failed to install helper, please try again");
        } else {
          return _this.init();
        }
      };
    })(this));
  };

  DropboxClientController.prototype.updateStatus = function(keepCurrentState) {
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
    return this.kiteHelper.run("" + HELPER + " status", (function(_this) {
      return function(err, res) {
        var message;
        message = "Failed to fetch state.";
        if (!err) {
          message = res.stdout.replace(/^\s+|\s+$/g, '');
          _this._previousLastState = _this._lastState;
          _this._lastState = res.exitStatus;
        }
        _this.announce(message);
        return _this._locked = false;
      };
    })(this));
  };

  DropboxClientController.prototype.createDropboxDirectory = function(cb) {
    return this.kiteHelper.run("mkdir -p " + DROPBOX_FOLDER + ";\nmkdir -p " + DROPBOX_FOLDER + "/Koding;", cb);
  };

  DropboxClientController.prototype.addReadMe = function() {
    var message;
    message = "Congrats on installing the Dropbox app on Koding.com!\n Your files in the Koding folder have already started syncing and will be there soon.";
    return this.kiteHelper.run("echo \"" + message + "\" > " + DROPBOX_FOLDER + "/Koding/README.txt");
  };

  DropboxClientController.prototype.excludeButKoding = function() {
    var interval;
    interval = KD.utils.repeat(2000, this.bound("excuteCronScript"));
    KD.utils.wait(30000, (function(_this) {
      return function() {
        return KD.utils.killRepeat(interval);
      };
    })(this));
    return this.excuteCronScript();
  };

  DropboxClientController.prototype.excuteCronScript = function() {
    return this.kiteHelper.run("" + CRON_HELPER + " " + USER);
  };

  return DropboxClientController;

})(KDController);
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/view/mainview.coffee */
var DropboxMainView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

DropboxMainView = (function(_super) {
  var AUTH_LINK_FOUND, DROPBOX_FOLDER, EXCLUDE_SUCCEED, HELPER_FAILED, IDLE, LIST_OF_EXCLUDED, NOT_INSTALLED, NO_FOLDER_EXCLUDED, RUNNING, WAITING_FOR_REGISTER, _ref;

  __extends(DropboxMainView, _super);

  DROPBOX_FOLDER = "/home/" + (KD.nick()) + "/Dropbox";

  _ref = [0, 1, 2, 3, 4, 5, 6, 7, 8], IDLE = _ref[0], RUNNING = _ref[1], HELPER_FAILED = _ref[2], WAITING_FOR_REGISTER = _ref[3], NOT_INSTALLED = _ref[4], AUTH_LINK_FOUND = _ref[5], NO_FOLDER_EXCLUDED = _ref[6], LIST_OF_EXCLUDED = _ref[7], EXCLUDE_SUCCEED = _ref[8];

  function DropboxMainView(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = 'dropbox';
    DropboxMainView.__super__.constructor.call(this, options, data);
    new DropboxClientController;
    this.interval;
    this.logger = new AppLogger;
    this.logger.info("Logger initialized.");
  }

  DropboxMainView.prototype.presentModal = function(dbc) {
    if (!this.modal) {
      return this.modal = new KDModalViewWithForms({
        title: "Please enter your Koding password",
        overlay: true,
        width: 550,
        height: "auto",
        cssClass: "new-kdmodal",
        tabs: {
          navigable: true,
          callback: (function(_this) {
            return function(form) {
              dbc.installHelper(form.password);
              return _this.modal.destroy();
            };
          })(this),
          forms: {
            "Sudo Password": {
              buttons: {
                Next: {
                  title: "Submit",
                  style: "modal-clean-green",
                  type: "submit"
                }
              },
              fields: {
                password: {
                  type: "password",
                  placeholder: "sudo password...",
                  validate: {
                    rules: {
                      required: true
                    },
                    messages: {
                      required: "password is required!"
                    }
                  }
                }
              }
            }
          }
        }
      });
    }
  };

  DropboxMainView.prototype.viewAppended = function() {
    var container, dbc, mcontainer;
    dbc = KD.singletons.dropboxController;
    this.addSubView(container = new KDView({
      cssClass: 'container'
    }));
    container.addSubView(new KDView({
      cssClass: "dropbox-logo"
    }));
    container.addSubView(this.reloadButton = new KDButtonView({
      cssClass: 'reload-button hidden',
      iconOnly: true,
      callback: function() {
        dbc.announce("Checking state...", true);
        return dbc.updateStatus(true);
      }
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
      partial: "Please wait while your vm turns on..."
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
          callback: (function(_this) {
            return function() {
              _this.toggle.hide();
              dbc.start();
              return _this.uninstallButton.hide();
            };
          })(this)
        }, {
          title: "Stop Dropbox",
          callback: (function(_this) {
            return function() {
              _this.toggle.hide();
              dbc.stop();
              return _this.finder.hide();
            };
          })(this)
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
    container.addSubView(this.uninstallButton = new KDButtonView({
      title: "Uninstall Dropbox",
      cssClass: "solid db-install hidden",
      callback: (function(_this) {
        return function() {
          _this.uninstallButton.hide();
          dbc.uninstall();
          return _this.toggle.hide();
        };
      })(this)
    }));
    container.addSubView(mcontainer = new KDView({
      cssClass: "description",
      partial: "<p>\n  Dropbox is a home for all your photos, docs, videos, and files. \n  Anything you add to Dropbox will automatically show up on all your computers, phones and even the \n  Dropbox website — so you can access your stuff from anywhere.\n</p>\n<p>\n  The Koding Dropbox app installs and manages <a target=\"_blank\" href=\"//dropbox.com\">Dropbox</a> straight from your\n  vm. This app will <strong>only</strong> synchronize the <code>~/Dropbox/Koding</code> folder.\n</p>\n<p>\n  <div>Things to Note:</div>\n  <ul>\n    <li>A Dropbox folder will be created in the <code>/home/" + (KD.nick()) + "</code> directory</li>\n    <li>This app only controls Dropbox, closing/removing the Dropbox app will not close/remove the Dropbox service</li>\n    <li>Git works with Dropbox</li>\n  </ul>\n</p>"
    }));
    this.finderController = new NFinderController;
    this.finderController.on("FileNeedsToBeOpened", (function(_this) {
      return function(file) {
        var appManager, router, _ref1;
        _ref1 = KD.singletons, appManager = _ref1.appManager, router = _ref1.router;
        appManager.openFile(file);
        return KD.utils.wait(100, function() {
          return router.handleRoute("/Ace");
        });
      };
    })(this));
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
    dbc.on("status-update", (function(_this) {
      return function(message, busy) {
        var spinner, _ref1;
        if (dbc._lastState === RUNNING && message !== "Up to date") {
          spinner = true;
          if (!_this.interval) {
            _this.interval = KD.utils.repeat(5000, dbc.bound("updateStatus"));
          }
        } else {
          spinner = busy;
          if (_this.interval) {
            KD.utils.killRepeat(_this.interval);
          }
        }
        _this.loader[spinner ? "show" : "hide"]();
        _this.reloadButton[spinner ? "hide" : "show"]();
        if (message) {
          _this.message.updatePartial(message);
        }
        if (message) {
          _this.logger.info(message, "| State:", dbc._lastState);
        }
        _this.toggle.hideLoader();
        _this.uninstallButton.hide();
        if (busy) {
          return;
        }
        if (dbc._lastState === IDLE) {
          _this.toggle.show();
        }
        if ((_ref1 = dbc._lastState) === RUNNING || _ref1 === WAITING_FOR_REGISTER) {
          _this.toggle.setState("Stop Dropbox");
        } else {
          _this.toggle.setState("Start Dropbox");
          if (!_this.toggle.hasClass("hidden")) {
            _this.uninstallButton.show();
          }
        }
        if (dbc._lastState === NOT_INSTALLED) {
          _this.installButton.show();
          _this.toggle.hide();
        } else {
          _this.installButton.hide();
          if (dbc._lastState === HELPER_FAILED) {
            _this.loader.show();
            _this.presentModal(dbc);
          } else {
            _this.toggle.show();
          }
        }
        _this.finder[dbc._lastState === RUNNING ? "show" : "hide"]();
        if (dbc._lastState === WAITING_FOR_REGISTER) {
          dbc.getAuthLink(function(err, link) {
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
          _this.details.hide();
        }
        if (dbc._lastState === RUNNING) {
          if (dbc._previousLastState === WAITING_FOR_REGISTER || message === "Up to date") {
            return dbc.excludeButKoding();
          }
        }
      };
    })(this));
    dbc.ready((function(_this) {
      return function() {
        var vm;
        vm = dbc.kiteHelper.getVm();
        vm.path = DROPBOX_FOLDER + "/Koding";
        return _this.finderController.mountVm(vm);
      };
    })(this));
    return KD.utils.defer(function() {
      return dbc.init();
    });
  };

  return DropboxMainView;

})(KDView);
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/view/maincontroller.coffee */
var DropboxController,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

DropboxController = (function(_super) {
  __extends(DropboxController, _super);

  function DropboxController(options, data) {
    var appManager, dropboxController, updateStatus, windowController, _ref;
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
    updateStatus = (function(_this) {
      return function(state) {
        dropboxController._stopped = !state;
        if (state) {
          _this.logger.info("Dropbox app is active now, check status.");
          return dropboxController.updateStatus();
        } else {
          return _this.logger.info("Dropbox app lost the focus, stop polling.");
        }
      };
    })(this);
    _ref = KD.singletons, windowController = _ref.windowController, appManager = _ref.appManager;
    appManager.on('AppIsBeingShown', (function(_this) {
      return function(app) {
        return updateStatus(app.getId() === _this.getId());
      };
    })(this));
    windowController.addFocusListener((function(_this) {
      return function(state) {
        if (appManager.frontApp.getId() === _this.getId()) {
          return updateStatus(state);
        }
      };
    })(this));
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
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/view/logger/loggeritem.coffee */
var AppLogItem,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

AppLogItem = (function(_super) {
  __extends(AppLogItem, _super);

  JView.mixin(AppLogItem.prototype);

  function AppLogItem(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = "app-log-item " + options.type;
    AppLogItem.__super__.constructor.call(this, options, data);
  }

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
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/view/logger/logger.coffee */
var AppLogger,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

AppLogger = (function(_super) {
  __extends(AppLogger, _super);

  function AppLogger(options, data) {
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
    ['log', 'warn', 'info', 'error'].forEach((function(_this) {
      return function(mtype) {
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
      };
    })(this));
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
/* BLOCK STARTS: /home/bvallelunga/Applications/Dropbox.kdapp/index.coffee */
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
        "/:name?/bvallelunga/Apps/Dropbox": null
      },
      dockPath: "/bvallelunga/Apps/Dropbox",
      behavior: "application"
    });
  }
})();

/* KDAPP ENDS */
}).call();