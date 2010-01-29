/**
* The class is used to create group usage widget that is used to show group information for the given group name.
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
    YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

    var _sbx = sandbox, _groupname = 'DataOps';
    log('Module: creating a genuine "'+string+'"','info',string);

    /**
    * Array of object literal Column definitions for group information datatable.
    * @property _dtColumnDefs
    * @type Object[]
    * @private
    */
    var _dtColumnDefs = [{ key: 'name', label: 'Node', "sortable": true, "resizeable": true },
                        { key: 'se', label: 'SE', "sortable": true, "resizeable": true },
                        { key: 'id', label: 'ID', "sortable": true, "resizeable": true },
                        { key: 'group[0].node_bytes', label: 'Resident Bytes', "sortable": true, "resizeable": true, "formatter": "customBytes" },
                        { key: 'group[0].node_files', label: 'Resident Files', "sortable": true, "resizeable": true },
                        { key: 'group[0].dest_bytes', label: 'Subscribed Bytes', "sortable": true, "resizeable": true, "formatter": "customBytes" },
                        { key: 'group[0].dest_files', label: 'Subscribed Files', "sortable": true, "resizeable": true}];

    /**
    * The responseSchema is an object literal of pointers that is used to parse data from the received response and creates 
    * YUI datasource for YUI datatable.
    * @property _dsResponseSchema
    * @type Object
    * @private
    */
    var _dsResponseSchema = { resultsList: 'node', fields: ['name', 'se', { key: 'id', parser: 'number' },
                                                                          { key: 'group[0].node_bytes', parser: 'number' },
                                                                          { key: 'group[0].node_files', parser: 'number' },
                                                                          { key: 'group[0].dest_bytes', parser: 'number' },
                                                                          { key: 'group[0].dest_files', parser: 'number'}]};

    //Used to construct the group usage widget.
    _construct = function() {
        return {
            /**
            * Used for styling the elements of the widget.
            * @property decorators
            * @type Object[]
            */
            decorators: [{
                name:'cMenuButton',
                source:'component-splitbutton',
                payload:{
                    name:'Show all fields',
                    map: { hideColumn: 'addMenuItem' },
                    onInit: 'hideByDefault',
                    container: 'param'
                }
            }],

            /**
            * Properties used for configuring the module.
            * @property meta
            * @type Object
            */
            meta: {
                table: { columns: _dtColumnDefs, schema: _dsResponseSchema},
                hide: ['se', 'id', 'group[0].node_files', 'group[0].dest_files']
            },

            /**
            * This inits the Phedex.GroupUsage module and notify to sandbox about its status.
            * @method initData
            */
            initData: function() {
                _sbx.notify( this.id, 'initData' );
            },
            
            /**
            * This gets the group information from Phedex data service for the given group name through sandbox.
            * @method getData
            */
            getData: function() {
                log('Fetching data','info',this.me);
                this.dom.title.innerHTML = this.me+': fetching data...';
                _sbx.notify( this.id, 'getData', { api: 'groupusage', args: { group: _groupname }});
            },
            
            /**
            * This processes the group information obtained from data service and shows in YUI datatable.
            * @method gotData
            * @param data {object} group information in json format used to fill the datatable directly using a defined schema.
            */
            gotData: function(data) {
                log('Got new data','info',this.me);
                this.dom.title.innerHTML = 'Parsing data';
                this.data = data;
                this.dom.title.innerHTML = this.me + ': ' + this.data.node.length + ' nodes found';
                this.fillDataSource(data, _dsResponseSchema);
                _sbx.notify( this.id, 'gotData' );
            }
        };
    };
    YAHOO.lang.augmentObject(this,_construct(),true);
    return this;
};

log('loaded...','info','groupusage');