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
            {key:'status',            label:'Status', className:'align-right'},
            {key:'max_pend_bytes',    label:'Max. Queued',    className:'align-right', parser:'number', formatter:'customBytes'},
            {key:'max_request_bytes', label:'Max. Requested', className:'align-right', parser:'number', formatter:'customBytes'},
          ],
          nestedColumns:[
            {key:'timebin',       label:'Timebin',   formatter:'UnixEpochToGMT' },
            {key:'pend_bytes',    label:'Queued',    className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'request_bytes', label:'Requested', className:'align-right', parser:'number', formatter:'customBytes' },
            {key:'ratio',         label:'Ratio',     className:'align-right', parser:'number', formatter:YwDF.customFixed(3) },
          ],
        },
        sort:{field:'Node'},
//         hide:['From Node'],
        filter: {
          'Requested-Queued attributes':{
            map: { to:'RQ' },
            fields: {
              'Node'           :{type:'regex',  text:'Node-name',           tip:'javascript regular expression' },
              'Status'         :{type:'regex',  text:'Status',              tip:'javascript regular expression' },
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
      _processData: function (jsonData) {
//         var indx, indxO, indxN, jsonO, jsonNArr, jsonN, Row, arrNestedVal, arrNested, Table = [],
//             arrOCols = ['node', 'status', 'max_pend_bytes', 'max_request_bytes'],
//             arrNCols = ['timebin', 'pend_bytes', 'request_bytes', 'ratio'],
//             nArrOLen = arrOCols.length, nArrNLen = arrNCols.length,
//             nOLen = jsonData.length, nNLen, nUnique = 0;
//         for (indxO = 0; indxO < nOLen; indxO++) {
//           jsonO    = jsonData[indxO];
//           jsonNArr = jsonData[indxO].timebins;
//           Row = {};
//           arrNested = []; //new Array();
//           for (indx = 0; indx < nArrOLen; indx++) {
//             this._extractElement(arrOCols[indx],jsonO,Row);
//           }
//           if ( jsonNArr ) {
//             nNLen    = jsonNArr.length;
//             for (indxN = 0; indxN < nNLen; indxN++) {
//               jsonN = jsonNArr[indxN];
//               arrNestedVal = {};
//               for (indx = 0; indx < nArrNLen; indx++) {
//                 this._extractElement(arrNCols[indx],jsonN,arrNestedVal);
//               }
//               arrNested.push(arrNestedVal);
//             }
//             Row['nesteddata'] = arrNested;
//             Row['uniqueid'] = ++nUnique;
//           }
//           Table.push(Row);
//         }
        log("The data has been processed for data source", 'info', this.me);
        this.needProcess = false;
//         return Table;
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
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','agents');
