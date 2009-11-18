/**
 * PhEDEx Core application class. Manages module lifetimes, drives the workflow of the application
 * @namespace PHEDEX
 * @class Core
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param loader {PHEDEX.Loader} reference to a PhEDEx loader object
 */
PHEDEX.Core = function(sandbox,loader) {
  var _modules = {}, _loaded = [],
      _sbx = sandbox,
      _ldr = loader,
      _me = 'Core',
      _timer, // used to clear the banner window after a while.
      _parent = document.getElementById('phedex-main'),
      _global_options = {}; // global application options, such as resizeability etc
  if ( !parent ) { throw new Error('cannot find parent element for core'); }

/**
 * Options defining the behaviour of the modules, i.e. resizeability, draggability etc.
 * @property _global_options
 * @private
 */
  _global_options = {
// window:false && resizeable:true do not work perfectly. The panel does not resize correctly following the handles.
// all other combinations work OK-ish
    window: false,
    constraintoviewport: true,
    resizeable: false,
  };

  var _setTimeout   = function() { _timer = setTimeout( function() { banner(); }, 5000 ); },
      _clearTimeout = function() { if ( _timer ) { clearTimeout(_timer); _timer = null; } };

/**
 * loads a module. Used as a sandbox-listener, which defines its signature. The name of the module to be loaded can be either the full base-name of the source-code file, or it can have the leading <strong>phedex-</strong> missing, in which case it is assumed to be <strong>phedex-module-<em>name</em></strong>
 * The function invokes the PhEDEx loader, and on successfully loading the source code, will notify the world with event='ModuleLoaded' and the name of the module, as originally given to it. Clients can listen for the 'ModuleLoaded' and then know that it is safe to instantiate a module of the given type.<br/>
 * _loadModule is used to listen to <strong>LoadModule</strong> events, so can be invoked via the sandbox:
 * <pre>
 * sandbox.notify('LoadModule','agents');
 * </pre>
 * @method _loadModule
 * @private
 * @param ev {string} name of event passed from the sandbox
 * @param arr {array} array of arguments passed from the sandbox. <strong>arr[0]</strong> is the name of the module to load
 */
  var _loadModule =  function(ev,arr) {
// N.B. loadModule() can return _before_ the module is created, if it has to load it first. It will call itself again later.
    var name = arr[0];
    if ( _loaded[name] ) { _sbx.notify('ModuleLoaded',name); return; }
    var module = name.toLowerCase();
    if ( ! module.match('^phedex-') ) { module = 'phedex-module-'+module; }
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

/**
 * instantiates a module, based on its name. Used as a sandbox-listener, which defines its signature. Once the module is created, its <strong>init()</strong> method will be called. It is expected that the module will send notifications from the init method which will trigger further activity by invoking listeners, either in the core or elsewhere in the application.<br/>
 * Once the module is instantiated, the core will listen for it's <strong>id</strong> as an event-name, assigning the <strong>moduleHandler</strong> routine to handle the events.<br/>
 * _createModule is used to listen to <strong>ModuleLoaded</strong> and <strong>CreateModule</strong> events, so can be invoked via the sandbox:
 * <pre>
 * sandbox.notify('CreateModule','agents');
 * </pre>
 * @method _createModule
 * @private
 * @param ev {string} name of event passed from the sandbox
 * @param arr {array} array of arguments passed from the sandbox. <strong>arr[0]</strong> is the name of the module to instantiate.
 */
  var _createModule = function(ev,arr) {
    var name = PxU.initialCaps(arr[0]);
    log ('creating a module "'+name+'"','info',_me);
    try {
      var m = new PHEDEX.Module[name](_sbx,name);
    } catch(ex) { log(ex,'error',_me); banner("Failed to construct an instance of '"+name+"'!"); }
    m.init(_global_options);
  }

  var _moduleExists =function(ev,arr) {
    var obj  = arr[0],
        who = obj.me,
        id   = obj.id;
    _modules[id]={obj:obj,state:'initialised'};
    if ( !_loaded[who] ) { _loaded[who]={}; }
    _sbx.listen(id,moduleHandler);
  };

/**
 * drives an instantiated module through its lifecycle. Used as a sandbox-listener, which defines its signature. This is the heart of the application, where modules interact with the core
* @method moduleHandler
 * @private
 * @param who {string} id of module to handle, passed from the sandbox
 * @param arr {array} array of arguments passed from the sandbox. <strong>arr[0]</strong> is the name of the action the module has notified, other array elements are specific to the action.
 */
  var moduleHandler = function(who,arr) {
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

//      the module is complete, now load the decorators!
        var _m=[],
            _d=m.decorators;
        for (var i in _d) {
          if ( _d[i].source ) { _m.push(_d[i].source); }
        }
        if ( _m.length ) {
//        load the decorators first, then notify when ready...
          log('loading decorators','info','Core');
          _ldr.load( {
            Success: function() {
              log('Successfully loaded decorators','warn','Core');
              _sbx.notify(m.id,'decoratorsLoaded');
            },
            Progress: function(item) { banner('Loaded item: '+item.name); }
          }, _m);
        } else {
//        nothing needs loading, I can notify the decorators directly
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
        _sbx.deleteEvent(action);
        break;
      }
      case 'decoratorsLoaded': {
        var ii = m.decorators.length,
            i  = 0;
        while ( i < ii ) {
          var d = m.decorators[i];
          if ( m.ctl[d.name] ) {
//          I'm not too clear why this happens, in principle it shouldn't...?
            log('Already loaded "'+d.name+'" for "'+m.me,'warn',_me);
            continue;
          }
          var ctor = PHEDEX;
//        I need a constructor for this decorator. Try three methods to get one:
//        1) look in the decorator specification
//        2) deduce it from the module-name, if there is an external module to load
//        3) deduce it from the type of the module it attaches to, and the name of the decorator
          if ( d.ctor ) {
            ctor = d.ctor;
          }
//        deduce the constructor from the source-name. 'phedex-abc-def-ghi' -> PHEDEX.Abc.Def.Ghi()
//        If I can't find an initialCaps match for a sub-component, try case-insensitive compare
//        If no source-name is given, assume a constructor PHEDEX[type][name], where type is the group of
//        this module (DataTable|TreeView) and name is the name of this decorator.
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
          i++;
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
  };

  return {
/**
 create the core module. Or rather, invoke the sandbox to listen for events that will start the ball rolling. Until <strong>create</strong> is called, the core will sit there, doing nothing at all.
 * method create
 */
    create: function() {
      _sbx.listen('ModuleExists', _moduleExists);
      _sbx.listen('LoadModule',   _loadModule);
      _sbx.listen('ModuleLoaded', _createModule);
      _sbx.listen('CreateModule', _createModule);
      _sbx.notify('CoreCreated');
      banner('PhEDEx App is up and running!');
    },
  };
}
