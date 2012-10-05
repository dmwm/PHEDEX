PHEDEX.namespace('Nextgen.Activity');
PHEDEX.Nextgen.Activity.RatePlots = function(sandbox) {
  var string = 'nextgen-activity-rateplots';
  Yla(this,new PHEDEX.Module(sandbox,string));

  var _sbx = sandbox, node;
  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      init: function() {
        alert("Hi Chih-Hao, insert your code here!");
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','nextgen-activity-rateplots');
