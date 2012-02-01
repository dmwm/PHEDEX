PHEDEX.namespace('Module');

PHEDEX.Module.LinkView=function(sandbox, string) {
  var _sbx = sandbox,
/** time-window, in hours. Set this value in the code to set the default
 * @property _time {integer}
 * @private
 */
      _time = 6,
/** direction, represented numerically. Set this value in the code to set the default
 * @property _direction {integer}
 * @private
 */
      _direction = 0,

      _direction_map = [],
      _directions = [
        { key:'to',   text:'Incoming Links' },
        { key:'from', text:'Outgoing Links' }
      ],
      node,
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
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week' },
            map: {
              onChange:'changeTimebin'
            }
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
            name:'Link',
            format: [
              {width:160,text:'From Node',     className:'phedex-tree-from-node',   otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width:160,text:'To Node',       className:'phedex-tree-to-node',     otherClasses:'align-left',  ctxArgs:['node','sort-alpha'], ctxKey:'node' },
              {width:130,text:'Done',          className:'phedex-tree-done',        otherClasses:'align-right', ctxArgs:['sort-files','sort-bytes'], format:PxUf.filesBytes },
              {width:130,text:'Failed',        className:'phedex-tree-failed',      otherClasses:'align-right', ctxArgs:['sort-files','sort-bytes'], format:PxUf.filesBytes },
              {width:130,text:'Expired',       className:'phedex-tree-expired',     otherClasses:'align-right', ctxArgs:['sort-files','sort-bytes'], format:PxUf.filesBytes },
              {width: 70,text:'Rate',          className:'phedex-tree-rate',        otherClasses:'align-right', ctxArgs:'sort-num', format:function(x){return PxUf.bytes(x)+'/s';} },
              {width: 70,text:'Quality',       className:'phedex-tree-quality',     otherClasses:'align-right', ctxArgs:'sort-num', format:PxU.format['%'] },
              {width:130,text:'Queued',        className:'phedex-tree-queued',      otherClasses:'align-right', ctxArgs:['sort-files','sort-bytes'], format:PxUf.filesBytes },
              {width: 90,text:'Link Errors',   className:'phedex-tree-error-total', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width:110,text:'Logged Errors', className:'phedex-tree-error-log',   otherClasses:'align-right', ctxArgs:'sort-num', hide:true }
            ]
          },
          {
            name:'Block',
            format: [
              {width:600,text:'Block Name',   className:'phedex-tree-block-name',     otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], ctxKey:'block', spanWrap:true },
              {width: 80,text:'Block ID',     className:'phedex-tree-block-id',       otherClasses:'align-right', ctxArgs:['block','sort-num'],   ctxKey:'blockid' },
              {width: 80,text:'State',        className:'phedex-tree-block-state',    otherClasses:'phedex-tnode-auto-height' },
              {width: 80,text:'Priority',     className:'phedex-tree-block-priority', otherClasses:'phedex-tnode-auto-height' },
              {width: 80,text:'Files',        className:'phedex-tree-block-files',    otherClasses:'phedex-tnode-auto-height align-right' },
              {width: 80,text:'Bytes',        className:'phedex-tree-block-bytes',    otherClasses:'phedex-tnode-auto-height align-right' },
              {width: 90,text:'Block Errors', className:'phedex-tree-block-errors',   otherClasses:'align-right', ctxArgs:'sort-num' }
            ]
          },
          {
            name:'File',
            format:[
              {width:600,text:'File Name',   className:'phedex-tree-file-name',   otherClasses:'align-left',  ctxArgs:['file','sort-alpha'], ctxKey:'file', spanWrap:true },
              {width: 80,text:'File ID',     className:'phedex-tree-file-id',     otherClasses:'align-right', ctxArgs:['file','sort-num'],   ctxKey:'fileid' },
              {width: 80,text:'Bytes',       className:'phedex-tree-file-bytes',  otherClasses:'align-right', ctxArgs:'sort-num', format:PxUf.bytes },
              {width: 90,text:'File Errors', className:'phedex-tree-file-errors', otherClasses:'align-right', ctxArgs:'sort-num' },
              {width:140,text:'Checksum',    className:'phedex-tree-file-cksum',  otherClasses:'align-right', hide:true }
            ]
          }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
          'Link-level attributes':{
            map:{from:'phedex-tree-', to:'L'},
            fields:{
              'phedex-tree-from-node'   :{type:'regex',       text:'From Node-name',   tip:'javascript regular expression' },
              'phedex-tree-to-node'     :{type:'regex',       text:'To Node-name',     tip:'javascript regular expression' },
              'phedex-tree-rate'        :{type:'minmaxFloat', text:'Transfer-rate',    tip:'transfer rate in bytes/sec' },
              'phedex-tree-quality'     :{type:'minmaxPct',   text:'Transfer-quality', tip:'transfer-quality in percent', preprocess:'toPercent' },
              'phedex-tree-done'        :{type:'minmax',      text:'Files-done',       tip:'number of files successfully transferred' },
              'phedex-tree-failed'      :{type:'minmax',      text:'Files-failed',     tip:'number of failed transfer attempts' },
              'phedex-tree-expired'     :{type:'minmax',      text:'Files-expired',    tip:'number of expired files' },
              'phedex-tree-queued'      :{type:'minmax',      text:'Files-queued',     tip:'number of files queued for transfer' },
              'phedex-tree-error-total' :{type:'minmax',      text:'Link-errors',      tip:'number of link-errors' },
              'phedex-tree-error-log'   :{type:'minmax',      text:'Logged-errors',    tip:'number of logged-errors' }
            }
          },
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-name'     :{type:'regex',  text:'Block-name',     tip:'javascript regular expression' },
              'phedex-tree-block-id'       :{type:'int',    text:'Block-ID',       tip:'ID of this block in TMDB' },
              'phedex-tree-block-state'    :{type:'regex',  text:'Block-state',    tip:"'assigned', 'exported', 'transferring', or 'transferred'" },
              'phedex-tree-block-priority' :{type:'regex',  text:'Block-priority', tip:"'low', 'medium', or 'high'" },
//            'phedex-tree-block-files'    :{type:'minmax', text:'Block-files',    tip:'number of files in the block' }, // These are multi-value fields, so cannot filter on them.
//            'phedex-tree-block-bytes'    :{type:'minmax', text:'Block-bytes',    tip:'number of bytes in the block' }, // This is because of the way multiple file-states are represented
              'phedex-tree-block-errors'   :{type:'minmax', text:'Block-errors',   tip:'number of errors for the block' }
            }
          },
          'File-level attributes':{
            map:{from:'phedex-tree-file-', to:'F'},
            fields:{
              'phedex-tree-file-name'   :{type:'regex',  text:'File-name',        tip:'javascript regular expression' },
              'phedex-tree-file-id'     :{type:'minmax', text:'File-ID',          tip:'ID-range of files in TMDB' },
              'phedex-tree-file-bytes'  :{type:'minmax', text:'File-bytes',       tip:'number of bytes in the file' },
              'phedex-tree-file-errors' :{type:'minmax', text:'File-errors',      tip:'number of errors for the given file' },
              'phedex-tree-file-cksum'  :{type:'regex',  text:'File-checksum(s)', tip:'javascript regular expression' }
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
        if ( !state ) { return {time:_time, dir:_direction}; }
        var i, k, v, kv, update=0, arr = state.split(' ');
        for (i in arr) {
          kv = arr[i].split('=');
          k = kv[0];
          v = kv[1];
          if ( k == 'time' && v != _time      ) { update++; _time = v; }
          if ( k == 'dir'  && v != _direction ) { update++; _direction = v; }
        }
        if ( !update ) { return; }
        log('set time='+_time+', dir='+_direction+' from state','info',this.me);
        this.getData();
      },

      changeTimebin: function(arg) {
        _time = parseInt(arg);
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
        var link = result.link[0],
            p    = node.payload,
            obj  = p.obj,
            call = p.call; // copy the value because of the dangers of shallow-copying in javascript
        if ( !link  ) { return; }
        if ( !link.transfer_queue ) { return; }
//      distinguish the type of node to build based on what the 'call' was that got me here. These 'if' clauses are too long for my liking...
        if ( call == 'TransferQueueBlocks' )
        {
          var errors = [];
          for (var k in p.data.errors)
          {
            var b = p.data.errors[k];
            errors[b.id] = { num_errors:b.num_errors, file:b.file };
          }
          var blocks = [];
          for (var i in link.transfer_queue )
          {
            var tq = link.transfer_queue[i];
            for (var j in tq.block)
            {
              var block;
              block = tq.block[j];
              if ( ! blocks[block.id] ) { blocks[block.id] = {id:block.id, name:block.name, queue:[]}; }
              blocks[block.id].queue.push({state:tq.state, priority:tq.priority, files:block.files, bytes: block.bytes});

//            Manual deep-copy of payload, prevents overwriting contents...
              var payload = [];
              payload.opts = {};
              for (var l in p.opts) { payload.opts[l] = p.opts[l];  }
              payload.data = {};
              for (var l in p.data) { payload.data[l] = p.data[l];  }
              payload.args = {};
              payload.args.from = p.args.from;
              payload.args.to   = p.args.to;
              payload.obj       = p.obj;
              payload.callback  = p.callback;

              payload.call = 'TransferQueueFiles';
              payload.data = errors;
              payload.args.block = block.name;
              blocks[block.id].payload = payload;
              var num_errors = 0;
              if ( errors[block.id] ) { num_errors = errors[block.id].num_errors; }
              blocks[block.id].num_errors = num_errors;
            }
          }
          for (var i in blocks) {
            var block = blocks[i],
                state = priority = files = bytes = '';
            for (var j in block.queue) {
              state    += block.queue[j].state+'<br/>';
              priority += block.queue[j].priority+'<br/>';
              files    += block.queue[j].files+'<br/>';
              bytes    += PxU.format.bytes(block.queue[j].bytes)+'<br/>';
            }
            var tNode = obj.addNode(
              { format:obj.meta.tree[1].format, payload:block.payload },
              [ block.name, block.id, state, priority, files, bytes, block.num_errors ],
              node
            );
          }
        }
        else if ( call == 'TransferQueueFiles' )
        {
          for (var i in link.transfer_queue )
          {
            var tq = link.transfer_queue[i];
            for (var j in tq.block)
            {
              var block = tq.block[j],
                  errors = [];
              if (p.data[block.id])
              {
                var files = p.data[block.id].file;
                for (var f in files)
                {
                  errors[files[f].id] = files[f].num_errors;
                }
              }
              for (var k in block.file)
              {
                var file = block.file[k],
                    num_errors = errors[file.id] || 0,
                    tNode = obj.addNode(
                  {format:obj.meta.tree[2].format},
                  [ file.name, file.id, file.bytes, num_errors, file.checksum ],
                  node
                 );
                tNode.isLeaf = true;
              }
            }
          }
        }
        else
        {
          var errstr = 'No action specified for handling callback data for "'+p.callback+'"';
          log(errstr,'error','linkview');
          throw new Error(errstr);
        }
      },

      fillBody: function() {
        var root = this.tree.getRoot(),
            antidirection=this.anti_direction_key(),
            tLeaf, i, j,
            data = this.data,
            link_errors, tNode, p, d, e, h, node;
        if ( !data.hist.length )
        {
          tLeaf = new Yw.TextNode({label: 'Nothing found, try another node or widen the parameters...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (i in data.hist) {
          h = data.hist[i];
          node = h[antidirection];
          d = {};
          e = {num_errors:0};
          for (j in this.data.queue) {
            if (data.queue[j][antidirection]==node) {
              d = data.queue[j];
              break;
            }
          }
          for (j in data.error) {
            if (data.error[j][antidirection]==node) {
              e = data.error[j];
              break;
            }
          }

          var done_bytes = PxU.sumArrayField(h.transfer,'done_bytes'),
              quality    = PxU.sumArrayField(h.transfer,'quality',parseFloat),
              done   = { files:PxU.sumArrayField(h.transfer,'done_files'), bytes:done_bytes },
              rate   = done_bytes/parseInt(h.transfer[0].binwidth),
              fail   = { files:PxU.sumArrayField(h.transfer,'fail_files'),   bytes:PxU.sumArrayField(h.transfer,'fail_bytes')   },
              expire = { files:PxU.sumArrayField(h.transfer,'expire_files'), bytes:PxU.sumArrayField(h.transfer,'expire_bytes') },
              queue  = { files:PxU.sumArrayField(d.transfer_queue,'files'),  bytes:PxU.sumArrayField(d.transfer_queue,'bytes')  };
          if ( isNaN(quality) ) { quality = 0; } // seems h.transfer[i].quality can be 'null', which gives NaN in parseFloat
          quality /= h.transfer.length;

//        Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level.
//        I did see a better way to do this in the YUI docs, but will find that later...
//        populate the payload with everything that might be useful, so I don't need widget-specific knowledge in the parent
//        payload.args is for the data-service call, payload.opts is for the callback to drive the next stage of processing
          p = { call:'TransferQueueBlocks', obj:this , args:{}, opts:{}, data:{}, callback:this.callback_Treeview };
          p.args.from = h.from;
          p.args.to   = h.to;
          p.opts.node = h[antidirection];
          p.opts.direction = this.direction_index(_direction);
          p.data.errors    = e.block;
          link_errors = PxU.sumArrayField(e.block,'num_errors');
          tNode = this.addNode(
            { format:this.meta.tree[0].format, payload:p },
            [ h.from,h.to,done,fail,expire,rate,quality,queue,link_errors,e.num_errors ]
          );
          if ( !queue.files ) { tNode.isLeaf = true; } // a link with no queue can have no children worth seeing, declare it to be a leaf-node
        }
        this.tree.render();
      },

      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( node ) {
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
        if ( arr && arr.node ) {
          node = arr.node;
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
        this.dom.title.innerHTML = this.me+': fetching data...';
        var args={}, args1={}, magic = _time+' '+_direction;
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        args[this.direction_key()] = args1[this.direction_key()] = node;
        this.data = {};
        this.truncateTree();
        this.tree.render();
        _sbx.notify( this.id, 'getData', { api:'TransferQueueStats', args:args, magic:magic } );
        _sbx.notify( this.id, 'getData', { api:'ErrorLogSummary',    args:args, magic:magic } );
        args1.binwidth = _time*3600;
        _sbx.notify( this.id, 'getData', { api:'TransferHistory',    args:args1, magic:magic } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        if ( this._magic != context.magic ) {
          log('Old data has lost its magic: "'+this._magic+'" != "'+context.magic+'"','warn',this.me);
          return;
        }
        if ( !data.link ) {
          throw new Error('data incomplete for '+context.api);
        }
        if ( context.api == 'TransferQueueStats' ) { this.data.queue = data.link; }
        if ( context.api == 'TransferHistory' )    { this.data.hist  = data.link; }
        if ( context.api == 'ErrorLogSummary' )    { this.data.error = data.link; }
        if ( this.data.hist && this.data.error && this.data.queue )
        {
          this._magic = null;
          this.dom.title.innerHTML = node;
          this.fillBody();
        }
        else { banner('Received '+context.api+' data, waiting for more...'); }
      }
    };
  };
  Yla(this,_construct(),true);
  return this;
}

log('loaded...','info','linkview');
