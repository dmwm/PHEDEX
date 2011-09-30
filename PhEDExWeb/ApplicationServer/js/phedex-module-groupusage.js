/**
* The class is used to create group usage module that is used to show group information for the given group name.
* The group information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class GroupUsage
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.GroupUsage = function(sandbox, string) {
    Yla(this,new PHEDEX.DataTable(sandbox,string));

    var _sbx = sandbox, _groupname;
    log('Module: creating a genuine "'+string+'"','info',string);

    //Used to construct the group usage widget.
    _construct = function() {
        return {
            /**
            * Used for styling the elements of the widget.
            * @property decorators
            * @type Object[]
            */
            decorators: [{
                name: 'ContextMenu',
                source:'component-contextmenu'
            },
            {
                name:'cMenuButton',
                source:'component-splitbutton',
                payload:{
                    name:'Show all fields',
                    map: { hideColumn: 'addMenuItem' },
                    container: 'param'
                }
            }],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                ctxArgs: { Node:'node', Group:'group' },
                table: {
                  columns: [
                            { key:'group',      label:'Group' },
                            { key:'name',       label:'Node' },
                            { key:'se',         label:'SE' },
                            { key:'id',         label:'ID',               className:'align-right', parser:'number' },
                            { key:'node_bytes', label:'Resident Bytes',   className:'align-right', parser:'number', formatter:'customBytes' },
                            { key:'node_files', label:'Resident Files',   className:'align-right', parser:'number' },
                            { key:'dest_bytes', label:'Subscribed Bytes', className:'align-right', parser:'number', formatter:'customBytes' },
                            { key:'dest_files', label:'Subscribed Files', className:'align-right', parser:'number' }
                           ]
                },

                hide: ['Group', 'SE', 'ID', 'Resident Files', 'Subscribed Files'],
                sort:{field:'Node'},
                filter: {
                  'GroupUsage attributes':{
                    map: { to:'G' },
                    fields: {
                      'Group':{type:'regex',  text:'Group', tip:'javascript regular expression' },
                      'Node' :{type:'regex',  text:'Node',  tip:'javascript regular expression' },
                      'SE'   :{type:'regex',  text:'SE',    tip:'javascript regular expression' },
                      'ID'   :{type:'int',    text:'ID',    tip:'ID'},
                      'Resident Bytes':   { type:'minmax', text:'Resident Bytes',   tip:'integer range' },
                      'Resident Files':   { type:'minmax', text:'Resident Files',   tip:'integer range' },
                      'Subscribed Bytes': { type:'minmax', text:'Subscribed Bytes', tip:'integer range' },
                      'Subscribed Files': { type:'minmax', text:'Subscribed Files', tip:'integer range' }
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
            _processData: function (jsonData) {
                var indx, indxGroup, indxNode, jsonGroup, jsonNode, Row, Table = [],
                arrNodeCols = ['id', 'name', 'se'],
                arrGroupCols = ['dest_bytes','dest_files','node_bytes','node_files',{name:'group'}],
                nArrGLen = arrGroupCols.length, nArrNLen = arrNodeCols.length,
                nNodeLen = jsonData.length, nGroupLen;
                for (indxNode = 0; indxNode < nNodeLen; indxNode++) {
                    jsonNode = jsonData[indxNode];
                    nGroupLen = jsonNode.group.length;
                    for (indxGroup = 0; indxGroup < nGroupLen; indxGroup++) {
                        jsonGroup = jsonNode.group[indxGroup];
                        Row = {};
                        for (indx = 0; indx < nArrNLen; indx++) {
                            this._extractElement(arrNodeCols[indx],jsonNode,Row);
                        }
                        for (indx = 0; indx < nArrGLen; indx++) {
                            this._extractElement(arrGroupCols[indx],jsonGroup,Row);
                        }
                        Table.push(Row);
                    }
                }
                this.needProcess = false;
                return Table;
            },
            /**
            * This initializes the Phedex.GroupUsage module and notify to sandbox about its status.
            * @method initData
            */
            initData: function() {
              this.dom.title.innerHTML = 'Waiting for parameters to be set...';
              if ( _groupname ) {
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
              if ( arr && arr.group ) {
                if ( arr.group == _groupname ) { return; }
                _groupname = arr.group;
                if ( !_groupname ) { return; }
                this.dom.title.innerHTML = 'setting parameters...';
                _sbx.notify(this.id,'setArgs');
              }
            },

            /**
            * This gets the group information from Phedex data service for the given group name through sandbox.
            * @method getData
            */
            getData: function() {
                if ( !_groupname ) {
                  this.initData();
                  return;
                }
                 log('Fetching data','info',this.me);
                this.dom.title.innerHTML = this.me+': fetching data...';
                _sbx.notify( this.id, 'getData', { api: 'groupusage', args: { group: _groupname }});
            },
            
            /**
            * This processes the group information obtained from data service and shows in YUI datatable.
            * @method gotData
            * @param data {object} group information in json format used to fill the datatable directly using a defined schema.
            */
            gotData: function(data,context,response) {
                PHEDEX.Datasvc.throwIfError(data,response);
                log('Got new data','info',this.me);
                this.dom.title.innerHTML = 'Parsing data';
                if ( !data.node ) {
                  throw new Error('data incomplete for '+context.api);
                }
                this.data = data.node;
                this.dom.title.innerHTML = _groupname + ': ' + this.data.length + ' nodes found';
                this.fillDataSource(this.data);
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};

log('loaded...','info','groupusage');
