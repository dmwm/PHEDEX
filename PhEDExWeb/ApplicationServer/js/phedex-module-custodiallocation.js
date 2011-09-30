PHEDEX.namespace('Module');

/** Node(s) at which a dataset is custodial, or datasets which are custodial at a node
 */
PHEDEX.Module.CustodialLocation=function(sandbox, string) {
/*
 * block          block name, can be multiple (*)
 * node           node name, can be multiple (*)
 * se             storage element name, can be multiple (*)
 * update_since   unix timestamp, only return replicas whose record was updated since this time
 * create_since   unix timestamp, only return replicas whose record was created since this time
 * complete       y or n, whether or not to require complete or incomplete blocks. Open blocks cannot be complete.  Default is to return either.
 * dist_complete  y or n, "distributed complete".  If y, then returns only block replicas for which at least one node has all files in the block.  If n, then returns block replicas for which no node has all the files in the block.  Open blocks cannot be dist_complete.  Default is to return either kind of block replica.
 * subscribed     y or n, filter for subscription. Default is to return either.
 * custodial      y or n. filter for custodial responsibility. Default is to return either. Set to 'y' explicitly in the call
 * group          group name. Default is to return replicas for any group.
*/
  var _sbx = sandbox;

  Yla(this,new PHEDEX.TreeView(sandbox,string));

  var node, block;
      opts = {
        update_since:     1,
        create_since:  9999,
        complete:      null,
        dist_complete: null,
        subscribed:    null,
        custodial:     null,
        group:         null
      },
      width = 1200;

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
          name: 'UpdateTimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return opts.update_since; },
            container: 'buttons',
            prefix:'Updated:',
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 weeks', 672:'Last 4 Weeks', 1342:'Last 8 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeUpdateTimebin'
            },
            title:'Time since last update'
          }
        },
        {
          name: 'CreateTimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return opts.create_since; },
            container: 'buttons',
            prefix:'Created:',
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 weeks', 672:'Last 4 Weeks', 1342:'Last 8 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeCreateTimebin'
            },
            title:'Time since creation'
          }
        }
      ],

      meta: {
        tree: [
          {
            width:1200,
            name:'Block',
            format: [
              {width:600,text:'Block Name', className:'phedex-tree-block-name',  otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], ctxKey:'block', spanWrap:true },
              {width: 60,text:'Block ID',   className:'phedex-tree-block-id',    otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 60,text:'Files',      className:'phedex-tree-block-files', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',      className:'phedex-tree-block-bytes', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
              {width: 60,text:'Open',       className:'phedex-tree-block-open',  otherClasses:'align-right', ctxArgs:'sort-alpha' }
            ]
          },
          {
            name:'Replica',
            format:[
              {width:160,text:'Node',        className:'phedex-tree-replica-node',       otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width:100,text:'SE',          className:'phedex-tree-replica-se',         otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
              {width: 80,text:'Files',       className:'phedex-tree-replica-files',      otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',       className:'phedex-tree-replica-bytes',      otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
              {width:180,text:'Create Time', className:'phedex-tree-replica-timecreate', otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToUTC' },
              {width:180,text:'Update Time', className:'phedex-tree-replica-timeupdate', otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToUTC' },
              {width: 90,text:'Subscribed',  className:'phedex-tree-replica-subscribed', otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60,text:'Complete',    className:'phedex-tree-replica-complete',   otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 90,text:'Group',       className:'phedex-tree-replica-group',      otherClasses:'align-right', ctxArgs:['group','sort-alpha'], ctxKey:'group' }
            ]
          }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-name'  :{type:'regex',  text:'Block-name',  tip:'javascript regular expression' },
              'phedex-tree-block-id'    :{type:'int',    text:'Block-ID',    tip:'ID of this block in TMDB' },
              'phedex-tree-block-files' :{type:'minmax', text:'Block-files', tip:'number of files in the block' },
              'phedex-tree-block-bytes' :{type:'minmax', text:'Block-bytes', tip:'number of bytes in the block' },
              'phedex-tree-block-open'  :{type:'yesno',  text:'Open',        tip:'is the block still open?' }
            }
          },
          'Replica-level attributes':{
            map:{from:'phedex-tree-replica-', to:'R'},
            fields:{
              'phedex-tree-replica-node'       :{type:'regex',  text:'Node-name',     tip:'javascript regular expression' },
              'phedex-tree-replica-se'         :{type:'regex',  text:'SE name',       tip:'javascript regular expression' },
              'phedex-tree-replica-files'      :{type:'minmax', text:'Files',         tip:'number of files in the replica' },
              'phedex-tree-replica-bytes'      :{type:'minmax', text:'Bytes',         tip:'number of bytes in the replica' },
              'phedex-tree-replica-timecreate' :{type:'minmax', text:'Creation time', tip:'Unix epoch seconds' },
              'phedex-tree-replica-timeupdate' :{type:'minmax', text:'Update time',   tip:'Unix epoch seconds' },
              'phedex-tree-replica-subscribed' :{type:'yesno',  text:'Subscribed',    tip:'is the replica subscribed?' },
              'phedex-tree-replica-complete'   :{type:'yesno',  text:'Complete',      tip:'is the replica complete?' },
              'phedex-tree-replica-group'      :{type:'regex',  text:'Group name',    tip:'Group that owns this replica' }
            }
          }
        }
      },

      initMe: function(){ },

      specificState: function(state) {
        var s, i, k, v, kv, update, arr;
        if ( !state ) {
          s = {};
//           if ( node )  { s.node =  node; }  // covered by 'target'
//           if ( block ) { s.block = block; } // covered by 'target'
          if ( opts.create_since ) { s.create_since = opts.create_since; }
          if ( opts.update_since ) { s.update_since = opts.update_since; }
          return s;
        }
        update=0;
        arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'create_since' && v != opts.create_since ) { update++; opts.create_since = v; }
          if ( k == 'update_since' && v != opts.update_since ) { update++; opts.update_since = v; }
        }
        if ( !update ) { return; }
        log('set create_since='+opts.create_since+', update_since='+opts.update_since+' from state','info',this.me);
        this.getData();
      },

      changeCreateTimebin: function(arg) {
        opts.create_since = parseInt(arg);
        this.getData();
      },
      changeUpdateTimebin: function(arg) {
        opts.update_since = parseInt(arg);
        this.getData();
      },
      fillBody: function() {
        var root = this.tree.getRoot(),
            tLeaf, tNode, tNode1, i, j, b, replicas, r,
            blocks = this.data.block;
        if ( !blocks.length )
        {
          tLeaf = new Yw.TextNode({label: 'Nothing found, try another block or node...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in blocks) {
          b = blocks[i];
          tNode = this.addNode(
            { format:this.meta.tree[0].format },
            [ b.name,b.id,b.files,b.bytes,b.is_open ]
          );
          if ( b.replica ) {
            if ( b.replica.length == 1 ) { tNode.title = '1 replica'; }
            else                         { tNode.title = b.replica.length+' replicas'; }
            for (j in b.replica) {
              r = b.replica[j];
              tNode1 = this.addNode(
                { format:this.meta.tree[1].format },
                [ r.node,r.se,r.files,r.bytes,r.time_create,r.time_update,r.subscribed,r.complete,r.group ],
                tNode
              );
              tNode1.isLeaf = true;
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
          block = arr.block || block;
          if ( !node && !block ) { return; }
          if ( node && block ) { node = null; }
          this.dom.title.innerHTML = 'setting parameters...';
          _sbx.notify(this.id,'setArgs');
        }
      },
      getData: function() {
        if ( !node && !block ) {
          this.initData();
          return;
        }
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = 'fetching data...';
        var args = { custodial:'y' }, magic = PxU.Sequence(), // TODO need better magic than this!
          now;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        if ( block ) { args.block = block; node = null; }
        if ( node  ) { args.node  = node; }
        now = PxU.epochAlign();
        if ( opts.update_since && opts.update_since != 9999 ) {
          args.update_since = now - 3600 * opts.update_since;
        }
        if ( opts.create_since && opts.create_since != 9999 ) {
          args.create_since = now - 3600 * opts.create_since;
        }
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'BlockReplicas', args:args, magic:magic } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        if ( this._magic != context.magic ) {
          log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
          return;
        }
        if ( !data.block ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data;
        this._magic = null;
        this.dom.title.innerHTML = ( node ? 'node='+node : '' ) + ( node && block ? ', ' : '' ) + ( block ? 'block='+block : '' );
        this.fillBody();
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','custodiallocation');
