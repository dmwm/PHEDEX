PHEDEX.Module = function(sandbox, string) {
  var _sbx = sandbox;
  this.name = string;
  myLog('Module: creating "'+string+'"');
  this.onRegistryCreate = function(obj) {
    return function() {
      _sbx.notify('moduleCreate',obj.name);
    }
  }(this);
  sandbox.listen('registryCreate',this.onRegistryCreate);
  sandbox.notify('moduleCreate',this.name);
  return this;
};
