/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class Agents
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module.Shift');
PHEDEX.Module.Shift.QueuedQuality = function(sandbox, string) {
  Yla(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox, node;
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
            animate:false
          }
        },
        {
          name: 'modeFull',
          source:'component-control',
          parent: 'control',
          payload:{
            handler: 'handleModeFull',
            text:    'Show Full',
            tooltip: function() {
              return 'Toggle between showing all nodes or only the nodes with a problem (re-fetches data from the data-service)';
            },
            map: {
              setModeFullLabel: 'Label'
            }
          }
        },
        {
          name: 'ContextMenu',
          source:'component-contextmenu',
          payload:{
          }
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

      options: {
        width:500,
        height:200,
        minwidth:600,
        minheight:50
      },

      meta: {
        ctxArgs: { Node:'node' },
        table: {
          columns: [
            {key:'node',           label:'Node'},
            {key:'status_text',    label:'Status',               className:'align-left'},
            {key:'reason',         label:'Reason',               className:'align-left'},
            {key:'max_pend_bytes', label:'Max. Queued Bytes',    className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'cur_pend_bytes', label:'Current Queued Bytes', className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'cur_quality',    label:'Current Quality (%)',  className:'align-right', parser:'number' },
          ],
          nestedColumns:[
            {key:'timebin',    label:'Timebin',  formatter:'UnixEpochToUTC' },
            {key:'pend_bytes', label:'Queued',      className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'failed',     label:'Failed',      className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'done',       label:'Done',        className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'quality',    label:'Quality (%)', className:'align-right', parser:'number' },
          ]
        },
        sort:{field:'Node'},
        hide:['Status' ],
        filter: {
          'Queued-Quality attributes':{
            map: { to:'TM' },
            fields: {
              'Node'            :{type:'regex',  text:'Node-name',             tip:'javascript regular expression' },
              'Status'          :{type:'regex',  text:'Status',                tip:'javascript regular expression' },
              'Reason'          :{type:'regex',  text:'Reason',                tip:'javascript regular expression' },
              'Max. Transferred':{type:'minmax', text:'Max. Transferred Data', tip:'integer range (bytes)' },
              'Max. Migrated'   :{type:'minmax', text:'Max. Migrated Data',    tip:'integer range (bytes)' },
              'Transferred'     :{type:'minmax', text:'Transferred Data',       tip:'integer range (bytes)' },
              'Migrated'        :{type:'minmax', text:'Migrated Data',         tip:'integer range (bytes)' }
            }
          }
        }
      },

      modeFull:0,

      /**
      * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
      * @method _processData
      * @param jsonBlkData {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
      * @private
      */
      _processData: function(jsonData) {
        var t=[], table = this.meta.table, i = jsonData.length, k = table.columns.length, j, a, c, map;
        map = [ 'green-circle', 'yellow-circle', 'red-circle' ]; // indexing here is tied to status-value, 0=>OK, 1=>warning, 2=>error
        while (i > 0) {
          i--
          a = jsonData[i];
          a['reason'] = PxU.icon[map[a['status']]] + a['reason'];
        }
        this.needProcess = false; //No need to process data further
        return jsonData;
      },

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed. If the module does not have enough parameters defined, it can notify the sandbox with <strong>needArguments</strong>, and someone out there (e.g. the global filter or the navigator history) can attempt to supply them
 * @method initData
 */
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
          _sbx.notify( this.id, 'initData' );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
      },
      getData: function() {
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'shift/queuedquality', args:{full:this.modeFull} } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        this.data = data.queuedquality;
        if ( !this.data ) {
          throw new Error('data incomplete for '+context.api);
        }
       this.needProcess = true;
       this.fillDataSource(this.data);
        var nOK=0, nNotOK=0, tm = data.queuedquality;
        this.dom.extra.innerHTML = 'No stuck nodes:';
        this.stuck = [];
        for (var i in tm) {
          if ( !tm[i].status ) { nOK++; }
          else                 { nNotOK++; this.stuck.push(tm[i].node); }
        }
        this.dom.title.innerHTML = nNotOK+' nodes not OK';
        if ( this.modeFull ) {
          this.dom.title.innerHTML = nOK+' nodes OK, '+this.dom.title.innerHTML;
        }
//        if ( nNotOK ) {
// TODO This should be something more meaningful, like an explanation of the algorithm...
//        }
        _sbx.notify( this.id, 'setModeFullLabel', this.setModeFullLabel() );
        if ( context.maxAge ) {
          setTimeout( function(obj) {
              if ( !obj.id ) { return; } // I may bave been destroyed before this timer fires
              _sbx.notify(obj.id,'dataExpires',{resetTT:true});
            }, context.maxAge * 1000, this );
          this.expires = new Date().getTime()/1000;
          this.expires += parseInt(context.maxAge);
        }
      },
      setModeFullLabel: function() {
        if ( this.modeFull ) { return 'Show Brief'; }
        else                 { return 'Show Full'; }
      },
      fillExtra: function() {
        this.stuck.sort( function (a, b) { return (a > b) - (a < b); } );
        this.dom.extra.innerHTML = 'List of stuck nodes:<br/>' + this.stuck.join(' ');
      },
      handleModeFull: function() {
        var ctl = this.ctl['modeFull'];
        if ( this.modeFull ) {
          this.modeFull = 0;
          ctl.Label('Show Full');
        } else {
          this.modeFull = 1;
          ctl.Label('Show Brief');
        }
        ctl.Hide();
        this.getData();
      },
      specificState: function(state) {
        if ( !state ) { return {full:this.modeFull}; }
        var i, k, v, kv, update=0, arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'full'  && v != this.modeFull ) { update++; this.modeFull = v; }
        }
        if ( !update ) { return; }
        log('set full='+this.modeFull+' from state','info',this.me);
        this.getData();
      },
// pre-fetch the icons, so they are here when we need them
      initMe: function() {
        this.decorators.push(
        {
          name: 'Info',
          source:'component-dom',
          parent: 'control',
          payload:{
            type: 'a',
//             handler: 'fillInfo',
            attributes: {
              target:     'phedex_datasvc_doc',
              href:       PxW.DataserviceBaseURL + 'doc/shift/queuedquality',
              innerHTML:  '&nbsp;<em>i</em>&nbsp;',
              className:  'phedex-link',
              title:      'Information about the algorithm used in this module, from the dataservice documentation.'
            },
            style: {
              fontWeight: 'bold',
              color:      'white',
              backgroundColor: '#00f'
            }
          }
        });
        PxL.get(PxW.WebAppURL+'/images/icon-circle-red.png',
                PxW.WebAppURL+'/images/icon-circle-yellow.png',
                PxW.WebAppURL+'/images/icon-circle-green.png');
      },
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','queuedquality');
