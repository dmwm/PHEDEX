// instantiate the PHEDEX.Widget.RequestView namespace
PHEDEX.namespace('Widget.RequestView');

PHEDEX.Page.Widget.Requests=function(divid) {
  var request = document.getElementById(divid+'_select').value;
  req_node = new PHEDEX.Widget.RequestView(request,divid);
  req_node.update();
}

PHEDEX.Widget.RequestView = function(request,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+request,null,
		{
		width:800,
		height:200,
		minwidth:400,
		minheight:80
		});
  that.request=request;
  that.fillBody = function(div) {
    var rNode, tNode, tNode1;
    var root = this.tree.getRoot();
    that.textNodeMap = [];

    var dlist = PHEDEX.Util.makeInlineDiv({className:'treeview-node',fields:[
	  {text:this.data.id,                    width:130,className:'phedex-tnode-field phedex-tree-ID'},
          {text:this.data.requested_by.username, width:130,className:'phedex-tnode-field phedex-tree-requestor'},
	  {text:PHEDEX.Util.format.filesBytes(this.data.data.files,this.data.data.files), width:130,className:'phedex-tnode-field phedex-tree-volume'},
	  {text:this.approval(),    width:130,className:'phedex-tnode-field phedex-tree-status'},
	  {text:this.classify(),    width:130,className:'phedex-tnode-field phedex-tree-xfertype'}
	]});
    tNode = new YAHOO.widget.TextNode(dlist.innerHTML, root, false);
    that.textNodeMap[tNode.labelElId] = tNode;
    tNode.isLeaf = true;
    rNode = new YAHOO.widget.TextNode({label: "Request status", expanded: false}, root);
    that.textNodeMap[rNode.labelElId] = rNode;
    tNode = new YAHOO.widget.TextNode(this.data.comments, rNode, false);
    that.textNodeMap[tNode.labelElId] = tNode;
    tNode.isLeaf = true;

    tNode = new YAHOO.widget.TextNode({label: "Requestor details", expanded: false}, rNode);
    that.textNodeMap[tNode.labelElId] = tNode;

    tNode1 = new YAHOO.widget.TextNode('Name: '+this.data.requested_by.name, tNode, false);
    that.textNodeMap[tNode1.labelElId] = tNode1; tNode1.isLeaf = true;
    tNode1 = new YAHOO.widget.TextNode('Date: '+PHEDEX.Util.format.date(this.data.time_create), tNode, false);
    that.textNodeMap[tNode1.labelElId] = tNode1; tNode1.isLeaf = true;
    tNode1 = new YAHOO.widget.TextNode('DN: '+this.data.requested_by.dn, tNode, false);
    that.textNodeMap[tNode1.labelElId] = tNode1; tNode1.isLeaf = true;
    tNode1 = new YAHOO.widget.TextNode('Host: '+this.data.requested_by.host, tNode, false);
    that.textNodeMap[tNode1.labelElId] = tNode1; tNode1.isLeaf = true;
    tNode1 = new YAHOO.widget.TextNode('UserAgent: '+this.data.requested_by.agent, tNode, false);
    that.textNodeMap[tNode1.labelElId] = tNode1; tNode1.isLeaf = true;

    tNode = new YAHOO.widget.TextNode({label: this.approval(), expanded: false}, rNode);
    var destinationDetail="";
    for (var i in this.data.destinations.node) {
      var d = this.data.destinations.node[i];;
      if ( d.decided_by.decision == 'y' ) { destinationDetail = 'Approved'; }
      else                                { destinationDetail = 'Rejected'; }

     dlist = PHEDEX.Util.makeInlineDiv({className:'treeview-node',fields:[
	  {text:d.name,           width:130,className:'phedex-tnode-field phedex-tree-node'},
          {text:destinationDetail,width:100,className:'phedex-tnode-field phedex-tree-decision'}
	]});
      tNode1 = new YAHOO.widget.TextNode(dlist.innerHTML, tNode, false);
      that.textNodeMap[tNode1.labelElId] = tNode1;

      tNode2 = new YAHOO.widget.TextNode('Name: '+d.decided_by.name, tNode1, false);
      that.textNodeMap[tNode2.labelElId] = tNode2; tNode2.isLeaf = true;
      tNode2 = new YAHOO.widget.TextNode('Date: '+PHEDEX.Util.format.date(d.decided_by.time_decided), tNode1, false);
      that.textNodeMap[tNode2.labelElId] = tNode2; tNode2.isLeaf = true;
      tNode2 = new YAHOO.widget.TextNode('DN: '+d.decided_by.dn, tNode1, false);
      that.textNodeMap[tNode2.labelElId] = tNode2; tNode2.isLeaf = true;
      tNode2 = new YAHOO.widget.TextNode('Host: '+d.decided_by.host, tNode1, false);
      that.textNodeMap[tNode2.labelElId] = tNode2; tNode2.isLeaf = true;
      tNode2 = new YAHOO.widget.TextNode('UserAgent: '+d.decided_by.agent, tNode1, false);
      that.textNodeMap[tNode2.labelElId] = tNode2; tNode2.isLeaf = true;
    }

    tNode = new YAHOO.widget.TextNode({label: "Block details", expanded: false}, root);
    that.textNodeMap[tNode.labelElId] = tNode;
    for (var i in this.data.data.dbs.dataset) {
      var d = this.data.data.dbs.dataset[i];
      var b = new YAHOO.widget.TextNode({label: d.name, expanded: false}, tNode);
      that.textNodeMap[b.labelElId] = b;
      var t = " BlockID: "+d.id+", "+d.files+" files / "+PHEDEX.Util.format['bytes'](d.bytes);
      tNode1 = new YAHOO.widget.TextNode(t, b, false);
//       tNode1.payload = { call:'TransferQueueFiles', obj:that, args:{}, callback:PHEDEX.Widget.TransferQueueFiles.callback_Treeview }; // so I can use this in the callback
//       tNode1.payload.args = {};//node.payload.args;
//       tNode1.payload.opts = {};//node.payload.opts;
//       tNode1.payload.args.block = b.name;
      tNode1.isLeaf = true;
      that.textNodeMap[tNode1.labelElId] = tNode1;
    }
    that.tree.render();
  }
  that.approval=function() {
    var dest_approve=0;
    var n_dest=this.data.destinations.node.length;
    for (var i in this.data.destinations.node) {
      if (this.data.destinations.node[i].decided_by.decision=='y') {
        dest_approve+=1;
      }
    }

    if ( !n_dest ) { return "No destinations, is that possible?"; }
    if (dest_approve==n_dest )
    {
      if ( n_dest == 1 ) { return "Approved"; }
      else		 { return "Approved ("+n_dest+")"; }
    }
    return "Approved ("+dest_approve+"/"+n_dest+")";
  }
  that.classify=function() {
    var result='';
    if (this.data.custodial=='y') { result += 'custodial, '; }
    if (this.data.move=='y') { result += 'move, '; }
    if (this.data.static=='n') { result += 'dynamic, '; }
    result += this.data.priority+' priority';
    return result;
  }
  that.update=function() {
    PHEDEX.Datasvc.TransferRequests(this.request,this);
  }
  that.receive=function(result,obj) {
    that.data=PHEDEX.Data.TransferRequests[that.request];
    if (that.data) {
      that.populate();
    }
  }
  that.isDynamic = true; // enable dynamic loading of data
  that.buildTree(that.div_content,
      PHEDEX.Util.makeInlineDiv({className:'treeview-header',fields:[
	  {text:'ID',        width:130,className:'phedex-tnode-field phedex-tree-ID'},
          {text:'Requestor', width:130,className:'phedex-tnode-field phedex-tree-requestor'},
	  {text:'Volume',    width:130,className:'phedex-tnode-field phedex-tree-volume'},
	  {text:'Status',    width:130,className:'phedex-tnode-field phedex-tree-status'},
	  {text:'XferType',  width:130,className:'phedex-tnode-field phedex-tree-xfertype'}
	]})
    );
  that.build();
  that.buildContextMenu('Request');
  return that;
}
