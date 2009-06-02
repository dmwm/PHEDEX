// instantiate the PHEDEX.Widget.Nodes namespace
PHEDEX.namespace('Widget.Nodes');

PHEDEX.Page.Widget.Nodes=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  var nodes = new PHEDEX.Widget.Nodes(site,divid);
  nodes.update();
}

PHEDEX.Widget.Nodes=function(site,divid) {
	if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
	var that=new PHEDEX.Core.Widget(divid+'_display',null,
		{width:500,
		 height:200,
		 minwidth:300,
		 minheight:80
		});
	that.site=site;
	that.data = null;
	that.fillHeader=function(div) {
	  div.innerHTML = 'PHEDEX Nodes: '+this.data.length+" sites found...";
	}
	that.buildBody=function(div) {
         that.columnDefs = [
	            {key:"ID", sortable:true, resizeable:true},
	            {key:"Name", sortable:true, resizeable:true},
	            {key:"Kind", sortable:true, resizeable:true},
	            {key:"Technology", sortable:true, resizeable:true},
	            {key:"SE", sortable:true, resizeable:true},
	        ];
          that.dataSource = new YAHOO.util.LocalDataSource();//table);
	  that.dataTable = new YAHOO.widget.DataTable(div, that.columnDefs, that.dataSource,
	  			 { draggableColumns:true, initialLoad:false });
	}
	that.fillBody=function(div) {
          var table = [];
	  for (var i in that.data) {
	    var a = that.data[i];
// Rather than fill by-hand and duplicate key-names, I take them from the columnDefs. This makes the code more generic.
//             var y = { ID:a['id'], Name:a['name'], Kind:a['kind'], Technology:a['technology'], SE:a['se'] };
	    var y = [];
	    for (var j in that.columnDefs )
	    {
	      var k = that.columnDefs[j].key;
	      y[k] = a[k.toLowerCase()];
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

	  var menu = new YAHOO.widget.Menu('nowhere');
	  var showColumns = new YAHOO.widget.Button(
	    {
	      type: "split",
	      label: "Show all columns",
	      name: "showColumnsButton",
	      menu: menu,
	      container: that.div_header,
	      disabled:true
	    }
	  );
	  var dt = that.dataTable;
	  showColumns.on("click", function () {
	    var m = menu.getItems();
	    for (var i = 0; i < m.length; i++) {
	      dt.showColumn(dt.getColumn(m[i].value));
	    }
	    menu.clearContent();
	    refreshButton();
	    debugger;
	    that.resizePanel(that.dataTable);
	  });

	  showColumns.on("appendTo", function () {
	    var m = this.getMenu();
	    m.subscribe("click", function onMenuClick(sType, oArgs) {
	      var oMenuItem = oArgs[1]; 
	      if (oMenuItem) {
	        that.dataTable.showColumn(dt.getColumn(oMenuItem.value));
	        m.removeItem(oMenuItem.index);
	        refreshButton();
	      }
	      that.resizePanel(that.dataTable);
	    });
	  });

	  var refreshButton = function() {
	    if (YAHOO.util.Dom.inDocument('nowhere')) {
	      menu.render();
	    } else {
	      menu.render(document.body);
	    }
	  showColumns.set('disabled', menu.getItems().length === 0);
	  };
	  
	  that.dataTable.subscribe('columnHideEvent', function(ev) {
				var column = this.getColumn(ev.column);
				menu.addItem({text: column.label || column.key,value:column.key});
				refreshButton();
			} );
	  that.resizePanel=function(table) {
	    var x = table.getTableEl().clientWidth;
	    that.panel.cfg.setProperty('width',x+25+'px');
	  }
	  that.dataTable.subscribe('renderEvent', function() { that.resizePanel(dt); } );
	}

	that.onContextMenuClick = function(p_sType, p_aArgs, p_DataTable) {
	  var label = p_aArgs[0].explicitOriginalTarget.textContent;
          var task = p_aArgs[1];
          if(task) {
// 	  Extract which TR element triggered the context menu
            var tgt = this.contextEventTarget;
	    var elCol = p_DataTable.getColumn(tgt);
            var elRow = p_DataTable.getTrEl(tgt);
            if(elRow) {
              var oRecord = p_DataTable.getRecord(elRow);
	      var selected_site = oRecord.getData('Name')
	      YAHOO.log('PHEDEX.Widget.Nodes: ContextMenu: "'+label+'" for '+selected_site);
	      this.payload[task.index]({table:p_DataTable,
	      				  row:elRow,
					  col:elCol,
				selected_site:selected_site});
            }
          }
        }
	that.onRowMouseOut = function(event) {
	  event.target.style.backgroundColor = null;
	}
	that.onRowMouseOver = function(event) {
	  event.target.style.backgroundColor = 'yellow';
        }

	that.postPopulate = function() {
	  YAHOO.log('PHEDEX.Widget.Nodes: postPopulate');
	  that.contextMenu = PHEDEX.Core.ContextMenu.Create('Node',{trigger:that.dataTable.getTbodyEl()});
	  PHEDEX.Core.ContextMenu.Build(that.contextMenu,'Node','dataTable');
          that.contextMenu.render(document.body); // that.div_body);
          that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.dataTable);
          that.dataTable.subscribe('rowMouseoverEvent',that.onRowMouseOver);
          that.dataTable.subscribe('rowMouseoutEvent', that.onRowMouseOut);
	}
	that.fillFooter=function(div) { return; }
	that.update=function() {
	  PHEDEX.Datasvc.Nodes(that.site,that);
	}
	that.receive=function(result) {
	  that.data = PHEDEX.Data.Nodes; // use global data object, instead of result['node'];
	  that.populate();
	}
	that.build();
	that.onPopulateComplete.subscribe(that.postPopulate);
	return that;
}
