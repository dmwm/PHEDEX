// instantiate the PHEDEX.Widget.Agents namespace
PHEDEX.namespace('Widget.Agents');

PHEDEX.Page.Widget.Agents=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  var agent_node = new PHEDEX.Widget.Agents(site,divid);
  agent_node.update();
}

PHEDEX.Widget.Agents=function(site,divid) {
	if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
	var that=new PHEDEX.Core.Widget(divid+'_'+site,null,
		{
		width:500,
		height:200,
		minwidth:300,
		minheight:80
		});
	that.site=site;
	that.fillHeader=function(div) {
          var now = new Date() / 1000;
          var minDate = now;
          var maxDate = 0;
          for ( var i in this.data) {
	    var a = this.data[i];
            var u = a['time_update'];
            a['gmtDate'] = new Date(u*1000).toGMTString();
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
          div.innerHTML = msg;
	}
	that.fillBody=function(div) {
	  var table = [];
	  for (var i in this.data) {
	    var a = this.data[i];
            var y = { Agent:a['name'], Version:a['version'], PID:a['pid'], Date:a['gmtDate'] };
            table.push( y );
          }
          that.columnDefs = [
	            {key:"Agent", sortable:true, resizeable:true},
	            {key:"Date", formatter:YAHOO.widget.DataTable.formatDate, sortable:true, resizeable:true},
	            {key:"PID", sortable:true, resizeable:true},
	            {key:"Version", sortable:true, resizeable:true},
	        ];
          that.dataSource = new YAHOO.util.DataSource(table);
	  that.dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
	  that.dataSource.responseSchema = { fields: {} };
	  for (var i in that.columnDefs) { that.dataSource.responseSchema.fields[i] = that.columnDefs[i].key; }
	  that.dataTable = new YAHOO.widget.DataTable(div, that.columnDefs, that.dataSource, { draggableColumns:true });
	}
	that.update=function() {
	  PHEDEX.Datasvc.Agents(that.site,that);
	}
	that.receive=function(result) {
	  that.data = PHEDEX.Data.Agents[that.site];
	  if (that.data) {
	    that.populate();
	    }
	}

//	Gratuitously flash yellow when the mouse goes over the rows
	that.onRowMouseOut = function(event) {
	  event.target.style.backgroundColor = null;
	}
	that.onRowMouseOver = function(event) {
	  event.target.style.backgroundColor = 'yellow';
        }
	that.postPopulate = function() {
	  YAHOO.log('PHEDEX.Widget.Agents: postPopulate');
          that.dataTable.subscribe('rowMouseoverEvent',that.onRowMouseOver);
          that.dataTable.subscribe('rowMouseoutEvent', that.onRowMouseOut);
	}

	that.build();
	that.onPopulateComplete.subscribe(that.postPopulate);
	return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Agents',function(selected_site) { PHEDEX.Widget.Agents(selected_site).update(); });
