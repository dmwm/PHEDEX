/**
 * The PhEDEx Application.
 * @module PHEDEX
 */

/**
 * The PHEDEX global namespace object.
 * @class PHEDEX
 */
PHEDEX= {}

/** 
 * Creates a namespace rooted from PHEDEX.
 * @method namespace
 * @param namespace {string} Namespace to create, optionally with  dot-notation, e.g. 'Appserv' or 'Base.Object'.
 * @return {object} The namespace created.
 */
// For more information, see:
//   http://yuiblog.com/blog/2007/06/12/module-pattern/
PHEDEX.namespace = function() {
    var a=arguments, o=null, i, j, d;
    for (i=0; i<a.length; i=i+1) {
        d=(""+a[i]).split(".");
        o=PHEDEX;

        // PHEDEX is implied, so it is ignored if it is included
        for (j=(d[0] == "PHEDEX") ? 1 : 0; j<d.length; j=j+1) {
            o[d[j]]=o[d[j]] || {};
            o=o[d[j]];
        }
    }

    return o;
};

/**
 * Contains application globals.
 * @namespace PHEDEX
 * @class Appserv
 */
PHEDEX.Appserv = {};

/**
 * Sets the version of the application, using a string set by the RPM build or a default.
 * @method makeVersion
 * @namespace PHEDEX.Appserv
 * @protected
 * @return {string} The version string
 */
PHEDEX.Appserv.makeVersion = function() {
  var version = '@APPSERV_VERSION@'; // set when RPM is built
  return version.match(/APPSERV_VERSION/) ? '0.0.0' : version;
};

/**
 * The version of the application.
 * @property Version
 * @type string
 * @public
 */
PHEDEX.Appserv.Version = PHEDEX.Appserv.makeVersion();

/**
 * Base object for all graphical entities in the application.
 * @namespace PHEDEX.Base
 * @class Object
 * @constructor
 */
PHEDEX.namespace('Base');
PHEDEX.Base.Object = function() {
  return {
    /**
     * Fired when the "extra" div has been populated.
     * @event onFillExtra
     */
// TODO replace events with notifications...
    onFillExtra: new YAHOO.util.CustomEvent("onFillExtra", this, false, YAHOO.util.CustomEvent.LIST),

    /**
     * Namespace for DOM elements managed by this object.
     * @property dom
     * @type object
     * @protected
     */
    dom: {},

    /**
     * Namespace for control elements managed by this object.
     * @property ctl
     * @type object
     * @protected
     */
    ctl: {},

    /**
     * Namespace for options in effect for this object.
     * @property options
     * @type object
     * @protected
     */
    options: {},

    /**
     * Decorations to apply for this object. E.g, context-menus, 'extra' handlers etc
     * @property decorators
     * @type object
     * @protected
     */
    decorators: {},

    /**
     * Returns the class name of this object
     * @method me
     * @returns string
     */
    // TODO:  There must be a lower-level way to do this, using obj.constructor or simmilar
//     me: function() { return this._me; },
  };
}

/**
 * on-demand loading of all phedex code and the YUI code it depends on
 * @namespace PHEDEX.Loader
 * @class Object
 * @constructor
 */
PHEDEX.Loader = function(opts) {
  var _dependencies = {
    'phedex-css':     { type: 'css', fullpath: '/css/phedex.css' },
    'phedex-util':    { requires: ['phedex-css'] },
    'phedex-datasvc': { requires: ['phedex-util','json'] },

//  these are just guesses, and may not work as-is
    'phedex-core-contextmenu': { requires:['phedex-util'] },
    'phedex-core-control':     { requires:['phedex-util','animation'] },
    'phedex-core-filter':      { requires:['phedex-util'] },

    'phedex-component-control':     { requires:['phedex-util','animation'] },

//     { name: 'phedex-global-filter',         requires:[] },
//     'phedex-core-widget-registry': { requires: ['phedex-util'] },
//     { name: 'phedex-navigator', requires: ['phedex-core-widget','phedex-widget-nodes','autocomplete','button'] },

    'phedex-logger':    { requires:['phedex-util', 'logger'] },
    'phedex-sandbox':   { requires:['phedex-util'] },
    'phedex-core':      { requires:['phedex-sandbox'] },
    'phedex-module':    { requires:['phedex-core','container','resize','button'] },
    'phedex-datatable': { requires:['datatable'] },
    'phedex-treeview':  { requires:['treeview'] },
    'phedex-module-nodes':  { requires:['phedex-module','phedex-datatable'] },
    'phedex-module-agents': { requires:['phedex-module','phedex-datatable'] },
  },
      _me = 'PxLoader',
      _busy = false,
      _success,
      _on = {},
      _loader = new YAHOO.util.YUILoader(),
      _conf = {
        loadOptional:  true,
        allowRollup:  false,
        base:        '/yui/build/',
        timeout:      15000,
        onSuccess:  function(item) { _callback([_me, 'Success',  _loader.inserted]); },
        onProgress: function(item) { _callback([_me, 'Progress', item]); },
        onFailure:  function(item) { _callback([_me, 'Failure',  item]); },
        onTimeout:  function(item) { _callback([_me, 'Timeout',  item]); },
      };

  var _callback = function(args) {
    var ev   = args[0],
        type = args[1],
        item = args[2];
    switch (type) {
      case 'Progress': { log(ev+': '+type+', '+item.name); break; }
      case 'Success':  {
        var l='';
        for (var i in item) { l += i+' ';};
        log(ev+': '+type+', '+l);
        _busy = false;
        break;
      }
      case 'Failure':  { log(ev+': '+type+', '+item.msg,'error',_me); _busy = false; break; }
      case 'Timeout':  { log(ev+': '+type,'error',_me); _busy = false; break; }
    };
    if ( _on[type] ) { setTimeout( function() { _on[type](item); },0); }
  };

  var _init = function(cf) {
    for (var i in cf) {
      _loader[i] = cf[i];
    }
  };

  if ( opts ) {
    for (var i in opts) { _conf[i] = opts[i]; }
  }
  _init(_conf);

  for (var i in _dependencies) {
    var x = _dependencies[i];
    x.name = i;
    if ( !x.type ) { x.type = 'js'; }
    if ( !x.fullpath ) { x.fullpath = '/'+x.type+'/'+x.name+'.'+x.type; }
    if ( !x.requires ) { x.requires = []; }
    _loader.addModule(x);
  }

  return {
    load: function( args, what ) {
      if ( _busy ) {
        setTimeout( function() { this.load(args,what) },100);
        log('Logger is busy, waiting...','info','Logger');
        return;
      }
      _busy = true;
      var _args = arguments;
      setTimeout( function() {
        if ( typeof(args) == 'function' ) { _on.Success = args; }
        else {
          _on = {};
          for (var i in args) { _on[i] = args[i]; }
        }
        for (var i=1; i<_args.length; i++)
        {
          var m = _args[i];
          if ( _dependencies['phedex-'+m] ) { m = 'phedex-'+m; }
          _loader.require(m);
        }
        _loader.insert();
      }, 0);
    },
    init: function(args) { _init(args); },
    loaded: function() { return _loader.inserted; },
    knownModules: function() {
      var km=[];
      for (var str in _dependencies) {
        if ( str.match('^phedex-module-(.+)$') ) {
          km.push(RegExp.$1);
        }
      }
      return km;
    },
  }
}
