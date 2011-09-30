/**
* The class is used to create queued migrations module that is used to show missing file information for the given node.
* The agent logs information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class QueuedMigrations
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.QueuedMigrations = function(sandbox, string) {
    Yla(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _nodename, _totalsize = 0;
    log('Module: creating a genuine "' + string + '"', 'info', string);

    /**
    * Check if the node name is valid or not i.e should contain either _MSS or _Buffer.
    * @method _isValidNode
    * @param strNodeName {String} node name to be validated.
    * @private
    */
    var _isValidNode = function(strNodeName) {
        if (strNodeName.match(/_MSS|_Buffer|T0_CH_CERN_Export|%/)) { //regExpNode)) {
            return true;
        }
        return false;
    };

    /**
    * Get the name of the 'from' node i.e in *_Buffer format.
    * @method _getFromNode
    * @param strNodeName {String} input node name.
    * @private
    */
    var _getFromNode = function(strNodeName) {
        if (strNodeName.match(/T0_CH_CERN_/) ) {
          return 'T0_CH_CERN_Export';
        }
        if (strNodeName.match(/_Buffer/)) {
            return strNodeName;
        }
        return strNodeName.replace('_MSS', '_Buffer');
    };

    /**
    * Get the name of the 'to' node i.e in *_Buffer format.
    * @method _getToNode
    * @param strNodeName {String} input node name.
    * @private
    */
    var _getToNode = function(strNodeName) {
        if (strNodeName.match(/T0_CH_CERN_/) ) {
          return 'T0_CH_CERN_MSS';
        }
        if (strNodeName.match(/_MSS/)) {
            return strNodeName;
        }
        return strNodeName.replace('_Buffer', '_MSS');
    };
    this.allowNotify['parseData'] = 1;

    //Used to construct the queued migrations module.
    _construct = function() {
        return {
            /**
            * Used for styling the elements of the module.
            * @property decorators
            * @type Object[]
            */
            decorators: [
                {
                    name: 'Extra',
                    source: 'component-control',
                    parent: 'control',
                    payload: {
                        target: 'extra',
                        handler: 'fillExtra',
                        animate: false
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
                },
                {
                    name: 'ContextMenu',
                    source: 'component-contextmenu',
                    payload: {
                        args: { 'block': 'Name' }
                    }
                }
            ],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                ctxArgs: { Block:'block', Node:'node' },
                table: {
                    columns: [{ key:'node',      label:'Node' },
                              { key:'block',     label:'Block' },
                              { key:'fileid',    label:'File ID',   className:'align-right', parser:'number' },
                              { key:'file',      label:'File' },
                              { key:'filebytes', label:'File Size', className:'align-right', parser:'number', formatter:'customBytes' }]
                },
                hide: ['File ID', 'Node'],
                sort: { field: 'Block' },
                filter: {
                    'QueuedMigrations attributes': {
                        map: { to: 'Q' },
                        fields: {
                            'Node':      { type:'regex',  text:'Node Name',  tip:'javascript regular expression' },
                            'Block':     { type:'regex',  text:'Block Name', tip:'javascript regular expression' },
                            'File':      { type:'regex',  text:'File Name',  tip:'javascript regular expression' },
                            'File Size': { type:'minmax', text:'File Size',  tip:'integer range (bytes)' },
                            'File ID':   { type:'int',    text:'File ID',    tip:'ID of file in TMDB' }
                        }
                    }
                }
            },

            /**
            * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
            * @method _processData
            * @param jsonData {object}
            * @private
            */
            _processData: function(jsonData) {
                var indx, indxQueues, indxQueue, indxBlock, indxFile, jsonQueues, jsonBlocks, jsonBlock, jsonFile, Row, Table = [],
                arrBlockCols = [ {name:'block'} ],
                arrFileCols = [{name:'file'}, {id:'fileid'}, {bytes:'filebytes'}],
                nArrBLen = arrBlockCols.length, nArrFLen = arrFileCols.length,
                _jLen = jsonData.length, jQLen, jBLen, jBfLen,
                toNode;
                _totalsize = 0;
                for (indxQueues = 0; indxQueues < jsonData.length; indxQueues++) {
                    jsonQueues = jsonData[indxQueues].transfer_queue;
                    jQLen = jsonQueues.length;
                    toNode = this._extractElement({to:'node'},jsonData[indxQueues]);
                    for (indxQueue = 0; indxQueue < jQLen; indxQueue++) {
                        jsonBlocks = jsonQueues[indxQueue].block;
                        jBLen = jsonBlocks.length;
                        for (indxBlock = 0; indxBlock < jBLen; indxBlock++) {
                            jsonBlock = jsonBlocks[indxBlock];
                            jBfLen = jsonBlock.file.length;
                            for (indxFile = 0; indxFile < jBfLen; indxFile++) {
                                jsonFile = jsonBlock.file[indxFile];
                                _totalsize = _totalsize + parseInt(jsonFile['bytes']);
                                Row = {};
                                Row['node'] = toNode;
                                for (indx = 0; indx < nArrBLen; indx++) {
                                    this._extractElement(arrBlockCols[indx],jsonBlock,Row);
                                }
                                for (indx = 0; indx < nArrFLen; indx++) {
                                    this._extractElement(arrFileCols[indx],jsonFile,Row);
                                }
                                Table.push(Row);
                            }
                        }
                    }
                }
                log("The data has been processed for data source", 'info', this.me);
                this.needProcess = false;
                return Table;
            },

            /**
            * This inits the Phedex.QueuedMigrations module and notify to sandbox about its status.
            * @method initData
            */
            initData: function() {
                this.dom.title.innerHTML = 'Waiting for parameters to be set...';
                if (_nodename) {
                    _sbx.notify(this.id, 'initData');
                    return;
                }
                _sbx.notify('module', 'needArguments', this.id);
            },

            /** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
            * @method setArgs
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>QueuedMigrations</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
            */
            setArgs: function(arr) {
                if (!arr) { return; }
                if (!arr.node) { return; }
                if (arr.node == _nodename) { return; }
                _nodename = arr.node;
                this.dom.title.innerHTML = 'setting parameters...';
                _sbx.notify(this.id, 'setArgs');
            },

            /**
            * This gets the queued migrations information from Phedex data service for the given node name through sandbox.
            * @method getData
            */
            getData: function() {
                if (!_nodename) {
                    this.initData();
                    return;
                }
                var strFromNode, strToNode;
                if (_isValidNode(_nodename)) {
                    log('The node is valid. So, fetching data..', 'info', this.me);
                    this.dom.title.innerHTML = this.me + ': fetching data...';
                    strFromNode = _getFromNode(_nodename);
                    strToNode = _getToNode(strFromNode);
                    _sbx.notify(this.id, 'getData', { api: 'transferqueuefiles', args: { from: strFromNode, to: strToNode} });
                }
                else {
                    banner("Invalid node name. Please enter the valid node name.", 'warn');
                    log("Invalid node name. Please enter the valid node name.", 'warn', this.me);
                }
            },

            /**
            * This intitiates processing of queued migrations information obtained from data service.
            * @method gotData
            * @param data {object} queued migration file information in json format.
            */
            gotData: function(data,context,response) {
                PHEDEX.Datasvc.throwIfError(data,response);
                var strFromNode, strToNode;
                log('Got new data', 'info', this.me);
                this.dom.title.innerHTML = 'Parsing data...';
                this.data = data.link;
                if ( !data.link ) {
                  throw new Error('data incomplete for '+context.api);
                }
                _sbx.notify(this.id, 'parseData'); // parsing takes a long time, so update the GUI to let them know why they're waiting...
            },

            /**
            * This processes the data after getting it from data service and shows result in YUI datatable.
            * @method parseData
            */
            parseData: function() {
                this.fillDataSource(this.data);
                strFromNode = _getFromNode(_nodename);
                strToNode = _getToNode(strFromNode);
                this.dom.title.innerHTML = this.data.length + ' non-migrated file(s) from' + strFromNode + ' to ' + strToNode;
            },

            /**
            * This updates the extra content with the total size of files that are yet to be migrated.
            * @method fillExtra
            */
            fillExtra: function() {
                this.dom.extra.innerHTML = 'Total size of files yet to be migrated is ' + PHEDEX.Util.format.bytes(_totalsize);
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...', 'info', 'queuedmigrations');
