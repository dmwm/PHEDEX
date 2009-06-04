//This 'class' represents a data-table widget for PhEDEx. It assumes it is derived for proper widget-specific behaviour, and it uses
// the base PHEDEX.Core.Widget for the basic implementation. I.e. it's only the fluff for data-tables that goes in here.

PHEDEX.namespace('Core.Widget.DataTable');

PHEDEX.Core.Widget.DataTable = function(divid,parent,opts) {
  var that=new PHEDEX.Core.Widget(divid,parent,opts);
  that.buildTable=function(div,columns,map) {
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
    that.columnDefs = columns;
    that.columnMap = map || {}; // {table-column-name:JSON-field-name, ...};
    for (var i in that.columnDefs )
    {
      var cDef = that.columnDefs[i];
      if ( typeof cDef != 'object' ) { cDef = {key:cDef}; that.columnDefs[i] = cDef; }
      if ( !cDef.resizeable ) { cDef.resizeable=true; }
      if ( !cDef.sortable   ) { cDef.sortable=true; }
      if ( !that.columnMap[cDef.key] ) { that.columnMap[cDef.key] = cDef.key.toLowerCase(); }
    }
    that.dataSource = new YAHOO.util.DataSource();
    that.dataTable = new YAHOO.widget.DataTable(div, that.columnDefs, that.dataSource, { draggableColumns:true, initialLoad:false });
    that.dataTable.subscribe('rowMouseoverEvent',that.onRowMouseOver);
    that.dataTable.subscribe('rowMouseoutEvent', that.onRowMouseOut);
  }
  that.me=function() { YAHOO.log('unimplemented "me"','warn','Core.DataTable'); return 'PHEDEX.Core.Widget.DataTable'; }
  that.fillDataSource=function(data) {
    var table = [];
    for (var i in that.data) {
      var a = that.data[i];
      var y = [];
      for (var j in that.columnDefs )
      {
	var c = that.columnDefs[j];
	var val = a[that.columnMap[c.key]];
// This applies the parser, if any. This is needed to ensure that numbers are sorted numerically, and not as strings.
// Declare fields to be numeric in your columns specified to buildTable, see above
	if ( c.parser )
	{
	  if (typeof c.parser == 'function' ) { val = c.parser(val); }
	  else { val = YAHOO.util.DataSourceBase.Parser[c.parser](val); }
	}
	y[c.key] = val;
      }
      table.push( y );
    }
    that.dataSource = new YAHOO.util.DataSource(table);
    var oCallback = {
      success : that.dataTable.onDataReturnInitializeTable,
      failure : that.dataTable.onDataReturnInitializeTable,
      scope : that.dataTable
    };
    that.dataSource.sendRequest('', oCallback);
  }

// A split-button and menu for the show-all-columns function
  that.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
  that.showColumns = new YAHOO.widget.Button(
    {
      type: "split",
      label: "Show all columns",
      name: 'showColumns_'+PHEDEX.Util.Sequence(),
      menu: that.column_menu,
      container: that.div_header,
      disabled:true
    }
  );
//   that.showColumns.on('render',that.hideDefaultColumns);
// event-handlers for driving the split button
  that.showColumns.on("click", function () {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      that.dataTable.showColumn(that.dataTable.getColumn(m[i].value));
    }
    that.column_menu.clearContent();
    that.refreshButton();
    that.resizePanel(that.dataTable);
  });
  that.showColumns.on("appendTo", function () {
    var m = this.getMenu();
    m.subscribe("click", function onMenuClick(sType, oArgs) {
      var oMenuItem = oArgs[1];
      if (oMenuItem) {
        that.dataTable.showColumn(that.dataTable.getColumn(oMenuItem.value));
        m.removeItem(oMenuItem.index);
        that.refreshButton();
      }
      that.resizePanel(that.dataTable);
    });
  });

// update the 'Show all columns' button state
  that.refreshButton = function() {
    that.column_menu.render(document.body);
    that.showColumns.set('disabled', that.column_menu.getItems().length === 0);
  };

// Create a context menu, with default entries for dataTable widgets
  that.buildContextMenu=function() {
    var args=[];
    for (var i=0; i< arguments.length; i++ ) { args[args.length] = arguments[i]; }
    args.push('dataTable');
    that.contextMenu = PHEDEX.Core.ContextMenu.Create(args[0],{trigger:that.dataTable.getTbodyEl()});
    PHEDEX.Core.ContextMenu.Build(that.contextMenu,args);
  }
  that.onContextMenuClick = function(p_sType, p_aArgs, p_DataTable) {
    YAHOO.log('ContextMenuClick for '+that.me(),'info','Core.DataTable');
    var label = p_aArgs[0].explicitOriginalTarget.textContent;
    var task = p_aArgs[1];
    if(task) {
//  Extract which TR element triggered the context menu
    var tgt = this.contextEventTarget;
    var elCol = p_DataTable.getColumn(tgt);
    var elRow = p_DataTable.getTrEl(tgt);
      if(elRow) {
	var oRecord = p_DataTable.getRecord(elRow);
	var selected_site = oRecord.getData('Name')
	YAHOO.log('ContextMenu: '+'"'+label+'" for '+that.me()+' ('+selected_site+')','info','Core.DataTable');
	this.payload[task.index]({table:p_DataTable,
				    row:elRow,
				    col:elCol,
			  selected_site:selected_site});
      }
    }
  }
  PHEDEX.Core.ContextMenu.Add('dataTable','Hide This Column', function(args) {
    YAHOO.log('hideColumn: '+args.col.key,'info','Core.DataTable');
    args.table.hideColumn(args.col);
  });

// This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
// it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
// I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
// complete. This allows me to ignore the menu completely if the user didn't build one.
// If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
// care that the object was assembled in exactly the right way. That would then make things a bit more complex...
  that.onBuildComplete.subscribe(function() {
    YAHOO.log('onBuildComplete: '+that.me(),'info','Core.DataTable');
    if ( that.contextMenu )
    {
      YAHOO.log('subscribing context menu: '+that.me(),'info','Core.DataTable');
      that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.dataTable);
      that.contextMenu.render(document.body);
    }
//  Event-subscriptions for the 'Show all columns' button. Require that the dataTable exist, so post-build!
    that.dataTable.subscribe('columnHideEvent', function(ev) {
      var column = this.getColumn(ev.column);
      YAHOO.log('column_menu.addItem: label:'+column.label+' key:'+column.key,'info','Core.DataTable');
      that.column_menu.addItem({text: column.label || column.key,value:column.key});
      that.refreshButton();
    } );
    that.dataTable.subscribe('renderEvent', function() { that.resizePanel(that.dataTable); } );
  });

  that.onPopulateComplete.subscribe(function() {
// Hide columns by default. TODO this is fired on PopulateComplete because I don't know how to do it earlier. Would be better if I did
    if ( !that.hideByDefault ) { return; }
    for (var i in that.hideByDefault)
    {
      var column = that.dataTable.getColumn(that.hideByDefault[i]);
      if ( column ) { that.dataTable.hideColumn(column); }
    }
    that.hideByDefault = null; // don't want to do this every time the build is complete...?
  });

// Allow the table to be build again after updates
  that.onUpdateComplete.subscribe( function() {that.fillDataSource(that.data); } );

// Gratuitously flash yellow when the mouse goes over the rows
  that.onRowMouseOut = function(event) {
    event.target.style.backgroundColor = null;
  }
  that.onRowMouseOver = function(event) {
    event.target.style.backgroundColor = 'yellow';
  }

// Resize the panel when extra columns are shown, to accomodate the width
  that.resizePanel=function(table) {
//I have no idea if this is the _best_ way to calculate the new size, but it seems to work, so I stick with it.
    var old_width = table.getContainerEl().clientWidth;
    var offset = 25; // No idea how to determine the correct value here, but this seems to fit.
    var x = table.getTableEl().clientWidth + offset;
    if ( x >= old_width ) { that.panel.cfg.setProperty('width',x+'px'); }
  }

// Custom formatter for unix-epoch dates
  that.UnixEpochToGMTFormatter = function(elCell, oRecord, oColumn, oData) {
    var gmt = new Date(oData*1000).toGMTString();
    elCell.innerHTML = gmt;
  };
  YAHOO.widget.DataTable.Formatter.UnixEpochToGMT = that.UnixEpochToGMTFormatter

  return that;
}
