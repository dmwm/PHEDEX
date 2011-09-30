/**
* The class is used to create agent logs module that is used to show agents log information for the given node name.
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
    Yla(this, new PHEDEX.DataTable(sandbox, string));

    var _sbx = sandbox, _nodename;
    log('Module: creating a genuine "' + string + '"', 'info', string);

    //The custom column format for the message column
    Yw.DataTable.Formatter.customTextBox = function(elCell, oRecord, oColumn, sData) {
        elCell.innerHTML = '<textarea class="phedex-dt-txtbox" readonly="yes">' + sData + '</textarea>';
    };

    //Used to construct the agent logs module.
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
                    }
                }
            ],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                ctxArgs: { Node:'node' },
                table: { columns: [{ key:'node',    label:'Node' },
                                   { key:'name',    label:'Agent Name' },
                                   { key:'time',    label:'Log Time', formatter:'UnixEpochToUTC', parser:'number' },
                                   { key:'reason',  label:'Log Reason' },
                                   { key:'message', label:'Log Message', width:450, formatter:'customTextBox'}]
                },
                hide: [ 'Node' ],
                sort: { field: 'Agent Name' },
                filter: {
                    'AgentLogs attributes': {
                        map: { to: 'A' },
                        fields: {
                            'Node':        { type:'regex',  text:'Node',        tip:'javascript regular expression' },
                            'Agent Name':  { type:'regex',  text:'Agent Name',  tip:'javascript regular expression' },
                            'Log Time':    { type:'minmax', text:'Log Time',    tip:'log time in unix-epoch seconds' },
                            'Log Reason':  { type:'regex',  text:'Log Reason',  tip:'javascript regular expression' },
                            'Log Message': { type:'regex',  text:'Log Message', tip:'javascript regular expression' }
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
            _processData: function(jData) {
                var i, str,
                jAgents=jData, nAgents=jAgents.length, jAgent, iAgent, aAgentCols=['name'], nAgentCols=aAgentCols.length,
                jLogs, nLogs, jLog, iLog, aLogCols=['time','reason'], nLogCols=aLogCols.length,
                nNode,
                Row, Table=[];
                for (iAgent = 0; iAgent < nAgents; iAgent++) {
                  jAgent = jAgents[iAgent];
                  jLogs = jAgent.log;
                  nLogs = jLogs.length;
                  for (iLog = 0; iLog < nLogs; iLog++) {
                    jLog = jLogs[iLog];
                    Row = {};
                    for (i = 0; i < nAgentCols; i++) {
                      this._extractElement(aAgentCols[i],jAgent,Row);
                    }
                    for (i = 0; i < nLogCols; i++) {
                      this._extractElement(aLogCols[i],jLog,Row);
                    }
                    Row['message'] = jLog.message.$t; // This is to store the message
                    str = jAgent.node[0].name;
                    nNode = jAgent.node.length;
                    for (i=1; i<nNode; i++) {
                      str += ', ' + jAgent.node[i].name;
                    }
                    Row['node'] = str;
                    Table.push(Row);
                  }
                }
                log("The data has been processed for data source", 'info', this.me);
                this.needProcess = false;
                return Table;
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
            * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>AgentLogs</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
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
            * @param data {object} agent logs information in json format.
            */
            gotData: function(data,context,response) {
              PHEDEX.Datasvc.throwIfError(data,response);
              log('Got new data', 'info', this.me);
              this.dom.title.innerHTML = 'Parsing data...';
              if (data.agent) {
                this.data = data.agent;
                this.fillDataSource(this.data);
                this.dom.title.innerHTML = this.data.length + ' agent log(s) for ' + _nodename + ' node';
              }
              else {
                this.dom.title.innerHTML = 'No agent logs are found for "' + _nodename + '"';
              }
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...','info','agentlogs');
