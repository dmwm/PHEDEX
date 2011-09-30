/**
* The class is used to create pending requests module that is used to show pending requests for the given node name, group name.
* The pending requests information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI nested datatable.
* @namespace PHEDEX.Module
* @class PendingRequests
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.PendingRequests = function (sandbox, string) {
    Yla(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _nodename = '', _groupname = '', opts = { status: null, kind: null, since: 720 };
    log('Module: creating a genuine "' + string + '"', 'info', string);

    //Used to construct the pending requests module.
    _construct = function () {
        return {
            /**
            * Used for styling the elements of the module.
            * @property decorators
            * @type Object[]
            */
            decorators: [
                {
                    name: 'ContextMenu',
                    source: 'component-contextmenu',
                    payload: {
                        args: { 'pendingrequests': 'Name' }
                    }
                },
                {
                    name: 'TimeSelect',
                    source: 'component-menu',
                    payload: {
                        type: 'menu',
                        initial: function () { return opts.since; },
                        container: 'buttons',
                        menu: { 24: 'Last Day', 168: 'Last Week', 720: 'Last Month', 4320: 'Last 6 Months', 9999: 'Forever' },
                        map: {
                            onChange: 'changeTimebin'
                        },
                        title: 'Time of Creation'
                    }
                },
                {
                    name: 'cMenuButton',
                    source: 'component-splitbutton',
                    payload: {
                        name: 'Show all fields',
                        map: { hideColumn: 'addMenuItem' },
                        container: 'param'
                    }
                }
            ],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                ctxArgs: { Node:'node', Group:'group' },
                table: { columns: [{ key:'id',          label:'Request ID', className:'align-right',    parser:'number' },
                                   { key:'time_create', label:'TimeCreate', formatter:'UnixEpochToUTC', parser:'number' },
                                   { key:'group',       label:'Group' },
                                   { key:'priority',    label:'Priority' },
                                   { key:'custodial',   label:'Custodial' },
                                   { key:'static',      label:'Static' },
                                   { key:'move',        label:'Move' }],
                    nestedColumns:[{ key:'node_id',     label:'Node ID', className: 'align-right',parser:'number' },
                                   { key:'name',        label:'Node' },
                                   { key:'se',          label:'SE'}]
                },
                hide: ['Request ID', 'Node ID'],
                sort: { field: 'Request ID' },
                filter: {
                    'PendingRequests attributes': {
                        map: { to: 'P' },
                        fields: {
                            'Request ID': { type:'int',    text:'Request ID', tip:'Request-ID' },
                            'TimeCreate': { type:'minmax', text:'TimeCreate', tip:'time of creation in unix-epoch seconds' },
                            'Group':      { type:'regex',  text:'Group',      tip:'javascript regular expression' },
                            'Priority':   { type:'regex',  text:'Priority',   tip:'javascript regular expression' },
                            'Custodial':  { type:'yesno',  text:'Custodial',  tip:'Show custodial and/or non-custodial files (default is both)' },
                            'Static':     { type:'yesno',  text:'Static',     tip:'Show request static value (default is both)' },
                            'Move':       { type:'yesno',  text:'Move',       tip:'Show if file had been moved or not (default is both)' },
                            'Node ID':    { type:'int',    text:'Node ID',    tip:'Node ID', nested:true },
                            'Node':       { type:'regex',  text:'Node name',  tip:'javascript regular expression', nested: true },
                            'SE':         { type:'regex',  text:'SE',         tip:'javascript regular expression', nested: true }
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
            _processData: function (jsonReqData) {
                var indx, indxReq, indxData, jsonReqs, jsonNode, Row, arrNestedVal, arrNested, Table = [],
                arrRequestCols = ['id', 'time_create', 'group', 'priority', 'custodial', 'static', 'move'],
                arrNodeCols = ['se', {id:'node_id'}, 'name'],
                nArrRLen = arrRequestCols.length, nArrNLen = arrNodeCols.length,
                nReqLen = jsonReqData.length, nDataLen, nUnique = 0;
                for (indxReq = 0; indxReq < nReqLen; indxReq++) {
                    jsonReqs = jsonReqData[indxReq];
                    jsonReq = jsonReqData[indxReq].destinations.node;
                    nDataLen = jsonReq.length;
                    Row = {};
                    arrNested = []; //new Array();
                    for (indx = 0; indx < nArrRLen; indx++) {
                        this._extractElement(arrRequestCols[indx],jsonReqs,Row);
                    }
                    for (indxData = 0; indxData < nDataLen; indxData++) {
                        jsonNode = jsonReq[indxData];
                        arrNestedVal = {};
                        for (indx = 0; indx < nArrNLen; indx++) {
                          this._extractElement(arrNodeCols[indx],jsonNode,arrNestedVal);
                        }
                        arrNested.push(arrNestedVal);
                    }
                    Row['nesteddata'] = arrNested;
                    Row['uniqueid'] = ++nUnique;
                    Table.push(Row);
                }
                log("The data has been processed for data source", 'info', this.me);
                this.needProcess = false;
                return Table;
            },

            /**
            * This inits the Phedex.PendingRequestsNested module and notify to sandbox about its status.
            * @method initData
            */
            initData: function () {
                this.dom.title.innerHTML = 'Waiting for parameters to be set...';
                if (_nodename || _groupname) {
                    _sbx.notify(this.id, 'initData');
                    return;
                }
                _sbx.notify('module', 'needArguments', this.id);
            },

            /** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
            * @method setArgs
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>PendingRequests</strong> module, <strong>arr.node</strong> or <strong>arr.group</strong> are required. <strong>arr</strong> may be null, in which case no data will be fetched.
            */
            setArgs: function (args) {
                if (!args) { return; }
                if (!(args.node) && !(args.group)) { return; }
                if (args.group) { _groupname = args.group; }
                else { _groupname = ''; }
                if (args.node) { _nodename = args.node; }
                else { _nodename = ''; }
                this.dom.title.innerHTML = 'setting parameters...';
                _sbx.notify(this.id, 'setArgs');
            },

            /** This allows user to bookmark the request with a particular timebin, and then to set timebin internally from value in a bookmark.
            * @method specificState
            * @param state {array} object containing time argument.
            */
            specificState: function (state) {
                var s, i, k, v, kv, update, arr;
                if (!state) {
                    s = {};
                    if (opts.since) { s.since = opts.since; }
                    return s;
                }
                update = 0;
                arr = state.split(' ');
                for (i in arr) {
                    kv = arr[i].split('=');
                    k = kv[0];
                    v = kv[1];
                    if (k == 'since' && v != opts.since) { update++; opts.since = v; }
                }
                if (!update) { return; }
                log('set since=' + opts.since + ' from state', 'info', this.me);
                this.getData();
            },

            /** Call this to set the time creation parameter of this module and cause it to fetch new data from the data-service.
            * @method changeTimebin
            * @param arg {array} object containing time arguments for this module.
            */
            changeTimebin: function (arg) {
                opts.since = parseInt(arg);
                this.getData();
            },

            /**
            * This gets the pending requests information from Phedex data service for the given node\group name through sandbox.
            * @method getData
            */
            getData: function () {
                if ((!_nodename) && (!_groupname)) {
                    this.initData();
                    return;
                }
                var dataserviceargs = { approval:'pending'},
                    d, now, magic;

                log('Fetching data', 'info', this.me);
                this.dom.title.innerHTML = this.me + ': fetching data...';
                if (_nodename) {
                    dataserviceargs.node = _nodename;
                    magic = 'node:'+_nodename;
                }
                if (_groupname) {
                    dataserviceargs.group = _groupname;
                    if ( magic ) { magic += ' '; }
                    magic += 'group:'+_groupname;
                }
                if (opts.since) {
                  if (opts.since != 9999) {
                    now = PxU.epochAlign(0,300);
                    dataserviceargs.create_since = now - (3600 * opts.since);
                  } else {
                    dataserviceargs.create_since = 0;
                  }
                  if ( magic ) { magic += ' '; }
                  magic += dataserviceargs.create_since
                }
                if ( this._magic == magic ) {
                  log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
                  return;
                }
                this._magic = magic;
                _sbx.notify(this.id, 'getData', { api:'transferrequests', args:dataserviceargs, magic:magic });
            },

            /**
            * This processes the pending requests information obtained from data service and shows in YUI datatable.
            * @method gotData
            * @param data {object} pending requests information in json format.
            */
            gotData: function (data,context,response) {
                PHEDEX.Datasvc.throwIfError(data,response);
                var msg = '';
                log('Got new data', 'info', this.me);
                if ( this._magic != context.magic ) {
                  log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
                  return;
                }
                this.dom.title.innerHTML = 'Parsing data...';
                this.data = data.request;
                if (!data.request) {
                    throw new Error('data incomplete for ' + context.api);
                }
                this.fillDataSource(this.data);
                if (_nodename && _groupname) {
                    msg = 'for node: ' + _nodename + ' and group: ' + _groupname;
                }
                else if (_nodename) {
                    msg = 'for node: ' + _nodename;
                }
                else if (_groupname) {
                    msg = 'for group: ' + _groupname;
                }
                this.dom.title.innerHTML = this.data.length + ' pending request(s) ' + msg;
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...', 'info', 'pendingrequests');
