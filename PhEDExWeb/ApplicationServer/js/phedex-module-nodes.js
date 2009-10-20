PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {

  var _sbx = sandbox;
  var _name = string;
  log('Module: creating a genuine "'+_name+'"');

  return {
    init: function() {
      log(_name+': initialising');
      YAHOO.lang.augmentObject(this,new PHEDEX.Core.Module(_sbx,_name));
      this._initModule();
    },
    show: function() {
      this.log('showing');
      this.dom.title.innerHTML = 'Nodes...';
    },
    hide: function() {
      this.log(_name+': hiding');
    },
    destroy: function() {
      this.log(_name+': destroying');
    },
    getData: function() {
      this.log('Fetching data');
      _sbx.notify( _name, 'getData', { api: 'nodes' } );
    },
    gotData: function(data) {
      this.log('Got new data');
      this.data = data.node;
      this.fillHeader();
    },
    fillHeader: function(div) {
      this.dom.title.innerHTML = 'Nodes: '+this.data.length+" found";
    }
  };
};
