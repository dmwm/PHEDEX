PHEDEX.namespace('Module');
PHEDEX.Module.Nodes = function(sandbox, string) {
  Yla(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox;
  log('Module: creating a genuine "'+string+'"','info',string);

   _construct = function() {
    return {
      decorators: [
        {
          name: 'ContextMenu',
          source:'component-contextmenu'
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem'
            },
            container: 'param'
          }
        }
      ],

      meta: {
        ctxArgs: { Name:'node' },
        table: {
          columns: [ {key:'ID',parser:'number', className:'align-right' },'Name','Kind','Technology','SE' ]
        },
        hide: ['ID'],
        sort: {field:'Name'}, // dir:Yw.DataTable.CLASS_ASC}, // this is the default
        filter: {
          'Node attributes':{
            map:{to:'N'},
            fields:{
              'ID'         :{type:'int',   text:'Node-ID',    tip:'Node-ID in TMDB' },
              'Name'       :{type:'regex', text:'Node-name',  tip:'javascript regular expression' },
              'SE'         :{type:'regex', text:'SE-name',    tip:'javascript regular expression' },
              'Kind'       :{type:'regex', text:'Kind',       tip:'javascript regular expression' },
              'Technology' :{type:'regex', text:'Technology', tip:'javascript regular expression' }
            }
          }
        }
      },

      initData: function() {
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        _sbx.notify( this.id, 'getData', { api: 'nodes' } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        if ( !data.node ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.node;
        this.dom.title.innerHTML = this.me + ': ' + this.data.length + " found";
        this.fillDataSource(this.data);
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
};

log('loaded...','info','nodes');
