PHEDEX.namespace('Module.Subscriptions');

PHEDEX.Module.Subscriptions.Treeview=function(sandbox, string) {
  var _sbx = sandbox,
/** creation-time-window, in hours, counting backwards from 'now'. Set to '9999' for infinity.
 * @property create_since {integer}
 * @private
 */
      create_since = 24,
/** update-time-window, in hours, counting backwards from 'now'. Set to '9999' for infinity.
 * @property update_since {integer}
 * @private
 */
      update_since = 24,
      opts = {},
      width = 1200;
alert("I have no idea if this module works properly or not");
throw new Error("Developer clueless");

  Yla(this,new PHEDEX.TreeView(sandbox,string));
  Yla(opts, {
    width:width,
    height:300
  });

  log('Module: creating a genuine "'+string+'"','info',string);

  _construct = function() {
    return {
      decorators: [
        {
          name:'Headers',
          source:'component-control',
          parent:'control',
          payload:{
            target: 'extra',
            animate:false
          }
        },
        {
          name:'ContextMenu',
          source:'component-contextmenu'
        },
        {
          name:'cMenuButton',
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
          name: 'CreateTimeSelect',
          source: 'component-menu',
          payload:{
            type:'menu',
            prefix:'Created:',
            initial: function() { return create_since; }, // Use a function rather than a set value in case the value is updated by permalink-state before the decorator is built!
            container:'buttons',
            menu: { 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 weeks', 672:'Last 4 Weeks', 1342:'Last 8 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeCreateTimebin'
            }
          }
        },
        {
          name:'UpdateTimeSelect',
          source:'component-menu',
          payload:{
            type:'menu',
            prefix:'Updated:',
            initial: function() { return update_since; }, // Use a function rather than a set value in case the value is updated by permalink-state before the decorator is built!
            container:'buttons',
            menu: { 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 weeks', 672:'Last 4 Weeks', 1342:'Last 8 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeUpdateTimebin'
            }
          }
        }
      ],

      meta: {
//         isDynamic: true, // enable dynamic loading of data
        tree: [
          {
            width:1200,
            name:'Dataset',
            format: [
              {width:418, text:'Dataset', className:'phedex-tree-dataset-name',  otherClasses:'align-left',  ctxArgs:['dataset','sort-alpha'], ctxKey:'dataset', spanWrap:true },
              {width: 60, text:'Id',      className:'phedex-tree-dataset-id',    otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 50, text:'Open',    className:'phedex-tree-dataset-open',  otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60, text:'Files',   className:'phedex-tree-dataset-files', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 60, text:'Bytes',   className:'phedex-tree-dataset-bytes', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes }
            ]
          },
          {
            width:1200,
            name:'Block',
            format: [
              {width:400, text:'Block',   className:'phedex-tree-block-name',  otherClasses:'align-left',  ctxArgs:['dataset','sort-alpha'], ctxKey:'block', spanWrap:true },
              {width: 60, text:'Id',      className:'phedex-tree-block-id',    otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 50, text:'Open',    className:'phedex-tree-block-open',  otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60, text:'Files',   className:'phedex-tree-block-files', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 60, text:'Bytes',   className:'phedex-tree-block-bytes', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes }
            ]
          },
          {
            name:'Subscription',
            format:[
//    'LEVEL' => 'dataset'
              {width: 60, text:'Level',         className:'phedex-tree-subscription-level',         otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 80, text:'RequestID',     className:'phedex-tree-subscription-rid',           otherClasses:'align-right', ctxArgs:['rid','sort-num'], ctxKey:'rid' },
              {width:120, text:'Node',          className:'phedex-tree-subscription-node',          otherClasses:'align-left',  ctxArgs:['node', 'sort-alpha'], ctxKey:'node' },
              {width: 80, text:'Group',         className:'phedex-tree-subscription-group',         otherClasses:'align-left',  ctxArgs:['group','sort-alpha'], ctxKey:'group' },
              {width: 80, text:'Custodial',     className:'phedex-tree-subscription-custodial',     otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 40, text:'Move',          className:'phedex-tree-subscription-move',          otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60, text:'Priority',      className:'phedex-tree-subscription-priority',      otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 80, text:'Suspended',     className:'phedex-tree-subscription-suspended',     otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width:180, text:'Suspend until', className:'phedex-tree-subscription-suspend-until', otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToUTC', hide:true },
              {width:180, text:'Creation-time', className:'phedex-tree-subscription-creation-time', otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToUTC' },
              {width:180, text:'Update-time',   className:'phedex-tree-subscription-update-time',   otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToUTC' }
            ]
          }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
//           'Link-level attributes':{
//             map:{from:'phedex-tree-', to:'L'},
//             fields:{
//               'phedex-tree-from-node'   :{type:'regex',       text:'From Node-name',   tip:'javascript regular expression' },
//             }
//           },
//           'Block-level attributes':{
//             map:{from:'phedex-tree-block-', to:'B'},
//             fields:{
//               'phedex-tree-block-name'     :{type:'regex',  text:'Block-name',     tip:'javascript regular expression' },
//               'phedex-tree-block-id'       :{type:'int',    text:'Block-ID',       tip:'ID of this block in TMDB' },
//               'phedex-tree-block-state'    :{type:'regex',  text:'Block-state',    tip:"'assigned', 'exported', 'transferring', or 'transferred'" },
//               'phedex-tree-block-priority' :{type:'regex',  text:'Block-priority', tip:"'low', 'medium', or 'high'" },
//            'phedex-tree-block-files'    :{type:'minmax', text:'Block-files',    tip:'number of files in the block' }, // These are multi-value fields, so cannot filter on them.
//            'phedex-tree-block-bytes'    :{type:'minmax', text:'Block-bytes',    tip:'number of bytes in the block' }, // This is because of the way multiple file-states are represented
//               'phedex-tree-block-errors'   :{type:'minmax', text:'Block-errors',   tip:'number of errors for the block' }
//             }
//           },
//           'File-level attributes':{
//             map:{from:'phedex-tree-file-', to:'F'},
//             fields:{
//               'phedex-tree-file-name'   :{type:'regex',  text:'File-name',        tip:'javascript regular expression' },
//               'phedex-tree-file-id'     :{type:'minmax', text:'File-ID',          tip:'ID-range of files in TMDB' },
//               'phedex-tree-file-bytes'  :{type:'minmax', text:'File-bytes',       tip:'number of bytes in the file' },
//               'phedex-tree-file-errors' :{type:'minmax', text:'File-errors',      tip:'number of errors for the given file' },
//               'phedex-tree-file-cksum'  :{type:'regex',  text:'File-checksum(s)', tip:'javascript regular expression' }
//             }
//           }
        }
      },

      specificState: function(state) {
        if ( !state ) { return {create_since:create-since}; }
        var i, k, v, kv, update=0, arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'create_since' && v != create_since ) {
            update++; create_since = v;
            log('set '+k+'='+v+' from state','info',this.me);
          }
          if ( k == 'update_since' && v != update_since ) {
            update++; update_since = v;
            log('set '+k+'='+v+' from state','info',this.me);
          }
        }
        if ( !update ) { return; }
        this.getData();
      },

      changeCreateTimebin: function(arg) {
        create_since = parseInt(arg);
        this.getData();
      },
      changeUpdateTimebin: function(arg) {
        update_since = parseInt(arg);
        this.getData();
      },

      fillBody: function() {
        var root = this.tree.getRoot(),
            tNode, tNode1, tNode2, tNode3, tLeaf,
            data = this.data,
            i, j, k, subscriptions, s, dataset, d, blocks, b, id, is_open, files, bytes;
        if ( !data.length )
        {
          tLeaf = new Yw.TextNode({label: 'Nothing found, try widening the parameters...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in data) {
          d = data[i];
          tNode = this.addNode(
            { format:this.meta.tree[0].format },
            [ d.name,d.id,d.is_open,d.files,d.bytes ]
          );
          subscriptions = d.subscription;
          if ( subscriptions && subscriptions.length ) {
            tNode.title = subscriptions.length+' dataset-level subscriptions';
            for (j in subscriptions) {
              s = subscriptions[j];
              if ( !s.group ) { s.group = '-'; }
              tNode1 = this.addNode(
                { format:this.meta.tree[2].format },
                [ s.level,s.request,s.node,s.group,s.custodial,s.move,s.priority,s.suspended,s.suspend_until,s.time_create,s.time_update ],
                tNode
              );
              tNode1.isLeaf = true;
            }
          } else {
            tNode.isLeaf = true;
          }
          blocks = d.block;
          if ( blocks && blocks.length ) {
            tNode.isLeaf = false;
            if ( tNode.title ) { tNode.title += ', '; }
            if ( tNode.title ) { tNode.title += blocks.length+' blocks subscribed'; }
            for (j in blocks) {
              b = blocks[j];
              tNode2 = this.addNode(
                { format:this.meta.tree[1].format },
                [ b.name,b.id,b.is_open,b.files,b.bytes ],
                tNode
              );
              subscriptions = b.subscription;
              if ( subscriptions && subscriptions.length ) {
                tNode.title = subscriptions.length+' subscriptions';
                for (k in subscriptions) {
                  s = subscriptions[k];
                  if ( !s.group ) { s.group = '-'; }
                  tNode3 = this.addNode(
                    { format:this.meta.tree[2].format },
                    [ s.level,s.request,s.node,s.group,s.custodial,s.move,s.priority,s.suspended,s.suspend_until,s.time_create,s.time_update ],
                    tNode2
                  );
                  tNode3.isLeaf = true;
                }
              }
            }
          } else {
            tNode.isLeaf = true;
          }
        }
        this.tree.render();
      },

      initData: function() {
        _sbx.notify( this.id, 'initData' );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
        if ( !arr ) { return; }
//         if ( arr && arr.node ) {
//           node = arr.node;
//           if ( !node ) { return; }
//           this.dom.title.innerHTML = 'setting parameters...';
//           _sbx.notify(this.id,'setArgs');
//         }
      },
      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        var args={}, magic=create_since+'_'+update_since, now=new Date().getTime()/1000, i;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        args.create_since = (create_since==9999) ? 0 : PxU.epochAlign(now - create_since*3600,3600);
        args.update_since = (update_since==9999) ? 0 : PxU.epochAlign(now - update_since*3600,3600);
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'Subscriptions', args:args, magic:magic } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        if ( this._magic != context.magic ) {
          log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
          return;
        }
        if ( !data.dataset ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.dataset;
        this._magic = null;
        this.dom.title.innerHTML = 'datasvc returned OK';
        this.fillBody();
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','subscriptions.treeview');
