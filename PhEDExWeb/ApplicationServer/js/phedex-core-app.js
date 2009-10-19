PHEDEX.namespace('Core');

PHEDEX.Core.App = function(sandbox) {
  var _modules = [], _loaded = [];
  var _sbx = sandbox;
  var _parent = document.getElementById('phedex-main');
  if ( !parent ) { throw new Error('cannot find parent element for core'); }

  var moduleHandler = function(obj) {
    return function(ev,arr) {
      var action = arr[0];
      var who = arr[1];
      log('Core: event='+ev+' module='+who+' has just done '+action);
      var m = _modules[ev].obj;
      switch ( action ) {
        case 'ReadyForAction': {
          log('calling "'+ev+'.initDom()"');
          var el = m.initDom();
          if ( el ) { _parent.appendChild(el); }
          break;
        }
        case 'initDom': {
          log('calling "'+ev+'.show()"');
          m.show();
          break;
        }
      };
    }
  }(this);

  return {
    dumpList: function() {
      for (var i in _modules) { log('dump of registered modules: "'+i+'"'); }
    },

    create: function() {
      var onModuleExists = function(obj) {
	return function(ev,arr) {
	  var string = arr[0];
	  var obj    = arr[1];
	  if ( !_modules[string] ) { _modules[string]={obj:obj,state:'initialised'}; }
	  if ( !_loaded[string] ) { _loaded[string]={}; }
          _sbx.listen(string,moduleHandler);
	}
      }(this);
      _sbx.listen('ModuleExists',onModuleExists);
      _sbx.notify('CoreAppCreate');
    },

    createModule: function(name) {
// N.B. createModule() can return _before_ the module is created, if it has to load it first. It will call itself again later.
      if ( ! _loaded[name] ) {
        var module = 'phedex-module-'+name.toLowerCase();
        log ('loading "'+module+'" (for '+name+')');
        PxL.load(function(obj) {
          return function() {
            log('module "'+name +'" loaded...');
            _loaded[name] = {};
            obj.createModule(name);
          }
        }(this), module);
        return;
      }
      log ('creating a module "'+name+'"');
      var m = new PHEDEX.Module[name](PxS,name);
      m.init();
    },

    initModule: function() {
      for (var i in _modules) {
	log('initialise module: "'+i+'"');
        var el = PxU.makeChild(_parent, 'div', {});
	_modules[i].obj.initModule(el);
      }
      log('all modules initialised');
    },

    send: function(ev,who,args) {
      log('send '+ev+' to module: "'+who+'"');
      _sbx.notify('module',who,ev,args);
    },
  };
}