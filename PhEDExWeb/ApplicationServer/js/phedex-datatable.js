PHEDEX.DataTable = function(sandbox,string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.Module(sandbox,string));
  var _me  = 'DataTable',
      _sbx = sandbox;

  var _construct = function() {
    return {
      type: 'DataTable',
      fillDataSource: function(data) {
        var table = [];
        for (var i in data) {
          var a = data[i];
          var y = [];
          for (var j in this.columnDefs )
          {
            var c = this.columnDefs[j];
            var val = a[this.columnMap[c.key]];
//          This applies the parser, if any. This is needed to ensure that numbers are sorted numerically, and not as strings.
//          Declare fields to be numeric in your columns specified to buildTable, see above
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
        var w = this.dataTable.getTableEl().offsetWidth;
        this.el.style.width = w+'px';
      },

// TODO: This only matters for resizeable panels, so belongs in a decorator to that effect. The core module class needs sorting for that.
      resizePanel: function() {
        var table = this.dataTable;
        var old_width = table.getContainerEl().clientWidth;
        var offset = this.dom.header.offsetWidth - this.dom.content.offsetWidth;
        var x = table.getTableEl().offsetWidth + offset;
        if ( x >= old_width ) { this.module.cfg.setProperty('width',x+'px'); }
      },

      menuSelectItem: function(arr) {
        this.dataTable.showColumn(this.dataTable.getColumn(arr[0]));
      },

      buildTable: function(div,columns,map,dsschema) {
        this.columnDefs = columns;
        this.dsResponseSchema = dsschema; //Stores the response schema for the datasource
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
        this.dataTable = new YAHOO.widget.DataTable(div, this.columnDefs, this.dataSource, { draggableColumns:true, initialLoad:false });
        var w = this.dataTable.getTableEl().offsetWidth;
        this.el.style.width = w+'px';

        this.dataTable.subscribe('columnHideEvent', function(obj) {
          return function(ev) {
            var column = obj.dataTable.getColumn(ev.column);
            log('columnHideEvent: label:'+column.label+' key:'+column.key,'info',_me);
            _sbx.notify(obj.id, 'hideColumn', {text: column.label || column.key,value:column.key} );
          }
        }(this));
        this.dataTable.subscribe('renderEvent', function() { this.resizePanel(); } );
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(),true);
  return this;
}

// Custom formatter for unix-epoch dates
YAHOO.widget.DataTable.Formatter.UnixEpochToGMT =  function(elCell, oRecord, oColumn, oData) {
  var gmt = new Date(oData*1000).toGMTString();
  elCell.innerHTML = gmt;
};

// decorators for the datatable.
PHEDEX.DataTable.ContextMenu = function(obj,args) {
  PHEDEX.Component.ContextMenu.Add('dataTable','Hide This Field',function(opts, el) {
    log('hideField: ' + el.col.key, 'info', 'ContextMenu');
    el.table.hideColumn(el.col);
  });
  var p = args.payload;
  if ( !p.config ) { p.config={}; }
  if ( !p.config.trigger ) { p.config.trigger = obj.dataTable.getTbodyEl(); }

  return {
   onContextMenuClick: function(p_sType, p_aArgs, obj) {
      log('ContextMenuClick for ' + obj.me, 'info', 'ContextMenu');
      var menuitem = p_aArgs[1];
      if (menuitem) {
        //  Extract which <tr> triggered the context menu
        var tgt = this.contextEventTarget;
        var elCol = obj.dataTable.getColumn(tgt);
        var elRow = obj.dataTable.getTrEl(tgt);
        var label = tgt.textContent;
        if (elRow) {
          var opts = {};
          var oRecord = obj.dataTable.getRecord(elRow);
          // map types to column names in order to prepare our options
          if (obj.contextMenuTypeMap) {
            for (var type in obj.contextMenuTypeMap) {
              var recName = obj.contextMenuTypeMap[type];
              opts[type] = oRecord.getData(recName);
            }
          }
          menuitem.value.fn(opts, { table: obj.dataTable, row: elRow, col: elCol, record: oRecord });
        }
      }
    },
  };
}

PHEDEX.DataTable.MouseOver = function(sandbox,args) {
  var obj = args.payload.obj;
//   obj[args.name] = {};
  var onRowMouseOut = function(event) {
// Gratuitously flash yellow when the mouse goes over the rows
// Would like to use the DOM, but this gets over-ridden by yui-dt-odd/even, so set colour explicitly.

// Leave this next line here in case phedex-drow-highlight ever becomes a useful class (e.g. when we do our own skins)
//     YAHOO.util.Dom.removeClass(event.target,'phedex-drow-highlight');
    event.target.style.backgroundColor = null;
  }
  var onRowMouseOver = function(event) {
//     YAHOO.util.Dom.addClass(event.target,'phedex-drow-highlight');
    event.target.style.backgroundColor = 'yellow';
  }
  obj.dataTable.subscribe('rowMouseoverEvent',onRowMouseOver);
  obj.dataTable.subscribe('rowMouseoutEvent', onRowMouseOut);
// return the functions, so they can be overridden if needed without having to redo the event subscription
  return { onRowMouseOut:onRowMouseOut, onRowMouseOver:onRowMouseOver};
};

//   //*******************************************************************************************************
//   //Function:fillDataSourceWithSchema
//   //Purpose :This function fills the datasource with the data and response schema
//   //*******************************************************************************************************
//   this.fillDataSourceWithSchema = function(jsonData, dsSchema) {
//       this.dataSource = new YAHOO.util.DataSource(jsonData);
//       this.dataSource.responseSchema = dsSchema;
//       var oCallback = {
//           success: this.dataTable.onDataReturnInitializeTable,
//           failure: this.dataTable.onDataReturnInitializeTable,
//           scope: this.dataTable
//       };
//       this.dataSource.sendRequest('', oCallback); //This is to update the datatable on UI
//   }
// 
// // This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
// // it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
// // I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
// // complete. This allows me to ignore the menu completely if the user didn't build one.
// // If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
// // care that the object was assembled in exactly the right way. That would then make things a bit more complex...
//   this.onBuildComplete.subscribe(function(obj) {
//     return function() {
//       YAHOO.log('onBuildComplete: '+this.me(),'info','Core.DataTable');
//       if ( obj.contextMenu )
//       {
//         YAHOO.log('subscribing context menu: '+obj.me(),'info','Core.DataTable');
//         obj.contextMenu.clickEvent.subscribe(obj.onContextMenuClick, obj);
//         obj.contextMenu.render(document.body);
//       }

//       obj.dataTable.subscribe('renderEvent', function() { obj.resizePanel(obj.dataTable); } );
//     }
//   }(this));
// 
//   this.onPopulateComplete.subscribe(function(obj) {
//     return function() {
//       for (var i in this.options.defhide)
//       {
//         var column = obj.dataTable.getColumn(this.options.defhide[i]);
//         if ( column ) { obj.dataTable.hideColumn(column); }
//       }
//       this.options.defhide = null; // don't want to do this every time the build is complete...?
//       
//       // sort by default
//       if (this.options.defsort) {
// 	obj.dataTable.sortColumn( obj.dataTable.getColumn( this.options.defsort ) );
//       }
//     }
//   }(this));
// 
// // Allow the table to be built again after updates
//   this.onUpdateComplete.subscribe( function(obj) {
//     return function() {
//       obj.fillDataSource(obj.data);
//     }
//   }(this) );
// 
//   this.onDataFailed.subscribe(function(obj) {
//     return function() {
// //    Empty the dataTable if it is there
//       if ( obj.dataTable ) { obj.dataTable.destroy(); obj.dataTable = null; } // overkill? Who cares!...
//       obj.dom.content.innerHTML='Data-load error, try again later...';
//     }
//   }(this));
// 
//
//   //****************************************************************************************************
//   //Function:resizePanel
//   //Purpose :This function resizes the panel when extra columns are shown, to accomodate the width
//   //****************************************************************************************************
//   this.resizePanel=function(table) {
//     var old_width = table.getContainerEl().clientWidth;
//     var offset = this.dom.header.offsetWidth - this.dom.content.offsetWidth;
//     var x = table.getTableEl().offsetWidth + offset;
//     if ( x >= old_width ) { this.panel.cfg.setProperty('width',x+'px'); }
//   }
//
//   this.filter.onFilterCancelled.subscribe( function(obj) {
//     return function() {
//       YAHOO.log('onWidgetFilterCancelled:'+obj.me(),'info','Core.DataTable');
//       YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.fillDataSource(obj.data);
//       obj.filter.Reset();
//       obj.ctl.filter.Hide();
//       PHEDEX.Event.onWidgetFilterCancelled.fire(obj.filter);
//     }
//   }(this));
//   PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
//     return function() {
//       YAHOO.log('onGlobalFilterCancelled:'+obj.me(),'info','Core.DataTable');
//       YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.fillDataSource(obj.data);
//       obj.filter.Reset();
//     }
//   }(this));
// 
//   PHEDEX.Event.onGlobalFilterValidated.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       if ( ! obj.filter.args ) { obj.filter.args = []; }
//       for (var i in args) {
// 	obj.filter.args[i] = args[i];
//       }
//       obj.applyFilter(arr[0]);
//     }
//   }(this));
//   this.filter.onFilterApplied.subscribe(function(obj) {
//     return function(ev,arr) {
//       obj.applyFilter(arr[0]);
//       obj.ctl.filter.Hide();
//     }
//   }(this));
// 
//   this.applyFilter=function(args) {
// // this is much easier for tables than for branches. Just go through the data-table and build a new one,
// // then feed that to the DataSource!
//     var table=[];
//     if ( ! args ) { args = this.filter.args; }
//     for (var i in this.data) {
//       var keep=true;
//       for (var key in args) {
// 	if ( typeof(args[key].value) == 'undefined' ) { continue; }
// 	var fValue = args[key].value;
// 	var kValue = this.data[i][key];
// 	if ( args[key].preprocess ) { kValue = args[key].preprocess(kValue); }
// 	var negate = args[key].negate;
// 	var status = this.filter.Apply[this.filter.fields[key].type](fValue,kValue);
// 	if ( args[key].negate ) { status = !status; }
// 	if ( !status ) { // Keep the element if the match succeeded!
// 	  this.filter.count++;
// 	  keep=false;
// 	}
//       }
//       if ( keep ) { table.push(this.data[i]); }
//     }
//     this.fillDataSource(table);
//     return this.filter.count;
//   }

log('loaded...','info','DataTable');
