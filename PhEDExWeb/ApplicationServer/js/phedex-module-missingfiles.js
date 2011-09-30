/**
* The class is used to create missing files module that is used to show missing files information for the given block name.
* The missing files information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class MissingFiles
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.MissingFiles = function(sandbox, string) {
    Yla(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _blockname;
    log('Module: creating a genuine "' + string + '"', 'info', string);

    //Used to construct the missing files module.
    _construct = function() {
        return {
            /**
            * Used for styling the elements of the module.
            * @property decorators
            * @type Object[]
            */
            decorators: [
                {
                    name: 'cMenuButton',
                    source: 'component-splitbutton',
                    payload: {
                        name: 'Show all fields',
                        map: { hideColumn: 'addMenuItem' },
                        container: 'param'
                    }
                },
                {
                    name: 'ContextMenu',
                    source: 'component-contextmenu',
                    payload: {
                        args: { 'missingfile': 'Name' }
                    }
                }
            ],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                ctxArgs: { 'Origin Node':'node', 'Node Name':'node', Group:'group', Block:'block' },
                table: { columns: [{ key: 'block',       label: 'Block' },
                                   { key: 'id',          label: 'File ID', className:'align-right' },
                                   { key: 'name',        label: 'File' },
                                   { key: 'bytes',       label: 'File Bytes', className:'align-right', formatter:'customBytes', parser:'number' },
                                   { key: 'origin_node', label: 'Origin Node' },
                                   { key: 'time_create', label: 'TimeCreate', formatter:'UnixEpochToUTC', parser:'number' },
                                   { key: 'group',       label: 'Group' },
                                   { key: 'se',          label: 'SE' },
                                   { key: 'node_id',     label: 'Node ID', className:'align-right', parser:'number' },
                                   { key: 'node_name',   label: 'Node Name' },
                                   { key: 'custodial',   label: 'Custodial' },
                                   { key: 'subscribed',  label: 'Subscribed'}]
                },
                hide: ['Block', 'SE', 'File ID', 'Node ID'],
                sort: { field: 'File' },
                filter: {
                    'MissingFiles attributes': {
                        map: { to: 'F' },
                        fields: {
                            'File ID':     { type:'int',    text:'ID',          tip:'File-ID' },
                            'File':        { type:'regex',  text:'File',        tip:'javascript regular expression' },
                            'File Bytes':  { type:'minmax', text:'File Bytes',  tip:'integer range' },
                            'Origin Node': { type:'regex',  text:'Origin Node', tip:'javascript regular expression' },
                            'TimeCreate':  { type:'minmax', text:'TimeCreate',  tip:'time of creation in unix-epoch seconds' },
                            'Group':       { type:'regex',  text:'Group',       tip:'javascript regular expression' },
                            'Custodial':   { type:'yesno',  text:'Custodial',   tip:'Show custodial and/or non-custodial files (default is both)' },
                            'SE':          { type:'regex',  text:'SE',          tip:'javascript regular expression' },
                            'Node ID':     { type:'int',    text:'Node ID',     tip:'Node ID' },
                            'Node Name':   { type:'regex',  text:'Node name',   tip:'javascript regular expression' },
                            'Subscribed':  { type:'yesno',  text:'Subscribed',  tip:'Show subscribed and/or non-subscribed files (default is both)' }
                        }
                    }
                }
            },

            /**
            * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
            * @method _processData
            * @param jsonBlkData {object}
            * @private
            */
            _processData: function(jsonBlkData) {
                var indx, indxBlk, indxFile, indxMiss, jsonBlock, jsonFile, jsonMissing, Row, Table = [],
                arrBlockCols = [ {name:'block'} ],
                arrFileCols = ['id', 'name', 'bytes', 'origin_node', 'time_create'],
                arrMissingCols = ['group', 'custodial', 'se', 'node_id', 'node_name', 'subscribed'],
                nArrBLen = arrBlockCols.length, nArrFLen = arrFileCols.length, nArrMLen = arrMissingCols.length,
                nBlkLen = jsonBlkData.length, nFileLen, nMissLen, objCol, objVal, key, mKey, fnParser;
                for (indxBlk = 0; indxBlk < nBlkLen; indxBlk++) {
                    jsonBlock = jsonBlkData[indxBlk];
                    jsonFiles = jsonBlock.file;
                    nFileLen = jsonFiles.length;
                    for (indxFile = 0; indxFile < nFileLen; indxFile++) {
                        jsonFile = jsonFiles[indxFile];
                        nMissLen = jsonFile.missing.length;
                        for (indxMiss = 0; indxMiss < nMissLen; indxMiss++) {
                            jsonMissing = jsonFile.missing[indxMiss];
                            Row = {};
                            for (indx = 0; indx < nArrBLen; indx++) {
                              this._extractElement(arrBlockCols[indx],jsonBlock,Row);
                            }
                            for (indx = 0; indx < nArrFLen; indx++) {
                              this._extractElement(arrFileCols[indx],jsonFile,Row);
                            }
                            for (indx = 0; indx < nArrMLen; indx++) {
                              this._extractElement(arrMissingCols[indx],jsonMissing,Row);
                            }
                            Table.push(Row);
                        }
                    }
                }
                log("The data has been processed for data source", 'info', this.me);
                this.needProcess = false;
                return Table;
            },

            /**
            * This inits the Phedex.MissingFiles module and notify to sandbox about its status.
            * @method initData
            */
            initData: function() {
                this.dom.title.innerHTML = 'Waiting for parameters to be set...';
                if (_blockname) {
                    _sbx.notify(this.id, 'initData');
                    return;
                }
                _sbx.notify('module', 'needArguments', this.id);
            },

            /** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
            * @method setArgs
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>MissingFiles</strong> module, only <strong>arr.block</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
            */
            setArgs: function(arr) {
                if (arr && arr.block) {
                    _blockname = arr.block;
                    if (!_blockname) { return; }
                    this.dom.title.innerHTML = 'setting parameters...';
                    _sbx.notify(this.id, 'setArgs');
                }
            },

            /**
            * This gets the missing files information from Phedex data service for the given block name through sandbox.
            * @method getData
            */
            getData: function() {
                if (!_blockname) {
                    this.initData();
                    return;
                }
                log('Fetching data', 'info', this.me);
                this.dom.title.innerHTML = this.me + ': fetching data...';
                _sbx.notify(this.id, 'getData', { api: 'missingfiles', args: { block: _blockname} });
            },

            /**
            * This processes the missing files information obtained from data service and shows in YUI datatable.
            * @method gotData
            * @param data {object} missing files information in json format.
            */
            gotData: function(data,context,response) {
                PHEDEX.Datasvc.throwIfError(data,response);
                log('Got new data', 'info', this.me);
                this.dom.title.innerHTML = 'Parsing data';
                this.data = data.block;
                if ( !data.block ) {
                  throw new Error('data incomplete for '+context.api);
                }
                this.fillDataSource(this.data);
                this.dom.title.innerHTML = this.data.length + ' missing file(s) for ' + _blockname;
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...','info','missingfiles');
