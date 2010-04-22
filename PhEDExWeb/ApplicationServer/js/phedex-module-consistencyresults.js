PHEDEX.namespace('Module');

PHEDEX.Module.ConsistencyResults=function(sandbox, string) {
  var _sbx = sandbox;

  Yla(this,new PHEDEX.TreeView(sandbox,string));

  var node, block;
      opts = {
        status: null,
        kind:   null,
        since:     1,
      },
      width = 1200,
      PxUf = PHEDEX.Util.format;

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
            animate:false,
          }
        },
        {
          name: 'ContextMenu',
          source:'component-contextmenu',
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem',
            },
            container: 'buttons',
          },
        },
        {
          name: 'TimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return opts.since; },
            container: 'buttons',
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 9999:'Forever' },
            map: {
              onChange:'changeTimebin',
            },
            title:'Time since last update'
          }
        },
      ],

      meta: {
        tree: [
          {
            width:1200,
            name:'Node',
            format: [
              {width:160,text:'Node', className:'phedex-tree-node',    otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width: 60,text:'ID',   className:'phedex-tree-node-id', otherClasses:'align-right', ctxArgs:'sort-num',   hide:true },
              {width:100,text:'SE',   className:'phedex-tree-se',      otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
            ]
          },
          {
            name:'Block',
            format: [
              {width:600,text:'Block Name', className:'phedex-tree-block-name',  otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], ctxKey:'block', format:PxUf.spanWrap },
              {width: 60,text:'Block ID',   className:'phedex-tree-block-id',    otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 60,text:'Files',      className:'phedex-tree-block-files', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',      className:'phedex-tree-block-bytes', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes, hide:true },
            ]
          },
//           {
//             name:'Replica',
//             format:[
//               {width:160,text:'Node',        className:'phedex-tree-replica-node',       otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
//               {width:100,text:'SE',          className:'phedex-tree-replica-se',         otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true },
//               {width: 80,text:'Files',       className:'phedex-tree-replica-files',      otherClasses:'align-right', ctxArgs:'sort-num' },
//               {width: 80,text:'Bytes',       className:'phedex-tree-replica-bytes',      otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
//               {width:120,text:'Create Time', className:'phedex-tree-replica-timecreate', otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToGMT' },
//               {width:120,text:'Update Time', className:'phedex-tree-replica-timeupdate', otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToGMT' },
//               {width: 90,text:'Subscribed',  className:'phedex-tree-replica-subscribed', otherClasses:'align-right', ctxArgs:'sort-alpha' },
//               {width: 60,text:'Complete',    className:'phedex-tree-replica-complete',   otherClasses:'align-right', ctxArgs:'sort-alpha' },
//               {width: 80,text:'Group',       className:'phedex-tree-replica-group',      otherClasses:'align-right', ctxArgs:['group','sort-alpha'], ctxKey:'group' },
//             ]
//           }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
             'Node-level attributes':{
                map:{from:'phedex-tree-node-', to:'N'},
                fields:{
                  'phedex-tree-node-name' :{type:'regex',  text:'Node-name', tip:'javascript regular expression' },
                  'phedex-tree-node-id'   :{type:'int',    text:'Node-ID',   tip:'Node-ID in TMDB'},
                  'phedex-tree-node-se'   :{type:'regex',  text:'SE-name',   tip:'javascript regular expression'},
                },
              },
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-name'  :{type:'regex',  text:'Block-name',  tip:'javascript regular expression' },
              'phedex-tree-block-id'    :{type:'int',    text:'Block-ID',    tip:'ID of this block in TMDB' },
              'phedex-tree-block-files' :{type:'minmax', text:'Block-files', tip:'number of files in the block' },
              'phedex-tree-block-bytes' :{type:'minmax', text:'Block-bytes', tip:'number of bytes in the block' },
//               'phedex-tree-block-open'  :{type:'yesno',  text:'Open',        tip:'is the block still open?' }
            }
          },
//           'Replica-level attributes':{
//             map:{from:'phedex-tree-replica-', to:'R'},
//             fields:{
//               'phedex-tree-replica-node'       :{type:'regex',  text:'Node-name',     tip:'javascript regular expression' },
//               'phedex-tree-replica-se'         :{type:'regex',  text:'SE name',       tip:'javascript regular expression' },
//               'phedex-tree-replica-files'      :{type:'minmax', text:'Files',         tip:'number of files in the replica' },
//               'phedex-tree-replica-bytes'      :{type:'minmax', text:'Bytes',         tip:'number of bytes in the replica' },
//               'phedex-tree-replica-complete'   :{type:'yesno',  text:'Complete',      tip:'is the replica complete?' },
//               'phedex-tree-replica-timecreate' :{type:'regex',  text:'Creation time', tip:'Unix epoch seconds' },
//               'phedex-tree-replica-timeupdate' :{type:'regex',  text:'Update time',   tip:'Unix epoch seconds' },
//               'phedex-tree-replica-subscribed' :{type:'yesno',  text:'Subscribed',    tip:'is the replica subscribed?' },
//               'phedex-tree-replica-group'      :{type:'regex',  text:'Group name',    tip:'Group that owns this replica' }
//             }
//           }
        },
      },

      initMe: function(){ },

      specificState: function(state) {
        var s, i, k, v, kv, update, arr;
        if ( !state ) {
          s = {};
//           if ( node )  { s.node =  node; }  // covered by 'target'
//           if ( block ) { s.block = block; } // covered by 'target'
          if ( opts.since ) { s.since = opts.since; }
          return s;
        }
        update=0;
        arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'since' && v != opts.since ) { update++; opts.since = v; }
        }
        if ( !update ) { return; }
        log('set since='+opts.since+' from state','info',this.me);
        this.getData();
      },

      changeTimebin: function(arg) {
        opts.since = parseInt(arg);
        this.getData();
      },
      fillBody: function() {
        var root = this.tree.getRoot(),
            tLeaf, tNode, tNode1, tNode2, i, j, k, b, n, t,
            nodes = this.data.node;
        if ( !nodes.length )
        {
          tLeaf = new YAHOO.widget.TextNode({label: 'Nothing found, try another block or node...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in nodes) {
          n = nodes[i];
          tNode = this.addNode(
            { format:this.meta.tree[0].format },
            [ n.node,n.id,n.se ]
          );
          if ( n.block ) {
            tNode.title = n.block.length+' tests';
            for (j in n.block) {
              b = n.block[j];
              tNode1 = this.addNode(
                { format:this.meta.tree[1].format },
                [ b.name,b.id,b.files,b.bytes ],
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
        var args = { }, magic = PxU.Sequence(), // TODO need better magic than tis!
          d = new Date(),
          now = d.getTime()/1000;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        if ( block ) { args.block = block; node = null; }
        if ( node  ) { args.node  = node; }
        if ( opts.since && opts.since != 9999 ) {
          args.test_since = now - 3600 * opts.since;
        }
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'BlockTests', args:args, magic:magic } );
      },
      gotData: function(data,context) {
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        if ( this._magic != context.magic ) {
          log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
          return;
        }
        if ( !data.node ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data;
        this._magic = null;
        this.dom.title.innerHTML = ( node ? 'node='+node : '' ) + ( node && block ? ', ' : '' ) + ( block ? 'block='+block : '' );
        this.fillBody();
        _sbx.notify( this.id, 'gotData' );
      },
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','consistencyresults');