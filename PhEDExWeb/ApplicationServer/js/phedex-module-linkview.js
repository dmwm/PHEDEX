PHEDEX.namespace('Module.LinkView','Module.TransferQueueBlock','Module.TransferQueueFiles');

PHEDEX.Module.LinkView=function(sandbox, string) {
  var _sbx = sandbox;
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
      ];

  YAHOO.lang.augmentObject(this,new PHEDEX.TreeView(sandbox,string));

  var node,
      opts = {},
      width = 1200;

  // Merge passed options with defaults
  YAHOO.lang.augmentObject(opts, {
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
//           payload:{ }
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem',
            },
            onInit: 'hideByDefault',
            container: 'buttons',
          },
        },
        {
          name: 'TimeSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: _time,
            container: 'buttons',
            menu: { 1:'Last Hour', 3:'Last 3 Hours', 6:'Last 6 Hours', 12:'Last 12 Hours', 24:'Last Day', 48:'Last 2 Days', 96:'Last 4 Days', 168:'Last Week' },
            map: {
              onChange:'changeTimebin',
            },
          }
        },
        {
          name: 'DirectionSelect',
          source: 'component-menu',
          payload:{
            type: 'menu',
            initial: _directions[_direction].key,
            container: 'buttons',
            menu: _directions,
            map: {
              onChange:'changeDirection',
            },
          }
        },
      ],

      meta: {
        isDynamic: true, // enable dynamic loading of data
        tree: [
          {
            width:1200,
            name:'Link',
            format: [
              {width:160,text:'Node',         className:'phedex-tree-node',       otherClasses:'align-left',  contextArgs:['node','sort-alpha'] },
              {width:120,text:'Done',         className:'phedex-tree-done',       otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
              {width:120,text:'Failed',       className:'phedex-tree-failed',     otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
              {width:120,text:'Expired',      className:'phedex-tree-expired',    otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
              {width: 70,text:'Rate',         className:'phedex-tree-rate',       otherClasses:'align-right', contextArgs:'sort-num', format:function(x){return PHEDEX.Util.format.bytes(x)+'/s';} },
              {width: 70,text:'Quality',      className:'phedex-tree-quality',    otherClasses:'align-right', contextArgs:'sort-num', format:PHEDEX.Util.format['%'] },
              {width:120,text:'Queued',       className:'phedex-tree-queue',      otherClasses:'align-right', contextArgs:['sort-files','sort-bytes'], format:PHEDEX.Util.format.filesBytes },
              {width: 70,text:'Link Errors',  className:'phedex-tree-error-total',otherClasses:'align-right', contextArgs:'sort-num' },
              {width: 90,text:'Logged Errors',className:'phedex-tree-error-log',  otherClasses:'align-right', contextArgs:'sort-num', hideByDefault:true }
            ]
          },
          {
            name:'Block',
            format: [
// using spanWrap for the block-name, I can (in principle):
// - locate the div with the block-name
// - locate the spanWrap child from it
// - compare their offsetHeights.
// - if the span offsetHeight is greater than the div, the word is truncated to fit, and I can style it to show that!
              {width:600,text:'Block Name',  className:'phedex-tree-block-name',     otherClasses:'align-left',  contextArgs:['block','sort-alpha'], format:PHEDEX.Util.format.spanWrap },
              {width: 80,text:'Block ID',    className:'phedex-tree-block-id',       otherClasses:'align-right', contextArgs:['block','sort-num'] },
              {width: 80,text:'State',       className:'phedex-tree-block-state',    otherClasses:'phedex-tnode-auto-height' },
              {width: 80,text:'Priority',    className:'phedex-tree-block-priority', otherClasses:'phedex-tnode-auto-height' },
              {width: 80,text:'Files',       className:'phedex-tree-block-files',    otherClasses:'phedex-tnode-auto-height align-right' },
              {width: 80,text:'Bytes',       className:'phedex-tree-block-bytes',    otherClasses:'phedex-tnode-auto-height align-right' },
              {width: 90,text:'Block Errors',className:'phedex-tree-block-errors',   otherClasses:'align-right', contextArgs:'sort-num' }
            ]
          },
          {
            name:'File',
            format:[
              {width:600,text:'File Name',  className:'phedex-tree-file-name',   otherClasses:'align-left',  contextArgs:['file','sort-alpha'], format:PHEDEX.Util.format.spanWrap },
              {width: 80,text:'File ID',    className:'phedex-tree-file-id',     otherClasses:'align-right', contextArgs:['file','sort-num'] },
              {width: 80,text:'Bytes',      className:'phedex-tree-file-bytes',  otherClasses:'align-right', contextArgs:'sort-num', format:PHEDEX.Util.format.bytes },
              {width: 90,text:'File Errors',className:'phedex-tree-file-errors', otherClasses:'align-right', contextArgs:'sort-num' },
              {width:140,text:'Checksum',   className:'phedex-tree-file-cksum',  otherClasses:'align-right', hideByDefault:true }
            ]
          }
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
          'Link-level attributes':{
            map:{from:'phedex-tree-', to:'L'},
            fields:{
              'phedex-tree-node'        :{type:'regex',       text:'Node-name',        tip:'javascript regular expression' },
              'phedex-tree-rate'        :{type:'minmaxFloat', text:'Transfer-rate',    tip:'transfer rate in MB/sec' },
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
              'phedex-tree-block-name'     :{type:'regex',     text:'Block-name',       tip:'javascript regular expression' },
              'phedex-tree-block-id'       :{type:'int',       text:'Block-ID',         tip:'ID of this block in TMDB' },
              'phedex-tree-block-state'    :{type:'regex',     text:'Block-state',      tip:'block-state' },
              'phedex-tree-block-priority' :{type:'regex',     text:'Block-priority',   tip:'block-priority' },
//            'phedex-tree-block-files'    :{type:'minmax',    text:'Block-files',      tip:'number of files in the block' }, // These are multi-value fields, so cannot filter on them.
//            'phedex-tree-block-bytes'    :{type:'minmax',    text:'Block-bytes',      tip:'number of bytes in the block' }, // This is because of the way multiple file-states are represented
              'phedex-tree-block-errors'   :{type:'minmax',    text:'Block-errors',     tip:'number of errors for the block' }
            }
          },
          'File-level attributes':{
            map:{from:'phedex-tree-file-', to:'F'},
            fields:{
              'phedex-tree-file-name'   :{type:'regex',     text:'File-name',        tip:'javascript regular expression' },
              'phedex-tree-file-id'     :{type:'minmax',    text:'File-ID',          tip:'ID-range of files in TMDB' },
              'phedex-tree-file-bytes'  :{type:'minmax',    text:'File-bytes',       tip:'number of bytes in the file' },
              'phedex-tree-file-errors' :{type:'minmax',    text:'File-errors',      tip:'number of errors for the given file' },
              'phedex-tree-file-cksum'  :{type:'regex',     text:'File-checksum(s)', tip:'javascript regular expression' }
            }
          }
        },
      },

      initMe: function(){
        for (var i in _directions) {
          _direction_map[_directions[i].key] = i;
        }
      },

//   PHEDEX.Event.onFilterDefined.fire(filterDef,that);
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
        try {
          var link = result.link[0],
              p    = node.payload,
              obj  = p.obj,
              call = p.call; // copy the value because of the dangers of shallow-copying in javascript
          if ( !link  ) { return; }
          if ( !link.transfer_queue ) { return; }
//        distinguish the type of node to build based on what the 'call' was that got me here. These 'if' clauses are too long for my liking...
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

//              Manual deep-copy of payload, prevents overwriting contents...
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
              var block = blocks[i];
              var state = priority = files = bytes = '';
              for (var j in block.queue) {
                state    += block.queue[j].state+'<br/>';
                priority += block.queue[j].priority+'<br/>';
                files    += block.queue[j].files+'<br/>';
                bytes    += PHEDEX.Util.format.bytes(block.queue[j].bytes)+'<br/>';
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
                var block = tq.block[j];
                var errors = [];
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
                  var file = block.file[k];
                  var num_errors = errors[file.id] || 0;
                  var tNode = obj.addNode(
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
          _sbx.notify(obj.id,'hideByDefault');
        } catch(e) {
          log('Error of some sort in PHEDEX.Widget.LinkView.callback_Treeview ('+e+')','error','linkview');
          var tNode = new YAHOO.widget.TextNode({label: 'Data-loading error, try again later...', expanded: false}, node);
          tNode.isLeaf = true;
        }
      },

      buildHeader: function(div) {
// Create the menu buttons. I create them inside a dedicated span so that they will be rendered on the left,
// before anything inserted by the core widgets.

//     var changeDirectionButton = new YAHOO.widget.Button(
// 	{ type: "menu",
// 	  label: that.direction_text(),
// 	  name: "changeDirection",
// 	  menu: changeDirectionMenu,
// 	  container: button_span
// 	});
//     var timeSelectButton = new YAHOO.widget.Button(
// 	{ type: "menu",
// 	  label: that.timebin_selected,
// 	  name: "timeSelect",
// 	  menu: timeSelectMenu,
// 	  container: button_span
// 	});
      YAHOO.util.Dom.insertBefore(document.createTextNode(this.node),that.dom.param.firstChild);

//     var onSelectedMenuItemChange = function (event) {
//       var oMenuItem = event.newValue;
//       var text = oMenuItem.cfg.getProperty("text");
//       log('onSelectedMenuItemChange: new value: '+text,'info','linkview');
//       this.set("label", text);
//     };
//     changeDirectionButton.on("selectedMenuItemChange", onSelectedMenuItemChange);
//     timeSelectButton.on(     "selectedMenuItemChange", onSelectedMenuItemChange);
    },
//     fillHeader: function(div) { },

//   that.onUpdateBegin.subscribe( function() { that.data = []; });

      fillBody: function() {
        var root = this.tree.getRoot(),
            antidirection=this.anti_direction_key();
        if ( !this.data.hist.length )
        {
          var tLeaf = new YAHOO.widget.TextNode({label: 'Nothing found, try another node...', expanded: false}, root);
          tLeaf.isLeaf = true;
        }
        for (var i in this.data.hist) {
          var h = this.data.hist[i],
              node = h[antidirection],
              d = {},
              e = {num_errors:0};
          for (var j in this.data.queue) {
            if (this.data.queue[j][antidirection]==node) {
              d = this.data.queue[j];
              break;
            }
          }
          for (var j in this.data.error) {
            if (this.data.error[j][antidirection]==node) {
              e = this.data.error[j];
              break;
            }
          }

          var done_bytes = PHEDEX.Util.sumArrayField(h.transfer,'done_bytes'),
              quality    = PHEDEX.Util.sumArrayField(h.transfer,'quality',parseFloat),
              done   = { files:PHEDEX.Util.sumArrayField(h.transfer,'done_files'), bytes:done_bytes },
              rate   = done_bytes/parseInt(h.transfer[0].binwidth),
              fail   = { files:PHEDEX.Util.sumArrayField(h.transfer,'fail_files'),   bytes:PHEDEX.Util.sumArrayField(h.transfer,'fail_bytes')   },
              expire = { files:PHEDEX.Util.sumArrayField(h.transfer,'expire_files'), bytes:PHEDEX.Util.sumArrayField(h.transfer,'expire_bytes') },
              queue  = { files:PHEDEX.Util.sumArrayField(d.transfer_queue,'files'),  bytes:PHEDEX.Util.sumArrayField(d.transfer_queue,'bytes')  };
          if ( isNaN(quality) ) { quality = 0; } // seems h.transfer[i].quality can be 'null', which gives NaN in parseFloat
          quality /= h.transfer.length;

//        Hack? Adding a 'payload' object allows me to specify what PhEDEx-y thing to call to get to the next level.
//        I did see a better way to do this in the YUI docs, but will find that later...
//        populate the payload with everything that might be useful, so I don't need widget-specific knowledge in the parent
//        payload.args is for the data-service call, payload.opts is for the callback to drive the next stage of processing
          var p = { call:'TransferQueueBlocks', obj:this , args:{}, opts:{}, data:{}, callback:this.callback_Treeview };
          p.args.from = h.from;
          p.args.to   = h.to;
          p.args.binwidth = h.transfer[0].binwidth;
          p.opts.node = h[antidirection];
          p.opts.direction = this.direction_index();
          p.data.errors    = e.block;
          var link_errors = PHEDEX.Util.sumArrayField(e.block,'num_errors');
          var tNode = this.addNode(
            { format:this.meta.tree[0].format, payload:p },
            [ node,done,fail,expire,rate,quality,queue,link_errors,e.num_errors ]
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
          _sbx.notify(this.id,'getData');
        }
      },
      getData: function() {
        if ( !node ) {
          this.initData();
          return;
        }
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        var args={};
        args[this.direction_key()] = node;
        args.binwidth = _time*3600;
        this.data = {};
        this.truncateTree();
        _sbx.notify( this.id, 'getData', { api: 'TransferQueueStats', args:args } );
        _sbx.notify( this.id, 'getData', { api: 'TransferHistory',    args:args } );
        _sbx.notify( this.id, 'getData', { api: 'ErrorLogSummary',    args:args } );
      },
      gotData: function(data,context) {
        log('Got new data','info',this.me);
        if ( context.api == 'TransferQueueStats' ) { this.data.queue = data.link; }
        if ( context.api == 'TransferHistory' )    { this.data.hist  = data.link; }
        if ( context.api == 'ErrorLogSummary' )    { this.data.error = data.link; }
        if ( this.data.hist && this.data.error && this.data.queue )
        {
          this.dom.title.innerHTML = node;
          this.fillBody();
          _sbx.notify( this.id, 'gotData' );
        }
        else { banner('Received '+context.api+' data, waiting for more...'); }
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(),true);
//   this.buildTree(this.dom.content);
//   this.buildExtra(this.dom.extra);
//   this.buildContextMenu();
//   this.build();
  return this;
}

log('loaded...','info','linkview');