PHEDEX.Core = function(sandbox) {
  var _modules = {}, _loaded = [],
      _sbx = sandbox,
      _me = 'Core',
      _timer, // used to clear the banner window after a while.
      _parent = document.getElementById('phedex-main'),
      _global_options = {}; // global application options, such as resizeability etc
  if ( !parent ) { throw new Error('cannot find parent element for core'); }

  _global_options = {
    window: false,
    constraintoviewport: true,
  };

  var _setTimeout   = function() { _timer = setTimeout( function() { banner(); }, 5000 ); },
      _clearTimeout = function() { if ( _timer ) { clearTimeout(_timer); _timer = null; } };

  var LoadModule =  function(ev,arr) {
// N.B. loadModule() can return _before_ the module is created, if it has to load it first. It will call itself again later.
    var name = arr[0];
    if ( _loaded[name] ) { _sbx.notify('ModuleLoaded',name); return; }
    var module = name.toLowerCase();
    if ( ! module.match('/^phedex-/') ) { module = 'phedex-module-'+module; }
    log ('loading "'+module+'" (for '+name+')','info',_me);
    PxL.load( {
      Success: function(obj) {
        return function() {
          banner('Loaded "'+name+'"!');
          log('module "'+name +'" loaded...','info',_me);
          _loaded[name] = {};
          _sbx.notify('ModuleLoaded',name);
        }
      }(this),
      Progress: function(item) { banner('Loaded item: '+item.name); }
    }, module);
    return;
  };

  var CreateModule = function(ev,arr) {
// create a module and call its init() function. It is expected that the module will notify the sandbox when it is up, and
// the core will handle it through the moduleHandler function after that.
    var name = PxU.initialCaps(arr[0]);
    log ('creating a module "'+name+'"','info',_me);
    try {
      var m = new PHEDEX.Module[name](PxS,name);
    } catch(ex) { log(ex,'error',_me); banner("Failed to construct an instance of '"+name+"'!"); }
    m.init(_global_options);
    var _m=[],
        _d=m.decorators;
    for (var i in _d) {
      if ( _d[i].module ) { _m.push(_d[i].module); }
      if ( _m.length ) {
//      Load the decorators first, then notify when ready...
        log('loading decorators','info','Core');
        PxL.load( {
          Success: function() {
            _sbx.notify(m.id,'decoratorsLoaded');
          },
          Progress: function(item) { banner('Loaded item: '+item.name); }
        }, _m);
      } else {
//      nothing needs loading, I can notify the decorators directly
        _sbx.notify(m.id,'decoratorsLoaded');
      }
    }
  }

  var _moduleExists = function(obj) {
    return function(ev,arr) {
      var obj  = arr[0],
          who = obj.me,
          id   = obj.id;
      _modules[id]={obj:obj,state:'initialised'};
      if ( !_loaded[who] ) { _loaded[who]={}; }
      _sbx.listen(id,moduleHandler);
    }
  }(this);

  var moduleHandler = function(obj) {
    return function(who,arr) {
// this is the meat of the application. This is where modules interact with the core
      var action = arr[0];
      var args = arr[1];
      log('module='+who+' action="'+action+'"','info',_me);
      var m = _modules[who].obj;
      _clearTimeout();
      switch ( action ) {
        case 'init': {
          var el = m.initDom();
          if ( el ) { _parent.appendChild(el); }
          else { log('module "'+name+'" did not return a DOM element?','warn',_me); }
          m.initModule();
          m.initData();
          break;
        }
        case 'initData': {
          log('calling "'+who+'.show()"','info',_me);
          m.show();
          m.getData();
          break;
        }
        case 'destroy': {
          _modules[who] = {};
          break;
        }
        case 'decoratorsLoaded': {
          for (var i in m.decorators) {
            var d = m.decorators[i];
//          deduce the constructor from the module name. 'phedex-abc-def-ghi' -> PHEDEX.Abc.Def.Ghi()
            var x = d.module;
            var _constructor;
            x.match('^phedex-(.+)$');
            x = RegExp.$1;
            _constructor = PHEDEX;
            while ( x ) {
              x.match('^([^-]+)(-(.+))?$');
              var a=PxU.initialCaps(RegExp.$1), b=RegExp.$3;
              _constructor = _constructor[PxU.initialCaps(RegExp.$1)];
              x = RegExp.$3;
            }
            setTimeout(function() {
                                    m.ctl[d.name] = new _constructor(_sbx,d);
                                    m.dom[d.parent].appendChild(m.ctl[d.name].el);
                                  },0);
          };
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
      _sbx.listen('ModuleExists', _moduleExists);
      _sbx.listen('LoadModule',   LoadModule);
      _sbx.listen('ModuleLoaded', CreateModule);
      _sbx.notify('CoreCreated');
      banner('PhEDEx App is up and running!');
    },
  };
}