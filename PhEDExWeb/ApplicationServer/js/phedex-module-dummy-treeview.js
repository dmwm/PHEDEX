/**
 * This is a dummy module, with no DOM or data-service interaction. It provides only the basic interaction needed for the core to be able to control it, for debugging or stress-testing the core and sandbox.
 * @namespace PHEDEX.Module.Dumy
 * @class TreeView
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module.Dummy');
PHEDEX.Module.Dummy.TreeView = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.TreeView(sandbox,string));
  var _sbx = sandbox;
  _construct = function(obj) {
    return {
      fillExtra: function() {},
      hideByDefault: function() {},
      addMenuItem: function() {},
      init: function(opts) {
        this._init(opts);
        _sbx.notify( this.id, 'init' );
      },
      initData: function() {
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
// dummy-out the call to get data, skip the dataservice completely. Uncomment the next three lines to get a module that simply 'bounce's off the data-service
//         _sbx.notify( this.id, 'getData', { api:'bounce' } );
//       },
//       gotData: function(data) {
        _sbx.notify( this.id, 'gotData' );
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  return this;
};

log('loaded...','info','dummy-treeview');