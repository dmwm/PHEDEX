PHEDEX.Core = function(sandbox,loader) {
  var _modules = {}, _loaded = [],
      _sbx = sandbox,
      _ldr = loader,
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

  var _loadModule =  function(ev,arr) {
// N.B. loadModule() can return _before_ the module is created, if it has to load it first. It will call itself again later.
    var name = arr[0];
    if ( _loaded[name] ) { _sbx.notify('ModuleLoaded',name); return; }
    var module = name.toLowerCase();
    if ( ! module.match('/^phedex-/') ) { module = 'phedex-module-'+module; }
    log ('loading "'+module+'" (for '+name+')','info',_me);
    _ldr.load( {
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

  var _createModule = function(ev,arr) {
// create a module and call its init() function. It is expected that the module will notify the sandbox when it is up, and
// the core will handle it through the moduleHandler function after that.
    var name = PxU.initialCaps(arr[0]);
    log ('creating a module "'+name+'"','info',_me);
    try {
      var m = new PHEDEX.Module[name](_sbx,name);
    } catch(ex) { log(ex,'error',_me); banner("Failed to construct an instance of '"+name+"'!"); }
    m.init(_global_options);
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
      var action = arr[0],
          args   = arr[1];
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

//        the module is complete, now load the decorators!
          var _m=[],
              _d=m.decorators;
          for (var i in _d) {
            if ( _d[i].source ) { _m.push(_d[i].source); }
          }
          if ( _m.length ) {
//          load the decorators first, then notify when ready...
            log('loading decorators','info','Core');
            _ldr.load( {
              Success: function() {
                log('Successfully loaded decorators','warn','Core');
                _sbx.notify(m.id,'decoratorsLoaded');
              },
              Progress: function(item) { banner('Loaded item: '+item.name); }
            }, _m);
          } else {
//          nothing needs loading, I can notify the decorators directly
            log('Already loaded decorators','warn','Core');
            _sbx.notify(m.id,'decoratorsLoaded');
          }
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
            if ( m.ctl[d.name] ) {
//            I'm not too clear why this happens, in principle it shouldn't...?
              log('Already loaded "'+d.name+'" for "'+m.me,'warn',_me);
              continue;
            }
            var ctor = PHEDEX;
//          I need a constructor for this decorator. Try three methods to get one:
//          1) look in the decorator specification
//          2) deduce it from the module-name, if there is an external module to load
//          3) deduce it from the type of the module it attaches to, and the name of the decorator
            if ( d.ctor ) {
              ctor = d.ctor;
            }
//          deduce the constructor from the source-name. 'phedex-abc-def-ghi' -> PHEDEX.Abc.Def.Ghi()
//          If I can't find an initialCaps match for a sub-component, try case-insensitive compare
//          If no source-name is given, assume a constructor PHEDEX[type][name], where type is the group of
//          this module (DataTable|TreeView) and name is the name of this decorator.
            else if ( d.source ) {
              var x = d.source.split('-');
              for (var j in x ) {
                if ( x[j] == 'phedex' ) { continue; }
                var field = PxU.initialCaps(x[j]);
                if ( ctor[field] ) { ctor = ctor[field] }
                else {
                  for (var k in ctor) {
                    field = k.toLowerCase();
                    if ( field == x[j] ) {
                      ctor = ctor[k];
                      break;
                    }
                  }
                }
                if ( !ctor ) {
                  log('decorator '+d.source+' not constructible at level '+x[j]+' ('+d.name+')');
                  throw new Error('decorator '+d.source+' not constructible at level '+x[j]+' ('+d.name+')');
                }
              }
            } else {
              ctor = PHEDEX[m.type][d.name];
            }
            if ( typeof(ctor) != 'function' ) {
              log('decorator '+d.source+' constructor is not a function');
              throw new Error('decorator '+d.source+' is not a function');
            }
            setTimeout(function(_m,_d,_ctor) {
              return function() {
                if ( !_d.payload )     { _d.payload = {}; }
                if ( !_d.payload.obj ) { _d.payload.obj = _m; }
                try { _m.ctl[_d.name] = new _ctor(_sbx,_d); }
                catch (ex) { log(err(ex),'error','Core'); }
                if ( _d.parent ) { _m.dom[_d.parent].appendChild(_m.ctl[_d.name].el); }
                }
              }(m,d,ctor),10);
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
    create: function() {
      _sbx.listen('ModuleExists', _moduleExists);
      _sbx.listen('LoadModule',   _loadModule);
      _sbx.listen('ModuleLoaded', _createModule);
      _sbx.notify('CoreCreated');
      banner('PhEDEx App is up and running!');
    },
  };
}
