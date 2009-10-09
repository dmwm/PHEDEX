//=================================================================================================
//File Name  : phedex-widget-datatable.js
//Purpose    : The javascript functions for creating data table widget that is used as base widget 
//             for many other widgets that require information to be shown in a table format. YUI  
//             datatable is used.
//=================================================================================================
PHEDEX.namespace('Core.Widget.DataTable');

<<<<<<< phedex-core-widget-datatable.js
//****************************************************************************************************
//Function:PHEDEX.Widget.DataTable
//Purpose :This initializes the datatable widget i.e variables, form controls and functions 
//****************************************************************************************************
PHEDEX.Core.Widget.DataTable = function(divid, opts) {
    var that = new PHEDEX.Core.Widget(divid, opts);

    //******************************************************************************************************************************
    //Function:buildTable
    //Purpose :This function builds new data table for the widget. The arguments are 'div' to instantiate the table into, an array
    //         of column definitions, a map and response schema for data source. The column definitions can be simply names of
    //         fields, or full datasource-column object specifications. They will be converted accordingly. Columns are sortable and 
    //         resizeable by default, so explicitly turn that off if you do not want it for your columns.
    //
    //         Columns which are to be treated as numbers need a 'parser' specified. E.g. {key:'ID' parser:'number' }
    //         Parsers from YAHOO.util.DataSourceBase may be specified by name (i.e. 'string', 'number', or 'date'), or a function
    //         may be given which takes the single input argument and returns the parsed value. By default, everything is a string.
    //
    //         The map is for mapping JSON field-names in the data to table column-names. By default, column-names are mapped to
    //         their lower-case selves in the data returned from the data-service. If you need it to be mapped differently, this
    //         is where you specify that mapping, giving the table-column name as the key, and the data-service field as the value.
    //******************************************************************************************************************************
    that.buildTable = function(div, columns, map, dsschema) {
        that.columnDefs = columns;
        that.dsResponseSchema = dsschema; //Stores the response schema for the datasource
        that.columnMap = map || {};       //{table-column-name:JSON-field-name, ...};
        for (var i in that.columnDefs) {
            var cDef = that.columnDefs[i];
            if (typeof cDef != 'object') { cDef = { key: cDef }; that.columnDefs[i] = cDef; }
            if (!cDef.resizeable) { cDef.resizeable = true; }
            if (!cDef.sortable) { cDef.sortable = true; }
            if (!that.columnMap[cDef.key]) { that.columnMap[cDef.key] = cDef.key.toLowerCase(); }
        }
        that.dataSource = new YAHOO.util.DataSource(); //Create an empty data source
        that.dataTable = new YAHOO.widget.DataTable(div, that.columnDefs, that.dataSource, { draggableColumns: true, initialLoad: false }); //Create empty datatable for widget
        that.dataTable.subscribe('rowMouseoverEvent', that.onRowMouseOver);
        that.dataTable.subscribe('rowMouseoutEvent', that.onRowMouseOut);
    }
    that.me = function() { YAHOO.log('unimplemented "me"', 'warn', 'Core.DataTable'); return 'PHEDEX.Core.Widget.DataTable'; }

    //*******************************************************************************************************
    //Function:fillDataSourceWithSchema
    //Purpose :This function fills the datasource with the data and response schema 
    //*******************************************************************************************************
    that.fillDataSourceWithSchema = function(jsonData, dsSchema) {
        that.dataSource = new YAHOO.util.DataSource(jsonData);
        that.dataSource.responseSchema = dsSchema;
        var oCallback = {
            success: that.dataTable.onDataReturnInitializeTable,
            failure: that.dataTable.onDataReturnInitializeTable,
            scope: that.dataTable
        };
        that.dataSource.sendRequest('', oCallback); //This is to update the datatable on UI
    }

    //*******************************************************************************************************
    //Function:fillDataSource
    //Purpose :This function fills the datasource with the data by parsing data if response schema is 
    //         undefined and finally triggers datatable to update its status on UI
    //*******************************************************************************************************
    that.fillDataSource = function(data) {
        if (that.dsResponseSchema) {
            that.fillDataSourceWithSchema(data, that.dsResponseSchema);
            return;
        }
        var table = [];
        for (var i in data) {
            var a = data[i];
            var y = [];
            for (var j in that.columnDefs) {
                var c = that.columnDefs[j];
                var val = a[that.columnMap[c.key]];
                // This applies the parser, if any. This is needed to ensure that numbers are sorted numerically, and not as strings.
                // Declare fields to be numeric in your columns specified to buildTable, see above
                if (c.parser) {
                    if (typeof c.parser == 'function') { val = c.parser(val); }
                    else { val = YAHOO.util.DataSourceBase.Parser[c.parser](val); }
                }
                y[c.key] = val;
            }
            table.push(y);
        }
        that.dataSource = new YAHOO.util.DataSource(table);
        var oCallback = {
            success: that.dataTable.onDataReturnInitializeTable,
            failure: that.dataTable.onDataReturnInitializeTable,
            scope: that.dataTable
        };
        that.dataSource.sendRequest('', oCallback);
    }

    that.column_menu = new YAHOO.widget.Menu('menu_' + PHEDEX.Util.Sequence()); //For split button menu items
    var aSpan = document.createElement('span');
    YAHOO.util.Dom.insertBefore(aSpan, that.dom.control.firstChild);
    
    //Create new Split button to show the list of hidden column names
    that.showFields = new YAHOO.widget.Button(
    {   type: "split",
        label: "Show all columns",
        name: 'showFields_' + PHEDEX.Util.Sequence(),
        menu: that.column_menu,
        container: that.dom.param,
        disabled: true
    });
=======
PHEDEX.Core.Widget.DataTable = function(divid,opts) {
//   var that=new PHEDEX.Core.Widget(divid,opts);
// instead of creating a Core.Widget and setting it to 'that', augment 'this'. Rather than
// fix the whole code-base properly to avoid 'that', just set this=that for now. Will fix
// the rest later...
  YAHOO.lang.augmentObject(this, new PHEDEX.Core.Widget(divid,opts));
//   var that=this;

  this.buildTable=function(div,columns,map) {
// Arguments are: the div to instantiate the table into, an array of column definitions, and a map:
// The column definitions can be simply names of fields, or full datasource-column object specifications. They will
// be converted accordingly.
//
// Columns are sorteable and resizeable by default, so explicitly turn that off if you do not want it for your columns.
//
// Columns which are to be treated as numbers need a 'parser' specified. E.g. {key:'ID' parser:'number' }
// Parsers from YAHOO.util.DataSourceBase may be specified by name (i.e. 'string', 'number', or 'date'), or a function
// may be given which takes the single input argument and returns the parsed value. By default, everything is a string.
//
// The map is for mapping JSON field-names in the data to table column-names. By default, column-names are mapped to
// their lower-case selves in the data returned from the data-service. If you need it to be mapped differently, this
// is where you specify that mapping, giving the table-column name as the key, and the data-service field as the value.
    this.columnDefs = columns;
    this.columnMap = map || {}; // {table-column-name:JSON-field-name, ...};
    for (var i in this.columnDefs )
    {
      var cDef = this.columnDefs[i];
      if ( typeof cDef != 'object' ) { cDef = {key:cDef}; this.columnDefs[i] = cDef; }
      if ( !cDef.resizeable ) { cDef.resizeable=true; }
      if ( !cDef.sortable   ) { cDef.sortable=true; }
      if ( !this.columnMap[cDef.key] ) { this.columnMap[cDef.key] = cDef.key.toLowerCase(); }
    }
    this.dataSource = new YAHOO.util.DataSource();
    this.dataTable = new YAHOO.widget.DataTable(div, this.columnDefs, this.dataSource,
						{ draggableColumns:true, initialLoad:false });
    this.dataTable.subscribe('rowMouseoverEvent',this.onRowMouseOver);
    this.dataTable.subscribe('rowMouseoutEvent', this.onRowMouseOut);
  }
  this._me = 'PHEDEX.Core.Widget.DataTable';
  this.me=function() { YAHOO.log('unimplemented "me"','warn','Core.DataTable'); return 'PHEDEX.Core.Widget.DataTable'; }
  this.fillDataSource=function(data) {
    var table = [];
    for (var i in data) {
      var a = data[i];
      var y = [];
      for (var j in this.columnDefs )
      {
	var c = this.columnDefs[j];
	var val = a[this.columnMap[c.key]];
//      This applies the parser, if any. This is needed to ensure that numbers are sorted numerically, and not as strings.
//      Declare fields to be numeric in your columns specified to buildTable, see above
	if ( c.parser )
	{
	  if (typeof c.parser == 'function' ) { val = c.parser(val); }
	  else { val = YAHOO.util.DataSourceBase.Parser[c.parser](val); }
	}
	y[c.key] = val;
      }
      table.push( y );
    }
    this.dataSource = new YAHOO.util.DataSource(table);
    var oCallback = {
      success : this.dataTable.onDataReturnInitializeTable,
      failure : this.dataTable.onDataReturnInitializeTable,
      scope : this.dataTable
    };
    this.dataSource.sendRequest('', oCallback);
  }
>>>>>>> 1.27

<<<<<<< phedex-core-widget-datatable.js
    //*******************************************************************************************************
    //Function:showFields - click event handler
    //Purpose :This function is event handler for split button that gets called on clicking it. This is used
    //         to show all hidden columns in the datatable
    //*******************************************************************************************************
    that.showFields.on("click", function() {
        var m = that.column_menu.getItems();
        for (var i = 0; i < m.length; i++) {
            that.dataTable.showColumn(that.dataTable.getColumn(m[i].value)); //Show the hidden column
        }
        that.column_menu.clearContent();
        that.refreshButton();
        that.resizePanel(that.dataTable);
    });
=======
// A split-button and menu for the show-all-columns function
  this.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
//  var aSpan = document.createElement('span');
//  YAHOO.util.Dom.insertBefore(aSpan,this.dom.control.firstChild);
  this.showFields = new YAHOO.widget.Button(
    {
      type: "split",
      label: "Show all columns",
      name: 'showFields_'+PHEDEX.Util.Sequence(),
      menu: this.column_menu,
      container: this.dom.param,
      disabled:true
    }
  );
// event-handlers for driving the split button
  this.showFields.on("click", function (obj) {
    return function() {
      var m = obj.column_menu.getItems();
      for (var i = 0; i < m.length; i++) {
        obj.dataTable.showColumn(obj.dataTable.getColumn(m[i].value));
      }
      obj.column_menu.clearContent();
      obj.refreshButton();
      obj.resizePanel(obj.dataTable);
    }
  }(this));
  this.showFields.on("appendTo", function (obj) {
    return function() {
      var m = this.getMenu();
      m.subscribe("click", function onMenuClick(sType, oArgs) {
        var oMenuItem = oArgs[1];
        if (oMenuItem) {
          obj.dataTable.showColumn(obj.dataTable.getColumn(oMenuItem.value));
          m.removeItem(oMenuItem.index);
          obj.refreshButton();
        }
        obj.resizePanel(obj.dataTable);
      });
    }
  }(this));
>>>>>>> 1.27

<<<<<<< phedex-core-widget-datatable.js
    //*******************************************************************************************************
    //Function:showFields - appendTo event handler
    //Purpose :This function is event handler for split button that gets called on adding menu item to it.
    //         This is used to add hidden column names to split button
    //*******************************************************************************************************
    that.showFields.on("appendTo", function() {
        var m = this.getMenu();
        //***************************************************************************************************
        //Function:showFields - menu items - click event handler
        //Purpose :This function is event handler for split button menu items that gets called on clicking
        //         menu item. This is used to show hidden column name.
        //***************************************************************************************************
        m.subscribe("click", function onMenuClick(sType, oArgs) {
            var oMenuItem = oArgs[1];
            if (oMenuItem) {
                that.dataTable.showColumn(that.dataTable.getColumn(oMenuItem.value)); //Show the hidden column
                m.removeItem(oMenuItem.index);
                that.refreshButton();
            }
            that.resizePanel(that.dataTable);
        });
    });

    //*******************************************************************************************************
    //Function:refreshButton
    //Purpose :This function is used to refresh the split button status after any hidden column is shown. If
    //         the split button has no more menu items, then it is disabled.
    //*******************************************************************************************************
    that.refreshButton = function() {
        that.column_menu.render(document.body);
        that.showFields.set('disabled', that.column_menu.getItems().length === 0);
    };

    /*
    that.locateNode=function(el) {
    //  find the nearest ancestor that has a phedex-dnode-* class applied to it, either
    //  phedex-dnode-field or phedex-dnode-header
    while (el.id != that.dom.content.id) { // walk up only as far as the content-div
    if(YAHOO.util.Dom.hasClass(el,'phedex-dnode-field')) { // phedex-dnode fields hold the values.
    return el;
    }
    if(YAHOO.util.Dom.hasClass(el,'phedex-dnode-header')) { // phedex-dnode headers hold the value-names.
    return el;
    }
    el = el.parentNode;
    }
    }
    */

    // Create a context menu, with default entries for dataTable widgets
    that.buildContextMenu = function() {
        that.contextMenuArgs = [];
        for (var i = 0; i < arguments.length; i++) { that.contextMenuArgs[that.contextMenuArgs.length] = arguments[i]; }
        that.contextMenuArgs.push('dataTable');
        that.contextMenu = PHEDEX.Core.ContextMenu.Create({ trigger: that.dataTable.getTbodyEl() });
        //     that.contextMenu.subscribe("beforeShow", that.onContextMenuBeforeShow);
        //     that.contextMenu.subscribe("hide",       that.onContextMenuHide);
        PHEDEX.Core.ContextMenu.Build(that.contextMenu, that.contextMenuArgs);
    }
    that.onContextMenuClick = function(p_sType, p_aArgs, p_DataTable) {
        YAHOO.log('ContextMenuClick for ' + that.me(), 'info', 'Core.DataTable');
        var task = p_aArgs[1];
        if (task) {
            //  Extract which TR element triggered the context menu
            var tgt = this.contextEventTarget;
            var elCol = p_DataTable.getColumn(tgt);
            var elRow = p_DataTable.getTrEl(tgt);
            var label = tgt.textContent;
            var payload = {};
            if (elRow) {
                //	TODO I haven't figured out yet how to define a row-payload. Should do that soon...
                if (elRow.payload) { payload = elRow.payload; }
                var args = payload.args || {};
                var opts = payload.opts || {};
                var oRecord = p_DataTable.getRecord(elRow);
                var selected_node = args.node; // allows me to specify a node in the payload, to override guesses here
                if (!selected_node) { selected_node = oRecord.getData('Name'); }
                YAHOO.log('ContextMenu: ' + '"' + label + '" for ' + that.me() + ' (' + selected_node + ')', 'info', 'Core.DataTable');
                //	this is not good, I should be building a payload inside the table object and passing it here, not
                //	building specific payloads in a generic base-widget!
                opts.node = selected_node;
                this.payload[task.index](args, opts, { table: p_DataTable, row: elRow, col: elCol, record: oRecord });
            }
        }
    }
    PHEDEX.Core.ContextMenu.Add('dataTable', 'Hide This Field', function(args, opts, el) {
        YAHOO.log('hideField: ' + el.col.key, 'info', 'Core.DataTable');
        el.table.hideColumn(el.col);
    });

    // This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
    // it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
    // I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
    // complete. This allows me to ignore the menu completely if the user didn't build one.
    // If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
    // care that the object was assembled in exactly the right way. That would then make things a bit more complex...
    that.onBuildComplete.subscribe(function() {
        YAHOO.log('onBuildComplete: ' + that.me(), 'info', 'Core.DataTable');
        if (that.contextMenu) {
            YAHOO.log('subscribing context menu: ' + that.me(), 'info', 'Core.DataTable');
            that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.dataTable);
            that.contextMenu.render(document.body);
        }
        //  Event-subscriptions for the 'Show all columns' button. Require that the dataTable exist, so post-build!
        that.dataTable.subscribe('columnHideEvent', function(ev) {
            var column = this.getColumn(ev.column);
            YAHOO.log('column_menu.addItem: label:' + column.label + ' key:' + column.key, 'info', 'Core.DataTable');
            that.column_menu.addItem({ text: column.label || column.key, value: column.key });
            that.refreshButton();
        });
        that.dataTable.subscribe('renderEvent', function() { that.resizePanel(that.dataTable); });
    });

    that.onPopulateComplete.subscribe(function() {
        for (var i in that.hideByDefault) {
            var column = that.dataTable.getColumn(that.hideByDefault[i]);
            if (column) { that.dataTable.hideColumn(column); }
        }
        that.hideByDefault = null; // don't want to do this every time the build is complete...?
    });

    // Allow the table to be built again after updates
    that.onUpdateComplete.subscribe(function() { that.fillDataSource(that.data); });

    that.onDataFailed.subscribe(function() {
        //  Empty the dataTable if it is there
        if (that.dataTable) { that.dataTable.destroy(); that.dataTable = null; } // overkill? Who cares!...
        that.dom.content.innerHTML = 'Data-load error, try again later...';
    });

    //****************************************************************************************************
    //Function:onRowMouseOut
    //Purpose :This function is called when cursor is out of a row in datatable to remove highlight
    //****************************************************************************************************
    that.onRowMouseOut = function(event) {
        // Would like to use the DOM, but this gets over-ridden by yui-dt-odd/even, so set colour explicitly.
        // Leave this in here in case phedex-drow-highlight ever becomes a useful class (e.g. when we do our own skins)
        // YAHOO.util.Dom.removeClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = null;
    }
    
    //****************************************************************************************************
    //Function:onRowMouseOver
    //Purpose :This function is called when cursor is on a row in datatable to highlight the row
    //****************************************************************************************************
    that.onRowMouseOver = function(event) {
        // YAHOO.util.Dom.addClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = 'yellow';
    }

    //****************************************************************************************************
    //Function:resizePanel
    //Purpose :This function resizes the panel when extra columns are shown, to accomodate the width
    //****************************************************************************************************
    that.resizePanel = function(table) {
        var old_width = table.getContainerEl().clientWidth;
        var offset = that.dom.header.offsetWidth - that.dom.content.offsetWidth;
        var x = table.getTableEl().offsetWidth + offset;
        if (x >= old_width) { that.panel.cfg.setProperty('width', x + 'px'); }
    }

    // Custom formatter for unix-epoch dates
    that.UnixEpochToGMTFormatter = function(elCell, oRecord, oColumn, oData) {
        var gmt = new Date(oData * 1000).toGMTString();
        elCell.innerHTML = gmt;
    };
    YAHOO.widget.DataTable.Formatter.UnixEpochToGMT = that.UnixEpochToGMTFormatter
    PHEDEX.Event.onFilterCancel.subscribe(function(obj) {
        return function() {
            YAHOO.log('onFilterCancel:' + obj.me(), 'info', 'Core.DataTable');
            obj.ctl.filter.Hide();
            YAHOO.util.Dom.removeClass(obj.ctl.filter.el, 'phedex-core-control-widget-applied');
            obj.fillDataSource(obj.data);
            obj.filter.Reset();
        }
    } (that));

    that.applyFilter = function(args) {
        // this is much easier for tables than for branches. Just go through the data-table and build a new one,
        // then feed that to the DataSource!
        var table = [];
        if (!args) { args = that.filter.args; }
        for (var i in that.data) {
            var keep = true;
            for (var key in args) {
                if (typeof (args[key].value) == 'undefined') { continue; }
                var fValue = args[key].value;
                if (args[key].format) { fValue = args[key].format(fValue); }
                var kValue = that.data[i][key];
                var negate = args[key].negate;
                var status = that.filter.Apply[this.filter.fields[key].type](fValue, kValue);
                if (args[key].negate) { status = !status; }
                if (!status) { // Keep the element if the match succeeded!
                    that.filter.count++;
                    keep = false;
                }
            }
            if (keep) { table.push(that.data[i]); }
        }
        that.fillDataSource(table);
=======
// update the 'Show all columns' button state
  this.refreshButton = function() {
    this.column_menu.render(document.body);
    this.showFields.set('disabled', this.column_menu.getItems().length === 0);
  };

// Create a context menu, with default entries for dataTable widgets
  this.buildContextMenu=function(typeMap) {
    this.contextMenuTypeMap = typeMap || {};
    this.contextMenuArgs=[];
    for (var type in typeMap) {
      this.contextMenuArgs.push(type);
    }
    this.contextMenuArgs.push('dataTable');
    // Create a context menu for any click on the table body
    this.contextMenu = PHEDEX.Core.ContextMenu.Create({trigger:this.dataTable.getTbodyEl()});
    PHEDEX.Core.ContextMenu.Build(this.contextMenu,this.contextMenuArgs);
  }

  this.onContextMenuClick = function(obj) {
    return function(p_sType, p_aArgs, p_DataTable) {
      YAHOO.log('ContextMenuClick for '+obj.me(),'info','Core.DataTable');
      var menuitem = p_aArgs[1];
      if(menuitem) {
        //  Extract which <tr> triggered the context menu
        var tgt = this.contextEventTarget;
        var elCol = p_DataTable.getColumn(tgt);
        var elRow = p_DataTable.getTrEl(tgt);
        var label = tgt.textContent;
        if (elRow) {
	  var opts = {};
	  var oRecord = p_DataTable.getRecord(elRow);
	  // map types to column names in order to prepare our options
	  if (obj.contextMenuTypeMap) {
	    for (var type in obj.contextMenuTypeMap) {
	      var recName = obj.contextMenuTypeMap[type];
	      opts[type] = oRecord.getData(recName);
	    }
	  }
	  menuitem.value.fn(opts, {table:p_DataTable, row:elRow, col:elCol, record:oRecord});
        }
      }
    }
  }(this);

  PHEDEX.Core.ContextMenu.Add('dataTable','Hide This Field', function(opts,el) {
    YAHOO.log('hideField: '+el.col.key,'info','Core.DataTable');
    el.table.hideColumn(el.col);
  });

// This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
// it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
// I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
// complete. This allows me to ignore the menu completely if the user didn't build one.
// If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
// care that the object was assembled in exactly the right way. That would then make things a bit more complex...
  this.onBuildComplete.subscribe(function(obj) {
    return function() {
      YAHOO.log('onBuildComplete: '+this.me(),'info','Core.DataTable');
      if ( obj.contextMenu )
      {
        YAHOO.log('subscribing context menu: '+obj.me(),'info','Core.DataTable');
        obj.contextMenu.clickEvent.subscribe(obj.onContextMenuClick, obj.dataTable);
        obj.contextMenu.render(document.body);
      }
//    Event-subscriptions for the 'Show all columns' button. Require that the dataTable exist, so post-build!
      obj.dataTable.subscribe('columnHideEvent', function(ev) {
        var column = obj.dataTable.getColumn(ev.column);
        YAHOO.log('column_menu.addItem: label:'+column.label+' key:'+column.key,'info','Core.DataTable');
        obj.column_menu.addItem({text: column.label || column.key,value:column.key});
        obj.refreshButton();
      } );
      obj.dataTable.subscribe('renderEvent', function() { obj.resizePanel(obj.dataTable); } );
    }
  }(this));

  this.onPopulateComplete.subscribe(function(obj) {
    return function() {
      // hide by default that which should be hidden
      for (var i in this.options.defhide)
      {
        var column = obj.dataTable.getColumn(this.options.defhide[i]);
        if ( column ) { obj.dataTable.hideColumn(column); }
      }
      this.options.defhide = null; // don't want to do this every time the build is complete...?
      
      // sort by default
      if (this.options.defsort) {
	obj.dataTable.sortColumn( obj.dataTable.getColumn( this.options.defsort ) );
      }
    }
  }(this));

// Allow the table to be built again after updates
  this.onUpdateComplete.subscribe( function(obj) {
    return function() {
      obj.fillDataSource(obj.data);
    }
  }(this) );

  this.onDataFailed.subscribe(function(obj) {
    return function() {
//    Empty the dataTable if it is there
      if ( obj.dataTable ) { obj.dataTable.destroy(); obj.dataTable = null; } // overkill? Who cares!...
      obj.dom.content.innerHTML='Data-load error, try again later...';
    }
  }(this));

  this.onRowMouseOut = function(event) {
// Gratuitously flash yellow when the mouse goes over the rows
// Would like to use the DOM, but this gets over-ridden by yui-dt-odd/even, so set colour explicitly.
// Leave this in here in case phedex-drow-highlight ever becomes a useful class (e.g. when we do our own skins)
//     YAHOO.util.Dom.removeClass(event.target,'phedex-drow-highlight');
    event.target.style.backgroundColor = null;
  }
  this.onRowMouseOver = function(event) {
//     YAHOO.util.Dom.addClass(event.target,'phedex-drow-highlight');
    event.target.style.backgroundColor = 'yellow';
  }

// Resize the panel when extra columns are shown, to accomodate the width
  this.resizePanel=function(table) {
    var old_width = table.getContainerEl().clientWidth;
    var offset = this.dom.header.offsetWidth - this.dom.content.offsetWidth;
    var x = table.getTableEl().offsetWidth + offset;
    if ( x >= old_width ) { this.panel.cfg.setProperty('width',x+'px'); }
  }

// Custom formatter for unix-epoch dates
  this.UnixEpochToGMTFormatter = function(elCell, oRecord, oColumn, oData) {
    var gmt = new Date(oData*1000).toGMTString();
    elCell.innerHTML = gmt;
  };
  YAHOO.widget.DataTable.Formatter.UnixEpochToGMT = this.UnixEpochToGMTFormatter;

  this.filter.onFilterCancelled.subscribe( function(obj) {
    return function() {
      YAHOO.log('onWidgetFilterCancelled:'+obj.me(),'info','Core.DataTable');
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      obj.fillDataSource(obj.data);
      obj.filter.Reset();
      obj.ctl.filter.Hide();
      PHEDEX.Event.onWidgetFilterCancelled.fire(obj.filter);
    }
  }(this));
  PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
    return function() {
      YAHOO.log('onGlobalFilterCancelled:'+obj.me(),'info','Core.DataTable');
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      obj.fillDataSource(obj.data);
      obj.filter.Reset();
    }
  }(this));

  PHEDEX.Event.onGlobalFilterValidated.subscribe( function(obj) {
    return function(ev,arr) {
      var args = arr[0];
      if ( ! obj.filter.args ) { obj.filter.args = []; }
      for (var i in args) {
	obj.filter.args[i] = args[i];
      }
      obj.applyFilter(arr[0]);
    }
  }(this));
  this.filter.onFilterApplied.subscribe(function(obj) {
    return function(ev,arr) {
      obj.applyFilter(arr[0]);
      obj.ctl.filter.Hide();
    }
  }(this));

  this.applyFilter=function(args) {
// this is much easier for tables than for branches. Just go through the data-table and build a new one,
// then feed that to the DataSource!
    var table=[];
    if ( ! args ) { args = this.filter.args; }
    for (var i in this.data) {
      var keep=true;
      for (var key in args) {
	if ( typeof(args[key].value) == 'undefined' ) { continue; }
	var fValue = args[key].value;
	var kValue = this.data[i][key];
	if ( args[key].preprocess ) { kValue = args[key].preprocess(kValue); }
	var negate = args[key].negate;
	var status = this.filter.Apply[this.filter.fields[key].type](fValue,kValue);
	if ( args[key].negate ) { status = !status; }
	if ( !status ) { // Keep the element if the match succeeded!
	  this.filter.count++;
	  keep=false;
	}
      }
      if ( keep ) { table.push(this.data[i]); }
>>>>>>> 1.27
    }
<<<<<<< phedex-core-widget-datatable.js
=======
    this.fillDataSource(table);
    return this.filter.count;
  }
>>>>>>> 1.27

<<<<<<< phedex-core-widget-datatable.js
    return that;
=======
  return this;
>>>>>>> 1.27
}
YAHOO.log('loaded...','info','Core.DataTable');