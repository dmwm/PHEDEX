// instantiate the PHEDEX.Widget.Nodes namespace
PHEDEX.namespace('Widget.Nodes');

PHEDEX.Page.Widget.Nodes=function(divid) {
  var node = document.getElementById(divid+'_select').value;
  var nodes = new PHEDEX.Widget.Nodes(node,divid);
  nodes.update();
}

PHEDEX.Widget.Nodes=function(node,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that=new PHEDEX.Core.Widget.DataTable(divid+'_display',null,
	{width:500,
	 height:200,
	 minwidth:400,
	 minheight:50
	});
  that.hideByDefault = ['Kind','Technology'];
  that.node=node;
  that.data = null;
  that.me=function() { return 'PHEDEX.Core.Widget.Nodes'; }
  that.fillHeader=function(div) {
    var s = document.createElement('span');
    div.appendChild(s);
    s.innerHTML = 'PHEDEX Nodes: '+this.data.length+" nodes";
  }
  that.buildTable(that.div_content,
            [ {key:'ID',parser:YAHOO.util.DataSource.parseNumber },'Name','Kind','Technology','SE' ]
	     );
  that.update=function() {
    PHEDEX.Datasvc.Nodes(that.node,that);
  }
  that.receive=function(result) {
    that.data = PHEDEX.Data.Nodes; // use global data object, instead of result['node'];
    if (that.data) { that.populate(); }
    else { that.failedLoading(); }
  }

  that.buildContextMenu('Node');
  that.build();
  return that;
}
