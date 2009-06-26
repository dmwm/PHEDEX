// instantiate the PHEDEX.Widget.RequestView namespace
PHEDEX.namespace('Widget.RequestView');

PHEDEX.Page.Widget.Requests=function(divid) {
  var request = document.getElementById(divid+'_select').value;
  req_node = new PHEDEX.Widget.RequestView(request,divid);
  req_node.update();
}

PHEDEX.Widget.RequestView = function(request,divid) {
  if ( !divid) { divid = PHEDEX.Util.generateDivName(); }
  var width=800;
  var that = new PHEDEX.Core.Widget.TreeView(divid+'_'+request,null,
		{
		width:width,
		height:200,
		minwidth:400,
		minheight:80
		});
  that.me=function() { return 'PHEDEX.Core.Widget.RequestView'; }
  that.request=request;
  that._custodial = {y:'custodial', n:'non-custodial'};
  that._static    = {y:'static',    n:'dynamic'};
  that._move      = {y:'move',      n:'copy'};

  var linkHeader1 = [
          {width: 80,text:'Request ID',className:'phedex-tree-request-id', otherClasses:'align-left'},
          {width: 90,text:'Username',  className:'phedex-tree-username'},
	  {width:120,text:'Volume',    className:'phedex-tree-volume'},
	  {width: 70,text:'Status',    className:'phedex-tree-status'},
	  {width:100,text:'Custodial', className:'phedex-tree-custodial'},
          {width: 50,text:'Move',      className:'phedex-tree-move'},
          {width: 60,text:'Static',    className:'phedex-tree-static'},
          {width: 70,text:'Priority',  className:'phedex-tree-priority'},
          {width: 70,text:'Group',     className:'phedex-tree-group'}
    ];
  var linkHeader2 = [
          {width:180,text:'Requestor',           className:'phedex-tree-requestor-name', otherClasses:'align-left'},
          {width:180,text:'Request Date',        className:'phedex-tree-request-date'},
	  {width:150,text:'Comments',            className:'phedex-tree-comments',           hideByDefault:true},
	  {width:150,text:'Requestor DN',        className:'phedex-tree-requestor-dn',       hideByDefault:true},
	  {width:100,text:'Requestor Host',      className:'phedex-tree-requestor-host',     hideByDefault:true},
	  {width:200,text:'Requestor User Agent',className:'phedex-tree-requestor-useragent',hideByDefault:true}
    ];
  var linkHeader3 = [
          {width:180,text:'Approver',            className:'phedex-tree-approver-name', otherClasses:'align-left'},
          {width:180,text:'Approval Date',       className:'phedex-tree-approval-date'},
	  {width:120,text:'Approval Status',     className:'phedex-tree-approval-status'},
	  {width:140,text:'Node',                className:'phedex-tree-approval-node'},
	  {width:150,text:'Approver DN',         className:'phedex-tree-approver-dn',       hideByDefault:true},
	  {width:100,text:'Approver Host',       className:'phedex-tree-approver-host',     hideByDefault:true},
	  {width:200,text:'Approver User Agent', className:'phedex-tree-approver-useragent',hideByDefault:true}
    ];
  var linkHeader4 = [
          {width:500,text:'Block Name',  className:'phedex-tree-block-name', otherClasses:'align-left'},
          {width: 70,text:'Block ID',    className:'phedex-tree-block-id',hideByDefault:true},
	  {width:120,text:'Data Volume', className:'phedex-tree-block-volume'}
    ];

  that.fillBody = function(div) {
    var tNode;
    var root = that.tree.getRoot();
    tNode = that.addNode(
      {format:linkHeader1},
      [ that.data.id,
        that.data.requested_by.username,
        PHEDEX.Util.format.filesBytes(this.data.data.files,this.data.data.bytes),
        that.approval(),
        that._custodial[that.data.custodial],
        that._move     [that.data.move],
        that._static   [that.data.static],
        that.data.priority,
        that.data.group || '(no group)'
      ]
    );

    that.addNode(
      {format:linkHeader2},
      [ that.data.requested_by.name,
        PHEDEX.Util.format.date(that.data.time_create),
        that.data.comments || '(no comments)',
        that.data.requested_by.dn,
        that.data.requested_by.host,
        that.data.requested_by.agent
      ],
       tNode
    );

    var destinationDetail="";
    for (var i in this.data.destinations.node) {
      var d = this.data.destinations.node[i];;

      if ( d.decided_by.decision == 'y' ) { destinationDetail = 'Approved'; }
      else                                { destinationDetail = 'Rejected'; }
      that.addNode(
          {format:linkHeader3},
          [
            d.decided_by.name,
            PHEDEX.Util.format.date(d.decided_by.time_decided),
            destinationDetail,
            d.name,
            d.decided_by.dn,
            d.decided_by.host,
            d.decided_by.agent
          ],
           tNode
        );
    }

    for (var i in this.data.data.dbs.dataset) {
      var d = this.data.data.dbs.dataset[i];
      that.addNode( {format:linkHeader4},
		    [ PHEDEX.Util.format.longString(d.name),d.id,PHEDEX.Util.format.filesBytes(d.files,d.bytes) ] );
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
  that.update=function() {
    PHEDEX.Datasvc.Call({api:'TransferRequests',args:{request:this.request},success_event:this.onDataReady});
  }
  that.onDataReady.subscribe(function(event,args) { that.receive(args); });
  that.receive=function(data) {
    that.data=data[0].request[0];
    if (that.data) {
      that.populate();
    }
  }
  that.isDynamic = false; // disable dynamic loading of data

  that.buildTree(that.div_content);
  var tNode = that.addNode( { width:width, format:linkHeader1, prefix:'Request' });
	      that.addNode( {              format:linkHeader2, prefix:'Requestor' }, null, tNode );
	      that.addNode( {              format:linkHeader3, prefix:'Approver' },  null, tNode );
	      that.addNode( {              format:linkHeader4, prefix:'Block' } );

  that.buildContextMenu('Request');
  that.build();
  return that;
}

YAHOO.log('loaded...','info','Widget.RequestView');
