// instantiate the PHEDEX.Widget.TransfersNode namespace
PHEDEX.namespace('Widget.TransfersNode');

linkview=function(divid) {
  var site = document.getElementById(divid+'_select').value;
  xfer_node = new PHEDEX.Widget.TransfersNode(divid,site);
  xfer_node.update();
}

PHEDEX.Widget.TransfersNode=function(divid,site) {
  var that = new PHEDEX.Core.Widget(divid+'_display_'+site,null,{
		fixed_extra:false,
		expand_children:false,
		width:1000,
		height:700
	      });
  that.site = site;
  that.mode='to';
  that.time='6';
  that.buildHeader=function(div) {
    var modeselect = document.createElement('select');
    var incoming = document.createElement('option');
    var outgoing = document.createElement('option');
    incoming.text = 'Incoming Links';
    incoming.value = 'to';
    outgoing.text = 'Outgoing Links';
    outgoing.value = 'from';
    modeselect.appendChild(incoming);
    modeselect.appendChild(outgoing);
    modeselect.selectedIndex=0;

    var timeselect = document.createElement('select');
    timeselect.innerHTML = "<option value='1'>Last Hour</option><option value='3'>Last 3 Hours</option><option value='6' selected>Last 6 Hours</option><option value='12'>Last 12 Hours</option><option value='24'>Last Day</option><option value='48'>Last 2 Days</option><option value='96'>Last 4 Days</option><option value='168'>Last Week</option>";
    
    modeselect.setAttribute('onchange',"PHEDEX.Widget.eventProxy('"+this.id+"','mode',this.value);"); //when called, 'this' will be modeselect, so this.value gets us the appropriate argument
    timeselect.setAttribute('onchange',"PHEDEX.Widget.eventProxy('"+this.id+"','time',this.value);");

    div.appendChild(modeselect);
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
    var reqNode, tmpNode, tmpLeaf, root;
    this.tree = new YAHOO.widget.TreeView(div);
    root = this.tree.getRoot();
  }

  that.event=function(what,val,arg2,arg3) {
    if (what=='time') {
      this.time=val;
      this.update();
    }
    if (what=='mode') {
      this.mode=val;
      this.update();
    }
  }
  that.update=function() {
    var args={};
    args[this.mode]=this.site;//apparently {this.mode:this.site} is invalid
    args['binwidth']=parseInt(this.time)*3600;
    PHEDEX.Datasvc.TransferQueueStats(args,this,this.receive_QueueStats);
    PHEDEX.Datasvc.TransferHistory   (args,this,this.receive_History);
    PHEDEX.Datasvc.TransferErrorStats(args,this,this.receive_ErrorStats);
    this.startLoading();
  }
  that.receive_QueueStats=function(result) {
    that.data_queue = PHEDEX.Data.TransferQueueStats;
    that.maybe_populate();
  }
  that.receive_History=function(result) {
    that.data_hist = PHEDEX.Data.TransferHistory;
    that.maybe_populate();
  }
  that.receive_ErrorStats=function(result) {
    that.data_error = PHEDEX.Data.TransferErrorStats;
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
    var antimode='to';
    if (this.mode=='to') { antimode='from'; }
    for (var i in this.data_hist) {
      var h = this.data_hist[i];
      var node = h[antimode];
      var d = {};
      var e={num_errors:0};
      for (var j in this.data_queue) {
        if (this.data_queue[j][antimode]==node) {
          d = this.data_queue[j];
          break;
        }
      }
      for (var j in this.data_error) {
        if (this.data_error[j][antimode]==node) {
          e = this.data_error[j];
        }
      }
      var id = this.id+'_'+this.mode+'_'+node;

      this.sum_hist(h);
      else { qual = '0 MB/s'; }
      var list = PHEDEX.Util.makeUList([
	  node,
          PHEDEX.Util.format.bytes(this.hist_speed(h))+'/s, quality: '+this.format['%'](h.quality),
	  PHEDEX.Util.format.filesBytes(h.done_files,h.done_bytes)+' done,',
	  PHEDEX.Util.format.filesBytes(this.sum_queue_files(d.transfer_queue),this.sum_queue_bytes(d.transfer_queue))+' queued',
          e.num_errors+' errors'
	]);
      var tNode = new YAHOO.widget.TextNode({label: '<div class="inline_list" style="width:900px;">'+list.innerHTML+'</div>', expanded: false}, root);
      var tLeaf = new YAHOO.widget.TextNode("this is a comment", tNode, false);
//    tLeaf.isLeaf = true;
//
//     tmpNode = new YAHOO.widget.TextNode({label: "Requestor details", expanded: false}, reqNode);
//     new YAHOO.widget.TextNode("this is a text node", tmpNode, false);

//       var child = this.getChild(id);
//       if (child) {
//         child.data_queue=d['transfer_queue'];
//         child.data_hist=h;
//         child.data_error=e;
//         child.marked=false;
//         child.update();
//       } else {
//         var childdiv = document.createElement('div');
//         childdiv.id = id;
//         div.appendChild(childdiv);
//         var childnode = new PHEDEX.Widget.LinkNode(node,this.mode,this,childdiv,d['transfer_queue'],h,e);
//         this.children.push(childnode);
//         childnode.update();
//       }
    }
/*    this.removeMarkedChildren();
    if (this.children.length==0) {
      this.children_info_none.innerHTML='No children returned';
    } else {
      this.children_info_none.innerHTML='';
    }*/
    that.tree.render();
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
    }
    if ( h.binwidth && h.transfer.length )
    {
      h.rate = h.done_bytes / (h.transfer.length*h.binwidth);
      h.quality /= h.transfer.length;
    }
  }
  that.buildChildren=function(div) {
debugger;
    this.markChildren();
    if (this.mode=='to') var antimode='from';
    else var antimode='to';
    for (var i in this.data_hist) {
      var h = this.data_hist[i];
      var node = h[antimode];
      var d = {};
      var e={num_errors:0};
      for (var j in this.data_queue) {
        if (this.data_queue[j][antimode]==node) {
          d = this.data_queue[j];
          break;
        }
      }
      for (var j in this.data_error) {
        if (this.data_error[j][antimode]==node) {
          e = this.data_error[j];
        }
      }
      var id = this.id+'_'+this.mode+'_'+node;
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
        var childnode = new PHEDEX.Widget.LinkNode(node,this.mode,this,childdiv,d['transfer_queue'],h,e);
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

PHEDEX.Widget.LinkNode=function(site,mode,parent,div,data_queue,data_hist,data_error) {
  var that = new PHEDEX.Widget(div,parent);
  that.site=site;
  that.mode=mode;
  if (that.mode=='to') that.antimode='from';
  else that.antimode='to';
  that.data_queue=data_queue;
  that.data_hist=data_hist;
  that.data_error=data_error;
  that.queues=[];
  that.sum_queue_files=function() {
    var fsum=0;
    for (var i in this.data_queue) {
      fsum+= parseInt(this.data_queue[i]['files']);
    }
    return fsum;
  }
  that.sum_queue_bytes=function() {
    var bsum=0;
    for (var i in this.data_queue) {
      bsum+=parseInt(this.data_queue[i]['bytes']);
    }
    return bsum;
  } 
  that.hist_speed=function() {
    return parseInt(this.data_hist['done_bytes'])/parseInt(this.data_hist['binwidth']);
  }
  that.buildHeader=function(span) {
    this.title = document.createElement('span');
    this.speed = document.createElement('span');
    this.speed.className='col1';
    this.done = document.createElement('span');
    this.done.className='col2';
    this.queue = document.createElement('span');
    this.queue.className='col3';
    this.errors = document.createElement('span');
    this.errors.className='col4';
    this.errors.style.color='red';
    span.appendChild(this.title);
    span.appendChild(this.speed);
    span.appendChild(this.done);
    span.appendChild(this.queue);
    span.appendChild(this.errors);
  }
  that.fillHeader=function() {
    //this.span_header.innerHTML=this.site+' '+this.hist_speed()+' B/s '+this.data_hist['done_files']+' files / '+this.data_hist['done_bytes']+' B quality:'+this.data_hist['quality']+' '+this.sum_queue_files()+' files / '+this.sum_queue_bytes()+' B queued';
    this.title.innerHTML=this.site;
    this.speed.innerHTML=this.format['bytes'](this.hist_speed())+'/s, quality: '+this.format['%'](this.data_hist['quality']);
    this.done.innerHTML=this.data_hist['done_files']+' files / '+this.format['bytes'](this.data_hist['done_bytes']);
    this.queue.innerHTML=this.sum_queue_files()+' files / '+this.format['bytes'](this.sum_queue_bytes())+' queued';
    this.errors.innerHTML=this.data_error['num_errors']+' errors';
  }
  that.buildExtra=function(div) {}
  that.fillExtra=function() {
    this.extra_div.innerHTML='Recent: '+this.data_hist['fail_files']+' failed / '+this.data_hist['expire_files']+' expired';
  }
  that.filter=function(filter_str) {
    if (filter_str.indexOf('link: ')>=0) {
      if (filter_str.indexOf(this.site)>=0) {
        return false;
      }
    }
    return true;
  }
  that.update=function() {
    var q = this.data_hist['quality'];
    var red = parseInt((1.-q)*256);
    var green = parseInt(q*256);
    this.div.style.border="3px solid rgb("+red+","+green+",0)";
    
    this.populate();
  }
  that.buildChildren=function(div) {
debugger;
    if (this.mode=='to') {
      var to = this.parent.site;
      var from = this.site;
    } else {
      var to = this.site;
      var from = this.parent.site;
    }
    Data.Call('TransferQueueBlocks',{from:from,to:to},this.receive,{obj:this,from:from,to:to});
//    PHEDEX.Datasvc.TransferQueueBlocks({from:from,to:to},this); // .receive,{obj:this,from:from,to:to});
    this.startLoading();
  }
  that.receive = function(result) {
    result.argument.obj.markChildren();
    var queues = eval('('+result.responseText+')')['phedex']['link'];
    for (var i in queues) {
      for (var j in queues[i]['transfer_queue']) {
        var q_prio = queues[i]['transfer_queue'][j]['priority'];
        var q_stat = queues[i]['transfer_queue'][j]['state'];
        for (var k in queues[i]['transfer_queue'][j]['block']) {
          var block = queues[i]['transfer_queue'][j]['block'][k];
          var bname = queues[i]['transfer_queue'][j]['block'][k]['name'];
          var e = {num_errors:0};
          for (var l in result.argument.obj.data_error['block']) {
            if (result.argument.obj.data_error['block'][l]['name']==bname) {
              e = result.argument.obj.data_error['block'][l];
            }
          }
          var id = result.argument.obj.id+'_i'+i+'_q'+j+'_b'+k;
          var child = result.argument.obj.getChild(id);
          if (child) {
            child.marked=false;
            child.data=block;
            child.q_p=q_prio;
            child.q_s=q_stat;
            child.data_error=e;
            child.update();
          } else {
            var bdiv = document.createElement('div');
            bdiv.id = id;
            result.argument.obj.children_div.appendChild(bdiv);
            var node = new PHEDEX.Widget.BlockNode(result.argument.from,result.argument.to,this,bdiv,block,q_prio,q_stat,e);
            result.argument.obj.children.push(node);
            node.update();
          }
        }
      }
    }
    result.argument.obj.removeMarkedChildren();
    if (result.argument.obj.children.length==0) {
      result.argument.obj.children_info_none.innerHTML='No children returned';
    } else {
      result.argument.obj.children_info_none.innerHTML='';
    }
    result.argument.obj.queues = queues;
    result.argument.obj.finishLoading();
  }
  that.build();
  return that;
}

PHEDEX.Widget.BlockNode = function(from,to,parent,div,data,queue_priority,queue_status,data_error) {
  var that = new PHEDEX.Widget(div,parent);
  that.from=from;
  that.to=to;
  that.data=data;
  that.data_error=data_error;
  that.q_p = queue_priority;
  that.q_s = queue_status;
  that.files=[];
  that.buildHeader=function(span) {
    this.title=document.createElement('span');
    this.priority = document.createElement('span');
    this.priority.className='col2';
    this.status = document.createElement('span');
    this.status.className='col3';
    this.errors = document.createElement('span');
    this.errors.className='col4';
    this.errors.style.color='red';
    span.appendChild(this.title);
    span.appendChild(this.priority);
    span.appendChild(this.status);
    span.appendChild(this.errors);
  }
  that.fillHeader=function() {
    //this.span_header.innerHTML='block: '+this.data['name']+' queue: '+this.q_p+' '+this.q_s;
    this.title.innerHTML=this.format['block'](this.data['name']);
    this.priority.innerHTML='Priority: '+this.q_p;
    this.status.innerHTML='Status: '+this.q_s;
    this.errors.innerHTML=this.data_error['num_errors']+' errors';
  }
  that.buildExtra=function(div) {}
  that.fillExtra=function() {
    this.extra_div.innerHTML='id: '+this.data['id']+' files: '+this.data['files']+' bytes: '+this.data['bytes'];
  }
  that.update=function() {
    this.populate();
  }
  that.buildChildren=function(div) {
debugger;
    var block = this.data['name'].replace(/#/,'%23');
    Data.Call('TransferQueueFiles',{from:this.from,to:this.to,block:block},this.receive,{obj:this,from:this.from,to:this.to,block:block});
    this.startLoading();
  }
  that.receive=function(result) {
    result.argument.obj.markChildren();
    var files=eval('('+result.responseText+')')['phedex']['link'];
    for (var i in files) {
      for (var j in files[i]['transfer_queue']) {
        for (var k in files[i]['transfer_queue'][j]['block']) {
          for (var l in files[i]['transfer_queue'][j]['block'][k]['file']) {
            var f = files[i]['transfer_queue'][j]['block'][k]['file'][l];
            var fname = files[i]['transfer_queue'][j]['block'][k]['file'][l]['name'];
            var e={num_errors:0};
            for (var m in result.argument.obj.data_error['file']) {
              if (result.argument.obj.data_error['file'][m]['name']==fname) {
                e = result.argument.obj.data_error['file'][m];
              }
            }
            var id = result.argument.obj.id+'_f'+l;
            var child = result.argument.obj.getChild(id);
            if (child) {
              child.data = f;
              child.data_error=e;
              child.marked=false;
              child.update();
            } else {
              var fdiv = document.createElement('div');
              result.argument.obj.children_div.appendChild(fdiv);
              fdiv.id = id;
              var node = new PHEDEX.Widget.FileNode(result.argument.from,result.argument.to,result.argument.block,this,fdiv,f,e);
              result.argument.obj.children.push(node);
              node.update();
            }
          }
        }
      }
    }
    result.argument.obj.removeMarkedChildren();
    if (result.argument.obj.children.length==0) {
      result.argument.obj.children_info_none.innerHTML='No children returned';
    } else {
      result.argument.obj.children_info_none.innerHTML='';
    }
    result.argument.obj.files = files;
    result.argument.obj.finishLoading();
  }
  that.build();
  return that;
}
PHEDEX.Widget.FileNode = function(from,to,block,parent,div,data,data_error) {
  var that = new PHEDEX.Widget(div,parent,{children:false});
  that.from=from;
  that.to=to;
  that.block=block;
  that.data=data;
  that.data_error=data_error;
  that.buildHeader=function(span) {
    this.title=document.createElement('span');
    this.errors=document.createElement('span');
    this.errors.className='col4';
    this.errors.style.color='red';
    span.appendChild(this.title);
    span.appendChild(this.errors);
  }
  that.fillHeader=function() {
    //this.span_header.innerHTML='name: '+this.data['name'];
    this.title.innerHTML=this.format['file'](this.data['name']);
    this.errors.innerHTML=this.data_error['num_errors']+' errors';
  }
  that.buildExtra=function(div) {}
  that.fillExtra=function() {
    this.extra_div.innerHTML='id: '+this.data['id']+' checksum: '+this.data['checksum']+' bytes: '+this.data['bytes'];
  }
  that.update=function() {
    this.populate();
  }
  that.build();
  return that;
}

// Data=function(){}
// Data.Call = function(query,args,callback,argument) {
//   debugger;
//   var argstr = "";
//   if (args) {
//     argstr = "?";
//     for (a in args) {
//       argstr+=a+"="+args[a]+";";
//     }
//   }
//   var url = '/phedex/datasvc/json/prod/'+query+argstr;
//   var c = YAHOO.util.Connect.asyncRequest('GET',url,{success:callback,argument:argument});
// }