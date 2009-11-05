PHEDEX.namespace('Module');
PHEDEX.Module.Agents = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox,
      node = 'T1_US_FNAL_Buffer';
  log('Module: creating a genuine "'+string+'"','info',string);

   var _construct = function(obj) {
    return {
      decorators: [
        {
          name: 'Extra',
          source:'component-control',
          parent: 'control',
          payload:{
            target: 'extra',
            handler: 'fillExtra',
            animate:false,
//             hover_timeout:200,
          }
        },
        {
          name: 'Refresh',
          source:'component-control',
          parent: 'control',
          payload:{
            handler: 'getData',
            animate:false,
            map: {
                   gotData:     'Disable',
                   dataExpires: 'Enable',
                  },
          }
        },
        {
          name: 'ContextMenu',
          source:'component-contextmenu',
          payload:{
            args: {'agent':'Name'},
            typeMap: [ 'dataTable' ],
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
            container: 'param',
          },
        },
        { name: 'MouseOver' },
      ],

      init: function(opts) {
        log('initialising','info',this.me);
        YAHOO.lang.augmentObject(opts, {
          width:500,
          height:200,
          minwidth:300,
          minheight:50,
          defsort:'Agent',
          defhide:['PID','Version','Host','State Dir']
        });
        this._init(opts);
        _sbx.notify( this.id, 'init' );
      },
      initData: function() {
        log('initData','info',this.me);
        this.buildTable(this.dom.content,
            [ 'Agent',
              {key:"Date", formatter:'UnixEpochToGMT'},
              {key:'PID',parser:YAHOO.util.DataSource.parseNumber},
              'Version','Label','Host','State Dir'
            ],
            {Agent:'name', Date:'time_update', 'State Dir':'state_dir' }
          );
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        _sbx.notify( this.id, 'getData', { api:'agents', args:{node:node} } );
      },
      gotData: function(data) {
        log('Got new data','info',this.me);
        this.data = data.node[0].agent;
        this.dom.title.innerHTML = node+': '+this.data.length+" agents";
        this.fillDataSource(this.data);
        _sbx.notify( this.id, 'gotData' );
//      Fake notification that the data is now stale. This should use the 'Expires' or 'Cache-Control' header from the data-service, but that isn't returned in the data
        setTimeout( function(obj) {
            return function() { _sbx.notify(obj.id,'dataExpires'); };
          }(this), 300 * 1000 );
        _sbx.notify( this.id, 'updated' );
      },
      fillExtra: function() {
        var msg = 'If you are reading this, there is a bug somewhere...',
            now = new Date() / 1000,
            minDate = now,
            maxDate = 0;
        for ( var i in this.data) {
          var u = this.data[i]['time_update'];
          if ( u > maxDate ) { maxDate = u; }
          if ( u < minDate ) { minDate = u; }
        }
        if ( maxDate > 0 )
        {
          var minGMT = new Date(minDate*1000).toGMTString(),
              maxGMT = new Date(maxDate*1000).toGMTString(),
              dMin = Math.round(now - minDate),
              dMax = Math.round(now - maxDate);
          msg = " Update-times: "+dMin+" - "+dMax+" seconds ago";
        }
        this.dom.extra.innerHTML = msg;
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  return this;
};
//   var filterDef = {
//     'Agent attributes':{
//       map: { to:'A' },
//       fields: {
// 	'name'        :{type:'regex',  text:'Agent-name',      tip:'javascript regular expression' },
// 	'label'       :{type:'regex',  text:'Agent-label',     tip:'javascript regular expression' },
// 	'pid'         :{type:'int',    text:'PID',             tip:'Process-ID' },
// 	'time_update' :{type:'minmax', text:'Date(s)',         tip:'update-times (seconds since now)', preprocess:'toTimeAgo' },
// 	'version'     :{type:'regex',  text:'Release-version', tip:'javascript regular expression' },
// 	'host'        :{type:'regex',  text:'Host',            tip:'javascript regular expression' },
// 	'state_dir'   :{type:'regex',  text:'State Directory', tip:'javascript regular expression' }
//       }
//     }
//   };

// PHEDEX.Core.Widget.Registry.add('PHEDEX.Widget.Agents','node','Show Agents',PHEDEX.Widget.Agents, {context_item:true});
