// instantiate the PHEDEX.Widget.TransfersNode namespace
PHEDEX.namespace('Widget.TransfersNode','Widget.TransferQueueBlock','Widget.TransferQueueFiles');

// This is for dynamic data-loading into a treeview. The callback is called with a treeview-node as the argument, by the YUI
// toolkit the node has a 'payload' hash which we create when we build the tree, it contains the necessary information to allow
// the callback to know which data-items to pick up and insert in the tree.
//
// The callback has to know how to construct payloads for child-nodes, which is not necessarily what we want. It would be
// nice if payloads for child-nodes could be constructed from knowledge of the data, rather than knowledge of the tree, but
// I'm not sure if that makes sense
PHEDEX.Widget.TransferQueueBlock.callback_Treeview=function(node) {
  var link = PHEDEX.namespace('PHEDEX.Data.TransferQueueBlocks.'+node.payload.args.from+'.'+node.payload.args.to);

  for (var i in link.transfer_queue )
  {
    var tq = link.transfer_queue[i];
    for (var j in tq.block)
    {
      var block = tq.block[j];
      var text = block.name+" priority:"+tq.priority+" state:"+tq.state;
      var dlist = PHEDEX.Util.makeInlineDiv({className:'treeview-node',fields:[
	  {text:block.name,                        className:'phedex-tnode-field phedex-tree-block-name align-left'},
          {text:'Priority='+tq.priority, width:130,className:'phedex-tnode-field phedex-tree-priority'},
	  {text:'State='+tq.state,       width:180,className:'phedex-tnode-field phedex-tree-state'}
	]});
      var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, node);

      var dlist1 = PHEDEX.Util.makeInlineDiv({width:300,className:'treeview-node',fields:[
	  {text:'ID='+block.id,       width:100,className:'phedex-tnode-field phedex-tree-block-id'},
          {text:'Files='+block.files, width:80,className:'phedex-tnode-field phedex-tree-block-files'},
	  {text:'Bytes='+PHEDEX.Util.format.bytes(block.bytes),width:100,className:'phedex-tnode-field phedex-tree-block-bytes'}
	]});
      var tNode1 = new YAHOO.widget.TextNode({label: dlist1.innerHTML, expanded: false}, tNode);
      tNode1.payload = { call:'TransferQueueFiles', obj:node.payload.obj, args:{}, callback:PHEDEX.Widget.TransferQueueFiles.callback_Treeview }; // so I can use this in the callback
      tNode1.payload.args = node.payload.args;
      tNode1.payload.opts = node.payload.opts;
      tNode1.payload.args.block = block.name;
    }
  }
}

// Treeview callback for the QueueFiles branches. These have no children, so do not construct payloads.
PHEDEX.Widget.TransferQueueFiles.callback_Treeview=function(node) {
  var link = PHEDEX.namespace('PHEDEX.Data.TransferQueueFiles.'+node.payload.args['from']+'.'+node.payload.args['to']);
  for (var block_name in link.byName )
  {
    var block = link.byName[block_name];
    for (var k in block.file)
    {
      var file = block.file[k];
      var dlist = PHEDEX.Util.makeInlineDiv({className:'treeview-node',fields:[
	  {text:file.name,                        className:'phedex-tnode-field phedex-tree-file-name align-left'},
	  {text:'ID='+file.id,          width:100,className:'phedex-tnode-field phedex-tree-file-id'},
          {text:'Cksum='+file.checksum, width:180,className:'phedex-tnode-field phedex-tree-file-cksum'},
	  {text:'Bytes='+PHEDEX.Util.format.bytes(file.bytes),width:100,className:'phedex-tnode-field phedex-tree-file-bytes'}
	]});
      var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, node);
//       var text = file.name+" id:"+file.id+" checksum:"+file.checksum+" bytes:"+PHEDEX.Util.format.bytes(file.bytes);
//       var tNode = new YAHOO.widget.TextNode({label: text, expanded: false}, node);
      tNode.isLeaf = true;
    }
  }
}

PHEDEX.Page.Widget.TransfersNode=function(divid) {
  var node = document.getElementById(divid+'_select').value;
  xfer_node = new PHEDEX.Widget.TransfersNode(node,divid);
  xfer_node.update();
}

PHEDEX.Widget.TransfersNode=function(node,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var width = 1000;
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+node,null,{
		width:width,
		height:300
	      });
  that.me=function() { return 'PHEDEX.Core.Widget.TransfersNode'; }
  that.node = node;
  var config = PHEDEX.Util.getConfig(divid);

// Build the options for the pull-down menus.
// 1. extract the default option from the configuration, or provide one if none given
// 2. build an array of items to go into the menu-list
// 3. create the callback function which is to be assigned to the menu-list items
// 4. build the menu-list, identifying which option corresponds to the selected default
//    N.B. I do not protect against failure to identify the correct default
// 5. The menu itself is created later, when the header is being built. The selected-value is used then, so must be stored in
//    the object, not in a local-scope variable.
  that.time=config.opts.time || '6';
  var timeselect_opts = config.opts.timeselect || { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week' };
  var changeTimebin = function(e) {
    if ( that.time == this.value ) { return; }
    that.time = this.value;
    that.deleteBodyContents();
    that.update();
  }
  var timeSelectMenu=[];
  that.timebin_selected='';
  for (var i in timeselect_opts)
  {
    if ( that.time == i ) { that.timebin_selected=timeselect_opts[i]; }
    timeSelectMenu[i] = { text: timeselect_opts[i], value:i, onclick: { fn: changeTimebin} };
  }

// rinse and repeat for the direction menu
  var direction_name=config.opts.direction || 'to';
  that.directions= [
      { key:'to',   text:'Incoming Links' },
      { key:'from', text:'Outgoing Links' }
    ];
  var changeDirection = function(e) {
    if ( that.direction == this.value ) { return; }
    that.direction = this.value;
    that.deleteBodyContents();
    that.update();
  }
  var changeDirectionMenu=[];
  for (var i in that.directions)
  {
    that.directions[i].value = i;
    if ( direction_name == that.directions[i].key ) { that.direction = i; }
    changeDirectionMenu[i] = { text: that.directions[i].text, value:i, onclick: { fn: changeDirection } };
  }
// A few utility functions, because the 'direction' is a numeric value in some places, (to|from) in others, and a long string again elsewhere
  that.direction_key=function()  { return that.directions[that.direction].key; }
  that.direction_text=function() { return that.directions[that.direction].text; }
  that.anti_direction_key=function() { return that.directions[1-that.direction].key; }

  that.buildHeader=function(div) {
// Create the menu buttons. I create them inside a dedicated span so that they will be rendered on the left, before anything inserted by the
// core widgets. 
    var button_span = document.createElement('span');
    div.appendChild(button_span);
    var timeSelectButton = new YAHOO.widget.Button(
	{ type: "menu",
	  label: that.timebin_selected,
	  name: "timeSelect",
	  menu: timeSelectMenu,
	  container: button_span
	});
    var changeDirectionButton = new YAHOO.widget.Button(
	{ type: "menu",
	  label: that.direction_text(),
	  name: "changeDirection",
	  menu: changeDirectionMenu,
	  container: button_span
	});

    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      var text = oMenuItem.cfg.getProperty("text");
      YAHOO.log('onSelectedMenuItemChange: new value: '+text,'info','Core.TransfersNode');
      this.set("label", text);
    };
    changeDirectionButton.on("selectedMenuItemChange", onSelectedMenuItemChange);
    timeSelectButton.on(     "selectedMenuItemChange", onSelectedMenuItemChange);

    var title = document.createElement('span');
    title.id = div.id+'_title';
    div.appendChild(title);
    that.title = title;
  }

  that.fillHeader=function(div) {
    this.title.innerHTML=this.node;
  }

  that.deleteBodyContents=function(div) {
//  In this case, I don't need the div, I can just operate on the tree object and null my data fields
    var node;
    while ( node = that.tree.root.children[1] ) { that.tree.removeNode(node); }
    that.tree.render();
    that.data_hist = null;
    that.data_queue = null;
    that.data_error = null;
  }

  that.fillBody=function(div) {
    var root = this.tree.getRoot();
    that.textNodeMap = [];
    var antidirection=that.anti_direction_key();
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

      var done_bytes = PHEDEX.Util.sumArrayField(h.transfer,'done_bytes');
      var quality    = PHEDEX.Util.sumArrayField(h.transfer,'quality',parseFloat);
      if ( isNaN(quality) ) { quality = 0; } // seems h.transfer[i].quality can be 'null', which gives Nan in parseFloat
      quality /= h.transfer.length;
      var rate = PHEDEX.Util.format.bytes(done_bytes/parseInt(h.transfer[0].binwidth))+'/s';
      var qual = PHEDEX.Util.format['%'](quality);
      var done = PHEDEX.Util.format.filesBytes(PHEDEX.Util.sumArrayField(h.transfer,'done_files'),done_bytes);
      var queue = PHEDEX.Util.format.filesBytes(PHEDEX.Util.sumArrayField(d.transfer_queue,'files'),PHEDEX.Util.sumArrayField(d.transfer_queue,'bytes'));
      var dlist = PHEDEX.Util.makeInlineDiv({width:width,fields:[
	  {text:node,        width:200,className:'phedex-tnode-field phedex-tree-node align-left'},
          {text:rate,        width:100,className:'phedex-tnode-field phedex-tree-rate'},
	  {text:qual,        width:100,className:'phedex-tnode-field phedex-tree-quality'},
	  {text:done,        width:200,className:'phedex-tnode-field phedex-tree-done'},
	  {text:queue,       width:200,className:'phedex-tnode-field phedex-tree-queue'},
          {text:e.num_errors,width:100,className:'phedex-tnode-field phedex-tree-errors'}
	]});
      var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, root);
      that.textNodeMap[tNode.labelElId] = tNode;
//    Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level. I did see a better way to do this in the YUI docs,
//    but will find that later...
//    populate the payload with everything that might be useful, so I don't need widget-specific knowledge in the parent
//    payload.args is for the data-service call, payload.opts is for the callback to drive the next stage of processing
      tNode.payload = { call:'TransferQueueBlocks', obj:this , args:{}, opts:{}, callback:PHEDEX.Widget.TransferQueueBlock.callback_Treeview }; // so I can use this in the callback
      tNode.payload.args.from = h.from;
      tNode.payload.args.to   = h.to;
      tNode.payload.opts.selected_node = h[antidirection];
      tNode.payload.opts.direction = that.direction;
    }
    that.tree.render();
//  Place the focus on the second node. The first is the 'title' node
    that.tree.root.children[1].focus();
  }

  that.update=function() {
    var args={};
    args[that.direction_key()]=this.node;//apparently {this.direction:this.node} is invalid
    args['binwidth']=parseInt(this.time)*3600;
    PHEDEX.Datasvc.TransferQueueStats(args,this,this.receive_QueueStats);
    PHEDEX.Datasvc.TransferHistory   (args,this,this.receive_History);
    PHEDEX.Datasvc.ErrorLogSummary   (args,this,this.receive_ErrorStats);
    this.startLoading();
  }
  that.receive_QueueStats=function(result,obj) {
    that.data_queue = PHEDEX.Data.TransferQueueStats[obj.direction_key()][obj.node];
    that.maybe_populate();
  }
  that.receive_History=function(result,obj) {
    that.data_hist = PHEDEX.Data.TransferHistory[obj.direction_key()][obj.node];
    that.maybe_populate();
  }
  that.receive_ErrorStats=function(result,obj) {
    that.data_error = PHEDEX.Data.ErrorLogSummary[obj.direction_key()][obj.node];
    that.maybe_populate();
  }
  that.maybe_populate=function() {
    if ( that.data_hist && that.data_error && that.data_queue )
    {
      this.finishLoading();
      this.populate();
    }
  }
  that.isDynamic = true; // enable dynamic loading of data
  that.buildTree(that.div_content,
    PHEDEX.Util.makeInlineDiv({width:width,className:'treeview-header',fields:[
	  {text:'Node',   width:200, className:'align-left'},
          {text:'Rate',   width:100},
	  {text:'Quality',width:100},
	  {text:'Done',   width:200},
	  {text:'Queued', width:200},
          {text:'Errors', width:100}
	]})
  );
  that.buildContextMenu('Node');
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Links',function(args,opts,el) { PHEDEX.Widget.TransfersNode(opts.selected_node).update(); });
YAHOO.log('loaded...','info','Core.TransfersNode');
