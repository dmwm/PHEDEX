// instantiate the PHEDEX.Widget.RequestView namespace
PHEDEX.namespace('Widget.Template');

PHEDEX.Page.Widget.Template=function(divid) {
  var value = document.getElementById(divid+'_select').value;
  widget = new PHEDEX.Widget.Template(value,divid);
}

PHEDEX.Widget.Template = function(request,divid) {
  divid = PHEDEX.Util.generateDivName();
  var that = new PHEDEX.Core.Widget.TreeView(divid,{
		width:width,
		height:300
	      });
  that.me=function() { return 'PHEDEX.Core.Widget.Template'; }

  var width = 1000;
  var branchDef1 = [
          {width:160,text:'Node',         className:'phedex-tree-node',       otherClasses:'align-left',  contextArgs:['Node','sort-alpha'] },
	  {width:120,text:'Done',         className:'phedex-tree-done',       otherClasses:'align-right', contextArgs:'sort-alpha' },
          {width:120,text:'Failed',       className:'phedex-tree-failed',     otherClasses:'align-right', contextArgs:'sort-alpha' },
          {width:120,text:'Expired',      className:'phedex-tree-expired',    otherClasses:'align-right', contextArgs:'sort-alpha' },
          {width: 70,text:'Rate',         className:'phedex-tree-rate',       otherClasses:'align-right', contextArgs:'sort-alpha' },
	  {width: 70,text:'Quality',      className:'phedex-tree-quality',    otherClasses:'align-right', contextArgs:'sort-alpha' },
	  {width:120,text:'Queued',       className:'phedex-tree-queue',      otherClasses:'align-right', contextArgs:'sort-alpha' },
	  {width: 70,text:'Link Errors',  className:'phedex-tree-error-total',otherClasses:'align-right', contextArgs:'sort-alpha' },
	  {width: 90,text:'Logged Errors',className:'phedex-tree-error-log',hideByDefault:true}
    ];
  var branchDef2 = [
	  {width:200,text:'Block Name',  className:'phedex-tree-block-name',  otherClasses:'align-left', contextArgs:'sort-alpha'},
	  {width: 80,text:'Block ID',    className:'phedex-tree-block-id', contextArgs:'sort-alpha'},
	  {width: 80,text:'State',       className:'phedex-tree-state',    contextArgs:'sort-alpha'},
          {width: 80,text:'Priority',    className:'phedex-tree-priority', contextArgs:'sort-alpha'},
          {width: 80,text:'Files',       className:'phedex-tree-block-files', otherClasses:'align-right', contextArgs:'sort-alpha'},
	  {width: 80,text:'Bytes',       className:'phedex-tree-block-bytes', otherClasses:'align-right', contextArgs:'sort-alpha'},
	  {width: 90,text:'Block Errors',className:'phedex-tree-block-errors',otherClasses:'align-right', contextArgs:'sort-alpha'}
    ];
  var branchDef3 = [
	  {width:200,text:'File Name',  className:'phedex-tree-file-name',  otherClasses:'align-left', contextArgs:'sort-alpha'},
	  {width: 80,text:'File ID',    className:'phedex-tree-file-id', contextArgs:'sort-alpha'},
	  {width: 80,text:'Bytes',      className:'phedex-tree-file-bytes', otherClasses:'align-right', contextArgs:'sort-alpha'},
	  {width: 90,text:'File Errors',className:'phedex-tree-file-errors',otherClasses:'align-right', contextArgs:'sort-alpha'},
          {width:140,text:'Checksum',   className:'phedex-tree-file-cksum', otherClasses:'align-right', contextArgs:'sort-alpha' ,hideByDefault:true}
    ];
  var structure = [
    { width:width, format:branchDef1, name:'Link'  },
    {              format:branchDef2, name:'Block',  parent:'Link'  },
    {              format:branchDef3, name:'File',   parent:'Block' }
   ];

  that.buildTree(that.dom.content);
  that.buildHeader=function(div) {
    var map = [];
    map.Root = that.headerTree.getRoot();
    for (var i in structure)
    {
      var iNode = structure[i];
      if ( !iNode.parent ) { iNode.parent = 'Root'; }
      map[iNode.name] = that.addNode( iNode, null, map[iNode.parent] );
      map[iNode.name].expand();
    }
    that.headerTree.render();
  }
  that.fillBody = function(div) {
    var map=[];
    map.Root = [];
    map.Root[0] = that.tree.getRoot();
    var alphabet = 'abcdefghijklmnopqrstuvwxyz';
    var longString = alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet+alphabet;
    for (var i in structure)
    {
      var iNode = structure[i];
      var parent = iNode.parent || 'Root';

      iNode.className = 'phedex-tnode-field';

      if ( !map[iNode.name] ) { map[iNode.name] = []; }
      for (var j in map[parent]) {
	for (var k=0; k<Math.floor(Math.random()*4+3); k++) {
	  var values = [];
	  for (var l in iNode.format) {
	    var start = Math.floor(Math.random()*20);
	    values[l] = longString.substring(start,Math.floor(iNode.format[l].width/25)+start+1);
	  }
	  var tNode = that.addNode( iNode, values, map[parent][j] );
	  map[iNode.name].push(tNode);
// 	  tNode.expand();
	}
      }
    }
    that.tree.render();
  }

//   var fillOther=function() { YAHOO.util.Dom.insertBefore(document.createTextNode('Other...'),that.dom.extra.firstChild); }
//   var fillMore=function() {  YAHOO.util.Dom.insertBefore(document.createTextNode('More...'),that.dom.extra.firstChild); }
//   var ctl1 = new PHEDEX.Core.Control( {name:'Other', text:'Other',
//                     payload:{target:that.dom.extra, fillFn:fillOther, obj:that} } );
//   YAHOO.util.Dom.insertBefore(ctl1.el,that.dom.control.firstChild);
//   var ctl2 = new PHEDEX.Core.Control( {name:'More', text:'More',
//                     payload:{target:that.dom.extra, fillFn:fillMore, obj:that} } );
//   YAHOO.util.Dom.insertBefore(ctl2.el,that.dom.control.firstChild);

  that.buildExtra(that.dom.extra);
  that.buildContextMenu();
  that.build();
  that.populate();
  return that;
}

YAHOO.log('loaded...','info','Widget.Template');
