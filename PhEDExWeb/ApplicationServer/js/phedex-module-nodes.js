PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox;
  log('Module: creating a genuine "'+string+'"','info',string);

   _construct = function() {
    return {
      decorators: [
        {
          name: 'ContextMenu',
          source:'component-contextmenu',
          payload:{
            typeNames: ['node'],
            typeMap: {node:'Name'},
          }
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem',
            },
            onInit: 'hideByDefault',
            container: 'param',
          },
        },
      ],

      init: function(opts) {
        log('initialising','info',this.me);
        this._init(opts);
        _sbx.notify( this.id, 'init' );
      },
      initData: function() {
        log('initData','info',this.me);
        this.buildTable(
                  [ {key:'ID',parser:YAHOO.util.DataSource.parseNumber },'Name','Kind','Technology','SE' ]
                 );
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        _sbx.notify( this.id, 'getData', { api: 'nodes' } );
      },
      gotData: function(data) {
        log('Got new data','info',this.me);
        this.data = data.node;
        this.dom.title.innerHTML = this.me+': '+this.data.length+" found";
        this.fillDataSource(this.data);
        _sbx.notify( this.id, 'gotData' );
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(),true);
  return this;
};
