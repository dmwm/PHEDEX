// instantiate the PHEDEX.Widget.Nodes namespace
PHEDEX.namespace('Widget.Nodes');

nodes=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  var nodes = new PHEDEX.Widget.Nodes(divid,site);
  nodes.update();
}

PHEDEX.Widget.Nodes=function(divid,site) {
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
