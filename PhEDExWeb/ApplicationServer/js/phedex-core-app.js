PHEDEX.namespace('Core');

PHEDEX.Core.App = function(sandbox) {
  var _modules = [], _loaded = [];
  var _sbx = sandbox;
  var _parent = document.getElementById('phedex-main');
  if ( !parent ) { throw new Error('cannot find parent element for core'); }

  var _timer; // used to clear the banner window after a while.
  var _banner_timeout = 5000;
  var _setTimeout = function() { _timer = setTimeout( function() { banner(); }, _banner_timeout); }
  var _clearTimeout = function() { if ( _timer ) { clearTimeout(_timer); } }

  var moduleHandler = function(obj) {
    return function(who,arr) {
      var action = arr[0];
      var args = arr[1];
      log('module='+who+' action="'+action+'"','info','Core');
      var m = _modules[who].obj;
      _clearTimeout();
      switch ( action ) {
        case 'initModule': {
          log('calling "'+who+'.initDom()"');
          var el = m.initDom();
          if ( el ) { _parent.appendChild(el); }
          break;
        }
        case 'initDom': {
          log('calling "'+who+'.show()"');
          m.show();
	  m.getData();
          break;
        }
        case 'getData': {
          log('fetching data for "'+who+'"');
	  try {
	    banner('Connecting to data-service...');

	    var dataReady = new YAHOO.util.CustomEvent("dataReady", this, false, YAHOO.util.CustomEvent.LIST);
	    dataReady.subscribe(function(type,args) {
	      return function(_m) {
		banner('Data-service returned OK...')
		var data = args[0];
		var context = args[1];
		var api = context.api;
		try {
		  _m.gotData(data);
		} catch(ex) { log(ex,'error',who); banner('Error processing data!'); }
	      }(m);
	    });
	    var dataFail = new YAHOO.util.CustomEvent("dataFail",  this, false, YAHOO.util.CustomEvent.LIST);
	    dataFail.subscribe(function(type,args) {
	      var api = args[1].api;
	      log('api:'+api+' error fetching data','error',who);
	      banner('Error fetching data: '+api+' '+args[0].message+'!');
	      _clearTimeout();
	    });
	    args.success_event = dataReady;
	    args.failure_event = dataFail;
	    PHEDEX.Datasvc.Call( args );
	  } catch(ex) { log(ex,'error','Core'); banner('Error fetching data!'); }
          break;
        }
      };
      _setTimeout();
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
        PxL.load( {
	  onSuccess: function(obj) {
	    return function() {
	      banner('PhEDEx App is up and running!');
	      log('module "'+name +'" loaded...');
	      _loaded[name] = {};
	      try {
		obj.createModule(name);
		_setTimeout();
	      } catch(ex) { log(ex,'error',name); banner('Error loading module '+name+'!'); }
	    }
          }(this),
	  onProgress: function(item) { banner('Loaded item: '+item.name); }
	}, module);
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