PHEDEX.namespace('Core');

PHEDEX.Core.App = function(sandbox) {
  var _modules = [];
  var _sbx = sandbox;

  return {
    dumpList: function() {
      for (var i in _modules) { myLog('dump of registered modules: "'+i+'"'); }
    },

    start: function() {
      var onModuleCreate = function(obj) {
	return function(ev,arr) {
	  var string = arr[0];
	  if ( !_modules[string] ) { _modules[string]=0; }
	  _modules[string]++;
	}
      }(this);
//    listen before notify, because otherwise modules would reply to the notification before I am listening for them...
      _sbx.listen('moduleCreate',onModuleCreate);
      _sbx.notify('registryCreate');
    },
  };
}