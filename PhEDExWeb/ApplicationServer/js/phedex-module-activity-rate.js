/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class Agents
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module.Activity');
PHEDEX.Module.Activity.Rate = function(sandbox, string) {
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
          name: 'Refresh',
          source:'component-control',
          parent: 'control',
          payload:{
            handler: 'getData',
            animate:  false,
            disabled: true,
              tooltip:function() {
                        if ( !this.obj.expires ) { return; }
                        var delta = new Date().getTime()/1000;
                        delta = Math.round(this.obj.expires - delta);
                        return 'Data expires in '+delta+' seconds';
                      },
            map: {
              gotData:     'Disable',
              dataExpires: 'Enable'
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
        },
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
// Files, Total Size, Rate, Errors, Expired, Avg.Est.Rate, Avg.Est.Latency
            {key:'from',        label:'From Node'},
            {key:'to',          label:'To Node'},
            {key:'done_files',  label:'Files',      className:'align-right' },
            {key:'done_bytes',  label:'Total Size', className:'align-right', formatter:'customBytes' },
            {key:'rate',        label:'Rate',       className:'align-right', formatter:'customRate' },
            {key:'errors',      label:'Errors',          className:'align-right' },
            {key:'expired',     label:'Expired',         className:'align-right' },
            {key:'est_rate',    label:'Avg.Est.Rate',    className:'align-right', formatter:'customRate' },
            {key:'est_latency', label:'Avg.Est.Latency', className:'align-right' }
          ],
        },
//         sort:{field:'Agent'},
//         hide:['Node'],
        filter: {
          'Agent attributes':{
            map: { to:'AR' },
            fields: {
              'From Node'        :{type:'regex',  text:'From Node-name',     tip:'javascript regular expression' },
              'To Node'          :{type:'regex',  text:'To Node-name',       tip:'javascript regular expression' },
            }
          }
        }
      },

      _processData: function(jData) {
        var i, str,
            nData=jData.length, jEntry, iData, aDataCols=['from','to'], nDataCols=aDataCols.length,
            jTransfers, nTransfer, jTransfer, iTransfer, aTransferCols=['done_files','done_bytes','rate'], nTransferCols=aTransferCols.length,
            Row, Table=[];
        for (iData = 0; iData < nData; iData++) {
          jEntry = jData[iData];
          jTransfers = jEntry.transfer;
          for (iTransfer in jTransfers) {
            jTransfer = jTransfers[iTransfer];
            Row = {};
            for (i = 0; i < nDataCols; i++) {
              this._extractElement(aDataCols[i],jEntry,Row);
            }
            for (i = 0; i < nTransferCols; i++) {
              this._extractElement(aTransferCols[i],jTransfer,Row);
            }
            Table.push(Row);
          }
        }
        log("The data has been processed for data source", 'info', this.me);
        this.needProcess = false;
        return Table;
      },

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed. If the module does not have enough parameters defined, it can notify the sandbox with <strong>needArguments</strong>, and someone out there (e.g. the global filter or the navigator history) can attempt to supply them
 * @method initData
 */
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
//         if ( node ) {
          _sbx.notify( this.id, 'initData' );
//           return;
//         }
//         _sbx.notify( 'module', 'needArguments', this.id );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
//         if ( !arr )      { return; }
//         if ( !arr.node ) { return; }
//         if ( arr.node == node ) { return; }
//         node = arr.node;
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
      },
      getData: function() {
//         if ( !node ) {
//           this.initData();
//           return;
//         }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
//         _sbx.notify( this.id, 'getData', { api:'transferhistory', args:{} } );
        _sbx.notify( this.id, 'getData', { api:'activity/rate', args:{} } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        if ( !data.link ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.link;
//         this.dom.title.innerHTML = node + ': ' + this.data.length + " agents";
        this.fillDataSource(this.data);

        if ( context.maxAge ) {
          setTimeout( function(obj) {
              return function() {
                if ( !obj.id ) { return; } // I may bave been destroyed before this timer fires
                _sbx.notify(obj.id,'dataExpires');
              };
            }(this), context.maxAge * 1000 );
          this.expires = new Date().getTime()/1000;
          this.expires += parseInt(context.maxAge);
        }
      },
      fillExtra: function() {
        var msg = 'If you are reading this, there is a bug somewhere...',
            now = new Date() / 1000,
            minDate = now,
            maxDate = 0,
            i, u, minGMT, maxGMT, dMin, dMax;
        if ( !node ) { msg = 'No extra information available (no node selected yet!)'; }
        for (i in this.data) {
          u = this.data[i].time_update;
          if ( u > maxDate ) { maxDate = u; }
          if ( u < minDate ) { minDate = u; }
        }
        if ( maxDate > 0 )
        {
          minGMT = new Date(minDate*1000).toGMTString();
          maxGMT = new Date(maxDate*1000).toGMTString();
          dMin = Math.round(now - minDate);
          dMax = Math.round(now - maxDate);
          msg = " Update-times: "+dMin+" - "+dMax+" seconds ago";
        }
        this.dom.extra.innerHTML = msg;
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','agents');
