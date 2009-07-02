// instantiate the PHEDEX.Widget.Agents namespace
PHEDEX.namespace('Widget.Agents');

PHEDEX.Page.Widget.Agents=function(divid) {
  var node = document.getElementById(divid+'_select').value;
  var agent_node = new PHEDEX.Widget.Agents(node,divid);
  agent_node.update();
}

PHEDEX.Widget.Agents=function(node,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that=new PHEDEX.Core.Widget.DataTable(divid+'_'+node,null,
    {
	width:500,
	height:200,
	minwidth:300,
	minheight:50
    });
  that.hideByDefault = ['PID','Label','Version','Host','State Dir'];
  that.node=node;
  that.me=function() { return 'PHEDEX.Core.Widget.Agents'; }
  that.fillHeader=function(div) {
    var msg = this.node+', '+this.data.length+' agents.';
    that.span_title.innerHTML = msg;
  }
  that.fillExtra=function(div) {
    var msg = 'If you are reading this, there is a bug somewhere...';
    var now = new Date() / 1000;
    var minDate = now;
    var maxDate = 0;
    for ( var i in this.data) {
      var a = this.data[i];
      var u = a['time_update'];
      if ( u > maxDate ) { maxDate = u; }
      if ( u < minDate ) { minDate = u; }
    }
    if ( maxDate > 0 )
    {
      var minGMT = new Date(minDate*1000).toGMTString();
      var maxGMT = new Date(maxDate*1000).toGMTString();
      var dMin = Math.round(now - minDate);
      var dMax = Math.round(now - maxDate);
      msg = " Update-times: "+dMin+" - "+dMax+" seconds ago";
    }
    that.div_extra.innerHTML = msg;
  }
  that.buildTable(that.div_content,
            [ 'Agent',
	      {key:"Date", formatter:'UnixEpochToGMT'},
	      {key:'PID',parser:YAHOO.util.DataSource.parseNumber},
	      'Version','Label','Host','State Dir'
	    ],
	    {Agent:'name', Date:'time_update', 'State Dir':'state_dir' } );
  that.update=function() { PHEDEX.Datasvc.Call({api:'agents',
                                                args:{node:that.node},
                                                success_event:that.onDataReady,
                                                limit:-1}); }
  that.onDataReady.subscribe(function(type,args) { var data = args[0]; that.receive(data); });
  that.receive=function(data) {
    that.data = data.node[0].agent;
    if (that.data) { that.populate(); }
    else { that.failedLoading(); }
  }

  that.buildExtra(that.div_extra);
  that.buildContextMenu('Agent');
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Agents',function(args,opts,el) { PHEDEX.Widget.Agents(opts.selected_node).update(); });
