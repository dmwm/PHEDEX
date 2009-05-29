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
	that.fillBody=function(div) {
          var table = [];
	  for (var i in that.data) {
	    var a = that.data[i];
            var y = { ID:a['id'], Name:a['name'], Kind:a['kind'], Technology:a['technology'], SE:a['se'] };
            table.push( y );
          }
          that.columnDefs = [
	            {key:"ID", sortable:true, resizeable:true},
	            {key:"Name", sortable:true, resizeable:true},
	            {key:"Kind", sortable:true, resizeable:true},
	            {key:"Technology", sortable:true, resizeable:true},
	            {key:"SE", sortable:true, resizeable:true},
	        ];
          that.dataSource = new YAHOO.util.DataSource(table);
	  that.dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
	  that.dataSource.responseSchema = { fields: {} };
	  for (var i in that.columnDefs) { that.dataSource.responseSchema.fields[i] = that.columnDefs[i].key; }
	  that.dataTable = new YAHOO.widget.DataTable(div, that.columnDefs, that.dataSource, { draggableColumns:true });
	}

	that.onContextMenuClick = function(p_sType, p_aArgs, p_myDataTable) {
	  var label = p_aArgs[0].explicitOriginalTarget.textContent;
          var task = p_aArgs[1];
          if(task) {
// 	  Extract which TR element triggered the context menu
            var elRow = this.contextEventTarget;
            elRow = p_myDataTable.getTrEl(elRow);
              if(elRow) {
                var oRecord = p_myDataTable.getRecord(elRow);
		var selected_site = oRecord.getData('Name')
		YAHOO.log('ContextMenu: "'+label+'" for '+selected_site);
		this.payload[task.index](selected_site);
//                 switch(task.index) {
//                   case 2:     // Delete row upon confirmation
//                     if(confirm("Are you sure you want to delete site " +oRecord.getData('Name')+"?")) {
//                       p_myDataTable.deleteRow(elRow);
//                     }
// 		    break;
//                 }
              }
            }
          }
	that.callback_ShowAgents=function(selected_site) {
	  var newAgent = new PHEDEX.Widget.Agents(selected_site);
	  newAgent.update();
	}
	that.callback_ShowLinks=function(selected_site) {
	  var newLinks = new PHEDEX.Widget.TransfersNode(selected_site);
	  newLinks.update();
	}
	that.postPopulate = function() {
	  YAHOO.log('PHEDEX.Widget.Nodes: postPopulate');
	  PHEDEX.Core.ContextMenu.Create('Node',{trigger:that.dataTable.getTbodyEl()});
	  PHEDEX.Core.ContextMenu.Add('Node','Show Agents',that.callback_ShowAgents);
	  PHEDEX.Core.ContextMenu.Add('Node','Show Links',that.callback_ShowLinks);
//        Render the ContextMenu instance to the parent container of the DataTable
	  that.contextMenu = PHEDEX.Core.ContextMenu.Build('Node');
          that.contextMenu.render(that.div_content);
          that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.dataTable);
	}
	that.fillFooter=function(div) { return; }
	that.update=function() {
	  PHEDEX.Datasvc.Nodes(that.site,that);
	}
	that.receive=function(result) {
	  that.data = PHEDEX.Data.Nodes; // use global data object, instead of result['node'];
	  that.populate();
	}
	that.onPopulateComplete.subscribe(that.postPopulate);
	that.build();
	return that;
}
