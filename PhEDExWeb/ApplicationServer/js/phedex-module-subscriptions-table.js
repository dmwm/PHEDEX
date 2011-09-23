PHEDEX.namespace('PHEDEX.Module.Subscriptions');
PHEDEX.Module.Subscriptions.Table = function(sandbox,string) {
  var _sbx  = sandbox,
      Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Icon  = PHEDEX.Util.icon,
      YwDF  = YAHOO.widget.DataTable.Formatter;
  Yla(this,new PHEDEX.DataTable(_sbx,string));

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    var formatPct       = YwDF.percentMap(2, [ {min:100, className:'phedex-box-green'}, {className:'phedex-box-red'} ] ),
        formatSuspended = YwDF.colourMap( [ {key:'y', className:'phedex-box-yellow'} ] ),
        formatRid       = YwDF.linkTo(PxW.WebURL+PHEDEX.Datasvc.Instance().instance+'/Request::View?request=RID',/RID$/,'unknown');
    return {
      options: { },
      decorators: [
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
            container: 'param'
          }
        }
      ],
      meta: {
        table: { columns: [{ key:'select',       label:'Select'},
                           { key:'request',      label:'Request',       className:'align-right', parser:'number', formatter:formatRid },
                           { key:'level',        label:'Data Level',    className:'align-left' },
                           { key:'item',         label:'Data Item',     className:'align-left' },
                           { key:'node',         label:'Node',          className:'align-left' },
                           { key:'priority',     label:'Priority',      className:'align-left' },
                           { key:'custodial',    label:'Custodial',     className:'align-left' },
                           { key:'group',        label:'Group',         className:'align-left' },
                           { key:'nodeFiles',    label:'Node Files',    className:'align-right', parser:'number' },
                           { key:'nodeBytes',    label:'Node Bytes',    className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'pctFiles',     label:'% Files',       className:'align-right', parser:'number', formatter:formatPct },
                           { key:'pctBytes',     label:'% Bytes',       className:'align-right', parser:'number', formatter:formatPct },
                           { key:'replicaMove',  label:'Replica/Move',  className:'align-left' },
                           { key:'suspended',    label:'Suspended',     className:'align-left', formatter:formatSuspended },
                           { key:'open',         label:'Open',          className:'align-left' },
                           { key:'timeCreate',   label:'Time Create',   className:'align-left', parser:'number', formatter:'UnixEpochToUTC' },
//                            { key:'timeComplete', label:'Time Complete', className:'align-left phedex-invisible', parser:'number', formatter:'UnixEpochToUTC' },
                           { key:'timeDone',     label:'Time Done',     className:'align-left', parser:'number', formatter:'UnixEpochToUTC' },
                          ],
//             nestedColumns:[{ key:'node',          label:'Node',     className:'align-left' }]
                },
        hide:[],
        sort:{ field:'Item' }
      },
      setSummary: function(status, text) {
        var dom = this.dom;
        if ( typeof(dom.title.innerHTML) != 'undefined' ) {
          dom.title.innerHTML = text;
        } else {
          _sbx.notify(this.id,'setSummary',status,text);
        }
      },
      _processData: function(data) {
        var dom=this.dom, context=this.context, api=context.api, Table=[], Row, Nested, unique=0, column, elList, oCallback,
            meta=this.meta, t=meta.table, parser=meta.parser, cDef, i, j, k, item, s, blocks, block, known={}, cBox;

        i = t.columns.length;
        if (!t.map) { t.map = {}; }
        Dom.removeClass(dom.preview,'phedex-invisible');

        if ( !data ) {
          this.setSummary('error','Error retrieving information from the data-service');
          return;
        }
        this.setSummary('OK',data.length+' item'+(data.length == 1 ? '' : 's')+' found');

//      Build the datatable and the information for per-node summaries
        for (i in data) {
          item = data[i];
          for (j in item.subscription) {
            s = item.subscription[j];
            s.level = s.level.toUpperCase();
            cBox = s.level+':'+item.name+':'+s.node;
// <input type='checkbox' name='s_value' value='BLOCK:/lifecycle/mc/bari_4#058c9352:TX_CH_CERN_Rapolas'
            Row = { select:"<input type='checkbox' name='s_value' value='"+cBox+"' />",
                    request:s.request,
                    level:s.level,
                    item:item.name,
                    node:s.node,
                    priority:s.priority,
                    custodial:s.custodial,
                    group:s.group,
                    nodeFiles:s.node_files,
                    nodeBytes:s.node_bytes,
                    pctFiles:s.percent_files,
                    pctBytes:s.percent_bytes,
                    replicaMove:( s.move == 'y' ? 'replica' : 'move' ),
                    suspended:s.suspended,
                    open:item.is_open,
                    timeCreate:s.time_create,
                    timeComplete:'???',
                    timeDone:s.time_update
                  };
            for (j in Row) {
              if ( parser[j] ) { Row[j] = parser[j](Row[j]); }
            }
            Table.push(Row);
            if ( Row.level == 'DATASET' ) { // TW ...which it always will at this point in the structure!
              if ( Row.request ) { known[Row.request] = 1; }
            }
          }
          blocks = item.block;
          for (j in blocks) {
            block = blocks[j];
            for (k in block.subscription) {
// TW hack for the current API structure
              s = block.subscription[k]
              if ( known[s.request] ) { // if this is a block for a known dataset-level request...
                continue;
              }
              Row = { request:s.request,
                      level:'DATASET',
                      item:block.name,
                      node:s.node,
                      priority:s.priority,
                      custodial:s.custodial,
                      group:s.group,
                      nodeFiles:s.node_files,
                      nodeBytes:s.node_bytes,
                      pctFiles:s.percent_files,
                      pctBytes:s.percent_bytes,
                      replicaMove:( s.move == 'y' ? 'replica' : 'move' ),
                      suspended:s.suspended,
                      open:item.is_open,
                      timeCreate:s.time_create,
                      timeComplete:'???',
                      timeDone:s.time_update
                    };
            }
            for (j in Row) {
              if ( parser[j] ) { Row[j] = parser[j](Row[j]); }
            }
            Table.push(Row);
          }
        }

// TW Need to uncomment this later?
//         this.needProcess = false;
        return Table;
      },

      initData: function() {
        if ( this.args ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
      setArgs: function(arr) {
        if ( !arr ) { return; }
        this.args = arr;
        _sbx.notify(this.id,'setArgs');
      },
      getData: function() {
        if ( !this.args ) {
          this.initData();
          return;
        }
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'subscriptions', args:this.args } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        if ( !data.dataset ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.dataset;
        this.context = context;
        this.fillDataSource(this.data);
        _sbx.notify( this.id, 'gotData' );
      },
     }
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','subscriptions.table');
