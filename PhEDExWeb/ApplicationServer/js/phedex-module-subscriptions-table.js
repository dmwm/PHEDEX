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
        formatRid       = YwDF.linkTo(PxW.WebURL+PHEDEX.Datasvc.Instance().instance+'/Request::View?request=RID',/RID$/,'-');
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
        table: { columns: [{ key:'select',       label:'Select' },
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
        hide:['Select'], // hidden by default, requires positive authentication to enable it
        sort:{ field:'Item' },
        select:{},
      },
      _processData: function(data) {
        var dom=this.dom, context=this.context, api=context.api, Table=[], Row, Nested, unique=0, column, elList, oCallback,
            meta=this.meta, t=meta.table, parser=meta.parser, cDef, i, j, k, item, s, blocks, block, known={}, id;

        i = t.columns.length;
        if (!t.map) { t.map = {}; }
        Dom.removeClass(dom.preview,'phedex-invisible');

        if ( !data ) {
          this.setSummary('error','Error retrieving information from the data-service');
          return;
        }

//      Build the datatable and the information for per-node summaries
        for (i in data) {
          item = data[i];
          for (j in item.subscription) {
            s = item.subscription[j];
            s.level = s.level.toUpperCase();
            id = 'cbox_'+PxU.Sequence();
            Row = { select:'',
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
                    timeComplete:'???', // TW
                    timeDone:s.time_update
                  };
            for (j in Row) {
              if ( parser[j] ) { Row[j] = parser[j](Row[j]); }
            }
            if ( s.request != null ) {
              Row.select = "<input type='checkbox' name='s_value' class='phedex-checkbox' id='"+id+"' value='"+id+"' onclick=\"PxS.notify('"+this.id+"','checkboxSelect','"+id+"')\" />";
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
              s.level = s.level.toUpperCase();
              id = 'cbox_'+PxU.Sequence();
              Row = { select:'',
                      request:s.request,
                      level:s.level,
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
                      timeComplete:'???', // TW
                      timeDone:s.time_update
                    };
              for (j in Row) {
                if ( parser[j] ) { Row[j] = parser[j](Row[j]); }
              }
              if ( s.request != null ) {
                Row.select = "<input type='checkbox' name='s_value' class='phedex-checkbox' id='"+id+"' value='"+id+"' onclick=\"PxS.notify('"+this.id+"','checkboxSelect','"+id+"')\" />";
            }
            Table.push(Row);
            }
          }
        }
        this.setSummary('OK',data.length+' data-item'+(data.length==1?'':'s')+' found, '
                        +Table.length+' subscription'+(Table.length==1?'':'s'));

// TW Need to uncomment this later?
//         this.needProcess = false;
        return Table;
      },
      initMe: function() {
        this.allowNotify['checkboxSelect'] = 1;
        this.allowNotify['updateRow'] = 1;
      },
      updateRow: function(id,data) {
        var el = id, i, record, recordSet, oldRow, oldValue, newRow, newValue, s, changed=false;
        if ( typeof(el) == 'string' ) { el = Dom.get(id); }
        recordSet = this.dataTable.getRecordSet();
        record = this.dataTable.getRecord(el);
        oldRow = record.getData();
        if ( oldRow.level == 'BLOCK' ) { // pick up information at the right level
          data = data.block[0];
        }
        s = data.subscription[0];
        newRow = { select:oldRow.select,
                   request:s.request,
                   level:s.level.toUpperCase(),
                   item:data.name,
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
                   open:data.is_open,
                   timeCreate:s.time_create,
                   timeComplete:'???', // TW
                   timeDone:s.time_update
                 };
        for (i in oldRow) {
          oldValue = oldRow[i];
          newValue = newRow[i];
          if ( newValue != oldValue ) {
            changed = true;
            break;
          }
        }
        if ( changed ) {
          this.dataTable.updateRow(record,newRow);
          _sbx.notify(this.id,'rowUpdated');
        }
      },
      checkboxSelect: function(id,value) {
        var el=id, record, text, values;
        if ( typeof(el) == 'string' ) { el = Dom.get(id); }
        record = this.dataTable.getRecord(el);
        values = record.getData();
        text = values.select;
        if ( value == null ) { value = el.checked; }
        if ( value ) {
          text = text.replace(/ name=/," checked='yes' name=");
        } else {
          text = text.replace(/checked='yes' /,'');
        }
        this.dataTable.updateCell(record,'select',text);
        _sbx.notify(this.id,'checkbox-select',id,value,{ level:values.level, item:values.item, node:values.node });
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
        if ( !data || !data.dataset ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.dataset;
        this.context = context;
        this.fillDataSource(this.data);
      },
     }
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','subscriptions.table');
