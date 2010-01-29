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

      meta: {
        table: {
          columns: [ {key:'ID',parser:YAHOO.util.DataSource.parseNumber },'Name','Kind','Technology','SE' ],
        },
        hide: ['ID'],
        sort: {field:'Name'}, // dir:YAHOO.widget.DataTable.CLASS_ASC}, // this is the default
        filter: {
          'Node attributes':{
            map:{to:'N'},
            fields:{
              'id'         :{type:'int',   text:'Node-ID',    tip:'Node-ID in TMDB' },
              'name'       :{type:'regex', text:'Node-name',  tip:'javascript regular expression' },
              'se'         :{type:'regex', text:'SE-name',    tip:'javascript regular expression' },
              'kind'       :{type:'regex', text:'Kind',       tip:'javascript regular expression' },
              'technology' :{type:'regex', text:'Technology', tip:'javascript regular expression' }
            }
          }
        },
      },

      initData: function() {
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        _sbx.notify( this.id, 'getData', { api: 'nodes' } );
      },
      gotData: function(data) {
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
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

log('loaded...','info','nodes');