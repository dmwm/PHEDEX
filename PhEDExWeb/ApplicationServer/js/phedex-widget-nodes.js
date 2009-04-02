PHEDEX.Data.nodes=null;

nodes=function() {
  var site = document.getElementById('select_for_nodes').value;
  var nodes = new PHEDEX.Widget.Nodes(site);
  nodes.update();
//  PHEDEX.Data.Nodes = nodes;
}

PHEDEX.Widget.Nodes=function(site) {
	var that=new PHEDEX.Widget('phedex_nodes',null,{children:false});
	that.site=site;
	that.data = null;
	that.buildHeader=function() {
	  return "Sites: "+this.data.length+" known...";
	}
	that.buildExtra=function() {
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
        var dataTable = new YAHOO.widget.ScrollingDataTable(that.id+"_table", columnDefs, dataSource,
                     {
                      caption:"PhEDEx Nodes",
                      height:'80px',
                      draggableColumns:true
                     });
	}
	that.update=function() {
	  PHEDEX.Datasvc.Nodes(site,this.receive,this);
	}
	that.receive=function(result) {
	  var data = result.responseText;
	  data = eval('('+data+')'); 
	  data = data['phedex']['node'];
	  if (data.length) {
            result.argument.data = data;
	    result.argument.build();
	    }
	}
	return that;
}

PHEDEX.Datasvc.Nodes = function(site,callback,argument) {
  var opts = 'nodes';
  if ( site ) { opts += '?node='+site; }
  PHEDEX.Datasvc.GET(opts,callback,argument);
}

PHEDEX.Util.addLoadListener(nodes);
