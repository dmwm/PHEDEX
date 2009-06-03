// instantiate the PHEDEX.Widget.Nodes namespace
PHEDEX.namespace('Widget.Nodes');

PHEDEX.Page.Widget.Nodes=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  var nodes = new PHEDEX.Widget.Nodes(site,divid);
  nodes.update();
}

PHEDEX.Widget.Nodes=function(site,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that=new PHEDEX.Core.Widget.DataTable(divid+'_display',null,
	{width:500,
	 height:200,
	 minwidth:400,
	 minheight:50
	});
  that.site=site;
  that.data = null;
  that.me=function() { return 'PHEDEX.Core.Widget.Nodes'; }
  that.fillHeader=function(div) {
    var s = document.createElement('span');
    div.appendChild(s);
    s.innerHTML = 'PHEDEX Nodes: '+this.data.length+" sites";
  }
  that.buildTable(that.div_content,
            [ 'ID','Name','Kind','Technology','SE' ],
	    {} );
  that.onUpdateComplete.subscribe( function() {that.fillDataSource(that.data); } );
  that.update=function() {
    PHEDEX.Datasvc.Nodes(that.site,that);
  }
  that.receive=function(result) {
    that.data = PHEDEX.Data.Nodes; // use global data object, instead of result['node'];
    that.populate();
  }

  that.buildContextMenu('Node');
  that.build();
  return that;
}
