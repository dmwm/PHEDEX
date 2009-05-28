// instantiate the PHEDEX.Widget.TransfersNode namespace
PHEDEX.namespace('Widget.TransfersNode','Widget.TransferQueueBlock','Widget.TransferQueueFiles');

// This is for dynamic data-loading into a treeview. The callback is called with a treeview-node as the argument, by the YUI
// toolkit the node has a 'payload' hash which we create when we build the tree, it contains the necessary information to allow
// the callback to know which data-items to pick up and insert in the tree.
//
// The callback has to know how to construct payloads for child-nodes, which is not necessarily what we want. It would be
// nice if payloads for child-nodes could be constructed from knowledge of the data, rather than knowledge of the tree, but
// I'm not sure if that makes sense
PHEDEX.Widget.TransferQueueBlock.Treeview_callback=function(node) {
  var link = PHEDEX.namespace('PHEDEX.Data.TransferQueueBlocks.'+node.payload.args['from']+'.'+node.payload.args['to']);
  for (var i in link.transfer_queue )
  {
    var tq = link.transfer_queue[i];
    for (var j in tq.block)
    {
      var block = tq.block[j];
      var text = block.name+" priority:"+tq.priority+" state:"+tq.state;
      var tNode = new YAHOO.widget.TextNode({label: text, expanded: false}, node);
      var text1 = "id:"+block.id+" files:"+block.files+" bytes:"+PHEDEX.Util.format.bytes(block.bytes);
      var tNode1 = new YAHOO.widget.TextNode({label: text1, expanded: false}, tNode);
      tNode1.payload = { call:'TransferQueueFiles', obj:node.payload.obj, args:{}, callback:PHEDEX.Widget.TransferQueueFiles.Treeview_callback }; // so I can use this in the callback
      tNode1.payload.args.from  = node.payload.args.from;
      tNode1.payload.args.to    = node.payload.args.to;
      tNode1.payload.args.block = block.name;
    }
  }
}

// Treeview callback for the QueueFiles branches. These have no children, so do not construct payloads.
PHEDEX.Widget.TransferQueueFiles.Treeview_callback=function(node) {
  var link = PHEDEX.namespace('PHEDEX.Data.TransferQueueFiles.'+node.payload.args['from']+'.'+node.payload.args['to']);
  for (var block_name in link.byName )
  {
    var block = link.byName[block_name];
    for (var k in block.file)
    {
      var file = block.file[k];
      var text = file.name+" id:"+file.id+" checksum:"+file.checksum+" bytes:"+PHEDEX.Util.format.bytes(file.bytes);
      var tNode = new YAHOO.widget.TextNode({label: text, expanded: false}, node);
      tNode.isLeaf = true;
    }
  }
}

PHEDEX.Page.Widget.TransfersNode=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  xfer_node = new PHEDEX.Widget.TransfersNode(site,divid);
  xfer_node.update();
}

PHEDEX.Widget.TransfersNode=function(site,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var width = 1000;
  var that = new PHEDEX.Core.Widget(divid+'_'+site,null,{
		fixed_extra:false,
		expand_children:false,
		width:width,
		height:300
	      });
  that.site = site;
  var config = PHEDEX.Util.getConfig(divid);
  that.direction=config.opts.direction || 'to';
  that.time=config.opts.time || '6';
  
// This is for event-handling with YUI, clean and simple. One function to clear the tree, two more to trigger updates based on the select boxes
  that.deleteBodyContents=function(div) {
//  In this case, I don't need the div, I can just operate on the tree object.
    var node;
    while ( node = that.tree.root.children[1] ) { that.tree.removeNode(node); }
    that.tree.render();
    that.data_hist = null;
    that.data_queue = null;
    that.data_error = null;
  }
  var changeDirection = function(e) {
    that.direction = this.value;
    that.deleteBodyContents();
    that.update();
  }
  var changeTimebin = function(e) {
    that.time = this.value;
    that.deleteBodyContents();
    that.update();
  }

  that.buildHeader=function(div) {
    var directionselect = document.createElement('select');
    var incoming = document.createElement('option');
    var outgoing = document.createElement('option');
    incoming.text = 'Incoming Links';
    incoming.value = 'to';
    outgoing.text = 'Outgoing Links';
    outgoing.value = 'from';
    directionselect.appendChild(incoming);
    directionselect.appendChild(outgoing);
    if ( that.direction == 'to' ) { directionselect.selectedIndex=0; }
    else			  { directionselect.selectedIndex=1; }

// build the timeselect like this so that I can override it from the configuration, which has already been used to set that.time
    var timeselect = document.createElement('select');
    var timeselect_opts = config.opts.timeselect || { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week' };
    timeselect.innerHTML = '';
    for (var i in timeselect_opts)
    {
      var selected='';
      if ( that.time == i ) { selected=' selected'; }
      timeselect.innerHTML += "<option value='"+i+"'"+selected+">"+timeselect_opts[i]+"</option";
    }
    
// Use YUI event listeners to handle the pull-down menus
    YAHOO.util.Event.addListener(directionselect, "change", changeDirection);
    YAHOO.util.Event.addListener(timeselect, "change", changeTimebin);

    div.appendChild(directionselect);
    div.appendChild(timeselect);
    var title = document.createElement('span');
    title.id = div.id+'_title';
    div.appendChild(title);
    that.title = title;
  }
  that.fillHeader=function(div) {
    this.title.innerHTML=this.site;
  }
  that.buildBody=function(div) {
    var dlist = PHEDEX.Util.makeInlineDiv({width:width,class:'treeview-header',fields:[
	  {text:'Node',width:200,class:'align-left'},
          {text:'Rate',width:100},
	  {text:'Quality',width:100},
	  {text:'Done',width:200},
	  {text:'Queued',width:200},
          {text:'Errors',width:100}
	]});
    this.tree = new YAHOO.widget.TreeView(div);
    var currentIconMode=0;
// turn dynamic loading on for entire tree:
    this.tree.setDynamicLoad(PHEDEX.Util.loadTreeNodeData, currentIconMode);
    var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, this.tree.getRoot());
    tNode.isLeaf = true;
  }

  that.update=function() {
    var args={};
    args[this.direction]=this.site;//apparently {this.direction:this.site} is invalid
    args['binwidth']=parseInt(this.time)*3600;
    PHEDEX.Datasvc.TransferQueueStats(args,this,this.receive_QueueStats);
    PHEDEX.Datasvc.TransferHistory   (args,this,this.receive_History);
    PHEDEX.Datasvc.ErrorLogSummary   (args,this,this.receive_ErrorStats);
    this.startLoading();
  }
  that.receive_QueueStats=function(result,obj) {
    that.data_queue = PHEDEX.Data.TransferQueueStats[obj.direction][obj.site];
    that.maybe_populate();
  }
  that.receive_History=function(result,obj) {
    that.data_hist = PHEDEX.Data.TransferHistory[obj.direction][obj.site];
    that.maybe_populate();
  }
  that.receive_ErrorStats=function(result,obj) {
    that.data_error = PHEDEX.Data.ErrorLogSummary[obj.direction][obj.site];
    that.maybe_populate();
  }
  that.maybe_populate=function() {
    if ( that.data_hist && that.data_error && that.data_queue )
    {
      this.finishLoading();
      this.populate();
    }
  }

  that.fillBody=function(div) {
    var root = this.tree.getRoot();
    var antidirection='to';
    if (this.direction=='to') { antidirection='from'; }
    if ( !this.data_hist.length )
    {
      var tLeaf = new YAHOO.widget.TextNode({label: 'Nothing found, try another node...', expanded: false}, root);
      tLeaf.isLeaf = true;
    }
    for (var i in this.data_hist) {
      var h = this.data_hist[i];
      var node = h[antidirection];
      var d = {};
      var e={num_errors:0};
      for (var j in this.data_queue) {
        if (this.data_queue[j][antidirection]==node) {
          d = this.data_queue[j];
          break;
        }
      }
      for (var j in this.data_error) {
        if (this.data_error[j][antidirection]==node) {
          e = this.data_error[j];
        }
      }
      this.sum_hist(h);
      var rate = PHEDEX.Util.format.bytes(this.hist_speed(h))+'/s';
      var qual = PHEDEX.Util.format['%'](h.quality);
      var done = PHEDEX.Util.format.filesBytes(h.done_files,h.done_bytes);
      var queue = PHEDEX.Util.format.filesBytes(this.sum_queue_files(d.transfer_queue),this.sum_queue_bytes(d.transfer_queue));
      var dlist = PHEDEX.Util.makeInlineDiv({width:width,fields:[
	  {text:node,width:200,class:'align-left'},
          {text:rate,width:100},
	  {text:qual,width:100},
	  {text:done,width:200},
	  {text:queue,width:200},
          {text:e.num_errors,width:100}
	]});
      var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, root);

//    Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level
      tNode.payload = { call: 'TransferQueueBlocks', obj: this , args: {}, callback: PHEDEX.Widget.TransferQueueBlock.Treeview_callback }; // so I can use this in the callback
      if (this.direction=='to') {
        tNode.payload.args.from = node;
        tNode.payload.args.to = this.site;
      } else {
        tNode.payload.args.from = node;
        tNode.payload.args.to = this.site;
      }
    }
    that.tree.render(); //?
//  Place the focus on the second node
    that.tree.root.children[1].focus();
  }

  that.sum_hist=function(h) {
    h.done_bytes   = h.done_files =
    h.fail_bytes   = h.fail_files =
    h.expire_bytes = h.expire_files =
    h.quality = h.rate = h.binwidth = 0;
    for (var i in h.transfer)
    {
      h.done_bytes   += parseInt(h.transfer[i].done_bytes);
      h.done_files   += parseInt(h.transfer[i].done_files);
      h.fail_bytes   += parseInt(h.transfer[i].fail_bytes);
      h.fail_files   += parseInt(h.transfer[i].fail_files);
      h.expire_bytes += parseInt(h.transfer[i].expire_bytes);
      h.expire_files += parseInt(h.transfer[i].expire_files);
      h.binwidth     += parseInt(h.transfer[i].binwidth);
      h.quality      += parseFloat(h.transfer[i].quality);
//       if ( isNaN(h.quality) ) { h.quality = 0; } // seems h.transfer[i].quality can be 'null', which gives Nan in parseFloat
    }
    if ( h.binwidth && h.transfer.length )
    {
      h.rate = h.done_bytes / (h.transfer.length*h.binwidth);
      h.quality /= h.transfer.length;
    }
  }
  that.buildChildren=function(div) {
    this.markChildren();
    if (this.direction=='to') var antidirection='from';
    else var antidirection='to';
    for (var i in this.data_hist) {
      var h = this.data_hist[i];
      var node = h[antidirection];
      var d = {};
      var e={num_errors:0};
      for (var j in this.data_queue) {
        if (this.data_queue[j][antidirection]==node) {
          d = this.data_queue[j];
          break;
        }
      }
      for (var j in this.data_error) {
        if (this.data_error[j][antidirection]==node) {
          e = this.data_error[j];
        }
      }
      var id = this.id+'_'+this.direction+'_'+node;
      var child = this.getChild(id);
      if (child) {
        child.data_queue=d['transfer_queue'];
        child.data_hist=h;
        child.data_error=e;
        child.marked=false;
        child.update();
      } else {
        var childdiv = document.createElement('div');
        childdiv.id = id;
        div.appendChild(childdiv);
        var childnode = new PHEDEX.Widget.LinkNode(node,this.direction,this,childdiv,d['transfer_queue'],h,e);
        this.children.push(childnode);
        childnode.update();
      }
    }
    this.removeMarkedChildren();
    if (this.children.length==0) {
      this.children_info_none.innerHTML='No children returned';
    } else {
      this.children_info_none.innerHTML='';
    }
  }

  that.sum_queue_files=function(q) {
    var fsum=0;
    for (var i in q) {
      fsum+= parseInt(q[i]['files']);
    }
    return fsum;
  }
  that.sum_queue_bytes=function(q) {
    var bsum=0;
    for (var i in q) {
      bsum+=parseInt(q[i]['bytes']);
    }
    return bsum;
  }
  that.hist_speed=function(h) {
    var sum_bytes = 0;
    for (var i in h.transfer) { sum_bytes += parseInt(h.transfer[i].done_bytes); }
    return parseInt(sum_bytes)/parseInt(h.transfer[0].binwidth);
  }

  that.build();
  return that;
}
