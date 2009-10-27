PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox;
  log('Module: creating a genuine "'+string+'"','info',string);

   var _construct = function() {
    return {
      decorators: {
        'phedex-core-control': {
          handler: function() {
debugger;
            return 'hello world';
          }
        }
      },

      init: function(opts) {
	log('initialising','info',this.id);
	this._init(opts);
	_sbx.notify( this.id, 'init' );
      },
      initData: function() {
	log('initData','info',this.id);
	this.buildTable(this.dom.content,
                  [ {key:'ID',parser:YAHOO.util.DataSource.parseNumber },'Name','Kind','Technology','SE' ]
                 );
	_sbx.notify( this.id, 'initData' );
      },
      getData: function() {
	log('Fetching data','info',this.id);
	this.dom.title.innerHTML = this.me+': fetching data...';
	_sbx.notify( this.id, 'getData', { api: 'nodes' } );
      },
      gotData: function(data) {
	log('Got new data','info',this.id);
	this.data = data.node;
	this.dom.title.innerHTML = this.me+': '+this.data.length+" found";
        this.fillDataSource(this.data);
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(),true);
  return this;
};
