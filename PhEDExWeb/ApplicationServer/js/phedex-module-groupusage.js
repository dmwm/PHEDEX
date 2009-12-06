PHEDEX.namespace('Module');
PHEDEX.Module.GroupUsage = function(sandbox, string) {
    YAHOO.lang.augmentObject(this,new PHEDEX.DataTable(sandbox,string));

    var _sbx = sandbox, _groupname = 'DataOps';
    log('Module: creating a genuine "'+string+'"','info',string);

    /** A custom formatter for byte-counts. Sets the elCell innerHTML to the smallest reasonable representation of oData, with units
    * @method YAHOO.widget.DataTable.Formatter.customBytes
    * @param elCell {HTML element} Cell for which the formatter must be applied
    * @param oRecord {datatable record}
    * @param oColumn {datatable column}
    * @param oData {data-value} number of bytes
    */
    YAHOO.widget.DataTable.Formatter.customBytes = function(elCell, oRecord, oColumn, oData) {
        elCell.innerHTML = PHEDEX.Util.format.bytes(oData); //Convert the size to higher ranges and then show it to user
    };

    /**
    * Array of object literal Column definitions for group information datatable.
    * @property _dtColumnDefs
    * @type Object[]
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
    */
    var _dsResponseSchema = { resultsList: 'node', fields: ['name', 'se', { key: 'id', parser: 'number' },
                                                                          { key: 'group[0].node_bytes', parser: 'number' },
                                                                          { key: 'group[0].node_files', parser: 'number' },
                                                                          { key: 'group[0].dest_bytes', parser: 'number' },
                                                                          { key: 'group[0].dest_files', parser: 'number'}]};


    /**
    * Used to construct the group usage widget.
    * @method _construct
    */
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
            * Properties used for configuring the widget.
            * @property meta
            * @type Object
            */
            meta: {
                table: { columns: _dtColumnDefs, schema: _dsResponseSchema},
                defhide: ['se', 'id', 'group[0].node_files', 'group[0].dest_files']
            },

            /**
            * Create a Phedex.GroupUsage widget to show the information of nodes associated with a group.
            * @method initData
            */
            initData: function() {
                _sbx.notify( this.id, 'initData' );
            },
            
            /**
            * Get the group information from Phedex data service for the given group name.
            * @method getData
            */
            getData: function() {
                log('Fetching data','info',this.me);
                this.dom.title.innerHTML = this.me+': fetching data...';
                _sbx.notify( this.id, 'getData', { api: 'groupusage', args: { group: _groupname }});
            },
            
            /**
            * Process group information and show in YUI datatable after it is obtained from Phedex data service for the given group name.
            * @method gotData
            * @param data {object} group information in json format used to fill the datatable directly using a defined schema.
            */
            gotData: function(data) {
                log('Got new data','info',this.me);
                this.dom.title.innerHTML = 'Parsing data';
                this.data = data;
                this.dom.title.innerHTML = this.me + ': ' + this.data.node.length + ' nodes found';
                this.fillDataSource(this.data, _dsResponseSchema);
                _sbx.notify( this.id, 'gotData' );
            }
        };
    };
    YAHOO.lang.augmentObject(this,_construct(),true);
    return this;
};