PHEDEX.namespace('Module');

PHEDEX.Module.ConsistencyResults=function(sandbox, string) {
  var _sbx = sandbox;

  Yla(this,new PHEDEX.TreeView(sandbox,string));

  var node, block;
      opts = {
        status: null,
        kind:   null,
        since:     1
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
          name: 'TimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: function() { return opts.since; },
            container: 'buttons',
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week', 336:'Last 2 Weeks', 672:'Last 4 Weeks', 9999:'Forever' },
            map: {
              onChange:'changeTimebin'
            },
            title:'Time since last update'
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
              {width:160,text:'Node', className:'phedex-tree-node',    otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width: 60,text:'ID',   className:'phedex-tree-node-id', otherClasses:'align-right', ctxArgs:'sort-num',   hide:true },
              {width:200,text:'SE',   className:'phedex-tree-node-se', otherClasses:'align-right', ctxArgs:'sort-alpha', hide:true }
            ]
          },
          {
            name:'Block',
            format: [
              {width:600,text:'Block Name', className:'phedex-tree-block-name',   otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], ctxKey:'block', spanWrap:true },
              {width: 60,text:'Block ID',   className:'phedex-tree-block-id',     otherClasses:'align-right', ctxArgs:'sort-num', hide:true },
              {width: 90,text:'Status',     className:'phedex-tree-block-status', otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 60,text:'Files',      className:'phedex-tree-block-files',  otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Bytes',      className:'phedex-tree-block-bytes',  otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes, hide:true }
            ]
          },
          {
            name:'Test',
            format:[
              {width: 60,text:'ID',           className:'phedex-tree-test-id',           otherClasses:'align-left',  ctxArgs:'sort-alpha' },
              {width: 60,text:'Kind',         className:'phedex-tree-test-kind',         otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width:180,text:'Report Time',  className:'phedex-tree-test-timereport',   otherClasses:'align-right', ctxArgs:'sort-alpha', format:'UnixEpochToUTC' },
              {width: 90,text:'Status',       className:'phedex-tree-test-status',       otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width: 80,text:'Files',        className:'phedex-tree-test-files',        otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Files OK',     className:'phedex-tree-test-files-ok',     otherClasses:'align-right', ctxArgs:'sort-num' },
              {width: 80,text:'Files Tested', className:'phedex-tree-test-files-tested', otherClasses:'align-right', ctxArgs:'sort-num' }
            ]
          },
          {
            name:'Files',
            format:[
              {width:600,text:'File Name',  className:'phedex-tree-file-name',   otherClasses:'align-left',  ctxArgs:['file','sort-alpha'], ctxKey:'file', spanWrap:true },
              {width: 80,text:'File ID',    className:'phedex-tree-file-id',     otherClasses:'align-right', ctxArgs:['file','sort-num'],   ctxKey:'fileid', hide:true },
              {width: 80,text:'Bytes',      className:'phedex-tree-file-bytes',  otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
              {width: 90,text:'Status',     className:'phedex-tree-file-status', otherClasses:'align-right', ctxArgs:'sort-alpha' },
              {width:200,text:'Checksum',   className:'phedex-tree-file-cksum',  otherClasses:'align-right', hide:true }
            ]
          }
        ],

// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
         'Node-level attributes':{
            map:{from:'phedex-tree-node-', to:'N'},
            fields:{
              'phedex-tree-node-name' :{type:'regex',  text:'Node-name', tip:'javascript regular expression' },
              'phedex-tree-node-id'   :{type:'int',    text:'Node-ID',   tip:'Node-ID in TMDB'},
              'phedex-tree-node-se'   :{type:'regex',  text:'SE-name',   tip:'javascript regular expression'}
            }
          },
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-name'  :{type:'regex',  text:'Block-name',  tip:'javascript regular expression' },
              'phedex-tree-block-id'    :{type:'int',    text:'Block-ID',    tip:'Block-ID in TMDB' },
              'phedex-tree-block-files' :{type:'minmax', text:'Block-files', tip:'number of files in the block' },
              'phedex-tree-block-bytes' :{type:'minmax', text:'Block-bytes', tip:'number of bytes in the block' }
            }
          },
          'Test-level attributes':{
            map:{from:'phedex-tree-test-', to:'T'},
            fields:{
              'phedex-tree-test-id'           :{type:'regex',  text:'ID',           tip:'Test-ID in TMDB' },
              'phedex-tree-test-kind'         :{type:'regex',  text:'Kind',         tip:'javascript regular expression' },
              'phedex-tree-test-timereport'   :{type:'minmax', text:'Report time',  tip:'Unix epoch seconds' },
//  status          "OK", "Fail", "Queued", "Active", "Timeout", "Expired", "Suspended", "Error", "Rejected" or "Indeterminate"
              'phedex-tree-test-status'       :{type:'regex',  text:'Status',       tip:'javascript regular expression' },
              'phedex-tree-test-files'        :{type:'minmax', text:'Files',        tip:'number of files' },
              'phedex-tree-test-files-ok'     :{type:'minmax', text:'Files OK',     tip:'number of files OK' },
              'phedex-tree-test-files-tested' :{type:'minmax', text:'Files tested', tip:'number of files tested' }
            }
          },
          'File-level attributes':{
            map:{from:'phedex-tree-file-', to:'F'},
            fields:{
              'phedex-tree-file-name'   :{type:'regex',  text:'File-name',        tip:'javascript regular expression' },
              'phedex-tree-file-id'     :{type:'minmax', text:'File-ID',          tip:'ID-range of files in TMDB' },
              'phedex-tree-file-bytes'  :{type:'minmax', text:'File-bytes',       tip:'number of bytes in the file' },
              'phedex-tree-file-status' :{type:'regex',  text:'File-status',      tip:'test-status for the given file' },
              'phedex-tree-file-cksum'  :{type:'regex',  text:'File-checksum(s)', tip:'javascript regular expression' }
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

// This is for dynamic data-loading into a treeview. The callback is called with a treeview-node as the argument.
// The node has a 'payload' hash which we create when we build the tree, it contains the necessary information to
// allow the callback to know which data-items to pick up and insert in the tree, once the data is loaded.
//
// This callback has to know how to construct payloads for child-nodes, which is not necessarily what we want. It would be
// nice if payloads for child-nodes could be constructed from knowledge of the data, rather than knowledge of the tree, but
// I'm not sure if that makes sense. Probably it doesn't
      callback_Treeview: function(node,result) {
        var files = result.node[0].block[0].test[0].file,
            p    = node.payload,
            obj  = p.obj,
            i, f, tNode;

        for (i in files) {
          f = files[i];
          tNode = obj.addNode(
            { format:obj.meta.tree[3].format },
            [ f.name, f.id, f.bytes, f.status, f.checksum ],
            node
          );
          tNode.isLeaf = true;
        }
      },

      fillBody: function() {
        var root  = this.tree.getRoot(),
            mtree = this.meta.tree,
            tLeaf, tNode, tNode1, tNode2, i, j, k, b, n, t, status,
            nodes = this.data.node, tTested, tOK, p;
        if ( !nodes.length ) {
          tLeaf = new Yw.TextNode({label: 'Nothing found, try another block or node...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in nodes) {
          n = nodes[i];
          tNode = this.addNode(
            { format:mtree[0].format },
            [ n.node,n.id,n.se ]
          );
          if ( n.block ) {
            if ( n.block == 1 ) { tNode.title = '1 block'; }
            else                { tNode.title = n.block.length+' blocks'; }
            for (j in n.block) {
              b = n.block[j];
              status = 'OK';
              if ( b.test ) {
                for (k in b.test) {
                  t = b.test[k];
                  if ( t.files_tested != t.files_ok ) { status = 'Not OK'; }
                }
              }
              tNode1 = this.addNode(
                { format:mtree[1].format },
                [ b.name,b.id,status,b.files,b.bytes ],
                tNode
              );
              if ( b.test ) {
                tFiles = tTested = tOK = 0;
                for (k in b.test) {
                  t = b.test[k];
                  p = { call:'BlockTestFiles', obj:this, args:{ test:t.id }, callback:this.callback_Treeview };
                  tNode2 = this.addNode(
                    { format:mtree[2].format, payload:p },
                    [ t.id,t.kind,t.time_reported,t.status,t.files,t.files_ok,t.files_tested ],
                    tNode1
                  );
                  tTested += parseInt(t.files_tested);
                  tOK     += parseInt(t.files_ok);
                }
                if ( b.test.kength = 1 ) { tNode1.title = '1 test'; }
                else                     { tNode1.title = b.test.length+' tests'; }
                tNode1.title += ' ('+tOK+'/'+tTested+' tested/OK)';
              } else { tNode1.isLeaf = true; }
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
        var args = { }, magic = PxU.Sequence(), // TODO need better magic than this!
          d, now;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        if ( block ) { args.block = block; node = null; }
        if ( node  ) { args.node  = node; }
        if ( opts.since ) {
          if ( opts.since != 9999 ) {
            now = PxU.epochAlign(0,300);
            args.test_since = now - 3600 * opts.since;
          } else {
            args.test_since = 0;
          }
        }
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'BlockTests', args:args, magic:magic } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
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
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','consistencyresults');
