/*
 TODO:
1) For T1_%_MSS, "Queued data" should show the sum of data queued to T1_%_Buffer and T1_%_MSS Since here we're trying to understand if the data isn't being queued at all, the interesting thing in this comparison is the total amount of queued data on the route, not just the queue to the final hop. Of course this will become a mess if we ever enable multi-hop routing!
 -> done!

2) Sorting by "Max Queued" or "Max Requested" is sorting the values based on the string representation; a sorting on the numerical value would be more useful.
 -> parsing of string to number is not happening, because _processData isn't being called - or rather, does nothing. This would be fine if the datasvc returned numerical values instead of strings, and it is supposed to, but it doesn't. Somewhere inside JSON::XS::encode_json, numerical values are not being recognised correctly, and are being returned as strings.
 -> done!

3) I'm wondering if some sort of 'red alert' flashing triangle (or KIT-style  unhappy face, which is more color-blind-friendly) would be more appreciated by the shifters instead of a simple 'Problem' text label

4) warning-state for expert operators, where ratio is lower than the threshold (9) but still significantly greater than 1 (???)

5) the OK/Problem logic doesn't seem to be correct for some sites. For example T1_CH_CERN_MSS:
http://cmswttest.cern.ch/phedex/datasvc/app#page=instance~Production+type~none+widget~shift-requestedqueued+module~sort{RQ.Status%20desc}filter{RQ.Node%3DT1_CH_CERN_MSS}
The volumes requested/queued are 0 since 8:00 am, so the Status should now be OK with comment 'No data requested'
On the other hand, for T2_BE_IIHE I see that volume queued is consistently 1/609th of volume requested; this is clearly a Problem, but the site is marked OK:
http://cmswttest.cern.ch/phedex/datasvc/app#page=instance~Production+type~none+widget~shift-requestedqueued+module~sort{RQ.Status%20desc}filter{RQ.Node%3DT2_BE_IIHE}
Maybe the issue is that the 'volume queued entry' for the latest timebin is 0, which is displayed as ratio = 0 while in this case it should be interpreted as ratio = infinity?

6) It makes sense to increase the threshold for 'very little data requested'. For T0/T1_%_MSS we even ask the shifters to report problems only when volume requested > 1 TB (the typical size of a tape, which is also the typical threshold to trigger buffer->tape migration). Maybe we should now implement a more refined logic now actually:
a) If volume requested > 1 TB, then mark 'Problem' after 4 hours
b) If volume requested < 1 TB, then mark 'Problem' after 12 hours (the files shouldn't sit on buffer forever waiting to be lost in a disk server crash).
 -> threshold changed to 1TB. Can set 'mindata' in API call to change this (value in bytes)

7) It might be more useful to display 'Current Queued', 'Current Requested' (i.e. the latest timebin) on the main page - after all, if the situation went away we don't need to worry anymore. Also 'Max Queued' vs. 'Max Requested' isn't a very useful comparison, since the two values could be from different timebins - maybe the most interesting comparisons would be 'Queued vs. Requested for timebin with max Ratio' and 'Queued vs. Requested for timebin with min Ratio'; this will clutter the display so maybe they should be hidden columns?
 -> Current Queued and Current Requested now added, will not do max/min-ratio just yet

*/
/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class Agents
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module.Shift');
PHEDEX.Module.Shift.RequestedQueued = function(sandbox, string) {
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
            {key:'node',              label:'Node'},
            {key:'status',            label:'Status',              className:'align-left'},
            {key:'reason',            label:'Reason',              className:'align-left'},
            {key:'max_pend_bytes',    label:'Max. Queued',         className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'max_request_bytes', label:'Max. Requested',      className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'cur_pend_bytes',    label:'Currently Queued',    className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'cur_request_bytes', label:'Currently Requested', className:'align-right', parser:'number', formatter:'customBytes'},
          ],
          nestedColumns:[
            {key:'timebin',       label:'Timebin',   formatter:'UnixEpochToGMT' },
            {key:'pend_bytes',    label:'Queued',    className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'request_bytes', label:'Requested', className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'ratio',         label:'Ratio',     className:'align-right', parser:'number', formatter:YwDF.customFixed(3) },
          ],
        },
        sort:{field:'Node'},
        hide:['Status','Max. Requested','Max. Queued'],
        filter: {
          'Requested-Queued attributes':{
            map: { to:'RQ' },
            fields: {
              'Node'           :{type:'regex',  text:'Node-name',           tip:'javascript regular expression' },
              'Status'         :{type:'regex',  text:'Status',              tip:'javascript regular expression' },
              'Reason'         :{type:'regex',  text:'Reason',              tip:'javascript regular expression' },
              'Max. Queued'    :{type:'minmax', text:'Max. Queued Data',    tip:'integer range (bytes)' },
              'Max. Requested' :{type:'minmax', text:'Max. Requested Data', tip:'integer range (bytes)' },
              'Queued'         :{type:'minmax', text:'Queued Data',         tip:'integer range (bytes)' },
              'Requested'      :{type:'minmax', text:'Requested Data',      tip:'integer range (bytes)' },
              'Ratio'          :{type:'minmax', text:'Ratio of Requested to Queued data', tip:'integer range (bytes)' },
            }
          }
        }
      },

      /**
      * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
      * @method _processData
      * @param jsonBlkData {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
      * @private
      */
//       _processData: function (jsonData) {
//         log("The data has been processed for data source", 'info', this.me);
//         this.needProcess = false;
//         return jsonData;
//       },

      _processData: function(jsonData) {
        var t=[], table = this.meta.table, i = jsonData.length, k = table.columns.length, j, a, c;
        while (i > 0) {
          i--
          a = jsonData[i];
          a['reason'] = PxU.icon['red-circle'] + a['reason'];
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
        _sbx.notify( this.id, 'getData', { api:'shift/requestedqueued', args:{} } );
      },
      gotData: function(data,context) {
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';
        this.data = data.requestedqueued;
        if ( !this.data ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.fillDataSource(this.data);
        var nOK=0, nNotOK=0, rq = data.requestedqueued, stuck = [];
        this.dom.extra.innerHTML = 'No stuck nodes:';
        for (var i in rq) {
          if ( rq[i].status == 'OK' ) { nOK++; }
          else                        { nNotOK++; stuck.push(rq[i].node); }
        }
        this.dom.title.innerHTML = nOK+' nodes OK, '+nNotOK+' nodes not OK';
        if ( nNotOK ) {
          stuck.sort( function (a, b) { return (a > b) - (a < b); } );
          this.dom.extra.innerHTML = 'List of stuck nodes:<br/>' + stuck.join(' ');
        }
        _sbx.notify( this.id, 'gotData' );

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
      },
// Apply a filter by default, to show only the bad fields
//       initMe: function() {
//         var f = this.meta._filter.fields;
//         f['Status'].value = 'OK';
//         f['Status'].negate = true;
//       }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','agents');
