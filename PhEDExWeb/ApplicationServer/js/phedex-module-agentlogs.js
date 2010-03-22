/**
* The class is used to create agent logs module that is used to show agents log information for the given node and agent name.
* The agent logs information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class AgentLogs
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.AgentLogs = function(sandbox, string) {
    YAHOO.lang.augmentObject(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _nodename;
    log('Module: creating a genuine "' + string + '"', 'info', string);

    /**
    * Array of object literal Column definitions for agent log information datatable.
    * @property _dtColumnDefs
    * @type Object[]
    * @private
    */
    var _dtColumnDefs = [{ key: 'name', label: 'Agent Name' },
                         { key: "time", label: 'Log Time', formatter: 'UnixEpochToGMT' },
                         { key: 'reason', label: 'Log Reason' },
                         { key: 'message', label: 'Log Message', width: 450, "formatter": "customTextBox"}];

     //The custom column format to the message column
     YAHOO.widget.DataTable.Formatter.customTextBox = function(elCell, oRecord, oColumn, sData) {
        elCell.innerHTML = '<textarea class="phedex-dt-txtbox" readonly="yes">' + sData + '</textarea>';
     };

    //Used to construct the agent logs module.
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
                },
                {
                    name: 'ContextMenu',
                    source: 'component-contextmenu',
                    payload: {
                        args: { 'agent': 'Name' }
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
                hide: [],
                sort: { field: 'name' },
                filter: {
                    'AgentCommand attributes': {
                        map: { to: 'A' },
                        fields: {
                            'name': { type: 'regex', text: 'Agent Name', tip: 'javascript regular expression' },
                            'time': { type: 'minmax', text: 'Log Time', tip: 'log time in unix-epoch seconds' },
                            'reason': { type: 'regex', text: 'Log Reason', tip: 'javascript regular expression' },
                            'message': { type: 'regex', text: 'Log Message', tip: 'javascript regular expression' }
                        }
                    }
                }
            },

            /**
            * Processes i.e flatten the response data so as to create a YAHOO.util.DataSource and display it on-screen.
            * @method _processData
            * @param jsonData {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
            * @private
            */
            _processData: function(jsonData) {
                var indx, indxNode, indxAgent, indxLog, jsonAgents, jsonAgent, jsonLog, arrFile, arrData = [],
                arrAgentCols = ['name'],
                arrLogCols = ['time', 'reason'];
                for (indxNode = 0; indxNode < jsonData.length; indxNode++) {
                    jsonAgents = jsonData[indxNode].agent;
                    for (indxAgent = 0; indxAgent < jsonAgents.length; indxAgent++) {
                        jsonAgent = jsonAgents[indxAgent];
                        for (indxLog = 0; indxLog < jsonAgent.log.length; indxLog++) {
                            jsonLog = jsonAgent.log[indxLog];
                            arrFile = [];
                            for (indx = 0; indx < arrAgentCols.length; indx++) {
                                arrFile[arrAgentCols[indx]] = jsonAgent[arrAgentCols[indx]];
                            }
                            for (indx = 0; indx < arrLogCols.length; indx++) {
                                arrFile[arrLogCols[indx]] = jsonLog[arrLogCols[indx]];
                            }
                            arrFile['message'] = jsonLog.message.$t; // Store the message
                            arrData.push(arrFile);
                        }
                    }
                }
                this.needProcess = false;
                return arrData;
            },

            /**
            * This inits the Phedex.AgentLogs module and notify to sandbox about its status.
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
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
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
            * This gets the agent logs information from Phedex data service for the given block name through sandbox.
            * @method getData
            */
            getData: function() {
                if (!_nodename) {
                    this.initData();
                    return;
                }
                log('Fetching data', 'info', this.me);
                this.dom.title.innerHTML = this.me + ': fetching data...';
                _sbx.notify(this.id, 'getData', { api: 'agentlogs', args: { node: _nodename} });
            },

            /**
            * This processes the agent logs information obtained from data service and shows in YUI datatable.
            * @method gotData
            * @param data {object} agent logs information in json format used to fill the datatable directly using a defined schema.
            */
            gotData: function(data) {
                log('Got new data', 'info', this.me);
                this.dom.title.innerHTML = 'Parsing data...';
                this.data = data.node;
                this.fillDataSource(this.data);
                this.dom.title.innerHTML = this.data.length + ' agent log(s) for ' + _nodename + ' node';
                _sbx.notify(this.id, 'gotData');
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...','info','agentlogs');