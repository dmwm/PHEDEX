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
		{children:false,
		 width:500,
		 height:200,
		 minwidth:300,
		 minheight:80
		});
	that.site=site;
	that.data = null;
	that.fillHeader=function(div) {
	  div.innerHTML = 'PHEDEX Nodes: '+this.data.length+" sites found...";
	}
	that.fillBody=function(div) {
          var table = [];
	  for (var i in this.data) {
	    var a = this.data[i];
            var y = { ID:a['id'], Name:a['name'], Kind:a['kind'], Technology:a['technology'], SE:a['se'] };
            table.push( y );
          }
          var columnDefs = [
	            {key:"ID", sortable:true, resizeable:true},
	            {key:"Name", sortable:true, resizeable:true},
	            {key:"Kind", sortable:true, resizeable:true},
	            {key:"Technology", sortable:true, resizeable:true},
	            {key:"SE", sortable:true, resizeable:true},
	        ];
          var dataSource = new YAHOO.util.DataSource(table);
	  dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
	  dataSource.responseSchema = {
	            fields: ["ID","Name","Kind","Technology","SE"]
	        };
	var h = div.clientHeight;
	var w = div.clientWidth;
        this.dataTable = new YAHOO.widget.DataTable(div, columnDefs, dataSource,
                     {
                      draggableColumns:true,
                     });
        var onContextMenuClick = function(p_sType, p_aArgs, p_myDataTable) {
          var task = p_aArgs[1];
          if(task) {
//	  Extract which TR element triggered the context menu
            var elRow = this.contextEventTarget;
            elRow = p_myDataTable.getTrEl(elRow);
              if(elRow) {
                var oRecord = p_myDataTable.getRecord(elRow);
		var site = oRecord.getData('Name')
                switch(task.index) {
                  case 0:     // Show agents for node...
// 		    var newAgent = new PHEDEX.Widget.Agents('Agents_auto_'+site,site);
		    var newAgent = new PHEDEX.Widget.Agents(site);
		    newAgent.update();
		    break;
                  case 1:     // Show links for node...
		    var newLinks = new PHEDEX.Widget.TransfersNode(site);
		    newLinks.update();
		    break;
                  case 2:     // Delete row upon confirmation
                    if(confirm("Are you sure you want to delete site " +oRecord.getData('Name')+"?")) {
                      p_myDataTable.deleteRow(elRow);
                    }
		    break;
                }
              }
            }
          };
          var myContextMenu = new YAHOO.widget.ContextMenu("mycontextmenu",
                {trigger:this.dataTable.getTbodyEl()});
          myContextMenu.addItem("Show Agents");
          myContextMenu.addItem("Show Links for site");
          myContextMenu.addItem("Delete Item");
          // Render the ContextMenu instance to the parent container of the DataTable
          myContextMenu.render(this.div_content);
          myContextMenu.clickEvent.subscribe(onContextMenuClick, this.dataTable);
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
	return that;
}

// YAHOO.util.Event.addListener(window, "load", function() {
//     YAHOO.example.ContextMenu = function() {
//         var myColumnDefs = [
//             {key:"SKU", sortable:true},
//             {key:"Quantity", sortable:true},
//             {key:"Item", sortable:true},
//             {key:"Description"}
//         ];
// 
//         var myDataSource = new YAHOO.util.DataSource(YAHOO.example.Data.inventory);
//         myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
//         myDataSource.responseSchema = {
//             fields: ["SKU","Quantity","Item","Description"]
//         };
// 
//         var myDataTable = new YAHOO.widget.DataTable("myContainer", myColumnDefs, myDataSource);
// 
//         var onContextMenuClick = function(p_sType, p_aArgs, p_myDataTable) {
//             var task = p_aArgs[1];
//             if(task) {
//                 // Extract which TR element triggered the context menu
//                 var elRow = this.contextEventTarget;
//                 elRow = p_myDataTable.getTrEl(elRow);
// 
//                 if(elRow) {
//                     switch(task.index) {
//                         case 0:     // Delete row upon confirmation
//                             var oRecord = p_myDataTable.getRecord(elRow);
//                             if(confirm("Are you sure you want to delete SKU " +
//                                     oRecord.getData("SKU") + " (" +
//                                     oRecord.getData("Description") + ")?")) {
//                                 p_myDataTable.deleteRow(elRow);
//                             }
//                     }
//                 }
//             }
//         };
// 
//         var myContextMenu = new YAHOO.widget.ContextMenu("mycontextmenu",
//                 {trigger:myDataTable.getTbodyEl()});
//         myContextMenu.addItem("Delete Item");
//         // Render the ContextMenu instance to the parent container of the DataTable
//         myContextMenu.render("myContainer");
//         myContextMenu.clickEvent.subscribe(onContextMenuClick, myDataTable);
//         
//         return {
//             oDS: myDataSource,
//             oDT: myDataTable
//         };
//     }();
// });
