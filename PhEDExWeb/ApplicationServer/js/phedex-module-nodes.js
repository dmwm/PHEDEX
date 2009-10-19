PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {

  var _sbx = sandbox;
  var _name = string;
  log('Module: creating a genuine "'+_name+'"');

  onRegistryCreate = function(obj) {
    return function() {
      _sbx.notify('moduleCreate',_name);
    }
  }();

  _sbx.listen('registryCreate',onRegistryCreate);
  _sbx.notify('moduleCreate',_name);
  return {
    init: function() {
      log(_name+': initialising');
      YAHOO.lang.augmentObject(this,new PHEDEX.Core.Module(_sbx,_name));
      this._initModule();
    },
    show: function() {
      log(_name+': showing');
      this.dom.header.innerHTML = 'this is a Nodes module...';
    },
    hide: function() {
      log(_name+': hiding');
    },
    destroy: function() {
      log(_name+': destroying');
    },
  };
};
