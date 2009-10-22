PHEDEX.Loader = function(opts) {
  var _dependencies = [
    { name: 'phedex-css', type: 'css', fullpath: '/css/phedex.css' },
    { name: 'phedex-base',    requires: ['phedex-css'] },
    { name: 'phedex-util',    requires: ['phedex-base'] },
    { name: 'phedex-datasvc', requires: ['phedex-util','json'] },

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
    { name: 'phedex-core-module-datatable', requires:['phedex-core-module','datatable'] },
    { name: 'phedex-core-module-treeview',  requires:['phedex-core-module','treeview'] },
    { name: 'phedex-module-nodes',          requires:['phedex-core-module-datatable'] },
    { name: 'phedex-module-agents',         requires:['phedex-core-module-datatable'] },
  ],
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
      case 'Failure':  { log(ev+': '+type+', '+item.name); _busy = false; break; }
      case 'Timeout':  { log(ev+': '+type); _busy = false; break; }
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
	  for (var i in args)     { _on[i] = args[i]; }
	}
	for (var i=1; i<=_args.length; i++) { _loader.require(_args[i]); }
	_loader.insert();
      }, 0);
    },
    init: function(args) { _init(args); },
    loaded: function() { return _loader.inserted; },
  }
}
