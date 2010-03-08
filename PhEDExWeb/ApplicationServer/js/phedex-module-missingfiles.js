/**
* The class is used to create missing files module that is used to show missing files information for the given block name.
* The group information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class MissingFiles
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.MissingFiles = function(sandbox, string) {
    YAHOO.lang.augmentObject(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _blockname; // = '/Cosmics/CRUZET09-v1/RAW#e315ea15-5750-49a5-9a69-907972fad673';
    log('Module: creating a genuine "' + string + '"', 'info', string);

    /**
    * Array of object literal Column definitions for missing file information datatable.
    * @property _dtColumnDefs
    * @type Object[]
    * @private
    */
    var _dtColumnDefs = [{ key: 'id', label: 'File ID', className: 'align-right' },
                         { key: 'name', label: 'File' },
                         { key: 'bytes', label: 'File Bytes', className: 'align-right', "formatter": "customBytes" },
                         { key: 'origin_node', label: 'Origin Node'},
                         { key: "time_create", label: 'TimeCreate', formatter: 'UnixEpochToGMT' },
                         { key: 'group', label: 'Group' },
                         { key: 'custodial', label: 'Custodial'},
                         { key: 'se', label: 'SE' },
                         { key: 'node_id', label: 'Node ID', className: 'align-right' },
                         { key: 'node_name', label: 'Node Name' },
                         { key: 'subscribed', label: 'Subscribed'}];

    /**
    * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
    * @method _processBlkData
    * @param jsonBlkData {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
    * @private
    */
    var _processBlkData = function(jsonBlkData) {
        var indx, indxBlk, indxFile, indxMiss, jsonFile, jsonMissing, arrFile, arrData = [],
        arrFileCols = ['id', 'name', 'bytes', 'origin_node', 'time_create'],
        arrMissingCols = ['group', 'custodial', 'se', 'node_id', 'node_name', 'subscribed'];
        for (indxBlk = 0; indxBlk < jsonBlkData.length; indxBlk++) {
            jsonFiles = jsonBlkData[indxBlk].file;
            for (indxFile = 0; indxFile < jsonFiles.length; indxFile++) {
                jsonFile = jsonFiles[indxFile];
                for (indxMiss = 0; indxMiss < jsonFile.missing.length; indxMiss++) {
                    jsonMissing = jsonFile.missing[indxMiss];
                    arrFile = [];
                    for (indx = 0; indx < arrFileCols.length; indx++) {
                        arrFile[arrFileCols[indx]] = jsonFile[arrFileCols[indx]];
                    }
                    for (indx = 0; indx < arrMissingCols.length; indx++) {
                        if (jsonMissing[arrMissingCols[indx]]) {
                            arrFile[arrMissingCols[indx]] = jsonMissing[arrMissingCols[indx]];
                        }
                        else {
                            arrFile[arrMissingCols[indx]] = "";
                        }
                    }
                    arrData.push(arrFile);
                }
            }
        }
        this.needProcess = false;
        return arrData;
    }

    //Used to construct the group usage widget.
    _construct = function() {
        return {
            /**
            * Used for styling the elements of the widget.
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
                }
            ],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                table: { columns: _dtColumnDefs },
                hide: ['se', 'id'],
                sort: { field: 'name' },
                filter: {
                    'MissingFiles attributes': {
                        map: { to: 'M' },
                        fields: {
                            'id': { type: 'int', text: 'ID', tip: 'File-ID' },
                            'name': { type: 'regex', text: 'File', tip: 'javascript regular expression' },
                            'bytes': { type: 'minmax', text: 'File Bytes', tip: 'integer range' },
                            'origin_node': { type: 'regex', text: 'Origin Node', tip: 'javascript regular expression' },
                            'time_create': { type: 'minmax', text: 'TimeCreate', tip: 'time of creation', preprocess: 'toTimeAgo' },
                            'group': { type: 'regex', text: 'Group', tip: 'javascript regular expression' },
                            'custodial': { type: 'yesno', text: 'Custodial', tip: 'Show custodial and/or non-custodial files (default is both)' },
                            'se': { type: 'regex', text: 'SE', tip: 'javascript regular expression' },
                            'node_id': { type: 'int', text: 'Node ID', tip: 'Node ID' },
                            'node_name': { type: 'regex', text: 'Node name', tip: 'javascript regular expression' },
                            'subscribed': { type: 'yesno', text: 'Subscribed', tip: 'Show subscribed and/or non-subscribed files (default is both)' }
                        }
                    }
                }
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
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
            */
            setArgs: function(arr) {
                if (arr && arr.blockname) {
                    _blockname = arr.blockname;
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
            * @param data {object} missing files information in json format used to fill the datatable directly using a defined schema.
            */
            gotData: function(data) {
                log('Got new data', 'info', this.me);
                this.dom.title.innerHTML = 'Parsing data';
                this._processData = _processBlkData; //Change the function that processes the data as the processing is different
                this.data = data.block;
                this.dom.title.innerHTML = 'Missing file(s) for ' + _blockname;
                this.fillDataSource(this.data);
                _sbx.notify(this.id, 'gotData');
            }
        };
    };
    YAHOO.lang.augmentObject(this, _construct(), true);
    return this;
};

log('loaded...','info','groupusage');
