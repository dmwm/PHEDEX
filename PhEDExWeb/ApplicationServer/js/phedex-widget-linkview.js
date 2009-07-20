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
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+node,{
		width:width,
		height:300
	      });
  that.me=function() { return 'PHEDEX.Core.Widget.LinkView'; }
  that.node = node;
  var config = PHEDEX.Util.getConfig(divid);

  var branchDef1 = [
          {width:160,text:'Node',         className:'phedex-tree-node',       otherClasses:'align-left',  contextArgs:['Node','sort-alpha'] },
	  {width:120,text:'Done',         className:'phedex-tree-done',       otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
          {width:120,text:'Failed',       className:'phedex-tree-failed',     otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
          {width:120,text:'Expired',      className:'phedex-tree-expired',    otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
          {width: 70,text:'Rate',         className:'phedex-tree-rate',       otherClasses:'align-right', contextArgs:'sort-num', format:function(x){return PHEDEX.Util.format.bytes(x)+'/s';} },
	  {width: 70,text:'Quality',      className:'phedex-tree-quality',    otherClasses:'align-right', contextArgs:'sort-num', format:PHEDEX.Util.format['%'] },
	  {width:120,text:'Queued',       className:'phedex-tree-queue',      otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
	  {width: 70,text:'Link Errors',  className:'phedex-tree-error-total',otherClasses:'align-right', contextArgs:'sort-num' },
	  {width: 90,text:'Logged Errors',className:'phedex-tree-error-log',  otherClasses:'align-right', contextArgs:'sort-num', hideByDefault:true }
    ];
// using spanWrap for the block-name, I can (in principla):
// - locate the div with the block-name
// - locate the spanWrap child from it
// - compare their offsetHeights.
// - if the span offsetHeight is greater than the div, the word is truncated to fit!
  var branchDef2 = [
	  {width:600,text:'Block Name',  className:'phedex-tree-block-name',  otherClasses:'align-left',  contextArgs:['Block','sort-alpha'], format:PHEDEX.Util.format.spanWrap },
	  {width: 80,text:'Block ID',    className:'phedex-tree-block-id',    otherClasses:'align-right', contextArgs:['Block','sort-num'] },
	  {width: 80,text:'State',       className:'phedex-tree-state',       otherClasses:'phedex-tnode-auto-height' },
          {width: 80,text:'Priority',    className:'phedex-tree-priority',    otherClasses:'phedex-tnode-auto-height' },
          {width: 80,text:'Files',       className:'phedex-tree-block-files', otherClasses:'phedex-tnode-auto-height align-right' },
	  {width: 80,text:'Bytes',       className:'phedex-tree-block-bytes', otherClasses:'phedex-tnode-auto-height align-right' },
	  {width: 90,text:'Block Errors',className:'phedex-tree-block-errors',otherClasses:'align-right', contextArgs:'sort-num' }
    ];
  var branchDef3 = [
	  {width:600,text:'File Name',  className:'phedex-tree-file-name',  otherClasses:'align-left',  contextArgs:['File','sort-alpha'], format:PHEDEX.Util.format.spanWrap },
	  {width: 80,text:'File ID',    className:'phedex-tree-file-id',    otherClasses:'align-right', contextArgs:['File','sort-num'] },
	  {width: 80,text:'Bytes',      className:'phedex-tree-file-bytes', otherClasses:'align-right', contextArgs:'sort-bytes', format:PHEDEX.Util.format.bytes },
	  {width: 90,text:'File Errors',className:'phedex-tree-file-errors',otherClasses:'align-right', contextArgs:'sort-num' },
          {width:140,text:'Checksum',   className:'phedex-tree-file-cksum', otherClasses:'align-right', hideByDefault:true }
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
            { format:branchDef2, payload:block.payload },
            [ block.name, block.id, state, priority, files, bytes, block.num_errors ],
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
                {format:branchDef3},
                [ file.name, file.id, file.bytes, num_errors, file.checksum ],
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
    YAHOO.util.Dom.insertBefore(button_span,that.dom.param.firstChild);
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
    YAHOO.util.Dom.insertBefore(document.createTextNode(this.node),that.dom.param.firstChild);

    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      var text = oMenuItem.cfg.getProperty("text");
      YAHOO.log('onSelectedMenuItemChange: new value: '+text,'info','Widget.LinkView');
      this.set("label", text);
    };
    changeDirectionButton.on("selectedMenuItemChange", onSelectedMenuItemChange);
    timeSelectButton.on(     "selectedMenuItemChange", onSelectedMenuItemChange);

    var root = that.headerTree.getRoot();
    var htNode  = that.addNode( { width:width, format:branchDef1, name:'Link'  }, null, root );    htNode.expand();
    var htNode1 = that.addNode( {              format:branchDef2, name:'Block' }, null, htNode );  htNode1.expand();
    var htNode2 = that.addNode( {              format:branchDef3, name:'File'  }, null, htNode1 ); htNode2.expand();
    htNode2.isLeaf = true;
    that.headerTree.render();
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
      var done   = { files:PHEDEX.Util.sumArrayField(h.transfer,'done_files'), bytes:done_bytes };
      var rate   = done_bytes/parseInt(h.transfer[0].binwidth);
      var fail   = { files:PHEDEX.Util.sumArrayField(h.transfer,'fail_files'),   bytes:PHEDEX.Util.sumArrayField(h.transfer,'fail_bytes')   };
      var expire = { files:PHEDEX.Util.sumArrayField(h.transfer,'expire_files'), bytes:PHEDEX.Util.sumArrayField(h.transfer,'expire_bytes') };
      var queue  = { files:PHEDEX.Util.sumArrayField(d.transfer_queue,'files'),  bytes:PHEDEX.Util.sumArrayField(d.transfer_queue,'bytes')  };

//    Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level.
//    I did see a better way to do this in the YUI docs, but will find that later...
//    populate the payload with everything that might be useful, so I don't need widget-specific knowledge in the parent
//    payload.args is for the data-service call, payload.opts is for the callback to drive the next stage of processing
      var payload = { call:'TransferQueueBlocks', obj:this , args:{}, opts:{}, data:{}, callback:that.callback_Treeview };
      payload.args.from = h.from;
      payload.args.to   = h.to;
      payload.args.binwidth = h.transfer[0].binwidth;
      payload.opts.node = h[antidirection];
      payload.opts.direction = that.direction;
      payload.data.errors    = e.block;
      var link_errors = PHEDEX.Util.sumArrayField(e.block,'num_errors');
      that.addNode(
        { format:branchDef1, payload:payload },
        [ node,done,fail,expire,rate,quality,queue,link_errors,e.num_errors ]
      );
    }
    that.tree.render();
  }

  that.applyFilter=function() { // Apply the filter to the data
    var args = that.filter.args;
// debugger;
// cheat, until I know how to do this properly...
  that.filter.count++;
  }
  that.fillFilter = function(div) { // Create the filter-form in the div allocated
    var cfg = [
		{type:'input', name:'phedex-tree-node',    value:'T.*', text:'Node-name (simple regex)' },
// 		{type:'input', name:'phedex-tree-done',    value:'0',   text:'Files-done (int, min)' },
// 		{type:'input', name:'phedex-tree-failed',  value:'0',   text:'Files-failed (int, min)' },
// 		{type:'input', name:'phedex-tree-expired', value:'0',   text:'Files-expired (int, min)' },
// 		{type:'input', name:'phedex-tree-rate',    value:'0',   text:'Transfer-rate (MB/sec)' },
		{type:'input', name:'phedex-tree-quality', value:'0',   text:'Transfer-quality (pct)' },
// 		{type:'input', name:'phedex-tree-queued',  value:'0',   text:'Files-queued (int, min)' }
	      ];
    for (var i in cfg) {
      var el = document.createElement('div');
      var input = document.createElement(cfg[i].type);
      input.setAttribute('type',cfg[i].text);
      input.setAttribute('id','phedex_filter_field_'+PHEDEX.Util.Sequence());
      input.setAttribute('class','phedex-filter-elem');
      input.setAttribute('name',cfg[i].name);
      input.setAttribute('value',cfg[i].value);
      el.appendChild(input);
      el.appendChild(document.createTextNode(cfg[i].text));
      div.appendChild(el);
    }
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
  that.buildTree(that.dom.content);
  that.buildExtra(that.dom.extra);
  that.buildContextMenu();
  that.build();
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Links',function(args,opts,el) { PHEDEX.Widget.LinkView(opts.node).update(); });
YAHOO.log('loaded...','info','Widget.LinkView');
