PHEDEX.namespace('Module');

PHEDEX.Module.UnroutableData=function(sandbox, string) {
  var _sbx = sandbox;

  Yla(this,new PHEDEX.TreeView(sandbox,string));

  var node, block;
      opts = {
        status: null,
        kind:   null,
        since:     1
      },
      width = 1200;

      _direction = 0,
      _direction_map = [],
      _directions = [
        { key:'to',   text:'Incoming Routes' },
        { key:'from', text:'Outgoing Routes' }
      ];

  Yla(opts, {
    width:width,
    height:300
  });

  log('Module: creating a genuine "'+string+'"','info',string);

  _construct = function() {
    return {
      decorators: [
        {
          name: 'Headers',
          source:'component-control',
          parent: 'control',
          payload:{
            target: 'extra',
            animate:false
          }
        },
        {
          name: 'ContextMenu',
          source:'component-contextmenu'
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem'
            },
            container: 'buttons'
          }
        },
        {
          name: 'DirectionSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return _directions[_direction].key; },
            container: 'buttons',
            menu: _directions,
            map: {
              onChange:'changeDirection'
            }
          }
        }
      ],

      meta: {
        isDynamic: true, // enable dynamic loading of data
        tree: [
          {
            width:1200,
            name:'Node',
            format: [
              {width:160,text:'From Node', className:'phedex-tree-node-from',      otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width: 60,text:'From ID',   className:'phedex-tree-node-from-id',   otherClasses:'align-right', ctxArgs:'sort-num',   hide:true },
              {width:200,text:'From SE',   className:'phedex-tree-node-from-se',   otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
              {width:160,text:'To Node',   className:'phedex-tree-node-to',        otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width: 60,text:'To ID',     className:'phedex-tree-node-to-id',     otherClasses:'align-right', ctxArgs:'sort-num',   hide:true },
              {width:200,text:'To SE',     className:'phedex-tree-node-to-se',     otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
//               {width: 60,text:'Valid',     className:'phedex-tree-node-valid',     otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60,text:'Priority',  className:'phedex-tree-node-priority',  otherClasses:'align-right', ctxArgs:'sort-alpha' }
            ]
          },
          {
            name:'Block',
            format: [
              {width:600,text:'Block Name',   className:'phedex-tree-block-name',         otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], ctxKey:'block', spanWrap:true },
              {width: 60,text:'Block ID',     className:'phedex-tree-block-id',           otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 60,text:'Files',        className:'phedex-tree-block-files',        otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',        className:'phedex-tree-block-bytes',        otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes, hide:true },
              {width: 90,text:'Routed Files', className:'phedex-tree-block-route-files',  otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 90,text:'Routed Bytes', className:'phedex-tree-block-route-bytes',  otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes, hide:true },
              {width: 90,text:'Xfer attempts',className:'phedex-tree-block-xfr-attempts', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 90,text:'Avg attempts', className:'phedex-tree-block-avg-attempts', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.toFixed(1), hide:true },
              {width:180,text:'Request Time', className:'phedex-tree-block-timerequest',  otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToUTC' }
            ]
          },
          {
            name:'Replica',
            format:[
              {width:160,text:'Node',        className:'phedex-tree-replica-node',       otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width:100,text:'SE',          className:'phedex-tree-replica-se',         otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
              {width: 80,text:'Files',       className:'phedex-tree-replica-files',      otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',       className:'phedex-tree-replica-bytes',      otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
              {width:180,text:'Create Time', className:'phedex-tree-replica-timecreate', otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true, format:'UnixEpochToUTC' },
              {width:180,text:'Update Time', className:'phedex-tree-replica-timeupdate', otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true, format:'UnixEpochToUTC' },
              {width: 90,text:'Subscribed',  className:'phedex-tree-replica-subscribed', otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
              {width: 60,text:'Complete',    className:'phedex-tree-replica-complete',   otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 90,text:'Group',       className:'phedex-tree-replica-group',      otherClasses:'align-right', ctxArgs:['group','sort-alpha'], ctxKey:'group' }
            ]
          }
        ],

// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
         'Node-level attributes':{
            map:{from:'phedex-tree-node-', to:'N'},
            fields:{
              'phedex-tree-node-from'     :{type:'regex',  text:'From Node-name', tip:'javascript regular expression' },
              'phedex-tree-node-from-id'  :{type:'int',    text:'From Node-ID',   tip:'Node-ID in TMDB'},
              'phedex-tree-node-from-se'  :{type:'regex',  text:'From SE-name',   tip:'javascript regular expression'},
              'phedex-tree-node-to'       :{type:'regex',  text:'To Node-name',   tip:'javascript regular expression' },
              'phedex-tree-node-to-id'    :{type:'int',    text:'To Node-ID',     tip:'Node-ID in TMDB'},
              'phedex-tree-node-to-se'    :{type:'regex',  text:'To SE-name',     tip:'javascript regular expression'},
//               'phedex-tree-node-valid'    :{type:'yesno',  text:'Valid',          tip:'javascript regular expression'},
              'phedex-tree-node-priority' :{type:'regex',  text:'Priority',       tip:'javascript regular expression'}
            }
          },
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-name'         :{type:'regex',  text:'Block-name',    tip:'javascript regular expression' },
              'phedex-tree-block-id'           :{type:'int',    text:'Block-ID',      tip:'Block-ID in TMDB' },
              'phedex-tree-block-files'        :{type:'minmax', text:'Block-files',   tip:'number of files in the block' },
              'phedex-tree-block-bytes'        :{type:'minmax', text:'Block-bytes',   tip:'number of bytes in the block' },
              'phedex-tree-block-route-files'  :{type:'minmax', text:'Routed-files',  tip:'number of files in the block' },
              'phedex-tree-block-route-bytes'  :{type:'minmax', text:'Routed-bytes',  tip:'number of bytes in the block' },
              'phedex-tree-block-xfr-attempts' :{type:'minmax', text:'Xfer attempts', tip:'number of transfer attempts' },
              'phedex-tree-block-avg-attempts' :{type:'minmax', text:'Avg attempts',  tip:'average number of transfer attempts' },
              'phedex-tree-block-timerequest'  :{type:'minmax', text:'Request time',  tip:'Unix epoch seconds' }
            }
          },
          'Replica-level attributes':{
            map:{from:'phedex-tree-replica-', to:'R'},
            fields:{
              'phedex-tree-replica-node'       :{type:'regex',  text:'Node-name',     tip:'javascript regular expression' },
              'phedex-tree-replica-se'         :{type:'regex',  text:'SE name',       tip:'javascript regular expression' },
              'phedex-tree-replica-files'      :{type:'minmax', text:'Files',         tip:'number of files in the replica' },
              'phedex-tree-replica-bytes'      :{type:'minmax', text:'Bytes',         tip:'number of bytes in the replica' },
              'phedex-tree-replica-timecreate' :{type:'regex',  text:'Creation time', tip:'Unix epoch seconds' },
              'phedex-tree-replica-timeupdate' :{type:'regex',  text:'Update time',   tip:'Unix epoch seconds' },
              'phedex-tree-replica-subscribed' :{type:'yesno',  text:'Subscribed',    tip:'is the replica subscribed?' },
              'phedex-tree-replica-complete'   :{type:'yesno',  text:'Complete',      tip:'is the replica complete?' },
              'phedex-tree-replica-group'      :{type:'regex',  text:'Group name',    tip:'Group that owns this replica' }
            }
          }
        }
      },

      initMe: function(){
        for (var i in _directions) {
          _direction_map[_directions[i].key] = i;
        }
      },

      specificState: function(state) {
        if ( !state ) { return {dir:_direction}; }
        var i, k, v, kv, update=0, arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'dir'  && v != _direction ) { update++; _direction = v; }
        }
        if ( !update ) { return; }
        log('set dir='+_direction+' from state','info',this.me);
        this.getData();
      },

      changeDirection: function(arg) {
        _direction = this.direction_index(arg);
        this.getData();
      },

// A few utility functions, because the 'direction' has the semantics of a numeric value in some places, (to|from) in others, and a long string again elsewhere
      direction_key:      function()    { return _directions[_direction].key; },
      direction_text:     function()    { return _directions[_direction].text; },
      anti_direction_key: function()    { return _directions[1-_direction].key; },
      direction_index:    function(arg) { return _direction_map[arg]; },

// This is for dynamic data-loading into a treeview. The callback is called with a treeview-node as the argument.
// The node has a 'payload' hash which we create when we build the tree, it contains the necessary information to
// allow the callback to know which data-items to pick up and insert in the tree, once the data is loaded.
//
// This callback has to know how to construct payloads for child-nodes, which is not necessarily what we want. It would be
// nice if payloads for child-nodes could be constructed from knowledge of the data, rather than knowledge of the tree, but
// I'm not sure if that makes sense. Probably it doesn't
      callback_Treeview: function(node,result) {
        var replicas = result.block[0].replica,
            i, r, tNode;

        if ( replicas ) {
          for ( i in replicas ) {
            r = replicas[i];
            tNode = this.obj.addNode(
              { format:this.obj.meta.tree[2].format },
              [ r.node,r.se,r.files,r.bytes,r.time_create,r.time_update,r.subscribed,r.complete,r.group ],
              node
            );
            tNode.isLeaf = true;
          }
        }
      },

      fillBody: function() {
        var root  = this.tree.getRoot(),
            mtree = this.meta.tree,
            tLeaf, tNode, tNode1, tNode2, i, j, k, b, t,
            routes = this.data.route, r, tTested, tOK, p;
        if ( !routes.length ) {
          tLeaf = new Yw.TextNode({label: 'Nothing found, try another block or node...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in routes) {
          r = routes[i];
          tNode = this.addNode(
            { format:mtree[0].format },
            [ r.from,r.from_id,r.from_se,r.to,r.to_id,r.to_se,/*r.valid,*/r.priority ]
          );
          if ( r.block ) {
            if ( r.block.length == 1 ) { tNode.title = '1 block'; }
            else                       { tNode.title = r.block.length+' blocks'; }
            for (j in r.block) {
              b = r.block[j];
              p = { call:'BlockReplicas', obj:this, args:{ block:b.name }, callback:this.callback_Treeview };
              tNode1 = this.addNode(
                { format:mtree[1].format, payload:p },
                [ b.name,b.id,b.files,b.bytes,b.route_files,b.route_bytes,b.xfer_attempts,b.avg_attempts,b.time_request ],
                tNode
              );
            }
          } else { tNode.isLeaf = true; }
        }
        this.tree.render();
      },

      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( block || node ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
        if ( arr && typeof(arr) == 'object' ) {
          node = arr.node || node;
          if ( !node ) { return; }
          this.dom.title.innerHTML = 'setting parameters...';
          _sbx.notify(this.id,'setArgs');
        }
      },
      getData: function() {
        if ( !node ) {
          this.initData();
          return;
        }
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = 'fetching data...';
        var args = { valid:'n' }, magic = PxU.Sequence(); // TODO need better magic than tis!
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        args[this.direction_key()] = node;
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'RoutedBlocks', args:args, magic:magic } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        if ( this._magic != context.magic ) {
          log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
          return;
        }
        if ( !data.route ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data;
        this._magic = null;
        this.dom.title.innerHTML = ( node ? this.direction_key()+' '+node : '' ) + ( node && block ? ', ' : '' ) + ( block ? 'block='+block : '' );
        this.fillBody();
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','consistencyresults');
