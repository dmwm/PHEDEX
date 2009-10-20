PHEDEX.Loader = function(opts) {
  var _dependencies = [
    { name: 'phedex-css', type: 'css', fullpath: '/css/phedex.css' },
    { name: 'phedex-base',    requires: ['phedex-css'] },
    { name: 'phedex-util',    requires: ['phedex-base'] },
    { name: 'phedex-datasvc', requires: ['phedex-util'] },

//  these are just guesses, and may not work as-is
    { name: 'phedex-page',             requires:['phedex-util'] },
    { name: 'phedex-event',            requires:['phedex-util'] },
    { name: 'phedex-core-logger',      requires:['phedex-util'] },
    { name: 'phedex-core-contextmenu', requires:['phedex-util'] },
    { name: 'phedex-core-control',     requires:['phedex-util'] },
    { name: 'phedex-core-filter',      requires:['phedex-util'] },
    { name: 'phedex-core-widget',      requires:['phedex-core-widget-registry', 'phedex-core-control', 'phedex-core-filter', 'phedex-core-contextmenu', 'phedex-event', 'phedex-datasvc', 'phedex-page'] },
    { name: 'phedex-core-widget-datatable', requires:['phedex-core-widget'] },
//     { name: 'phedex-core-widget-treeview',  requires:['phedex-core-widget'] },
//     { name: 'phedex-global-filter',         requires:[] },
//     { name: 'phedex-widget-agents',         requires:['phedex-core-widget-datatable'] },
//     { name: 'phedex-widget-nodes',          requires:['phedex-core-widget-datatable'] },
//     { name: 'phedex-widget-linkview',       requires:['phedex-core-widget-treeview'] },
//     { name: 'phedex-widget-requestview',    requires:['phedex-core-widget-treeview'] },
    { name: 'phedex-core-widget-registry', requires: ['phedex-util'] },
//     { name: 'phedex-navigator', requires: ['phedex-core-widget','phedex-widget-nodes'] },

    { name: 'phedex-core-logger',  requires:['phedex-util', 'logger'] },
    { name: 'phedex-sandbox',      requires:['phedex-util'] },
    { name: 'phedex-core-app',     requires:['phedex-sandbox'] },
    { name: 'phedex-core-module',  requires:['phedex-core-app','autocomplete','button','container','resize'] },
    { name: 'phedex-module-nodes', requires:['phedex-core-module','treeview','datatable'] },
  ];

  var _name = 'PxLoader';
  var _success;

  var _callback = function(args) {
    var ev, type, item;
    ev   = args[0];
    type = args[1];
    item = args[2];
    switch (type) {
      case 'Progress': { log(ev+': '+type+', '+item.name); break; }
      case 'Success':  {
	var l='';
	for (var i in item) { l += i+' ';};
	log(ev+': '+type+', '+l);
	if ( _success ) { setTimeout( function() { _success(_name,item); },0); }
	break;
      }
      case 'Failure':  { log(ev+': '+type+', '+item.name); break; }
      case 'Timeout':  { log(ev+': '+type); break; }
    };
  };

  var _conf = {
    loadOptional:  true,
    allowRollup:  false,
    base:	  '/yui/build/',
    timeout:	10000,
    onSuccess:  function(item) { _callback([_name, 'Success',  _loader.inserted]); },
    onProgress: function(item) { _callback([_name, 'Progress', item]); },
    onFailure:  function(item) { _callback([_name, 'Failure',  item]); },
    onTimeout:  function(item) { _callback([_name, 'Timeout',  item]); },
  }
  if ( opts ) {
    for (var i in opts) { _conf[i] = opts[i]; }
  }

  var _init = function(cf) {
    for (var i in cf) {
      _loader[i] = cf[i];
    }
  };

  var _loader = new YAHOO.util.YUILoader();
  _init(_conf);

  for (var i in _dependencies) {
    var x = _dependencies[i];
    if ( !x.type ) { x.type = 'js'; }
    if ( !x.fullpath ) { x.fullpath = '/'+x.type+'/'+x.name+'.'+x.type; }
    if ( !x.requires ) { x.requires = []; }
    _loader.addModule(x);
  }

  return {
    load: function( args, what ) {
      var _args = arguments;
      setTimeout( function() {
	_success = null;
	if ( typeof(args) == 'function' ) { _success = args; }
	else {
	  _loader.onSuccess  = _conf.onSuccess;
	  _loader.onProgress = _conf.onProgress;
	  _loader.onFailure  = _conf.onFailure;
	  _loader.onTimeout  = _conf.onTimeout;
	  for (var i in args)     { _loader[i] = args[i]; }
	}
	for (var i=1; i<=_args.length; i++) { _loader.require(_args[i]); }
	_loader.insert();
      }, 0);
    },
    init: function(args) {
      _init(args);
    },
    name: function(string) { _name = string; },
  }
}
