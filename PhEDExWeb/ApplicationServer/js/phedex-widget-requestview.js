req_node=null;

requestview=function() {
  var req = document.getElementById('select_for_requestview').value;
  req_node = new PHEDEX.Widget.RequestView(req);
  req_node.update();
}

PHEDEX.Widget.RequestView = function(req_num) {
  var that = new PHEDEX.Widget('phedex_requestview',null);
  that.req_num=req_num;
  that.data={};
  that.buildHeader=function(span) {
    this.title=document.createElement('span');
    this.requestor=document.createElement('span');
    this.requestor.className='col1';
    this.volume=document.createElement('span');
    this.volume.className='col2';
    this.status=document.createElement('span');
    this.status.className='col3';
    this.xfertype=document.createElement('span');
    this.xfertype.className='col4';
    span.appendChild(this.title);
    span.appendChild(this.requestor);
    span.appendChild(this.volume);
    span.appendChild(this.status);
    span.appendChild(this.xfertype);
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
  that.fillHeader=function() {
    this.title.innerHTML='Request '+this.data['id'];
    this.requestor.innerHTML=this.data['requested_by']['username'];
    this.volume.innerHTML=this.data['files']+' files / '+this.format['bytes'](this.data['bytes']);
    this.status.innerHTML=this.approval();
    this.xfertype.innerHTML=this.classify();
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
  that.fillExtra=function() {
    this.comment.innerHTML = this.data['comments'];
    this.creator.innerHTML = "<div>Created: "+this.format['date'](this.data['time_create'])+"</div><div>By: <a href='mailto:"+this.data['requested_by']['email']+"'>"+this.data['requested_by']['username']+"</a> ("+this.data['requested_by']['name']+")</div><div>Host: "+this.data['requested_by']['host']+" using "+this.data['requested_by']['agent']+"</div><div>DN: "+this.data['requested_by']['dn']+"</div>";
    this.approver.innerHTML="";
    for (var i in this.data['sources']) {
      this.approver.innerHTML += "<div><div>SOURCE: "+this.data['sources'][i]['name']+"</div><div>Approved: "+this.data['sources'][i]['decision']+"</div><div>Approved by: <a href='mailto:"+this.data['sources'][i]['approved_by']['email']+"'>"+this.data['sources'][i]['approved_by']['username']+"</a> ("+this.data['sources'][i]['approved_by']['name']+")</div><div>Approved at: "+this.format['date'](this.data['sources'][i]['time_decided'])+"</div></div>";
    }
    for (var i in this.data['destinations']) {
      this.approver.innerHTML += "<div><div>DESTINATION: "+this.data['destinations'][i]['name']+"</div><div>Approved: "+this.data['destinations'][i]['decision']+"</div><div>Approved by: <a href='mailto:"+this.data['destinations'][i]['approved_by']['email']+"'>"+this.data['destinations'][i]['approved_by']['username']+"</a> ("+this.data['destinations'][i]['approved_by']['name']+")</div><div>Approved at: "+this.format['date'](this.data['destinations'][i]['time_decided'])+"</div></div>";
    }
    
  }
  that.update=function() {
    Data.Call('TransferRequests',{req_num:this.req_num},this.receive,{obj:this});
    this.startLoading();
  }
  that.receive=function(result) {
    var data=eval('('+result.responseText+')')['phedex']['request'];
    if (data.length==1) {
      result.argument.obj.data=data[0];
    }
    result.argument.obj.finishLoading();
    result.argument.obj.populate();
  }
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
  
  that.build();
  return that;
}

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

Data=function(){}
//PHEDEX.Datasvc.Nodes = function(site,callback,argument) {
//  var opts = 'nodes';
//  if ( site ) { opts += '?node='+site; }
//  PHEDEX.Datasvc.GET(opts,callback,argument);
//}
Data.Call = function(query,args,callback,argument) {
  var argstr = "";
  if (args) {
    argstr = "?";
    for (a in args) {
      argstr+=a+"="+args[a]+";";
    }
  }
// var url = '/phedex/datasvc/json/prod/'+query+argstr;
// var c = YAHOO.util.Connect.asyncRequest('GET',url,{success:callback,argument:argument});
  query = query + argstr;
  PHEDEX.Datasvc.GET(query,callback,argument);
}
