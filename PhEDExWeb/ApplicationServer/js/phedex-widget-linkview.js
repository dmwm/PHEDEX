// instantiate the PHEDEX.Widget.LinkView namespace
PHEDEX.namespace('Widget.LinkView','Widget.TransferQueueBlock','Widget.TransferQueueFiles');

PHEDEX.Page.Widget.LinkView=function(divid) {
  var node = document.getElementById(divid+'_select').value;
  xfer_node = new PHEDEX.Widget.LinkView(node,divid);
  xfer_node.update();
}

PHEDEX.Widget.LinkView=function(node,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var width = 1000;
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+node,null,{
		width:width,
		height:300
	      });
  that.me=function() { return 'PHEDEX.Core.Widget.LinkView'; }
  that.node = node;
  var config = PHEDEX.Util.getConfig(divid);

  var linkHeader1 = [
          {width:160,text:'Node',         className:'phedex-tree-node',       otherClasses:'align-left',  contextArgs:['Node','sort-alpha'] },
	  {width:120,text:'Done',         className:'phedex-tree-done',       otherClasses:'align-right', contextArgs:'sort-num' },
          {width:120,text:'Failed',       className:'phedex-tree-failed',     otherClasses:'align-right', contextArgs:'sort-num' },
          {width:120,text:'Expired',      className:'phedex-tree-expired',    otherClasses:'align-right', contextArgs:'sort-num' },
          {width: 70,text:'Rate',         className:'phedex-tree-rate',       otherClasses:'align-right', contextArgs:'sort-num' },
	  {width: 70,text:'Quality',      className:'phedex-tree-quality',    otherClasses:'align-right', contextArgs:'sort-num' },
	  {width:120,text:'Queued',       className:'phedex-tree-queue',      otherClasses:'align-right', contextArgs:'sort-num' },
	  {width: 70,text:'Link Errors',  className:'phedex-tree-error-total',otherClasses:'align-right', contextArgs:'sort-num' },
	  {width: 90,text:'Logged Errors',className:'phedex-tree-error-log',hideByDefault:true}
    ];
  var linkHeader2 = [
	  {width:600,text:'Block Name',  className:'phedex-tree-block-name',  otherClasses:'align-left'},
	  {width: 80,text:'Block ID',    className:'phedex-tree-block-id'},
	  {width: 80,text:'State',       className:'phedex-tree-state',       otherClasses:'phedex-tnode-auto-height'},
          {width: 80,text:'Priority',    className:'phedex-tree-priority',    otherClasses:'phedex-tnode-auto-height'},
          {width: 80,text:'Files',       className:'phedex-tree-block-files', otherClasses:'phedex-tnode-auto-height align-right'},
	  {width: 80,text:'Bytes',       className:'phedex-tree-block-bytes', otherClasses:'phedex-tnode-auto-height align-right'},
	  {width: 90,text:'Block Errors',className:'phedex-tree-block-errors',otherClasses:'align-right'}
    ];
  var linkHeader3 = [
	  {width:600,text:'File Name',  className:'phedex-tree-file-name',  otherClasses:'align-left'},
	  {width: 80,text:'File ID',    className:'phedex-tree-file-id'},
	  {width: 80,text:'Bytes',      className:'phedex-tree-file-bytes', otherClasses:'align-right'},
	  {width: 90,text:'File Errors',className:'phedex-tree-file-errors',otherClasses:'align-right'},
          {width:140,text:'Checksum',   className:'phedex-tree-file-cksum', otherClasses:'align-right',hideByDefault:true}
    ];

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
    that.emptyBody();
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
    that.emptyBody();
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

// This is for dynamic data-loading into a treeview. The callback is called with a treeview-node as the argument.
// The node has a 'payload' hash which we create when we build the tree, it contains the necessary information to
// allow the callback to know which data-items to pick up and insert in the tree, once the data is loaded.
//
// This callback has to know how to construct payloads for child-nodes, which is not necessarily what we want. It would be
// nice if payloads for child-nodes could be constructed from knowledge of the data, rather than knowledge of the tree, but
// I'm not sure if that makes sense. Probably it doesn't
  that.callback_Treeview=function(node,result) {
    try {
      var link = result.link[0];
      var call = node.payload.call; // copy the value because of the dangers of shallow-copying in javascript
      if ( !link  ) { return; }
      if ( !link.transfer_queue ) { return; }
//    distinguish the type of node to build based on what the 'call' was that got me here. These 'if' clauses are too long for my liking...
      if ( call == 'TransferQueueBlocks' )
      {
	var errors = [];
	for (var k in node.payload.data.errors)
	{
	  var b = node.payload.data.errors[k];
	  errors[b.id] = { num_errors:b.num_errors, file:b.file };
	}
	var blocks = [];
	for (var i in link.transfer_queue )
	{
	  var tq = link.transfer_queue[i];
	  for (var j in tq.block)
	  {
	    var block;
	    block = tq.block[j];
	    if ( ! blocks[block.id] ) { blocks[block.id] = {id:block.id, name:block.name, queue:[]}; }
	    blocks[block.id].queue.push({state:tq.state, priority:tq.priority, files:block.files, bytes: block.bytes});

//	    Manual deep-copy of payload, prevents overwriting contents...
	    var payload = [];
	    payload.opts = {};
	    for (var l in node.payload.opts) { payload.opts[l] = node.payload.opts[l];  }
	    payload.data = {};
	    for (var l in node.payload.data) { payload.data[l] = node.payload.data[l];  }
	    payload.args = {};
            payload.args.from = node.payload.args.from;
            payload.args.to   = node.payload.args.to;
            payload.obj       = node.payload.obj;
            payload.callback  = node.payload.callback;

            payload.call = 'TransferQueueFiles';
	    payload.data = errors;
            payload.args.block = block.name;
	    blocks[block.id].payload = payload;
	    var num_errors = 0;
	    if ( errors[block.id] ) { num_errors = errors[block.id].num_errors; }
	    blocks[block.id].num_errors = num_errors;
          }
	}
	for (var i in blocks) {
	  var block = blocks[i];
	  var state = priority = files = bytes = '';
	  for (var j in block.queue) {
	    state    += block.queue[j].state+'<br/>';
	    priority += block.queue[j].priority+'<br/>';
	    files    += block.queue[j].files+'<br/>';
	    bytes    += PHEDEX.Util.format.bytes(block.queue[j].bytes)+'<br/>';
	  }
          var tNode = node.payload.obj.addNode(
            { format:linkHeader2, payload:block.payload },
            [ PHEDEX.Util.format.longString(block.name), block.id, state, priority, files, bytes, block.num_errors ],
	    node
          );
	}
      }
      else if ( call == 'TransferQueueFiles' )
      {
	for (var i in link.transfer_queue )
	{
	  var tq = link.transfer_queue[i];
	  for (var j in tq.block)
	  {
	    var block = tq.block[j];
	    var errors = [];
	    if (node.payload.data[block.id])
	    {
	      var files = node.payload.data[block.id].file;
	      for (var f in files)
	      {
		errors[files[f].id] = files[f].num_errors;
	      }
	    }
            for (var k in block.file)
            {
              var file = block.file[k];
	      var num_errors = errors[file.id] || 0;
              var tNode = node.payload.obj.addNode(
                {format:linkHeader3},
                [ PHEDEX.Util.format.longString(file.name), file.id, PHEDEX.Util.format.bytes(file.bytes), num_errors, file.checksum ],
	         node
               );
              tNode.isLeaf = true;
            }
          }
	}
      }
      else
      {
        var errstr = 'No action specified for handling callback data for "'+node.payload.callback+'"';
        YAHOO.log(errstr,'error','Widget.LinkView');
        throw new Error(errstr);
      }
    } catch(e) {
      YAHOO.log('Error of some sort in PHEDEX.Widget.LinkView.callback_Treeview ('+e+')','error','Widget.LinkView');
      var tNode = new YAHOO.widget.TextNode({label: 'Data-loading error, try again later...', expanded: false}, node);
      tNode.isLeaf = true;
    }
  }

  that.buildHeader=function(div) {
// Create the menu buttons. I create them inside a dedicated span so that they will be rendered on the left,
// before anything inserted by the core widgets.
    var button_span = document.createElement('span');
    YAHOO.util.Dom.insertBefore(button_span,that.span_param.firstChild);
    var changeDirectionButton = new YAHOO.widget.Button(
	{ type: "menu",
	  label: that.direction_text(),
	  name: "changeDirection",
	  menu: changeDirectionMenu,
	  container: button_span
	});
    var timeSelectButton = new YAHOO.widget.Button(
	{ type: "menu",
	  label: that.timebin_selected,
	  name: "timeSelect",
	  menu: timeSelectMenu,
	  container: button_span
	});
    YAHOO.util.Dom.insertBefore(document.createTextNode(this.node),that.span_param.firstChild);

    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      var text = oMenuItem.cfg.getProperty("text");
      YAHOO.log('onSelectedMenuItemChange: new value: '+text,'info','Widget.LinkView');
      this.set("label", text);
    };
    changeDirectionButton.on("selectedMenuItemChange", onSelectedMenuItemChange);
    timeSelectButton.on(     "selectedMenuItemChange", onSelectedMenuItemChange);
  }
  that.fillHeader=function(div) { }

  that.emptyBody=function(div) {
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
      var e = {num_errors:0};
      for (var j in this.data_queue) {
        if (this.data_queue[j][antidirection]==node) {
          d = this.data_queue[j];
          break;
        }
      }
      for (var j in this.data_error) {
        if (this.data_error[j][antidirection]==node) {
          e = this.data_error[j];
          break;
        }
      }

      var done_bytes = PHEDEX.Util.sumArrayField(h.transfer,'done_bytes');
      var quality    = PHEDEX.Util.sumArrayField(h.transfer,'quality',parseFloat);
      if ( isNaN(quality) ) { quality = 0; } // seems h.transfer[i].quality can be 'null', which gives Nan in parseFloat
      quality /= h.transfer.length;
      var rate   = PHEDEX.Util.format.bytes(done_bytes/parseInt(h.transfer[0].binwidth))+'/s';
      var qual   = PHEDEX.Util.format['%'](quality);
      var done   = PHEDEX.Util.format.filesBytes(PHEDEX.Util.sumArrayField(h.transfer,'done_files'),done_bytes);
      var fail   = PHEDEX.Util.format.filesBytes(
                      PHEDEX.Util.sumArrayField(h.transfer,'fail_files'),
                      PHEDEX.Util.sumArrayField(h.transfer,'fail_bytes')
                   );
      var expire = PHEDEX.Util.format.filesBytes(
                      PHEDEX.Util.sumArrayField(h.transfer,'expire_files'),
                      PHEDEX.Util.sumArrayField(h.transfer,'expire_bytes')
                   );
      var queue  = PHEDEX.Util.format.filesBytes(
                      PHEDEX.Util.sumArrayField(d.transfer_queue,'files'),
                      PHEDEX.Util.sumArrayField(d.transfer_queue,'bytes')
                   );

//    Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level.
//    I did see a better way to do this in the YUI docs, but will find that later...
//    populate the payload with everything that might be useful, so I don't need widget-specific knowledge in the parent
//    payload.args is for the data-service call, payload.opts is for the callback to drive the next stage of processing
      var payload = { call:'TransferQueueBlocks', obj:this , args:{}, opts:{}, data:{}, callback:that.callback_Treeview };
      payload.args.from = h.from;
      payload.args.to   = h.to;
      payload.args.binwidth = h.transfer[0].binwidth;
      payload.opts.selected_node = h[antidirection];
      payload.opts.direction = that.direction;
      payload.data.errors    = e.block;
      var link_errors = PHEDEX.Util.sumArrayField(e.block,'num_errors');
      that.addNode(
        { format:linkHeader1, payload:payload },
        [ node,done,fail,expire,rate,qual,queue,link_errors,e.num_errors ]
      );
    }
    that.tree.render();
  }

  that.receive=function(event,data) {
    var result   = data[0];
    var context  = data[1];
    if ( context.api == 'TransferQueueStats' ) { that.data_queue = result.link; }
    if ( context.api == 'TransferHistory' )    { that.data_hist  = result.link; }
    if ( context.api == 'ErrorLogSummary' )    { that.data_error = result.link; }
    if ( that.data_hist && that.data_error && that.data_queue )
    {
      that.finishLoading();
      that.populate();
    }
  }
  that.onDataReady.subscribe(that.receive);
  that.update=function() {
    var args={};
    args[that.direction_key()]=this.node;
    args['binwidth']=parseInt(this.time)*3600;
    PHEDEX.Datasvc.Call({api:'TransferQueueStats', args:args, success_event:that.onDataReady, failure_event:that.onDataFailed });
    PHEDEX.Datasvc.Call({api:'TransferHistory',    args:args, success_event:that.onDataReady, failure_event:that.onDataFailed });
    PHEDEX.Datasvc.Call({api:'ErrorLogSummary',    args:args, success_event:that.onDataReady, failure_event:that.onDataFailed });
    this.startLoading();
  }
  that.isDynamic = true; // enable dynamic loading of data
  that.buildTree(that.div_content);

  that.buildExtra(that.div_extra);
  var root = that.headerTree.getRoot();
  var htNode  = that.addNode( { width:width, format:linkHeader1, prefix:'Link'  }, null, root );    htNode.expand();
  var htNode1 = that.addNode( {              format:linkHeader2, prefix:'Block' }, null, htNode );  htNode1.expand();
  var htNode2 = that.addNode( {              format:linkHeader3, prefix:'File'  }, null, htNode1 ); htNode2.expand();
  htNode2.isLeaf = true;
  that.headerTree.render();

  that.buildContextMenu();
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Links',function(args,opts,el) { PHEDEX.Widget.LinkView(opts.selected_node).update(); });
YAHOO.log('loaded...','info','Widget.LinkView');