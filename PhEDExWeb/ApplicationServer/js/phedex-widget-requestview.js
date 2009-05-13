// instantiate the PHEDEX.Widget.RequestView namespace
PHEDEX.namespace('Widget.RequestView');

requestview=function(divid) {
  var req = document.getElementById(divid+'_select').value;
  req_node = new PHEDEX.Widget.RequestView(divid,req);
  req_node.update();
}

PHEDEX.Widget.RequestView = function(divid,req_num) {
  var that = new PHEDEX.Core.Widget(divid+'_display_'+req_num,null,
		{
		children:false,
		width:500,
		height:200,
		minwidth:400,
		minheight:80
		});
  that.req_num=req_num;
  that.data={};
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
  that.fillBody = function(div) {
    var reqNode, tmpNode, tmpLeaf;
    var tree = new YAHOO.widget.TreeView(div);
    var root = tree.getRoot();
    
    reqNode = new YAHOO.widget.TextNode({label: "Request status", expanded: false}, root);
    tmpLeaf = new YAHOO.widget.TextNode(this.data.comments, reqNode, false); 
    tmpLeaf.isLeaf = true;

    tmpNode = new YAHOO.widget.TextNode({label: "Requestor details", expanded: false}, reqNode);
    var requestDetail = "Created: "+this.format.date(this.data.time_create)+"<br/>By: "+this.data.requested_by.username+" ("+this.data.requested_by.name+")<br/>Host: "+this.data.requested_by.host+" using "+this.data.requested_by.agent+"<br/>DN: "+this.data.requested_by.dn;
    new YAHOO.widget.TextNode(requestDetail, tmpNode, false); 

// this bit about SOURCE: was in the prototype code, but I'm not sure what it does...
/*
    tmpNode = new YAHOO.widget.TextNode({label: this.approval(), expanded: false}, reqNode);
    var approverDetail="";
    for (var i in this.data['sources']) {
      approverDetail += "SOURCE: "+this.data['sources'][i]['name']+"<br/>Approved: "+this.data['sources'][i]['decision']+"<br/>Approved by: "+this.data['sources'][i]['approved_by']['username']+" ("+this.data['sources'][i]['approved_by']['name']+")<br/>Approved at: "+this.format['date'](this.data['sources'][i]['time_decided'])+"<br/>";
    }
    new YAHOO.widget.TextNode(approverDetail, tmpNode, false); 
*/
    tmpNode = new YAHOO.widget.TextNode({label: "Approval status: "+this.approval(), expanded: false}, reqNode);
    var destinationDetail="";
    for (var i in this.data.destinations) {
      destinationDetail += "DESTINATION: "+this.data.destinations[i].name+"<br/>Approved: "+this.data.destinations[i].decision+"<br/>Approved by: "+this.data.destinations[i].approved_by.username+" ("+this.data.destinations[i].approved_by.name+")<br/>Approved at: "+this.format.date(this.data.destinations[i].time_decided)+"<br/>";
    }
    new YAHOO.widget.TextNode(destinationDetail, tmpNode, false); 

    tmpNode = new YAHOO.widget.TextNode({label: "Block details", expanded: false}, root);
    tmpLeaf.isLeaf = true;
    for (var i in this.data.data.dbs.dataset) {
      var d = this.data.data.dbs.dataset[i];
//       var b = new YAHOO.widget.TextNode({label: this.format.dataset(d.name), expanded: false}, tmpNode); // shorten dataset name for label?
      var b = new YAHOO.widget.TextNode({label: d.name, expanded: false}, tmpNode);
      var t = " BlockID: "+d.id+", "+d.files+" files / "+this.format['bytes'](d.bytes);
//       if ( d.name != this.format.dataset(d.name) ) { t += "<br/>Block: "+d.name; } // not needed if full name used in label
      tmpLeaf = new YAHOO.widget.TextNode(t, b, false);
      tmpLeaf.isLeaf = true;
    }

    tree.render(); 
  }
  that.approval=function() {
    var dest_approve=0;
    var src_approve=0;
    var n_dest=this.data['destinations'].length;
    var n_src=this.data['sources'].length;
    for (var i in this.data['destinations']) {
      if (this.data['destinations'][i]['decision']=='y') {
        dest_approve+=1;
      }
    }
    for (var i in this.data['sources']) {
      if (this.data['sources'][i]['decision']=='y') {
        src_approve+=1;
      }
    }
    if (dest_approve==0 && src_approve==0)
      return "No approvals";
    if (dest_approve==n_dest && src_approve==n_src)
      return "Approved";
    return "Approved ("+src_approve+"/"+n_src+" sources, "+dest_approve+"/"+src_approve+" destinations";
  }
  that.classify=function() {
    var result=this.data['priority']+' priority';
    if (this.data['custodial']=='y')
      result += ', custodial';
    if (this.data['move']=='y')
      result += ', move';
    return result;
  }
  that.fillHeader=function(div) {
    that.title.innerHTML='Request '+this.data['id'];
    that.requestor.innerHTML=this.data['requested_by']['username'];
    that.volume.innerHTML=this.data['files']+' files / '+this.format['bytes'](this.data['bytes']);
    that.status.innerHTML=this.approval();
    that.xfertype.innerHTML=this.classify();
  }
  that.buildExtra=function(div) {
    that.comment=document.createElement('div');
    that.comment.className='comment';
    div.appendChild(this.comment);
    that.creator=document.createElement('div');
    that.creator.className='border';
    div.appendChild(this.creator);
    that.approver=document.createElement('div');
    that.approver.className='border';
    div.appendChild(this.approver);
  }
  that.update=function() {
    PHEDEX.Datasvc.TransferRequests(this.req_num,this);
  }
  that.receive=function(result) {
    var data=PHEDEX.Datasvc.TransferRequests[that.req_num];
    if (data) {
      that.data = data;
      that.build();
      that.populate();
    }
  }

// this doesn't seem to do anything particularly useful, in that it creates a broken URL
/*
  that.buildChildren=function(div) {
    this.startLoading();
    this.markChildren();
    for (var i in this.data['data']['dbs']['dataset']) {
      var d = this.data['data']['dbs']['dataset'][i];
      var id = this.id+"_d"+i;
      var child = this.getChild(id);
      if (child) {
        child.data=d;
        child.marked=false;
        child.update();
      } else {
        var cdiv = document.createElement('div');
        cdiv.id=id;
        this.children_div.appendChild(cdiv);
        var c = new PHEDEX.Widget.ReqBlockNode(cdiv,this,d);
        this.children.push(c);
        c.update();
      }
    }
    if (this.children.length==0) {
      this.children_info_div.innerHTML='No children returned';
    }
    this.removeMarkedChildren();
    this.finishLoading();
  }
*/  
//   that.build();
  return that;
}

// Not sure what this was used for...
/*
PHEDEX.Widget.ReqBlockNode = function(div,parent,data) {
  var that = new PHEDEX.Widget(div,parent,{children:false});
  that.data=data;
  that.buildHeader=function(span) {
    this.title=document.createElement('span');
    this.volume=document.createElement('span');
    this.volume.className='col3';
    span.appendChild(this.title);
    span.appendChild(this.volume);
  }
  that.fillHeader=function() {
    this.title.innerHTML=this.format['dataset'](this.data['name']);
    this.volume.innerHTML=this.data['files']+" files / "+this.format['bytes'](this.data['bytes']);
  }
  that.buildExtra=function(div) {
    this.dbslink = document.createElement('div');
    div.appendChild(this.dbslink);
  }
  that.fillExtra=function() {
    this.dbslink.innerHTML="<a href='dbs?"+this.data['name']+"'>DBS</a>";
  }
  that.update=function() {
    this.populate();
  }
  that.build();
  return that;
}
*/