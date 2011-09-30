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
            {key:'node',        label:'Node'},
            {key:'name',        label:'Agent'},
            {key:'time_update', label:'Date', formatter:'UnixEpochToUTC'},
            {key:'pid',         label:'PID',  parser:'number', className:'align-right'},
            {key:'version',     label:'Version' },
            {key:'label',       label:'Label' },
            {key:'host',        label:'Host' },
            {key:'state_dir',   label:'State Dir' }
          ]
//             {key:'node',                 label:'Node'},
//             {key:'name',                 label:'Agent'},
//             {key:'agent[0].time_update', label:'Date', formatter:'UnixEpochToUTC'},
//             {key:'agent[0].pid',         label:'PID',  className:'align-right'},
//             {key:'agent[0].version',     label:'Version' },
//             {key:'agent[0].label',       label:'Label' },
//             {key:'host',                 label:'Host' },
//             {key:'agent[0].state_dir',   label:'State Dir' }
//           ],
//           schema: {
//             resultsList: 'node',
//             fields: [ 'host', 'name', 'node', 'agent[0].label', {key:'agent[0].pid', parser:'number'}, 'agent[0].state_dir', 'agent[0].time_update', 'agent[0].version' ]
//           },
        },
        sort:{field:'Agent'},
        hide:['Node','PID','Host','State Dir'],
        filter: {
          'Agent attributes':{
            map: { to:'A' },
            fields: {
              'Node'        :{type:'regex',  text:'Node-name',       tip:'javascript regular expression' },
              'Agent'       :{type:'regex',  text:'Agent-name',      tip:'javascript regular expression' },
              'Label'       :{type:'regex',  text:'Agent-label',     tip:'javascript regular expression' },
              'PID'         :{type:'int',    text:'PID',             tip:'Process-ID' },
              'Date'        :{type:'minmax', text:'Date(s)',         tip:'update-times (seconds ago, i.e. min is most recent)', preprocess:'toTimeAgo' },
              'Version'     :{type:'regex',  text:'Release-version', tip:'javascript regular expression' },
              'Host'        :{type:'regex',  text:'Host',            tip:'javascript regular expression' },
              'State Dir'   :{type:'regex',  text:'State Directory', tip:'javascript regular expression' }
            }
          }
        }
      },

      _processData: function(jData) {
        var i, str,
            jAgents=jData, nAgents=jAgents.length, jAgent, iAgent, aAgentCols=['node','name','host'], nAgentCols=aAgentCols.length,
            jProcs, nProc, jProc, iProc, aProcCols=['time_update','pid','version','label','state_dir'], nProcCols=aProcCols.length,
            Row, Table=[];
        for (iAgent = 0; iAgent < nAgents; iAgent++) {
          jAgent = jAgents[iAgent];
          jProcs = jAgent.agent;
          for (iProc in jProcs) {
            jProc = jProcs[iProc];
            Row = {};
            for (i = 0; i < nAgentCols; i++) {
              this._extractElement(aAgentCols[i],jAgent,Row);
            }
            for (i = 0; i < nProcCols; i++) {
              this._extractElement(aProcCols[i],jProc,Row);
            }
            Table.push(Row);
          }
        }
        this.needProcess = false;
        return Table;
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
        if ( !arr )      { return; }
        if ( !arr.node ) { return; }
        if ( arr.node == node ) { return; }
        node = arr.node;
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
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
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        if ( !data.node ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.node;
        this.dom.title.innerHTML = node + ': ' + this.data.length + ' agents';
        this.fillDataSource(this.data);
      },
      fillExtra: function() {
        var msg = 'If you are reading this, there is a bug somewhere...',
            now = new Date() / 1000,
            minDate = now,
            maxDate = 0,
            i, u, minUTC, maxUTC, dMin, dMax;
        if ( !node ) { msg = 'No extra information available (no node selected yet!)'; }
        for (i in this.data) {
          u = this.data[i].time_update;
          if ( u > maxDate ) { maxDate = u; }
          if ( u < minDate ) { minDate = u; }
        }
        if ( maxDate > 0 )
        {
          minUTC = new Date(minDate*1000).toUTCString();
          maxUTC = new Date(maxDate*1000).toUTCString();
          dMin = Math.round(now - minDate);
          dMax = Math.round(now - maxDate);
          msg = ' Update-times: '+dMin+' - '+dMax+' seconds ago';
        }
        this.dom.extra.innerHTML = msg;
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','agents');
