PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.Module.Core(sandbox,string));

  var _sbx = sandbox;
  var _name = string;
  log('Module: creating "'+_name+'"');

  onRegistryCreate = function(obj) {
    return function() {
      _sbx.notify('moduleCreate',_name);
    }
  }();

  sandbox.listen('registryCreate',onRegistryCreate);
  sandbox.notify('moduleCreate',_name);
  return {
    init: function() {
      log(_name+': initialising');
    },
    show: function() {
      log(_name+': showing');
    },
    hide: function() {
      log(_name+': hiding');
    },
    destroy: function() {
      log(_name+': destroying');
    },
  };
};
