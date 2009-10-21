PHEDEX.namespace('Core');

PHEDEX.Core.App = function(sandbox) {
  var _modules = [], _loaded = [],
      _sbx = sandbox,
      _me = 'Core',
      _timer, // used to clear the banner window after a while.
      _parent = document.getElementById('phedex-main');
  if ( !parent ) { throw new Error('cannot find parent element for core'); }

  var _setTimeout   = function() { _timer = setTimeout( function() { banner(); }, 5000 ); },
      _clearTimeout = function() { if ( _timer ) { clearTimeout(_timer); _timer = null; } };

  var moduleHandler = function(obj) {
    return function(who,arr) {
      var action = arr[0];
      var args = arr[1];
      log('module='+who+' action="'+action+'"','info',_me);
      var m = _modules[who].obj;
      _clearTimeout();
      switch ( action ) {
        case 'initModule': {
          log('calling "'+who+'.initDom()"','info',_me);
          var el = m.initDom();
          if ( el ) { _parent.appendChild(el); }
          break;
        }
        case 'initDom': {
          log('calling "'+who+'.show()"','info',_me);
          m.show();
	  m.initData();
	  m.getData();
          break;
        }
        case 'getData': {
          log('fetching data for "'+who+'"','info',_me);
	  try {
	    banner('Connecting to data-service...');
	    var dataReady = new YAHOO.util.CustomEvent("dataReady", this, false, YAHOO.util.CustomEvent.LIST);
	    dataReady.subscribe(function(type,args) {
	      return function(_m) {
		banner('Data-service returned OK...')
		var data = args[0],
		    context = args[1],
		    api = context.api;
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
	  } catch(ex) { log(ex,'error',_me); banner('Error fetching data!'); }
          break;
        }
      };
      _setTimeout();
    }
  }(this);

  return {
    dumpList: function() {
      for (var i in _modules) { log('dump of registered modules: "'+i+'"','info',_me); }
    },

    create: function() {
      var onModuleExists = function(obj) {
	return function(ev,arr) {
	  var string = arr[0],
	      obj    = arr[1];
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
        log ('loading "'+module+'" (for '+name+')','info',_me);
        PxL.load( {
	  onSuccess: function(obj) {
	    return function() {
	      banner('PhEDEx App is up and running!');
	      log('module "'+name +'" loaded...','info',_me);
	      _loaded[name] = {};
	      try {
		obj.createModule(name);
		_setTimeout();
	      } catch(ex) { log(ex,'error',_me); banner('Error loading module '+name+'!'); }
	    }
          }(this),
	  onProgress: function(item) { banner('Loaded item: '+item.name); }
	}, module);
      return;
      }
      log ('creating a module "'+name+'"','info',_me);
      var m = new PHEDEX.Module[name](PxS,name);
      m.init();
    },

    initModule: function() {
      for (var i in _modules) {
	log('initialise module: "'+i+'"','info',_me);
        var el = PxU.makeChild(_parent, 'div', {});
	_modules[i].obj.initModule(el);
      }
      log('all modules initialised','info',_me);
    },

    send: function(ev,who,args) {
      log('send '+ev+' to module: "'+who+'"','info',_me);
      _sbx.notify('module',who,ev,args);
    },
  };
}