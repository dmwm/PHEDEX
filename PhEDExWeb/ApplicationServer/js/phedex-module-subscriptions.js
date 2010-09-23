PHEDEX.namespace('Module');

PHEDEX.Module.Subscriptions=function(sandbox, string) {
  var _sbx = sandbox,
/** time-window, in hours. Set this value in the code to set the default
 * @property _time {integer}
 * @private
 */
      _time = 24,
      opts = {},
      width = 1200;

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
          name: 'TimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return _time; }, // Use a function rather than a set value in case the value is updated by permalink-state before the decorator is built!
            container: 'buttons',
            menu: { 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 weeks', 672:'Last 4 Weeks', 1342:'Last 8 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeTimebin'
            }
          }
        },
      ],

      meta: {
//         isDynamic: true, // enable dynamic loading of data
        tree: [
          {
            width:1200,
            name:'Dataset',
            format: [
              {width:400,text:'Dataset', className:'phedex-tree-dataset-name',  otherClasses:'align-left',  ctxArgs:['dataset','sort-alpha'], ctxKey:'dataset', spanWrap:true },
              {width:60, text:'Id',      className:'phedex-tree-dataset-id',    otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width:60, text:'Open',    className:'phedex-tree-dataset-open',  otherClasses:'align-right', ctxArgs:'sort-num' },
              {width:60, text:'Files',   className:'phedex-tree-dataset-files', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width:60, text:'Bytes',   className:'phedex-tree-dataset-bytes', otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes }
            ]
          },
          {
            name:'File',
            format:[
//    'LEVEL' => 'dataset'
              {width:100, text:'RequestID',     className:'phedex-tree-subs-rid',           otherClasses:'align-right', ctxArgs:'rid', ctxKey:'rid' },
              {width:160, text:'Node',          className:'phedex-tree-subs-node',          otherClasses:'align-right', ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width:100, text:'Group',         className:'phedex-tree-subs-group',         otherClasses:'align-right', ctxArgs:['group','sort-alpha'], ctxKey:'group' },
              {width:60,  text:'Custodial',     className:'phedex-tree-subs-custodial',     otherClasses:'align-right' },
              {width:60,  text:'Move',          className:'phedex-tree-subs-move',          otherClasses:'align-right' },
              {width:60,  text:'Priority',      className:'phedex-tree-subs-priority',      otherClasses:'align-right', ctxArgs:['sort-alpha'] },
              {width:100, text:'Suspended',     className:'phedex-tree-subs-suspended',     otherClasses:'align-right' },
              {width:160, text:'Suspend until', className:'phedex-tree-subs-suspend-until', otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToGMT' },
              {width:160, text:'Creation-time', className:'phedex-tree-subs-creation-time', otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToGMT' },
              {width:160, text:'Update-time',   className:'phedex-tree-subs-update-time',   otherClasses:'align-right', ctxArgs:['sort-alpha'], format:'UnixEpochToGMT' }
            ]
          }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
          'Link-level attributes':{
            map:{from:'phedex-tree-', to:'L'},
            fields:{
              'phedex-tree-from-node'   :{type:'regex',       text:'From Node-name',   tip:'javascript regular expression' },
            }
          },
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
//               'phedex-tree-block-name'     :{type:'regex',  text:'Block-name',     tip:'javascript regular expression' },
//               'phedex-tree-block-id'       :{type:'int',    text:'Block-ID',       tip:'ID of this block in TMDB' },
//               'phedex-tree-block-state'    :{type:'regex',  text:'Block-state',    tip:"'assigned', 'exported', 'transferring', or 'transferred'" },
//               'phedex-tree-block-priority' :{type:'regex',  text:'Block-priority', tip:"'low', 'medium', or 'high'" },
//            'phedex-tree-block-files'    :{type:'minmax', text:'Block-files',    tip:'number of files in the block' }, // These are multi-value fields, so cannot filter on them.
//            'phedex-tree-block-bytes'    :{type:'minmax', text:'Block-bytes',    tip:'number of bytes in the block' }, // This is because of the way multiple file-states are represented
//               'phedex-tree-block-errors'   :{type:'minmax', text:'Block-errors',   tip:'number of errors for the block' }
            }
          },
          'File-level attributes':{
            map:{from:'phedex-tree-file-', to:'F'},
            fields:{
//               'phedex-tree-file-name'   :{type:'regex',  text:'File-name',        tip:'javascript regular expression' },
//               'phedex-tree-file-id'     :{type:'minmax', text:'File-ID',          tip:'ID-range of files in TMDB' },
//               'phedex-tree-file-bytes'  :{type:'minmax', text:'File-bytes',       tip:'number of bytes in the file' },
//               'phedex-tree-file-errors' :{type:'minmax', text:'File-errors',      tip:'number of errors for the given file' },
//               'phedex-tree-file-cksum'  :{type:'regex',  text:'File-checksum(s)', tip:'javascript regular expression' }
            }
          }
        }
      },

      specificState: function(state) {
        if ( !state ) { return {time:_time}; }
        var i, k, v, kv, update=0, arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'time' && v != _time ) { update++; _time = v; }
        }
        if ( !update ) { return; }
        log('set time='+_time+' from state','info',this.me);
        this.getData();
      },

      changeTimebin: function(arg) {
        _time = parseInt(arg);
        this.getData();
      },

      fillBody: function() {
        var root = this.tree.getRoot(),
            tNode, tNode1, tLeaf,
            data = this.data,
            i, j, subscriptions, s, dataset, d, block, b, id, is_open, files, bytes;
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
          if ( subscriptions.length ) {
            tNode.title = subscriptions.length+' subscriptions';
            for (j in subscriptions) {
              s = subscriptions[j];
              tNode1 = this.addNode(
                { format:this.meta.tree[1].format },
                [ s.request,s.node,s.group,s.custodial,s.move,s.priority,s.suspended,s.suspend_until,s.time_create,s.time_update ],
                tNode
              );
              tNode1.isLeaf = true;
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
        var args={}, magic=_time, now=new Date().getTime()/1000;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        args.create_since = PxU.epochAlign(now-_time*3600,3600);;
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'Subscriptions', args:args, magic:magic } );
      },
      gotData: function(data,context) {
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
        _sbx.notify( this.id, 'gotData' );
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','subscriptions');
