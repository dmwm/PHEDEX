PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {

  var _sbx = sandbox;
  log('Module: creating a genuine "'+string+'"','info',string);

   var _construct = function() {
    return {
      init: function() {
	log('initialising','info',this._me);
	this._initModule();
      },
      show: function() {
	log('showing','info',this._me);
	this.dom.title.innerHTML = 'Nodes...';
      },
      initData: function() {
	log('initData','info',this._me);
	this.buildTable(this.dom.content,
                  [ {key:'ID',parser:YAHOO.util.DataSource.parseNumber },'Name','Kind','Technology','SE' ]
                 );
      },
      hide: function() {
	log('hiding','info',this._me);
      },
      destroy: function() {
	log('destroying','info',this._me);
      },
      getData: function() {
	log('Fetching data','info',this._me);
	_sbx.notify( this._me, 'getData', { api: 'nodes' } );
      },
      gotData: function(data) {
	log('Got new data','info',this._me);
	this.data = data.node;
	this.fillHeader();
        this.fillDataSource(this.data);
      },
      fillHeader: function(div) {
	this.dom.title.innerHTML = 'Nodes: '+this.data.length+" found";
      }
    };
  };
  YAHOO.lang.augmentObject(this,new PHEDEX.Core.Module.DataTable(_sbx,string));
  YAHOO.lang.augmentObject(this,_construct(),true);
  return this;
};
