PHEDEX.namespace('PHEDEX.Module');
PHEDEX.Module.PreviewRequestData = function(sandbox,string) {
  var _sbx = sandbox,
      Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      NUtil = PHEDEX.Nextgen.Util;
  Yla(this,new PHEDEX.DataTable(_sbx,string));

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      options: { },
      meta: {
        table: { columns: [{ key:'level',         label:'Level',    className:'align-left' },
                           { key:'item',          label:'Item',     className:'align-left' },
                           { key:'files',         label:'Files',    className:'align-right', parser:'number' },
                           { key:'bytes',         label:'Bytes',    className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'dbs',           label:'DBS',      className:'align-left' },
                           { key:'replicas',      label:'Replicas', className:'align-left' },
                           { key:'comment',       label:'Comment',  className:'align-left' }],
            nestedColumns:[{ key:'node',          label:'Node',     className:'align-left' },
                           { key:'b_files',       label:'Files',    className:'align-right', parser:'number' },
                           { key:'b_bytes',       label:'Bytes',    className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'is_subscribed', label:'Subscribed' },
                           { key:'is_custodial',  label:'Custodial' },
                           { key:'is_move',       label:'Move' },
                           { key:'time_start',    label:'Start time',  formatter:'UnixEpochToUTC', parser:'number' },
                           { key:'subs_level',    label:'Subscription level', className:'align-leftx' }]
                }
      },

      _processData: function(jData) {
debugger;
//         var i, str,
//             jAgents=jData, nAgents=jAgents.length, jAgent, iAgent, aAgentCols=['node','name','host'], nAgentCols=aAgentCols.length,
//             jProcs, nProc, jProc, iProc, aProcCols=['time_update','pid','version','label','state_dir'], nProcCols=aProcCols.length,
//             Row, Table=[];
//         for (iAgent = 0; iAgent < nAgents; iAgent++) {
//           jAgent = jAgents[iAgent];
//           jProcs = jAgent.agent;
//           for (iProc in jProcs) {
//             jProc = jProcs[iProc];
//             Row = {};
//             for (i = 0; i < nAgentCols; i++) {
//               this._extractElement(aAgentCols[i],jAgent,Row);
//             }
//             for (i = 0; i < nProcCols; i++) {
//               this._extractElement(aProcCols[i],jProc,Row);
//             }
//             Table.push(Row);
//           }
//         }
//         this.needProcess = false;
//         return Table;
      },

      initData: function() {
        if ( this.args ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },

      setArgs: function(arr) {
        this.args = arr;
        _sbx.notify(this.id,'setArgs');
      },
      getData: function() {
        if ( !this.args ) {
          this.initData();
          return;
        }
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'previewrequestdata', args:this.args } );
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        if ( !data.preview ) {
          throw new Error('data incomplete for '+context.api);
        }
        this.data = data.preview;
        this.fillDataSource(this.data);
        _sbx.notify( this.id, 'gotData' );
      },
 
      previewCallback: function(data,context,response) {
        var dom=this.dom, api=context.api, Table=[], Row, Nested, unique=0, showDBS=false, showComment=false, dbs=context.args.dbs, column, elList, oCallback,
            preview, t=this.meta.table, cDef, i, j, item, src_info, tFiles=0, tBytes=0, text,
            summary={}, s, node, time_start, isRequired={}, unknown=0, known=0, excessNodes, nExcessNodes=0;

        Dom.removeClass(dom.preview,'phedex-box-yellow');
        Dom.removeClass(dom.preview,'phedex-box-red');
        switch (api) {
          case 'previewrequestdata': {
            preview = data.preview;
            Dom.removeClass(dom.preview,'phedex-invisible');
            if ( !preview ) {
              dom.preview_summary.innerHTML = 'Error retrieving information from the data-service';
              Dom.addClass(dom.preview,'phedex-box-red');
              return;
            }
            if ( preview.comment ) { dom.preview_summary = preview.comment; }
            for (i in context.args.node ) {
              isRequired[context.args.node[i]] = true;
            }

//          Build the datatable and the information for per-node summaries
            for (i in preview) {
              item = preview[i];
              Row = { level:item.level, item:item[item.level.toLowerCase()] || item.item, files:item.files, bytes:item.bytes, dbs:item.dbs, comment:item.comment };
              if ( item.level == 'User Search' ) { unknown++; }
              else { known++; }

              tFiles += parseInt(item.files) || 0;
              tBytes += parseInt(item.bytes) || 0;
              for (j in item.src_info ) { // produce individual entries,plus summary matrix
                src_info = item.src_info[j];
                text = node = src_info.node;
                if ( !summary[node] ) {
                  summary[node] = { empty:0, incomplete:0, subscribed:0, OK:0, isRequired:isRequired[node] };
                }
                s = summary[node];

                if ( item.files == 0 ) { // empty items are OK by definition (!)
                  s.OK++;
                } else {                         // item is not empty
                  if ( src_info.files == '-' ) { // replica is empty
                    text += ', empty';
                    s.empty++;
                  } else if ( src_info.files == item.files )  { // replica is incomplete
                    s.OK++;
                  } else {                       // replica is (currently) complete
                    text += ', incomplete';
                    s.incomplete++;
                  }
                }
                if ( src_info.is_subscribed == 'n' ) {
                  text += ', not subscribed';
                  if ( this.type == 'xfer' && s.isRequired ) { text = "<span class='phedex-box-green'>" + text + "</span>"; }
                } else {
                  s.subscribed++;
                  if ( this.type == 'xfer' && s.isRequired ) { text = "<span class='phedex-box-yellow'>" + text + "</span>"; }
                }
                if ( this.type == 'delete' ) {
                  if ( s.isRequired ) {
                    if ( src_info.files == '-' && src_info.subscribed == 'n' ) { text = "<span class='phedex-box-red'>" + text + "</span>"; }
                    else {
                      text = "<span class='phedex-box-green'>" + text + "</span>";
                    }
                  }
                }

                if ( Row.replicas ) { Row.replicas += '<br/>' + text; }
                else { Row.replicas = text; }
              }
              if ( Row.comment ) {
                showComment = true;
              }
              if ( item.dbs == dbs ) {
                Row.dbs = "<span class='phedex-silver'>" + Row.dbs + "</span>";
              } else {
                showDBS = true;
              }
              Row.uniqueid = unique++;
              Nested = [];
              for (j in item.src_info ) {
                src_info = item.src_info[j];
                Nested.push({ node:src_info.node,
                              b_files:src_info.files,
                              b_bytes:src_info.bytes,
                              is_subscribed:src_info.is_subscribed,
                              is_custodial:src_info.is_custodial,
                              is_move:src_info.is_move,
                              time_start:src_info.time_start,
                              subs_level:src_info.subs_level
                             });
              }
              if ( Nested.length > 0 ) {
                Row.nesteddata = Nested;
              }
              Table.push(Row);
            }

//          Build the global summary
            text = '';
            if ( known ) {
              if ( known == 1 ) {
                text = 'One data-item matches your request';
              } else {
                text = known+' data-items match your request';
              }
              text += ', with '+tFiles+' file';
              if ( tFiles != 1 ) { text += 's'; }
              if ( tFiles ) {
                text += ', ' + ( tBytes ? PxUf.bytes(tBytes) : '0') + ' byte';
                if ( tBytes != 1 ) { text += 's'; }
              }
              text += ' in total';
            }

//          Most severe errors first...
            if ( this.re_evaluate_request ) {
              if ( !unknown && !dom.data_items.value.match(/\*/) && this.getRadioValues(this.re_evaluate_request) == 'y') {
                text += '<br/>'+IconError+'All items were matched & there are no wildcards, so <strong>re-evaluating</strong> makes no sense';
              }
            }
            if ( unknown ) {
              if ( text ) { text += '<br/>'; }
              text += IconWarn+unknown+' item';
              if ( unknown > 1 ) { text += 's'; }
              text += ' did not match anything known to PhEDEx';
            }
            time_start=context.args.time_start;
            if ( tBytes == 0 ) {
              if ( time_start ) {
                if ( time_start > new Date().getTime()/1000 ) {
                  text += '<br/>'+IconWarn+'The specified start-time (' + PxUf.UnixEpochToUTC(time_start) + ') is in the future, no currently existing data will match it.';
                } else {
                  text += '<br/>'+IconWarn+'No data injected since the time you specified (' + PxUf.UnixEpochToUTC(time_start) + ')';
                }
                Dom.addClass(dom.preview,'phedex-box-yellow');
              } else {
                text = IconError+'No data found matching your selection';
                Dom.addClass(dom.preview,'phedex-box-red');
              }
              text += '<br/>If you expect data to be injected later on, you can continue with this request. Otherwise, please modify it.';
              dom.preview_summary.innerHTML = text;
              return;
            }

            if ( time_start ) {
              text += '<br/>'+IconWarn+'You will only receive data injected after '+PxUf.UnixEpochToUTC(time_start);
            }

            j=true;
            for (node in summary) {
              s = summary[node];
              if ( !s.isRequired ) {
                delete summary[node];
                continue;
              }
              if ( s.subscribed == known ) {
                if ( j ) {
                  if ( this.type == 'xfer' ) {
                    text += "<br/>"+IconWarn+"All matched items are already subscribed to <strong>"+node+"</strong>";
                    excessNodes = node;
                    nExcessNodes = 1;
                  } else {
                    text += '<br/>'+IconOK+'All matched items are subscribed to <strong>'+node+'</strong>';
                  }
                  j=false;
                } else {
                  text += ', <strong>'+node+'</strong>';
                  if ( this.type == 'xfer' ) { excessNodes += ' '+node; nExcessNodes++; }
                }
                delete summary[node];
                delete isRequired[node];
              }
            }
            if ( nExcessNodes ) {
              text += " <a href='#' id='_phedex_remove_excess_nodes' onclick=\"PxS.notify('"+this.id+"','suppressExcessNodes','"+excessNodes+"')\" >(remove " +
                      (nExcessNodes == 1 ? "this node" : "these nodes" ) + ")</a>";
            }
            j=true;
            for (node in summary) {
              s = summary[node];
              if ( s.OK == known ) {
                if ( j ) {
                  text += '<br/>'+IconOK+'All matched items have replicas at <strong>'+node+'</strong>';
                  j=false;
                } else {
                  text += ', <strong>'+node+'</strong>';
                }
                delete summary[node];
                delete isRequired[node];
              }
            }

            if ( this.type == 'xfer' ) {
              j=true;
              for (node in summary) {
                s = summary[node];
                if ( s.subscribed ) {
                  if ( j ) {
                    text += '<br/>'+IconWarn+'Some items are already subscribed to <strong>'+node+'</strong>';
                    j=false;
                  } else {
                    text += ', <strong>'+node+'</strong>';
                  }
                  delete summary[node];
                  delete isRequired[node];
                }
              }
            }

            j=true;
            for (node in summary) {
              if ( j ) {
                if ( this.type == 'xfer' ) {
                  text += '<br/>'+IconWarn+'Some items already have replicas at <strong>'+node+'</strong>';
                } else {
                  text += '<br/>'+IconWarn+'Only some items have replicas at <strong>'+node+'</strong>';
                }
                j=false;
              } else {
                text += ', <strong>'+node+'</strong>';
              }
              delete summary[node];
              delete isRequired[node];
            }

            if ( this.type == 'delete' ) {
              j=true;
              for (node in isRequired) {
                if ( j ) {
                  text += '<br/>'+IconError+'No items have replicas at <strong>'+node+'</strong>';
                  j=false;
                  excessNodes = node;
                  nExcessNodes = 1;
                } else {
                  text += ', <strong>'+node+'</strong>';
                  excessNodes += ' '+node;
                  nExcessNodes++;
                }
              }
              if ( nExcessNodes ) {
                text += " <a href='#' id='_phedex_remove_excess_nodes' onclick=\"PxS.notify('"+this.id+"','suppressExcessNodes','"+excessNodes+"')\" >(remove " +
                        (nExcessNodes == 1 ? "this node" : "these nodes" ) + ")</a>";
              }
            }
            dom.preview_summary.innerHTML = text;

            i = t.columns.length;
            if (!t.map) { t.map = {}; }
            while (i > 0) { //This is for main columns
              i--;
              cDef = t.columns[i];
              if (typeof cDef != 'object') { cDef = { key:cDef }; t.columns[i] = cDef; }
              if (!cDef.label)      { cDef.label      = cDef.key; }
              if (!cDef.resizeable) { cDef.resizeable = true; }
              if (!cDef.sortable)   { cDef.sortable   = true; }
              if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
            }
            if ( !t.nestedColumns ) {
              t.nestedColumns = [];
            }
            i = t.nestedColumns.length;
            while (i > 0) { //This is for inner nested columns
              i--;
              cDef = t.nestedColumns[i];
              if (typeof cDef != 'object') { cDef = { key:cDef }; t.nestedColumns[i] = cDef; }
              if (!cDef.label)      { cDef.label      = cDef.key; }
              if (!cDef.resizeable) { cDef.resizeable = true; }
              if (!cDef.sortable)   { cDef.sortable   = true; }
              if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
            }
            if ( this.dataSource ) {
              delete this.dataSource;
              delete this.nestedDataSource;
            }
            this.dataSource = new YAHOO.util.DataSource(Table);
            this.nestedDataSource = new YAHOO.util.DataSource();
            if ( this.dataTable  ) {
              this.dataTable.destroy();
              delete this.dataTable;
            }
            if ( t.columns[0].key == '__NESTED__' ) { t.columns.shift(); } // NestedDataTable has side-effects on its arguments, need to undo that before re-creating the table
            this.dataTable = new YAHOO.widget.NestedDataTable(this.dom.preview_table, t.columns, this.dataSource, t.nestedColumns, this.nestedDataSource,
                            {
                               initialLoad: false,
                               generateNestedRequest: this.processNestedrequest
                            });
            oCallback = {
              success: this.dataTable.onDataReturnInitializeTable,
              failure: this.dataTable.onDataReturnInitializeTable,
              scope: this.dataTable
            };

            this.dataTable.subscribe('nestedDestroyEvent',function(obj) {
              return function(ev) {
                delete obj.nestedtables[ev.dt.getId()];
              }
            }(this));
            this.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
              var dt = oArgs.dt,
                  oCallback = {
                  success: dt.onDataReturnInitializeTable,
                  failure: dt.onDataReturnInitializeTable,
                  scope: dt
              }, ctxId;
              this.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
              if ( !dt ) { return; }
              var col = dt.getColumn('b_files');
              dt.sortColumn(col, YAHOO.widget.DataTable.CLASS_DESC);
              // This is to maintain the list of created nested tables that would be used in context menu
              if ( !o.nestedtables ) {
                o.nestedtables = {};
              }
              o.nestedtables[dt.getId()] = dt;
            }, this);
            this.dataSource.sendRequest('', oCallback);

            column = this.dataTable.getColumn('item');
            this.dataTable.sortColumn(column, YAHOO.widget.DataTable.CLASS_ASC);
            elList = Dom.getElementsByClassName('phedex-error','span',this.dom.preview_table);
            for (i in elList) { // I've hacked the error class into the entry in the table, but it really needs to belong to its parent, for better visual effect
              Dom.removeClass(elList[i],'phedex-error');
              Dom.addClass(elList[i].parentNode,'phedex-error');
            }
            if ( !showDBS ) {
              this.dataTable.hideColumn(this.dataTable.getColumn('dbs'));
            }
            if ( !showComment ) {
              this.dataTable.hideColumn(this.dataTable.getColumn('comment'));
            }
            break;
          }
        }
      },
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','previewrequestdata');
