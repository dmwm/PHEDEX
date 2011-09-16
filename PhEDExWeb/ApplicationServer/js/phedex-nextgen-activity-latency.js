PHEDEX.namespace('Nextgen.Activity');
PHEDEX.Nextgen.Activity.Latency = function(sandbox) {
  var string = 'nextgen-activity-latency',
      _sbx = sandbox,
      NUtil = PHEDEX.Nextgen.Util,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Button = YAHOO.widget.Button,
      YwDF  = Yw.DataTable.Formatter,
      YuDS  = YAHOO.util.DataSource,
      YuDSB = YAHOO.util.DataSourceBase;

  Yla(this,new PHEDEX.DataTable(sandbox,string));

  var _sbx = sandbox, node;
  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      options: {
        width:500,
        height:200,
        minwidth:600,
        minheight:50
      },
      _default:{}, // default values for various DOM fields, extracted as they are built
      meta: {
        table: {
          columns:[
            { key:'block',       label:'Block',           className:'align-left' },
            { key:'max_latency', label:'Max Latency',     className:'align-right', formatter:'secondsToDHMS', parser:'number' },
            { key:'ndest',       label:'# destinations',  className:'align-right', parser:'number' },
            { key:'files',       label:'Files',           className:'align-right', parser:'number' },
            { key:'bytes',       label:'Bytes',           className:'align-right', parser:'number', formatter:'customBytes' },
            { key:'time_create', label:'Creation Time',   className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'time_update', label:'Last Update',     className:'align-right', formatter:'UnixEpochToUTC' },
          ],
          nestedColumns:[
            { key:'node',                 label:'Node',                 className:'align-right' },
            { key:'latency',              label:'Latency',              className:'align-right', formatter:'secondsToDHMS', parser:'number' },
            { key:'files',                label:'Files',                className:'align-right', parser:'number' },
            { key:'bytes',                label:'Bytes',                className:'align-right', parser:'number', formatter:'customBytes' },
            { key:'priority',             label:'Priority',             className:'align-right' },
            { key:'is_custodial',         label:'Custodial',            className:'align-right' },
            { key:'block_create',         label:'Block Create',         className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'block_close',          label:'Block Close',          className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'first_replica',        label:'1st Replica',          className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'first_request',        label:'1st Request',          className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'last_replica',         label:'Last Replica',         className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'last_suspend',         label:'Last Suspend',         className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'latest_replica',       label:'Latest Replica',       className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'time_subscription',    label:'Time Subscription',    className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'time_update',          label:'Time Update',          className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'percent25_replica',    label:'25th percentile',      className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'percent50_replica',    label:'50th percentile',      className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'percent75_replica',    label:'75th percentile',      className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'percent95_replica',    label:'95th percentile',      className:'align-right', formatter:'UnixEpochToUTC' },
            { key:'partial_suspend_time', label:'Partial Suspend Time', className:'align-right', parser:'number' },
            { key:'total_suspend_time',   label:'Total Suspend Time',   className:'align-right', parser:'number' }
          ],
        }
      },
      useElement: function(el) {
        var d = this.dom;
        this.el = el;
        d.container = document.createElement('div'); d.container.className  = 'phedex-nextgen-container'; d.container.id = 'doc3';
        d.hd        = document.createElement('div'); d.hd.className         = 'phedex-nextgen-hd'; d.hd.id = 'hd';
        d.bd        = document.createElement('div'); d.bd.className         = 'phedex-nextgen-bd'; d.bd.id = 'bd';
        d.ft        = document.createElement('div'); d.ft.className         = 'phedex-nextgen-ft'; d.ft.id = 'ft';
        d.main      = document.createElement('div'); d.main.className       = 'yui-main';
        d.main_block= document.createElement('div'); d.main_block.className = 'yui-b phedex-nextgen-main-block';
        d.selector  = document.createElement('div'); d.selector.id          = 'phedex-activity-latency-selector';
        d.dataform  = document.createElement('div'); d.dataform.id          = 'phedex-activity-latency-dataform';
        d.datatable = document.createElement('div'); d.datatable.id         = 'phedex-activity-latency-datatable';
        d.datatable.style.padding='0 0 0 210px';
        d.plot      = document.createElement('div'); d.plot.id              = 'phedex-activity-latency-plot';
        d.plot.style.padding = '0 0 0 210px';

        form = document.createElement('form');
        form.id   = 'activity-latency-action';
        form.name = 'activity-latency-action';
        form.method = 'post';
        form.action = location.pathname;
        this.activity_latency_action = form;

        d.bd.appendChild(d.main);
//         d.container.appendChild(d.main);
        d.main.appendChild(d.main_block);
        d.container.appendChild(d.hd);
        d.container.appendChild(d.bd);
        d.container.appendChild(d.ft);
        d.container.appendChild(d.selector);
        d.container.appendChild(d.dataform);
        d.dataform.appendChild(form);
        d.container.appendChild(d.plot);
        d.container.appendChild(d.datatable);
        el.innerHTML = '';
        el.appendChild(d.container);

        form.innerHTML =
                "<div id='phedex-filterpanel-container' class='phedex-nextgen-filterpanel'>" +
                  "<div id='phedex-filterpanel' class='phedex-nextgen-control'>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-dataitems'>data items</div>" +
                  "</div>" +
                  "<div id='phedex-activity-latency-apply' style='float:right'></div>" +
                "</div>"

        d.floating_help = document.createElement('div'); d.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible';
        document.body.appendChild(d.floating_help);

// Data items
        el = Dom.get('phedex-filterpanel-dataitems');
        var field=el.innerHTML, Field=PxU.initialCaps(field);
        field = field.replace(/ /,'');
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-nextgen-filter-resize-"+field+"'><textarea id='phedex-activity-latency-input-"+field+"' name='"+field+"' class='phedex-filter-inputbox'>" + "Block name or Perl reg-ex" + "</textarea></div>" +
                  "</div>" +
                "</div>";
        d[field] = el = Dom.get('phedex-activity-latency-input-'+field);
        this._default[field] = function(e,t) {
          return function() { e.value=t; Dom.setStyle(e,'color','grey'); }
        }(el,el.value);
        Dom.setStyle(el,'color','grey')
        el.onfocus=function(obj,text) {
          return function() {
            if ( this.value == text ) {
              this.value = '';
              Dom.setStyle(this,'color','black');
            }
          }
        }(this,el.value);
        el.onblur=function(obj,text) {
          return function() {
            if ( this.value == '' ) {
              this.value = text;
              Dom.setStyle(this,'color','grey')
            }
          }
        }(this,el.value);
        NUtil.makeResizable('phedex-nextgen-filter-resize-'+field,'phedex-activity-latency-input-'+field,{maxWidth:1000, minWidth:100});

        var button = new Button({ label:'Apply', id:'phedex-activity-latency-update', container:'phedex-activity-latency-apply' });
        button.on('click', function(obj) { return function() { _sbx.notify(obj.id,'getLatencyData'); } }(this) );
      },
      getLatencyData: function() {
       var d = this.dom,
           el = d.dataitems,
           val = el.value;
        if ( val == 'Block name or Perl reg-ex' ) {
          d.datatable.innerHTML = "<span class='phedex-box-red' style='padding:5px;'>No data-item specified</span>";
          return;
        }
        d.datatable.innerHTML = PxU.stdLoading('loading latency data...');
        d.plot.innerHTML = '';
        PHEDEX.Datasvc.Call( { api:'blocklatency', callback:this.gotLatencyData, args:{block:val} } );
      },
      gotLatencyData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        var blocks=data.block, block, dest, d=obj.dom, t=obj.meta.table,
            Row, Table=[], Nested, unique=0, cDef, latency, i, j, k, l, n;
        if ( !blocks.length ) {
          d.datatable.innerHTML = "<span class='phedex-box-red' style='padding:5px;'>No data found matching your query!</span>";
          d.datatable.style.margin = '5px 0';
          return;
        }
        d.datatable.innerHTML = d.datatable.style.margin = '';
        for ( i in blocks ) {
          block = blocks[i];
          Row = {
                 block:block.name,
                 ndest:block.destination.length,
                 files:block.files,
                 bytes:block.bytes,
                 time_create:block.time_create,
                 time_update:block.time_update,
                 uniqueid:unique++
                 };
          Nested=[];
          for (j in block.destination) {
            dest = block.destination[j];
            for (k in dest.latency) {
              latency = dest.latency[k];
              Nested.push({
                node:                 dest.name,
                latency:              latency.latency,
                files:                latency.files,
                bytes:                latency.bytes,
                block_create:         latency.block_create,
                block_close:          latency.block_close,
                priority:             latency.priority,
                is_custodial:         latency.is_custodial,
                first_replica:        latency.first_replica,
                first_request:        latency.first_request,
                last_replica:         latency.last_replica,
                percent25_replica:    latency.percent25_replica,
                percent50_replica:    latency.percent50_replica,
                percent75_replica:    latency.percent75_replica,
                percent95_replica:    latency.percent95_replica,
                partial_suspend_time: latency.partial_suspend_time,
                total_suspend_time:   latency.total_suspend_time,
              });
              if (!Row.max_latency ) { Row.max_latency = latency.latency; }
              if (Row.max_latency < latency.latency ) { Row.max_latency = latency.latency; }
            }
          }
          Row.nesteddata = Nested;
          Table.push(Row);
        }

        var columns = t.columns, nestedColumns = t.nestedColumns, column, nestedColumn;
        for (i in Table) {
          Row=Table[i];
          for ( j in columns) {
            column = columns[j];
            if ( column.parser ) {
              Row[column.key] = column.parser(Row[column.key]);
            }
          }
          for (k in Row.nesteddata) {
            Nested=Row.nesteddata[k];
            for (l in nestedColumns) {
              nestedColumn = nestedColumns[l];
              if ( nestedColumn.parser ) {
                Nested[nestedColumn.key] = nestedColumn.parser(Nested[nestedColumn.key]);
              }
            }
          }
        }

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
        if ( obj.dataSource ) {
          delete obj.dataSource;
          delete obj.nestedDataSource;
        }

        obj.dataSource = new YAHOO.util.DataSource(Table);
        obj.nestedDataSource = new YAHOO.util.DataSource();
        if ( obj.dataTable  ) {
          obj.dataTable.destroy();
          delete obj.dataTable;
        }
        if ( t.columns[0].key == '__NESTED__' ) { t.columns.shift(); } // NestedDataTable has side-effects on its arguments, need to undo that before re-creating the table
        obj.dataTable = new YAHOO.widget.NestedDataTable(d.datatable, t.columns, obj.dataSource, t.nestedColumns, obj.nestedDataSource,
                        {
                           initialLoad: false,
                           generateNestedRequest: obj.processNestedrequest
                        });
        obj.dataTable.subscribe('nestedDestroyEvent',function(o) {
          return function(ev) {
            delete o.nestedtables[ev.dt.getId()];
          }
        }(obj));
        obj.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
          var dt = oArgs.dt,
              oCallback = {
              success: dt.onDataReturnInitializeTable,
              failure: dt.onDataReturnInitializeTable,
              scope: dt
          }, ctxId;
          obj.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
          if ( !dt ) { return; }
          var col = dt.getColumn('name');
          dt.sortColumn(col, YAHOO.widget.DataTable.CLASS_DESC);
          // This is to maintain the list of created nested tables that would be used in context menu
          if ( !o.nestedtables ) {
            o.nestedtables = {};
          }
          o.nestedtables[dt.getId()] = dt;
        }, obj);
        oCallback = {
          success: obj.dataTable.onDataReturnInitializeTable,
          failure: obj.dataTable.onDataReturnInitializeTable,
          scope: obj.dataTable
        };
        obj.dataSource.sendRequest('', oCallback);
// TW Here we try to plot something!
        _sbx.notify(obj.id,'plotLatencyData',data);
      },
      processNestedrequest: function (record) {
        try {
          var nesteddata = record.getData('nesteddata');
          obj.nestedDataSource = new YuDS(nesteddata);
          return nesteddata;
        }
        catch (ex) {
          log('Error in expanding nested table.. ' + ex.Message, 'error', _me);
        }
      },
      plotLatencyData: function(data) {
        var i, j, k, l, dst, ltn, d1, result=[], tmp, dom=this.dom, order, max, min, value, newResult=[], maxInterval, now,
             vis, width = 900, height = 400;
        order=[
//           'block_create', 'block_close',
//           'time_create', 'time_subscription', 'time_update',
//           'first_request', 'first_replica', 'latest_replica', 'last_replica',
            {key:'first_request',     value:0},
            {key:'percent25_replica', value:25},
            {key:'percent50_replica', value:50},
            {key:'percent75_replica', value:75},
            {key:'percent95_replica', value:95},
            {key:'last_replica',      value:100}
          ];
        for ( i in data.block ) {
          tmp={};
          d1 = data.block[i];
          tmp.time_create = d1.time_create;
          tmp.time_update = d1.time_update;
          tmp.name = d1.name;
          for ( j in d1.destination ) {
            dst = d1.destination[j];
            tmp.node = dst.name;
            for ( k in dst.latency ) {
              ltn = dst.latency[k];
              for ( l in ltn ) {
                tmp[l] = ltn[l];
              }
              result.push( tmp );
            }
          }
        }
        log('Got new data','info',this.me);

        vis = new pv.Panel()
                    .canvas(dom.plot)
                    .width(width)
                    .height(height)
                    .margin(20)
                    .bottom(20);

        maxInterval = 0;
        now = new Date().getTime()/1000;
        for ( i in result ) {
          max = 0;
          min = now;
          d = result[i];
          tmp=[];
          for (j in order) {
            value = d[order[j].key];
            if ( value ) {
              tmp.push([order[j].value,value]);
              if ( value > max ) { max = value; }
              if ( value < min ) { min = value; }
            }
          }
          if ( max > min ) { // only consider complete entries
            if ( max - min > maxInterval ) { maxInterval = max - min; }
            newResult.push(tmp);
          }
        }

        for ( i in newResult ) {
          tmp = newResult[i];
          min = tmp[0][1];
          for ( j in tmp ) {
            if ( tmp[j][1] ) { tmp[j][1] = (tmp[j][1]-min)/(maxInterval); }
          }

          vis.add(pv.Line)
             .data(tmp)
             .left(function(t) {   return width  * t[0] / 100;} )
             .bottom(function(t) { return height * t[1]; })
             .strokeStyle("rgba(0, 0, 0, .5)")
             .lineWidth(1);
        }

        var percentiles, times, step, y;
        y = pv.Scale.linear(0, maxInterval).range(0,height);
        step = 3600, range=pv.range(0, Math.ceil(maxInterval/step)*step, step);
        times = vis.add(pv.Rule)
                   .data(function() { return range; })
                   .bottom(y)
                   .strokeStyle("#eee");
        times.anchor('left').add(pv.Label)
             .textStyle('#000')
             .text(function(s) { return Math.round(s/step); });

        percentiles = vis.add(pv.Rule)
                         .data(order)
                         .left(function(s) { return width * s.value/100; } )
                         .strokeStyle( '#eee' );
        percentiles.anchor('bottom').add(pv.Label)
                   .textStyle('#000')
                   .text(function(s) { return s.value+'%'; });

//         dom.title.innerHTML = 'Found '+newResult.length+' completed blocks out of '+result.length+' candidates';
        vis.render();
      },
      Help:function(arg) {
        var item      = this[arg],
            help_text = item.help_text,
            elSrc     = item.help_align,
            elContent = this.dom.floating_help,
            elRegion  = Dom.getRegion(elSrc);
        if ( this.help_item != arg ) {
          Dom.removeClass(elContent,'phedex-invisible');
          Dom.setX(elContent,elRegion.left);
          Dom.setY(elContent,elRegion.bottom);
          elContent.innerHTML = help_text;
          this.help_item = arg;
        } else {
          Dom.addClass(elContent,'phedex-invisible');
          delete this.help_item;
        }
      },
      init: function(params) {
        if ( !params ) { params={}; }
        this.params = params;
        var el;
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr.shift();
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action].apply(obj,arr);
              return;
            }
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
        this.useElement(params.el);
        this.initSub();
      },
      initSub: function() {
        var d = this.dom;
        this.needProcess = true; //Process data by default
        var t = this.meta.table,
            i = t.columns.length,
            cDef;
        if (!t.map) { t.map = {}; }
        while (i > 0) { //This is for main columns
          i--;
          cDef = t.columns[i];
          if (typeof cDef != 'object') { cDef = { key: cDef }; t.columns[i] = cDef; }
          if (!cDef.label) { cDef.label = cDef.key; }
          if (!cDef.resizeable) { cDef.resizeable = true; }
          if (!cDef.sortable) { cDef.sortable = true; }
          if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          if ( cDef.parser && typeof cDef.parser == 'string') { cDef.parser = YuDSB.Parser[cDef.parser]; }
        }
        if ( !t.nestedColumns ) { t.nestedColumns = []; }
        i = t.nestedColumns.length;
        while (i > 0) { //This is for inner nested columns
          i--;
          cDef = t.nestedColumns[i];
          if (typeof cDef != 'object') { cDef = { key: cDef }; t.nestedColumns[i] = cDef; }
          if (!cDef.label) { cDef.label = cDef.key; }
          if (!cDef.resizeable) { cDef.resizeable = true; }
          if (!cDef.sortable) { cDef.sortable = true; }
          if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          if ( cDef.parser && typeof cDef.parser == 'string') { cDef.parser = YuDSB.Parser[cDef.parser]; }
        }
      }
    }
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','nextgen-activity-latency');
