/**
 * on-demand loading of all phedex code and the YUI code it depends on
 * @namespace PHEDEX
 * @class Loader
 * @constructor
 * @param {object} options contains options for the YAHOO.util.Loader. Can (should!) be empty
 */
PHEDEX.Loader = function(opts) {
    /**
    * dependency-relationships between PhEDEx classes, and between PhEDEx classes and YUI. Needs to be updated every time a
    * new file is added to the distribution, or when objects are changed to depend on more or fewer files
    * @property _dependencies
    * @type object
    * @protected
    */
    var _dependencies = {
    'treeview-css':   { type: 'css', fullpath: '/css/tree.css' },
    'phedex-css':     { type: 'css', fullpath: '/css/phedex.css' },
    'nesteddatatable-css': { type:'css', fullpath:'/css/nesteddatatable.css' },
    'nesteddatatable':  { type:'js',  fullpath:'/js/yui-nesteddatatable.js', requires:['datatable','nesteddatatable-css'] },
    'protovis':       { type: 'js', fullpath: '/protovis/protovis-d3.2.js' },
    'phedex-util':    { requires: ['phedex-css'] },
    'phedex-datasvc': { requires: ['phedex-util','connection','json'] },
    'phedex-util-idletimer': { },

    'phedex-component-autocomplete':{ requires:['phedex-datasvc','phedex-util','autocomplete'] },
    'phedex-component-contextmenu': { requires:['phedex-util','phedex-registry','menu'] },
    'phedex-component-control':     { requires:['phedex-util','animation'] },
    'phedex-component-dom':         { requires:['phedex-util'] },
    'phedex-component-filter':      { requires:['phedex-util','phedex-component-control','container','dragdrop','button'] },
    'phedex-component-menu':        { requires:['phedex-util','menu','button'] },
    'phedex-component-panel':       { requires:['phedex-util','phedex-component-control','phedex-component-autocomplete','container','dragdrop','button'] },
    'phedex-component-refresh':     { requires:['phedex-component-control'] },
    'phedex-component-splitbutton': { requires:['phedex-util','menu','button'] },
    'phedex-component-subscribe':   { requires:['phedex-component-panel','calendar'] },

    'phedex-config':       { requires:['phedex-util'] },
    'phedex-login':        { requires:['phedex-util','button'] },
    'phedex-navigator':    { requires: ['phedex-registry','phedex-config'/*,'phedex-globalfilter'*/,'phedex-login','history','autocomplete','button'] },
    'phedex-globalfilter': { requires: ['phedex-component-filter'] },

    'phedex-profiler':  { requires:['phedex-util','profiler','datatable','json'] },
    'phedex-history':   { requires:['phedex-sandbox','history'] },
    'phedex-registry':  { requires:['phedex-util'] },
    'phedex-logger':    { requires:['phedex-util','logger','connection','cookie'] },
    'phedex-sandbox':   { requires:['phedex-util'] },
    'phedex-core':      { requires:['phedex-sandbox'] },
    'phedex-module':    { requires:['phedex-core','container','resize'] },
    'phedex-treeview':  { requires: ['phedex-module','treeview', 'treeview-css'] },
    'phedex-datatable': { requires: ['phedex-module','datatable','nesteddatatable'] },
    'phedex-protovis':  { requires: ['phedex-module','protovis'] },

// These are the main data-display modules
    'phedex-module-agentlogs':              { requires:['phedex-datatable'] },
    'phedex-module-agents':                 { requires:['phedex-datatable'] },
    'phedex-module-blocklocation':          { requires:['datatable','slider','button'] },
    'phedex-module-custodiallocation':      { requires:['phedex-treeview'] },
    'phedex-module-consistencyresults':     { requires:['phedex-treeview'] },
    'phedex-module-databrowser':            { requires:['phedex-treeview'] },
    'phedex-module-groupusage':             { requires:['phedex-datatable'] },
    'phedex-module-linkview':               { requires:['phedex-treeview'] },
    'phedex-module-missingfiles':           { requires:['phedex-datatable'] },
    'phedex-module-nodes':                  { requires:['phedex-datatable'] },
    'phedex-module-pendingrequests':        { requires:['phedex-datatable'] },
    'phedex-module-previewrequestdata':     { requires:['phedex-datatable'] },
    'phedex-module-queuedmigrations':       { requires:['phedex-datatable'] },
    'phedex-module-static':                 { requires:['phedex-config'] },
    'phedex-module-storageusage':           { requires:['phedex-protovis'] },
    'phedex-module-subscriptions-treeview': { requires:['phedex-treeview'] },
    'phedex-module-subscriptions-table':    { requires:['phedex-datatable'] },
    'phedex-module-unroutabledata':         { requires:['phedex-treeview'] },

// prototype activity-rate module, probably not useful anymore
    'phedex-module-activity-rate':          { requires:['phedex-datatable'] },
// demo protovis modules
    'phedex-module-protovisdemo':           { requires:['phedex-protovis'] },
    'phedex-module-protovisqualitymap':     { requires:['phedex-protovis'] },
    'phedex-module-protovis-latency':       { requires:['phedex-protovis'] },

// a few custom-modules for shifters
    'phedex-module-shift-requestedqueued':     { requires:['phedex-datatable'] },
    'phedex-module-shift-transferredmigrated': { requires:['phedex-datatable'] },
    'phedex-module-shift-idlerequested':       { requires:['phedex-datatable'] },
    'phedex-module-shift-queuedquality':       { requires:['phedex-datatable'] },

// old website override modules
    'phedex-graph-datasvc':              { requires:[] },
    'phedex-nextgen-activity-rateplots': { requires:['phedex-module','phedex-graph-datasvc','button','menu'] },
    'phedex-nextgen-activity-latency':   { requires:['phedex-module', 'phedex-nextgen-util','button','phedex-datatable','protovis'] },
    'phedex-nextgen-util':               { requires:['phedex-util'] },
    'phedex-nextgen-data-subscriptions': { requires:['phedex-module-subscriptions-table','phedex-datatable','phedex-history','phedex-nextgen-util','button','animation','tabview','resize'] },
    'phedex-nextgen-data-bulkdelete':    { requires:['phedex-module-previewrequestdata','phedex-nextgen-util','button','animation'] },
    'phedex-nextgen-request-create':     { requires:['phedex-module-previewrequestdata','phedex-nextgen-util','button','calendar'] },
    'phedex-nextgen-request-view':       { requires:['phedex-module','phedex-nextgen-util','button'] },

    'phedex-module-dummy':          { requires:['phedex-module'] },
    'phedex-module-dummy-treeview': { requires:['phedex-treeview'] }
  },

  _me = 'PxLoader',
  _busy = false,
  _success,
  _on = {},
  _loader = new Yu.YUILoader(),
  _insertBefore = 'phedex-body-style',
  _conf = {
    loadOptional: true,
    allowRollup:  true,
    combine:      PxW.combineRequests,
    base:         PxW.WebAppURL + '/yui/build/',
    timeout:      15000,
// filter:'DEBUG',
    skin: {
      defaultSkin: 'sam',
      base: 'assets/skins/',
      path: 'skin.css',
      rollup: 1
    },
    onSuccess:  function(item) { _callback([_me, 'Success',  _loader.inserted]); },
    onProgress: function(item) { _callback([_me, 'Progress', item]); },
    onFailure:  function(item) { _callback([_me, 'Failure',  item]); },
    onTimeout:  function(item) { _callback([_me, 'Timeout',  item]); }
  };
  if ( document.getElementById(_insertBefore) ) { _conf.insertBefore = _insertBefore; }

/**
 * handles events from the loader, specifically <strong>Progress</strong>, <strong>Success</strong>, <strong>Failure</strong>, and <strong>Timeout</strong>. Calls the user-defined function, if any, to handle that particular event. Logs all events, using the default group/severity.
 * @method _callback
 * @private
 */
  var _callback = function(args) {
    var ev   = args[0],
        type = args[1],
        item = args[2];
    switch (type) {
      case 'Progress': { log(ev+': '+type+', '+item.name);
        try { // ...to register the PhEDEx-module with YAHOO. Not too sure what use this is, but Satyam says to do it, so we do it (http://yuiblog.com/blog/2008/06/24/buildingwidgets/#register)
          var cTor = PxU.getConstructor(item.name);
          if ( cTor ) { YAHOO.register(item.name, cTor, {version:'1.0', build:'1'}); }
          } catch(ex) { }
        break;
      }
      case 'Success':  {
        banner('loading complete');
        var l='';
        for (var i in item) { l += i+' ';};
        log(ev+': '+type+', '+l);
        _busy = false;
        if ( typeof(PxS) != 'undefined' ) { // TW Hack to notify the core of all loaded items
          try { PxS.notify('Loaded',item); } catch(ex) { } // silently ignore errors
        }
        break;
      }
      case 'Failure':  { log(ev+': '+type+', '+item.msg,'error',_me); _busy = false; break; }
      case 'Timeout':  { log(ev+': '+type,'error',_me); _busy = false; break; }
    };
    if ( _on[type] ) { setTimeout( _on[type], 0, item ); }
  };

/**
 * @method _init
 * @private
 * @param {object} config the default options updated with the configuration object passed in to the constructor
 */
  var _init = function(cf) {
    for (var i in cf) {
      _loader[i] = cf[i];
    }
    if ( PxW.ProductionMode ) { // pick up the minified versions of everything
      _loader.filter =
        {
          searchExp: '/js/(phedex[a-z,-]+)\\.js',
          replaceStr: '/js/$1-min.js'
        };
      _dependencies['phedex-css'] = { type: 'css', fullpath: '/css/phedex-min.css' };
    }

    if ( _loader.combine ) {
      _loader._filter = function(str) { // overload the builtin, private (!) _filter function
        var f = this.filter;
        if (f) { str = str.replace(new RegExp(f.searchExp, 'g'), f.replaceStr); }
        str = str.replace(new RegExp('/yui/build//','g'),'/');
        str = str.replace(new RegExp('&','g'),',');
        str = str.replace(/,$/,'');
        return str;
      }
      _loader.comboBase = '/phedex/datasvc/combo/?f=';
      _loader.root = '/yui/build/';
    }
  };

  if ( opts ) {
    for (var i in opts) { _conf[i] = opts[i]; }
  }
  _init(_conf);

  _construct = function(){
    return {
      add: function( args ) {
        if ( !args.type ) { args.type = 'js'; }
        if ( !args.fullpath ) { args.fullpath = '/'+args.type+'/'+args.name+'.'+args.type; }
        if ( !args.fullpath.match('^/yui/build') ) {
          args.fullpath = PxW.WebAppURL + args.fullpath;
          args.path = args.fullpath;
          args.ext=false;
        }
        if ( !args.requires ) { args.requires = []; }
        _loader.addModule(args);
      },
      /**
      * asynchronously load one or more javascript or CSS source files from the PhEDEx and YUI installations
      * @method load
      * @param {object|function} callback function to be called on successful loading, or object containing separate callbacks for each of the <strong>Progress</strong>, <strong>Success</strong>, <strong>Failure</strong>, and <strong>Timeout</strong> keys.<br/>The callbacks are passed an argument containing information about the item that triggered the call.
      * <br/><strong>Progress</strong> and <strong>Failure</strong> both have the name of the relevant source file in <strong>item.name</strong>.
      * <br/><strong>Timeout</strong> doesn't have any useful information about which source file triggered the timeout, but you can inspect the return of <strong>loaded()</strong> for more information.
      * <br/><strong>Success</strong> is called with the list of loaded modules.<br>&nbsp;
      * @param {arbitrary number of strings|single array of strings} modules these are the modules to load.<br/>Either a series of additional string arguments, or an array of strings. Each string is either a PhEDEx or a YUI component name. In the case of PhEDEx components, the leading <strong>phedex-</strong> can be omitted, it is assumed if there is a matching component. This means that PhEDEx components can mask YUI components in some cases. E.g, a PhEDEx component stored in a file <strong>phedex-button.js</strong> would mask the YUI <strong>button</strong> component. This can be covered in the <strong>_dependencies</strong> map, where items that a component requires are named in full.
      */
      load: function( args ) {
        var _args = Array.apply(null,arguments);
        _args.shift();
        if ( typeof(_args[0]) == 'object' || typeof(_args[0]) == 'array' ) { _args = _args[0]; }
        if ( _busy ) {
          setTimeout( function(obj) {
            obj.load(args,_args);
          }, 100, this );
          return;
        }
        _busy = true;
        setTimeout( function() {
          if ( typeof(args) == 'function' ) { _on.Success = args; }
          else {
            _on = {};
            for (var i in args) { _on[i] = args[i]; }
          }
          var i = 0, j = _args.length;
          while ( i<j )
          {
            var m = _args[i];
            if ( _dependencies['phedex-'+m] ) { m = 'phedex-'+m; }
            _loader.require(m);
            i++;
          }
          _loader.insert();
        }, 0);
      },

      /**
      * Initialise the loader. Called internally in the constructor, you only need to call it if you wish to override something.
      * @method init
      * @param config {object} configuration object. Takes the same keys at the YUI loader.
      */
      init: function(args) {
        _init(args);
        for (var i in _dependencies) {
          var x = _dependencies[i];
          x.name = i;
          this.add(x);
        }
      },

      /** Returns a full list of modules loaded by this loader. This is the full list since the loader was instantiated, so will grow monotonically if the loader is used several times
      * @method loaded
      * @return {string}
      */
      loaded: function() { return _loader.inserted; },

      /** Return a list of PHEDEX modules known to the loader. Use this to determine the names of instantiatable data-display modules before they are loaded.
      * @method knownModules
      * @param all {boolean} Return all known modules. Defaults to <strong>false</strong>, which explicitly excludes dummy module(s) used for debugging
      * @return {array} List of all source-files matching <strong>/^phedex-module-/</strong>.
      */
      knownModules: function(all) {
        var km=[];
        for (var str in _dependencies) {
          if ( !all && str.match('^phedex-module-dummy') ) {
            continue;
          }
          if ( str.match('^phedex-module-(.+)$') ) {
            km.push(RegExp.$1);
          }
        }
        return km;
      },

      /** Useful for debugging, e.g. for building a menu of files to test loading them one by one
      * @method knownFiles
      * @return {array} a list of names known to the loader that it can be used to load.
      */
      knownObjects: function() {
        var o=[];
        for (var str in _dependencies) {
          o.push(str);
        }
        return o;
      },
      /** Fetch the given URI(s), ignoring errors and not passing back any results to the user. Used to pre-load images and other static content.
      * @method get
      * @return null
      * @param {string} URI to be fetched, may be repeated (i.e. many arguments are allowed)
      */
      get: function() {
        var args = Array.apply(null,arguments), fn;
        fn = function(_args) {
          return function() {
            var _uri = _args.shift();
            if ( !_uri ) { return; }
            log('prefetch: '+_uri,'info',_me);
            var YuC = Yu.Connect;
            YuC.initHeader('user-agent',PxU.UserAgent());
            YuC.asyncRequest(
              'get',
              _uri,
              {timeout:60*1000}
            );
            log('prefetched: '+_uri,'info',_me);
            if ( args[0] ) { setTimeout(fn,100); }
          }
        }(args);
        fn();
        return;
      }
    }
  }
  Yla(this,_construct(this),true);
  this.init();
}
YAHOO.register('phedex-loader', PHEDEX.Loader, {version:'1.0', build:'1'});
