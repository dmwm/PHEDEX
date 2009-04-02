var agent_node=null;

agents=function() {
  var site = document.getElementById('select_for_agents').value;
  agent_node = new PHEDEX.Widget.Agents(site);
  agent_node.update();
}

PHEDEX.Widget.Agents=function(site) {
	var that=new PHEDEX.Widget('phedex_agents');
	that.site=site;
	that.data = null;
	that.buildHeader=function() {
          var now = new Date() / 1000;
          var minDate = now;
          var maxDate = 0;
          for ( var i in this.data['agent']) {
	    var a = this.data['agent'][i];
            var u = a['time_update'];
            a['gmtDate'] = new Date(u*1000).toGMTString();
            if ( u > maxDate ) { maxDate = u; }
            if ( u < minDate ) { minDate = u; }
          }
	  var msg = "Site: "+this.data['node']+", agents: "+this.data['agent'].length;
          if ( maxDate > 0 )
          {
            var minGMT = new Date(minDate*1000).toGMTString();
            var maxGMT = new Date(maxDate*1000).toGMTString();
            var dMin = Math.round(now - minDate);
            var dMax = Math.round(now - maxDate);
            msg += " Update-times range: "+dMin+" - "+dMax+" seconds ago";
          }
          return msg;
	}
	that.buildExtra=function() {
          var table = [];
	  for (var i in this.data['agent']) {
	    var a = this.data['agent'][i];
            var y = { Agent:a['name'], Version:a['version'], PID:a['pid'], Date:a['gmtDate'] };
            table.push( y );
          }
          var columnDefs = [
	            {key:"Agent", sortable:true, resizeable:true},
	            {key:"Version", sortable:true, resizeable:true},
	            {key:"PID", sortable:true, resizeable:true},
	            {key:"Date", formatter:YAHOO.widget.DataTable.formatDate, sortable:true, resizeable:true},
	        ];
          var dataSource = new YAHOO.util.DataSource(table);
	        dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
	        dataSource.responseSchema = {
	            fields: ["Agent","Version","PID","Date"]
	        };
        var dataTable = new YAHOO.widget.ScrollingDataTable(that.id+"_table", columnDefs, dataSource,
                     {
                      caption:"PhEDEx Agents on "+site,
                      height:'150px',
                      draggableColumns:true
                     });
	}
	that.update=function() {
	  PHEDEX.Datasvc.Agents(site,this.receive,this);
	}
	that.receive=function(result) {
	  var data = result.responseText;
	  data = eval('('+data+')'); 
	  data = data['phedex']['node'];
	  if (data.length) {
	    result.argument.data = data[0];
	    result.argument.build();
	    }
	}
	return that;
}

PHEDEX.Datasvc.Agents = function(site,callback,argument) {
  PHEDEX.Datasvc.GET('agents?node='+site,callback,argument);
}
