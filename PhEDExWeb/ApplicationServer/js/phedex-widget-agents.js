// instantiate the PHEDEX.Widget.Agents namespace
PHEDEX.namespace('Widget.Agents');

PHEDEX.Page.Widget.Agents=function(divid) {
  var node = document.getElementById(divid+'_select').value;
  var agent_node = new PHEDEX.Widget.Agents(node,divid);
  agent_node.update();
}

PHEDEX.Widget.Agents=function(node,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that=new PHEDEX.Core.Widget.DataTable(divid+'_'+node,
    {
	width:500,
	height:200,
	minwidth:300,
	minheight:50
    });
  that.hideByDefault = ['PID','Label','Version','Host','State Dir'];
  that.node=node;
  that.me=function() { return 'PHEDEX.Core.Widget.Agents'; }
  that.offsetTime = function(x)
  {
    var d = new Date();
    var now = d.getTime()/1000;
    var y = {min:null, max:null};
    if ( x.min ) { y.max = now-x.min; }
    if ( x.max ) { y.min = now-x.max; }
    return y;
  }
 that.filter.init( {
    'Node attributes':{
      'name'        :{type:'regex',  text:'Agent-name',      tip:'javascript regular expression' },
      'label'       :{type:'regex',  text:'Agent-label',     tip:'javascript regular expression' },
      'pid'         :{type:'int',    text:'PID',             tip:'Process-ID' },
      'time_update' :{type:'minmax', text:'Date(s)',         tip:'update-times (seconds since now)', format:that.offsetTime },
      'version'     :{type:'regex',  text:'Release-version', tip:'javascript regular expression' },
      'host'        :{type:'regex',  text:'Host',            tip:'javascript regular expression' },
      'state_dir'   :{type:'regex',  text:'State Directory', tip:'javascript regular expression' }
    } } );
  that.fillHeader=function(div) {
    var msg = this.node+', '+this.data.length+' agents.';
    that.dom.title.innerHTML = msg;
  }
  that.fillExtra=function(div) {
    var msg = 'If you are reading this, there is a bug somewhere...';
    var now = new Date() / 1000;
    var minDate = now;
    var maxDate = 0;
    for ( var i in that.data) {
      var a = that.data[i];
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
    that.dom.extra.innerHTML = msg;
  }
  that.buildTable(that.dom.content,
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

  that.buildExtra(that.dom.extra);
  that.buildContextMenu('Agent');
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Agents',function(args,opts,el) { PHEDEX.Widget.Agents(opts.node).update(); });
