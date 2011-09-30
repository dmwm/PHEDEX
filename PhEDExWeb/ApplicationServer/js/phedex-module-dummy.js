/**
 * This is a dummy module, with no DOM or data-service interaction. It provides only the basic interaction needed for the core to be able to control it, for debugging or stress-testing the core and sandbox.
 * @namespace PHEDEX.Module
 * @class Dummy
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module');
PHEDEX.Module.Dummy = function(sandbox, string) {
  Yla(this,new PHEDEX.Module(sandbox,string));
  var _sbx = sandbox;
  _construct = function(obj) {
    return {
      getData: function() {
// dummy-out the call to get data, skip the dataservice completely. Uncomment the next three lines to get a module that simply 'bounce's off the data-service
//         _sbx.notify( this.id, 'getData', { api:'bounce' } );
//       },
//       gotData: function(data) {
      },
    };
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','dummy');
