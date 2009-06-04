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
//       that.textNodeMap[tNode1.labelElId] = tNode1;
      tNode1.payload = { call:'TransferQueueFiles', obj:node.payload.obj, args:{}, callback:PHEDEX.Widget.TransferQueueFiles.callback_Treeview }; // so I can use this in the callback
      tNode1.payload.args.from  = node.payload.args.from;
      tNode1.payload.args.to    = node.payload.args.to;
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
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+site,null,{
		width:width,
		height:300
	      });
  that.me=function() { return 'PHEDEX.Core.Widget.TransfersNode'; }
  that.site = site;
  var config = PHEDEX.Util.getConfig(divid);
  that.time=config.opts.time || '6';
  var direction_name=config.opts.direction || 'to';
  that.directions= [
      { key:'to',   text:'Incoming Links' },
      { key:'from', text:'Outgoing Links' }
    ];
  for (var i in that.directions)
  {
    that.directions[i].value = i;
    if ( direction_name == that.directions[i].key ) { that.direction = i; }
  }
  that.direction_key=function()  { return that.directions[that.direction].key; }
  that.direction_text=function() { return that.directions[that.direction].text; }

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
    if ( that.direction == this.value ) { return; }
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
//     YAHOO.util.Event.addListener(timeselect, "change", changeTimebin);
//     div.appendChild(timeselect);
    var changeDirectionMenu=[];
    for (var i in that.directions)
    {
      changeDirectionMenu[i] = { text: that.directions[i].text, value:i, onclick: { fn: changeDirection } };
    }
    var changeDirectionButton = new YAHOO.widget.Button({ type: "menu", label: that.direction_text(), name: "changeDirection", menu: changeDirectionMenu, container: div });

    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      this.set("label", oMenuItem.cfg.getProperty("text"));
    };
    var onMenuRender = function (type, args, button) {
      var index;
      button.set("selectedMenuItem", this.getItem(index));
    };
    var onFormSubmit = function (event, button) {
      var oMenuItem = button.get("selectedMenuItem"),
	UA = YAHOO.env.ua,
	oEvent,
	oMenu;

      if (!oMenuItem) {
	YAHOO.util.Event.preventDefault(event);
	oMenu = button.getMenu();
	oMenu.addItems(oMenu.itemData);
	oMenu.subscribe("render", function () {
	  var bSubmitForm;
	  if (UA.ie) {
	    bSubmitForm = this.fireEvent("onsubmit");
	  }
	  else {  // Gecko, Opera, and Safari
	    oEvent = document.createEvent("HTMLEvents");
	    oEvent.initEvent("submit", true, true);
	    bSubmitForm = this.dispatchEvent(oEvent);
	  }
//	In IE and Safari, dispatching a "submit" event to a form
//	WILL cause the form's "submit" event to fire, but WILL
//	NOT submit the form.  Therefore, we need to call the
//	"submit" method as well.
	  if ((UA.ie || UA.webkit) && bSubmitForm) {
	    this.submit();
	  }
	}, this, true);
	oMenu.render(oMenu.cfg.getProperty("container"));
      }
  };

    changeDirectionButton.on("selectedMenuItemChange", onSelectedMenuItemChange);
    changeDirectionButton.on("appendTo", function () {
	var oMenu = this.getMenu();
	oMenu.subscribe("render", onMenuRender, this);
	YAHOO.util.Event.on(this.getForm(), "submit", onFormSubmit, this);
    });

    var title = document.createElement('span');
    title.id = div.id+'_title';
    div.appendChild(title);
    that.title = title;
  }
  that.fillHeader=function(div) {
    this.title.innerHTML=this.site;
  }
//   that.buildBody=function(div) {
//     var dlist = PHEDEX.Util.makeInlineDiv({width:width,class:'treeview-header',fields:[
// 	  {text:'Node',width:200,class:'align-left'},
//           {text:'Rate',width:100},
// 	  {text:'Quality',width:100},
// 	  {text:'Done',width:200},
// 	  {text:'Queued',width:200},
//           {text:'Errors',width:100}
// 	]});
//     this.tree = new YAHOO.widget.TreeView(that.div_content);
//     var currentIconMode=0;
// // turn dynamic loading on for entire tree:
//     this.tree.setDynamicLoad(PHEDEX.Util.loadTreeNodeData, currentIconMode);
//     var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, this.tree.getRoot());
//     tNode.isLeaf = true;
//   }

  that.update=function() {
    var args={};
    args[that.direction_key()]=this.site;//apparently {this.direction:this.site} is invalid
    args['binwidth']=parseInt(this.time)*3600;
    PHEDEX.Datasvc.TransferQueueStats(args,this,this.receive_QueueStats);
    PHEDEX.Datasvc.TransferHistory   (args,this,this.receive_History);
    PHEDEX.Datasvc.ErrorLogSummary   (args,this,this.receive_ErrorStats);
    this.startLoading();
  }
  that.receive_QueueStats=function(result,obj) {
    that.data_queue = PHEDEX.Data.TransferQueueStats[obj.direction_key()][obj.site];
    that.maybe_populate();
  }
  that.receive_History=function(result,obj) {
    that.data_hist = PHEDEX.Data.TransferHistory[obj.direction_key()][obj.site];
    that.maybe_populate();
  }
  that.receive_ErrorStats=function(result,obj) {
    that.data_error = PHEDEX.Data.ErrorLogSummary[obj.direction_key()][obj.site];
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
    that.textNodeMap = [];
    var antidirection='to';
    if (this.direction_key() == 'to' ) { antidirection='from'; }
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
      that.textNodeMap[tNode.labelElId] = tNode;

//    Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level
      tNode.payload = { call: 'TransferQueueBlocks', obj: this , args: {}, callback: PHEDEX.Widget.TransferQueueBlock.callback_Treeview }; // so I can use this in the callback
      if (this.direction_key()=='to') {
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

//   that.onContextMenuClick = function(p_sType, p_aArgs, p_TreeView) {
// //  Based on http://developer.yahoo.com/yui/examples/menu/treeviewcontextmenu.html
//     var oTarget = this.contextEventTarget,
// 	Dom = YAHOO.util.Dom,
// 	oCurrentTextNode;
// 
//     var oTextNode = Dom.hasClass(oTarget, "ygtvlabel") ?
// 	oTarget : Dom.getAncestorByClassName(oTarget, "ygtvlabel");
// 
//     if (oTextNode) {
//       var tNodeMap  = that.textNodeMap;
//       oCurrentTextNode = that.textNodeMap[oTextNode.id];
//     }
//     else {
// // Cancel the display of the ContextMenu instance.
//       this.cancel();
//       return;
//     }
//     if ( oCurrentTextNode )
//     {
//       var direction = oCurrentTextNode.payload.obj.direction;
//       if ( direction == 'to' ) { direction = 'from'; } // point the other way...
//       else		     { direction = 'to'; }
//       var selected_site = oCurrentTextNode.payload.args[direction];
//       YAHOO.log('PHEDEX.Widget.TransferNode: ContextMenu: '+direction+' '+selected_site);
//       var task = p_aArgs[1];
//       if (task) {
// 	      this.payload[task.index](selected_site);
//       }
//     }
//   }

  that.postPopulate = function() {
    YAHOO.log('PHEDEX.Widget.TransfersNode: postPopulate');
//     that.contextMenu = PHEDEX.Core.ContextMenu.Create('Links',{trigger:that.div_content});
//     PHEDEX.Core.ContextMenu.Build(that.contextMenu,'Node');
//     that.contextMenu.render(that.div_content);
//     that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.tree.getEl());
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
      if ( isNaN(h.quality) ) { h.quality = 0; } // seems h.transfer[i].quality can be 'null', which gives Nan in parseFloat
    }
    if ( h.binwidth && h.transfer.length )
    {
      h.rate = h.done_bytes / (h.transfer.length*h.binwidth);
      h.quality /= h.transfer.length;
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

  that.buildTree(that.div_content,
    PHEDEX.Util.makeInlineDiv({width:width,class:'treeview-header',fields:[
	  {text:'Node',width:200,class:'align-left'},
          {text:'Rate',width:100},
	  {text:'Quality',width:100},
	  {text:'Done',width:200},
	  {text:'Queued',width:200},
          {text:'Errors',width:100}
	]})
  );
  that.build();
//   that.onPopulateComplete.subscribe(that.postPopulate);
  return that;
}

// What can I respond to...?
PHEDEX.Core.ContextMenu.Add('Node','Show Links',function(args) { PHEDEX.Widget.TransfersNode(args.selected_site).update(); });
