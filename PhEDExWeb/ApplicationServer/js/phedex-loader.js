PHEDEX.Loader = function(opts) {
  var _dependencies = {
    'phedex-css':     { type: 'css', fullpath: '/css/phedex.css' },
    'phedex-base':    { requires: ['phedex-css'] },
    'phedex-util':    { requires: ['phedex-base'] },
    'phedex-datasvc': { requires: ['phedex-util','json'] },

//  these are just guesses, and may not work as-is
    'phedex-core-contextmenu': { requires:['phedex-util'] },
    'phedex-core-control':     { requires:['phedex-util'] },
    'phedex-core-filter':      { requires:['phedex-util'] },
//     { name: 'phedex-global-filter',         requires:[] },
//     'phedex-core-widget-registry': { requires: ['phedex-util'] },
//     { name: 'phedex-navigator', requires: ['phedex-core-widget','phedex-widget-nodes'] },

    'phedex-logger':    { requires:['phedex-util', 'logger'] },
    'phedex-sandbox':   { requires:['phedex-util'] },
    'phedex-core':      { requires:['phedex-sandbox','autocomplete','button'] },
    'phedex-module':    { requires:['phedex-core','container','resize'] },
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
      case 'Failure':  { log(ev+': '+type+', '+item.msg); _busy = false; break; }
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
  }
}
