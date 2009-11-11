//=================================================================================================
//File Name  : phedex-widget-groupusage.js
//Purpose    : The javascript functions for creating group usage widget that is used to get group 
//             information from Phedex database using web APIs provided by Phedex and then format 
//             result to show it to user in an YUI datatable.
//=================================================================================================
PHEDEX.namespace('Widget.GroupUsage');

//****************************************************************************************************
//Function:PHEDEX.Widget.GroupUsage
//Purpose :This initializes the group usage widget i.e variables, form controls 
//****************************************************************************************************
PHEDEX.Widget.GroupUsage = function(groups, divid, widgetargs) {
    if (!divid) { divid = PHEDEX.Util.generateDivName(); }
    if (!widgetargs) { widgetargs = {} };
    
    // Merge passed options with defaults
    YAHOO.lang.augmentObject(widgetargs, {
        width: 600,
        height: 200,
        minwidth: 400,
        minheight: 50,
        defhide: ['se', 'id', 'group[0].node_files', 'group[0].dest_files']
    });

    var that = new PHEDEX.Core.Widget.DataTable(divid, widgetargs); //Create new datatable widget as base widget
    that.strGroupName = groups;
    that._me = 'PHEDEX.Core.Widget.GroupUsage';
    that.me = function() { return that._me; }

    //****************************************************************************************************
    //Function:fillHeader
    //Purpose :This function fills the header with node count
    //****************************************************************************************************
    that.fillHeader = function(div) {
        var msg = this.data.node.length + ' nodes.';
        that.dom.title.innerHTML = msg;
    };

    //The custom column format to the bytes column
    var formatBytes = function(elCell, oRecord, oColumn, sData) {
        elCell.innerHTML = PHEDEX.Util.format.bytes(sData); //Convert the size to higher ranges and then show it to user
    };

    YAHOO.widget.DataTable.Formatter.customBytes = formatBytes; //Assign column format with the custom bytes format

    // The column definition of the datatable
    var dtColumnDefs = [{ key: 'name', label: 'Node', "sortable": true, "resizeable": true },
                                        { key: 'se', label: 'SE', "sortable": true, "resizeable": true },
                                        { key: 'id', label: 'ID', "sortable": true, "resizeable": true },
                                        { key: 'group[0].node_bytes', label: 'Resident Bytes', "sortable": true, "resizeable": true, "formatter": "customBytes" },
                                        { key: 'group[0].node_files', label: 'Resident Files', "sortable": true, "resizeable": true },
                                        { key: 'group[0].dest_bytes', label: 'Subscribed Bytes', "sortable": true, "resizeable": true, "formatter": "customBytes" },
                                        { key: 'group[0].dest_files', label: 'Subscribed Files', "sortable": true, "resizeable": true}];

    // The response schema for the data source
    var dsResponseSchema = { resultsList: 'node', fields: ['name', 'se', { key: 'id', parser: 'number' },
                                                                            { key: 'group[0].node_bytes', parser: 'number' },
                                                                            { key: 'group[0].node_files', parser: 'number' },
                                                                            { key: 'group[0].dest_bytes', parser: 'number' },
                                                                            { key: 'group[0].dest_files', parser: 'number'}]
    };

    that.buildTable(that.dom.content, dtColumnDefs, null, dsResponseSchema); //Build the YUI data table

    //*******************************************************************************************************
    //Function:Update
    //Purpose :This function gets the group information from Phedex database using web APIs provided by 
    //         Phedex. The result is shown to user in YUI datatable.
    //*******************************************************************************************************
    that.update = function() {
        PHEDEX.Datasvc.Call({ api: 'groupusage',
            args: { group: that.strGroupName },
            success_event: that.onDataReady,
            limit: -1
        });
    }
    that.onDataReady.subscribe(function(type, args) { var data = args[0]; that.receive(data); });
    that.receive = function(data) {
        that.data = data;
        if (that.data) {
            that.populate();
        }
        else {
            that.failedLoading();
        }
    }
    that.buildExtra(that.dom.extra); //Build an element to show extra information

    //****************************************************************************************************
    //Function:fillExtra
    //Purpose :This function fills the extra content with info about the widget
    //****************************************************************************************************   
    that.fillExtra = function(div) {
        that.dom.extra.innerHTML = "This is Group Usage widget that is used to display node information associated with group '" + that.strGroupName + "'";
    };
    that.build();
    return that;
}