PHEDEX.namespace('Nextgen.Components');
PHEDEX.Nextgen.Components.Status = function(sandbox) {
  var string = 'nextgen-components-status';
  Yla(this,new PHEDEX.Module(sandbox,string));

  var _sbx = sandbox, node;
  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      init: function() {
        alert("Hi Alberto, insert your code here!");
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','nextgen-components-status');
