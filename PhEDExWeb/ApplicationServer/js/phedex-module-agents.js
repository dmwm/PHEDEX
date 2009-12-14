/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class Agents
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module');
PHEDEX.Module.Agents = function(sandbox, string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox,
      node;
  log('Module: creating a genuine "'+string+'"','info',string);

   _construct = function(obj) {
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

      options: {
        width:500,
        height:200,
        minwidth:600,
        minheight:50,
      },

      meta: {
        table: {
          columns: [
              'Agent',
              {key:"Date", formatter:'UnixEpochToGMT'},
              {key:'PID',parser:YAHOO.util.DataSource.parseNumber},
              'Version','Label','Host','State Dir'
            ],
          map: {Agent:'name', Date:'time_update', 'State Dir':'state_dir' }
        },
        defsort:'Agent',
        defhide:['PID','Host','State Dir']
      },

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed. If the module does not have enough parameters defined, it can notify the sandbox with <strong>needArguments</strong>, and someone out there (e.g. the global filter or the navigator history) can attempt to supply them
 * @method initData
 */
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( node ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
        if ( arr ) { node = arr.node; }
        if ( !node ) { return; }
        this.dom.title.innerHTML = 'setting parameters...';
      },
      getData: function() {
        if ( !node ) {
          this.initData();
          return;
        }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'agents', args:{node:node} } );
      },
      gotData: function(data) {
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        this.data = data.node[0].agent;
        this.dom.title.innerHTML = node+': '+this.data.length+" agents";
        this.fillDataSource(this.data);
        _sbx.notify( this.id, 'gotData' );
//      Fake notification that the data is now stale. This should use the 'Expires' or 'Cache-Control' header from the data-service, but that isn't returned in the data
        setTimeout( function(obj) {
            return function() { _sbx.notify(obj.id,'dataExpires'); };
          }(this), 300 * 1000 );
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
