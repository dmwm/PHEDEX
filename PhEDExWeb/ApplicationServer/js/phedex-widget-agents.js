// instantiate the PHEDEX.Widget.Agents namespace
PHEDEX.namespace('Widget.Agents');

PHEDEX.Page.Widget.Agents=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  var agent_node = new PHEDEX.Widget.Agents(site,divid);
  agent_node.update();
}

PHEDEX.Widget.Agents=function(site,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that=new PHEDEX.Core.Widget.DataTable(divid+'_'+site,null,
    {
	width:500,
	height:200,
	minwidth:300,
	minheight:50
    });
  that.hideByDefault = ['PID','Label','Version','Host','State Dir'];
  that.site=site;
  that.me=function() { return 'PHEDEX.Core.Widget.Agents'; }
  that.fillHeader=function(div) {
    var now = new Date() / 1000;
    var minDate = now;
    var maxDate = 0;
    for ( var i in this.data) {
      var a = this.data[i];
      var u = a['time_update'];
      if ( u > maxDate ) { maxDate = u; }
      if ( u < minDate ) { minDate = u; }
    }
    var msg = "Site: "+this.site+", agents: "+this.data.length;
    if ( maxDate > 0 )
    {
      var minGMT = new Date(minDate*1000).toGMTString();
      var maxGMT = new Date(maxDate*1000).toGMTString();
      var dMin = Math.round(now - minDate);
      var dMax = Math.round(now - maxDate);
      msg += " Update-times range: "+dMin+" - "+dMax+" seconds ago";
    }
    var s = document.createElement('span');
    div.appendChild(s);
    s.innerHTML = msg;
  }
  that.buildTable(that.div_content,
            [ 'Agent',
	      {key:"Date", formatter:'UnixEpochToGMT'},
	      {key:'PID',parser:YAHOO.util.DataSource.parseNumber},
	      'Version','Label','Host','State Dir'
	    ],
	    {Agent:'name', Date:'time_update', 'State Dir':'state_dir' } );
  that.update=function() { PHEDEX.Datasvc.Agents(that.site,that); }
  that.receive=function(result) {
    that.data = PHEDEX.Data.Agents[that.site];
    if (that.data) { that.populate(); }
    else { that.failedLoading(); }
  }

  that.buildContextMenu('Agent');
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Agents',function(args) { PHEDEX.Widget.Agents(args.selected_site).update(); });
