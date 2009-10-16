PHEDEX.namespace('Core');

PHEDEX.Core.App = function(sandbox) {
  var _modules = [];
  var _sbx = sandbox;
  var _parent = document.getElementById('phedex-main');
  if ( !parent ) { throw new Error('cannot find parent element for core'); }
  return {
    dumpList: function() {
      for (var i in _modules) { log('dump of registered modules: "'+i+'"'); }
    },

    create: function() {
      var onModuleCreate = function(obj) {
	return function(ev,arr) {
	  var string = arr[0];
	  var obj    = arr[1];
	  if ( !_modules[string] ) { _modules[string]={obj:obj,state:'created'}; }
	}
      }(this);
      _sbx.listen('moduleCreate',onModuleCreate);
      _sbx.notify('registryCreate');
    },

    createModule: function(name) {
      var m = new PHEDEX.Core.Module(PxS,name);
      m.connect();
    },

    init: function() {
      for (var i in _modules) {
	log('initialise module: "'+i+'"');
        var el = PxU.makeChild(_parent, 'div', {});
	_modules[i].obj.initObj(el);
      }
      log('all modules initialised');
    },

    send: function(ev,who,args) {
      log('send '+ev+' to module: "'+who+'"');
      _sbx.notify('module',ev,who,args);
    },
  };
}