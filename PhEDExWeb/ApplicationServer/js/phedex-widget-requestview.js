// instantiate the PHEDEX.Widget.RequestView namespace
PHEDEX.namespace('Widget.RequestView');

requestview=function(divid) {
  var req = document.getElementById(divid+'_select').value;
  req_node = new PHEDEX.Widget.RequestView(divid,req);
  req_node.update();
}

PHEDEX.Widget.RequestView = function(divid,request) {
  var that = new PHEDEX.Core.Widget(divid+'_display_'+request,null,
		{
		children:false,
		width:800,
		height:200,
		minwidth:400,
		minheight:80
		});
  that.request=request;
  that.buildHeader=function(div) {
    this.list = document.createElement('ul');
    this.list.className='inline_list';
    this.title = document.createElement('li');
    this.list.appendChild(this.title);
    this.requestor = document.createElement('li');
    this.list.appendChild(this.requestor);
    this.volume = document.createElement('li');
    this.list.appendChild(this.volume);
    this.status = document.createElement('li');
    this.list.appendChild(this.status);
    this.xfertype = document.createElement('li');
    this.list.appendChild(this.xfertype);
    div.appendChild(this.list);
  }
  that.fillHeader=function(div) {
    this.title.innerHTML='Request '+this.data.id;
    this.requestor.innerHTML=this.data.requested_by.username;
    this.volume.innerHTML=this.data.data.files+' files / '+this.format['bytes'](this.data.data.bytes);
    this.status.innerHTML=this.approval();
    this.xfertype.innerHTML=this.classify();
  }
  that.fillBody = function(div) {
    var reqNode, tmpNode, tmpLeaf;
    var tree = new YAHOO.widget.TreeView(div);
    var root = tree.getRoot();
    
    reqNode = new YAHOO.widget.TextNode({label: "Request status", expanded: false}, root);
    tmpLeaf = new YAHOO.widget.TextNode(this.data.comments, reqNode, false); 
    tmpLeaf.isLeaf = true;

    tmpNode = new YAHOO.widget.TextNode({label: "Requestor details", expanded: false}, reqNode);
    var requestDetail = "Requested by "+this.data.requested_by.username+" ("+this.data.requested_by.name+") on "+this.format.date(this.data.time_create)+"<br/>DN: "+this.data.requested_by.dn+"<br/>Host: "+this.data.requested_by.host+" using "+this.data.requested_by.agent;
    new YAHOO.widget.TextNode(requestDetail, tmpNode, false); 

    tmpNode = new YAHOO.widget.TextNode({label: this.approval(), expanded: false}, reqNode);
    var destinationDetail="";
    for (var i in this.data.destinations.node) {
      var d = this.data.destinations.node[i];
      destinationDetail += "DESTINATION: "+d.name+"<br/>";
      if ( d.decided_by.decision == 'y' ) { destinationDetail += "Approved"; }
      else                                { destinationDetail += "Rejected"; }
      destinationDetail += " by "+d.decided_by.username+" ("+d.decided_by.name+") on "+this.format.date(d.decided_by.time_decided);
    }
    new YAHOO.widget.TextNode(destinationDetail, tmpNode, false); 

    tmpNode = new YAHOO.widget.TextNode({label: "Block details", expanded: false}, root);
    tmpLeaf.isLeaf = true;
    for (var i in this.data.data.dbs.dataset) {
      var d = this.data.data.dbs.dataset[i];
      var b = new YAHOO.widget.TextNode({label: d.name, expanded: false}, tmpNode);
      var t = " BlockID: "+d.id+", "+d.files+" files / "+this.format['bytes'](d.bytes);
      tmpLeaf = new YAHOO.widget.TextNode(t, b, false);
      tmpLeaf.isLeaf = true;
    }

    tree.render(); 
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
  that.buildExtra=function(div) {
    this.comment=document.createElement('div');
    this.comment.className='comment';
    div.appendChild(this.comment);
    this.creator=document.createElement('div');
    this.creator.className='border';
    div.appendChild(this.creator);
    this.approver=document.createElement('div');
    this.approver.className='border';
    div.appendChild(this.approver);
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
  that.build();
  return that;
}