/**
* This is the base class for all PhEDEx nested datatable-related modules. It extends PHEDEX.Module to provide the functionality needed for modules that use a YAHOO.Widget.NestedDataTable.
* @namespace PHEDEX
* @class PHEDEX.DataTable
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
var YwDF  = Yw.DataTable.Formatter,
    YuDS  = Yu.DataSource,
    YuDSB = Yu.DataSourceBase;
PHEDEX.DataTable = function (sandbox, string) {
    Yla(this, new PHEDEX.Module(sandbox, string));
    var _me = 'datatable', _sbx = sandbox;
    this.allowNotify['setColumnVisibility'] = 1;
    this.allowNotify['postGotData'] = 1;

    /**
    * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
    * @method _construct
    * @private
    */
    _construct = function () {
        return {
            /**
            * Used in PHEDEX.Module and elsewhere to derive the type of certain decorator-style objects, such as mouseover handlers etc. These can be different for TreeView and DataTable objects, so will be picked up as PHEDEX.[this.type].function(), or similar.
            * @property type
            * @default DataTable
            * @type string
            * @private
            * @final
            */
            type: 'DataTable',

            /**
            * extract the named field from the src object, applying any parser functions, and store in the dst object. If the field is an object, treat the key as the
            * item to extract from the src, and the value as the item to set in the dst.
            * E.g.
            * _extractElement('name',[name:'T1_ES_PIC_Buffer',time:12345678},dst) will set dst[name] = 'T1_ES_PIC_Buffer'.
            * _extractElement({name:'node'},[name:'T1_ES_PIC_Buffer',time:12345678},dst) will set dst[node] = 'T1_ES_PIC_Buffer'.
            * @method _extractElement
            * @public
            */
            _extractElement : function(field,src,dst) {
              var fn, key=field, mKey=field, val;
              if ( typeof(field) == 'object' ) {
                for (key in field) {
                  mKey = field[key];
                }
              }
              fn = this.meta.parser[mKey];
              if ( fn ) {
                val = fn(src[key]);
              } else {
                val = src[key];
              }
              if ( dst ) { dst[mKey] = val; }
              return val;
            },

            /**
            * Processes the response data so as to create a YAHOO.util.DataSource and display it on-screen.
            * @method _processData
            * @param moduledata {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>this.meta.table.columns</strong> for this table.
            * @private
            */
            _processData: function(moduledata) {
              var t=[], table=this.meta.table, i=moduledata.length, k=table.columns.length, j, a, c, y, val;
              if ( !this.needProcess ) { return; }
              while (i > 0) {
                i--
                a = moduledata[i], y = [];
                j = k;
                while (j > 0) {
                  j--;
                  c = table.columns[j], val = a[table.map[c.key]];
                  if (c.parser) { val = c.parser(val); }
                  y[c.key] = val;
                }
                t.push(y);
              }
              this.needProcess = false; //No need to process data further
              return t;
            },
            // This method checks columns of both main and nested datatables to find the key
            _getKeyByKeyOrLabel: function (str) {
              var m = this.meta, cols = m.table.columns, i;
              for (i in cols) {
                if (cols[i].label == str) { return cols[i].key; }
                if (cols[i].key   == str) { return str; }
              }
              for (i in cols) {
                if ( cols[i].label.replace(/ /g,'') == str ) {
                  return cols[i].key;
                }
              }

              cols = m.table.nestedColumns;
              for (i in cols) {
                if (cols[i].label == str) { return cols[i].key; }
                if (cols[i].key   == str) { return str; }
              }
              for (i in cols) {
                if ( cols[i].label.replace(/ /g,'') == str ) {
                  return cols[i].key;
                }
              }
            },

            /** Initialise the data-table, using the parameters in this.meta.table, set in the module during construction
            * @method initDerived
            * @private
            */
            initDerived: function () {
              var m = this.meta,
                  t = m.table,
                  columns = t.columns,
                  nColumns = t.nestedColumns,
                  allColumns=[], mff, col, h = {}, i, j, fName, key;

              for (i in m.hide) {
                h[this._getKeyByKeyOrLabel(m.hide[i])] = 1;
              }
              m.hide = h;
              if ( !this.dom.datatable ) { this.dom.datatable = this.dom.content; }
              this.buildTable()
              if ( !this.options.noExtraDecorators ) {
                this.decorators.push( { name:'Refresh', source:'component-refresh' });
                this.decorators.push(
                {
                  name: 'Filter',
                  source: 'component-filter',
                  payload: {
                    control: {
                      parent: 'control',
                      payload: {
                        disabled: false,
                        hidden: true
                      },
                      el: 'content'
                    }
                  },
                  target: 'filter'
                });
              }

              m.parser = {};
              for (i in columns)  { allColumns.push(columns[i]); }
              for (i in nColumns) { allColumns.push(nColumns[i]); nColumns[i].nested = true; }

              for (i in allColumns) {
                col = allColumns[i];
                if (col.parser) {
                  if (typeof col.parser == 'function') { m.parser[col.key] = col.parser; }
                  else { m.parser[col.key] = col.parser = YuDSB.Parser[col.parser]; }
                }
              }

              m._filter = this.createFilterMeta();
              // Now add the key-names to the friendlyName object, to allow looking up friendlyNames from column keys as well. Needed for some of the more
              // obscure metadata manipulations. Finessing the lookup in this direction only allows me to avoid adding datatable-specific code elsewhere
              for (i in m.filter) {
                h = {};
                for (key in m.filter[i].fields) {
                  h[this._getKeyByKeyOrLabel(key)] = m.filter[i].fields[key];
                }
                m.filter[i].fields = h;
              }
              mff = m._filter.fields;
              for (i in allColumns) {
                col = allColumns[i];
                key = this._getKeyByKeyOrLabel(col.key);
                if ( key == '__NESTED__' ) { continue; }
                fName = this.friendlyName(col.label);
                if (!mff[key]) {
                  mff[key] = { friendlyName: fName };
                }
                if ( col.nested ) {
                  j = col.label.replace(/ /g,'');
                  if ( mff[j] ) { mff[j].nested = true; }
                }
              }
              if (m.sort) {
                if (m.sort.field && !m.sort.dir) { m.sort.dir = Yw.DataTable.CLASS_ASC; }
              }
              var moduleHandler = function (o) {
                return function (ev, arr) {
                  var action = arr[0];
                  switch (action) {
                    case 'gotData': {
                      o.postGotData();
                      break;
                    }
                  }
                }
              } (this);
              _sbx.listen(this.id, moduleHandler);
            },

            postGotData: function (step, node) {
                this.sortNeeded = true;
                var i, steps = ['doFilter', 'doSort', 'hideFields'];
                for (i in steps) { _sbx.notify(this.id, steps[i]); }
            },

            /**
            * Create a YAHOO.util.DataSource from the data-structure passed as argument, and display it on-screen.
            * @method fillDataSource
            * @param moduledata {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>this.meta.table.columns</strong> for this table.
            */
            fillDataSource: function (moduledata) {
                if (this.meta.table.schema) {
                    this.fillDataSourceWithSchema(moduledata); // Fill datasource directly if schema is available
                    return;
                }
                if (this.needProcess) { // Process the data if it is new to module and is not from filter
                    moduledata = this._processData(moduledata);
                    this.data = moduledata; // cache for later use, e.g. by filtering
                }
                this.dataSource = new YuDS(moduledata);
                var oCallback = {
                    success: this.dataTable.onDataReturnInitializeTable,
                    failure: this.dataTable.onDataReturnInitializeTable,
                    scope: this.dataTable
                };
                this.dataSource.sendRequest('', oCallback);
                var w = this.dataTable.getTableEl().offsetWidth;
                this.el.style.width = w + 'px';
            },

            /**
            * Toggle visibility for given columns
            * @method setColumnVisibility
            * @param columns { array} an array of {label:string, show:bool} objects that determine if the 'label' column is to be shown.
            */
            setColumnVisibility: function(columns) {
              var hide=this.meta.hide, i, column, show=[], nHide=0;
              for (i in columns) {
                column = columns[i];
                if ( column.show ) {
                  show.push(column.label);
                } else {
                  hide[this._getKeyByKeyOrLabel(column.label)] = 1;
                  nHide++;
                }
              }
              if ( show.length ) {
                this.menuSelectItem(show); // poor choice of name for the function, but there it is... TODO fix that
              }
              if ( nHide ) {
                this.hideFields();
              }
            },

            setSummary: function(status, text) {
              var dom = this.dom;
              if ( typeof(dom.title.innerHTML) != 'undefined' ) {
                dom.title.innerHTML = text;
              } else {
                _sbx.notify(this.id,'setSummary',status,text);
              }
            },

            /**
            * hide all columns which have been declared to be hidden by default. Needed on initial rendering, on update, or after filtering. Uses <strong>this.options.hide</strong> to determine what to hide.
            * @method hideFields
            */
            hideFields: function () {
// TODO This could probably be made faster by searching the metadata first, before searching the tables?
              var key, k, col, i, w, minWidth = this.options.minwidth, m = this.meta;
              if (!m.hide) { return; }
              for (key in m.hide) {
                k = this._getKeyByKeyOrLabel(key);
                col = this.dataTable.getColumn(this._getKeyByKeyOrLabel(key));
                if (col) {
                  this.dataTable.hideColumn(col);
                  _sbx.notify(this.id, 'hideColumn', { text: col.label, value: col.label });
                } else {
                  for (i in this.nestedtables) {
                    col = this.nestedtables[i].getColumn(this._getKeyByKeyOrLabel(key));
                    if (col) {
                      this.nestedtables[i].hideColumn(col);
                      _sbx.notify(this.id, 'hideColumn', { text: col.label, value: col.label });
                    }
                  }
                }
              }
              w = this.dataTable.getTableEl().offsetWidth;
              if (minWidth && w < minWidth) { w = minWidth; }
              this.el.style.width = w + 'px';
            },

            /** Fill a data-source with JSON data, using a schema to describe it. Used internally by <strong>fillDataSource</strong> if a schema is provided
            * @method fillDataSourceWithSchema
            * @param jsonData {JSON data} a JSON object that contains the data for the table
            * @param dsSchema {YAHOO.util.DataSource.responseSchema} an object describing the contents of the JSON object
            * @private
            */
            fillDataSourceWithSchema: function(data) {
                var rList = this.meta.table.schema.resultsList, _d = {};
                if ( ! data[rList] ) { _d[rList] = data; data = _d; }
                this.dataSource = new YuDS(data);
                this.dataSource.responseSchema = this.meta.table.schema;
                var oCallback = {
                    success: this.dataTable.onDataReturnInitializeTable,
                    failure: this.dataTable.onDataReturnInitializeTable,
                    scope: this.dataTable
                };
                this.dataSource.sendRequest('', oCallback); //This is to update the datatable on UI
            },

            /**
            * A callback for the 'show-fields' button. Used to show a column that has been hidden thus far
            * @method menuSelectItem
            * @private
            * @param arg {string} The name of a column.
            */
            menuSelectItem: function(args) {
              var m=this.meta, l=0, i, key,
                  dt=this.dataTable, col, j;
              if ( !dt ) { return; } // can happen if columns are manipulated before the table is created/rendered
              if ( m.table.nestedColumns ) { l = m.table.nestedColumns.length; }
              for (i in args) {
                delete m.hide[args[i]];
                key = this._getKeyByKeyOrLabel(args[i]);
                delete m.hide[key];
                if ( l || key != '__NESTED__' ) {
                  if ( col = dt.getColumn(key) ) {
                    dt.showColumn(col);
                  } else {
                    for (j in this.nestedtables) {
                      col = this.nestedtables[j].getColumn(key);
                      this.nestedtables[j].showColumn(col);
                    }
                  }
                }
              }
              _sbx.notify(this.id, 'updateHistory');
            },

            /**
            * Used to resize the panel when viewing modules in 'window' mode. Specifically, when the table is redrawn, either for new data or for a column being shown or hidden, this will make sure the width of the table is extended to show all the data.
            * @method resizePanel
            * @private
            */
            resizePanel: function () {
                var table = this.dataTable,
                old_width = table.getContainerEl().clientWidth,
                offset = this.dom.header.offsetWidth - this.dom.datatable.offsetWidth,
                x = table.getTableEl().offsetWidth + offset;
                if (x >= old_width) {
                    this.module.cfg.setProperty('width', x + 'px');
                    this.el.style.width = x + 'px';
                }
            },

            doSort: function () {
                var s = this.meta.sort;
                if (s.field) {
                    if (s.sorted_field == s.field &&
                        s.sorted_dir == s.dir &&
                       !this.sortNeeded) { return; } // break the chain!
                    s.sorted_field = s.field;
                    s.sorted_dir = s.dir;
                    this.sortNeeded = false;
                    var column = this.dataTable.getColumn(this._getKeyByKeyOrLabel(s.field));
                    this.dataTable.sortColumn(column, s.dir);
                }
            },

            decoratorsConstructed: function () {
                if (!this.data) { return; }
                this.postGotData(); // TODO This is a bit of a hammer, do I need to do this? Maybe! on filter-reset, must re-establish the sort field
                // _sbx.notify(this.id,'doSort');
                // _sbx.notify(this.id,'hideFields');
            },

            /**
            * Used to process the request to expand the row and show the nested datatable.
            * @method processNestedrequest
            * @private
            */
            processNestedrequest: function (record) {
                try {
                    var nesteddata = record.getData('nesteddata');
                    this.nestedDataSource = new YuDS(nesteddata);
                    return nesteddata;
                }
                catch (ex) {
                    log('Error in expanding nested table.. ' + ex.Message, 'error', _me);
                }
            },

            /**
            * Build a table. This does not draw the table on-screen, use <strong>fillDataSource</strong> for that. This function needs to be called once, to create the DOM elements, and to prepare the module to receive data.
            * @method buildTable
            * @param columns {array} An array containing column-definitions. Each element in the array is either a simple string, which must correspond one-to-one with column-headers (case-blind), or an object.<br /><br />
            * If an object, it must have a key called <strong>key</strong>, which contains the column-header name (case-blind), and zero or more other keys, from the following.<br /><br />
            * The <strong>parser</strong> key tells the module to parse the field-value accordingly. It's either a reference (e.g. <strong>parser:YAHOO.util.DataSource.parseNumber</strong>) to a function that takes the value and returns the correct data-type, or the name (string) of a member of YAHOO.util.DataSourceBase.Parser (e.g. <strong>'parseNumber'</strong>). Useful for turning numeric data into integers or floats, instead of strings, for example.<br /><br />
            * The <strong>formatter</strong> formats the field for display. It's either a reference to a function that takes (elCell,oRecord,oColumn,oData) and returns a formatted string representation of it, or the name (string) of a member of YAHOO.widget.DataTable.Formatter. Useful for formatting dates, or for convering bytes to GB, for example.<br /><br />
            * @param map {object} (optional) a key-value map used map column-names returned by the data-service to more friendly names for display on-screen. The key is the on-screen name (i.e. matches a <strong>key</strong> in the <strong>columns</strong> object), the value is the name of the field returned by the data-service. Order of entries in the map is irrelevant.
            * @param dsschema {YAHOO.util.DataSource.responseSchema} (optional) a responseSchema to describe how to parse the data.
            */
            buildTable: function () {
              this.needProcess = true; //Process data by default
              var t = this.meta.table,
                  i = t.columns.length,
                  cDef, masterConfig, nestedConfig, tmp;

              masterConfig = {
                           initialLoad: false,
                           generateNestedRequest: this.processNestedrequest,
                           draggableColumns:true,
                           renderLoopSize: 100
                         };
              if ( t.config ) { Yla(masterConfig,t.config,true); }
              nestedConfig = {
                           initialLoad: false,
                           draggableColumns:true
                         };
              this.dataSource = new YuDS();

              if (!t.map) { t.map = {}; }
              while (i > 0) { //This is for main columns
                i--;
                cDef = t.columns[i];
                if (typeof cDef != 'object') { cDef = { key: cDef }; t.columns[i] = cDef; }
                if (!cDef.label)      { cDef.label = cDef.key; }
                if (!cDef.resizeable) { cDef.resizeable = true; }
                if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
                if (!cDef.sortable)   { cDef.sortable = true; }
                if ( tmp = cDef.sortOptions ) {
                  if ( typeof(tmp.sortFunction == 'string') ) {
                    tmp.sortFunction = function(obj,method) {
                      return function() {
                        obj[method].apply(obj,arguments);
                      };
                    }(this,tmp.sortFunction);
                  }
                }
              }
              if ( t.nestedColumns ) { // map the nested columns too
                this.nestedDataSource = new YuDS();
                i = t.nestedColumns.length;
                while (i > 0) {
                  i--;
                  cDef = t.nestedColumns[i];
                  if (typeof cDef != 'object') { cDef = { key: cDef }; t.nestedColumns[i] = cDef; }
                  if (!cDef.label)      { cDef.label = cDef.key; }
                  if (!cDef.resizeable) { cDef.resizeable = true; }
                  if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
                  if (!cDef.sortable)   { cDef.sortable = true; }
                  if ( tmp = cDef.sortOptions ) {
                    if ( typeof(tmp.sortFunction == 'string') ) {
                      tmp.sortFunction = function(obj,method) {
                        return function() {
                          obj[method].apply(obj,arguments);
                        };
                      }(this,tmp.sortFunction);
                    }
                  }
                }
              }

//            create the right type of data-table
              if ( t.nestedColumns ) {
                this.dataTable = new Yw.NestedDataTable(this.dom.datatable, t.columns, this.dataSource, t.nestedColumns, this.nestedDataSource, masterConfig, nestedConfig);
              } else {
                this.dataTable = new Yw.DataTable(this.dom.datatable, t.columns, this.dataSource, masterConfig);
              }
              this.dataTable.subscribe('columnSortEvent', function (obj) {
                return function (ev) {
                  var column = obj.dataTable.getColumn(ev.column);
                  obj.meta.sort.field = column.key;
                  obj.meta.sort.dir = ev.dir;
                  _sbx.notify(obj.id, 'updateHistory');
                }
              } (this));
              // TODO This can get shoved into the context-menu someday, it's the only place that needs it
              this.dataTable.subscribe('columnHideEvent', function (obj) {
                return function (ev) {
                  var column = obj.dataTable.getColumn(ev.column);
                  if ( column.key == '__NESTED__' ) { return; }
                  log('columnHideEvent: label:' + column.label + ' key:' + column.key, 'info', _me);
                  _sbx.notify(obj.id, 'hideColumn', { text: column.label, value: column.label });
                }
              } (this));

              // Only needed for resizeable windows, I think?
              this.dataTable.subscribe('renderEvent', function (obj) {
                return function () {
                  _sbx.notify(obj.id,'datatable_renderEvent');
                  obj.resizePanel();
                }
              } (this));
              var w = this.dataTable.getTableEl().offsetWidth;
              if (this.options.minwidth && w < this.options.minwidth) { w = this.options.minwidth; }
              this.el.style.width = w + 'px';

              if ( t.nestedColumns ) { // further events to drive the nested data table
                this.dataTable.subscribe('nestedDestroyEvent',function(obj) {
                  return function(ev) {
                    delete obj.nestedtables[ev.dt.getId()];
                  }
                }(this) );

                this.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
                  var dt = oArgs.dt,
                      oCallback = {
                      success: dt.onDataReturnInitializeTable,
                      failure: dt.onDataReturnInitializeTable,
                      scope: dt
                  }, ctxId;
                  this.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
                  if ( !dt ) { return; }
                  // This is to maintain the list of created nested tables that would be used in context menu
                  if ( !o.nestedtables ) {
                    o.nestedtables = {};
                  }
                  o.nestedtables[dt.getId()] = dt;
                  o.hideFields();
                  try {
                    _sbx.notify(o.ctl.ContextMenu.id,'addContextElement',dt.getTbodyEl());
                  } catch (_ex) { }
                  try {
                    _sbx.notify(o.ctl.MouseOver.id,'addContextElement',dt);
                  } catch (_ex) { }
                }, this);
              }
            },

            /** return a boolean indicating if the module is in a fit state to be bookmarked
            * @method isStateValid
            * @return {boolean} <strong>false</strong>, must be over-ridden by derived types that can handle their separate cases
            */
            isStateValid: function () {
                if (this.obj.data) { return true; } // TODO is this good enough...? Use _needsParse...?
                return false;
            },

            dirMap: function (dir) {
                var i, map = { 'yui-dt-asc': 'asc', 'yui-dt-desc': 'desc' };
                if (map[dir]) { return map[dir]; }
                for (i in map) {
                    if (map[i] == dir) { return i; }
                }
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
}

/** A custom formatter for unix-epoch dates. Sets the elCell innerHTML to the GMT representation of oDate
* @method YAHOO.widget.DataTable.Formatter.UnixEpochToGMT
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} unix epoch seconds
*/
YwDF.UnixEpochToGMT =  function(elCell, oRecord, oColumn, oData) {
  if( !oData )
  {
    elCell.innerHTML = '-';
  } else {
    elCell.innerHTML = new Date(oData*1000).toUTCString();
  }
};
/** A custom formatter for unix-epoch dates. Sets the elCell innerHTML to the UTC representation of oDate. In practice, identical to UnixEpochToGMT, but post-edits the string to show UTC.
* @method YAHOO.widget.DataTable.Formatter.UnixEpochToUTC
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} unix epoch seconds
*/
YwDF.UnixEpochToUTC =  function(elCell, oRecord, oColumn, oData) {
  if( !oData )
  {
    elCell.innerHTML = '-';
  } else {
    elCell.innerHTML =new Date(oData*1000).toUTCString().replace(/GMT/,'UTC');
  }
};
/** A custom formatter for time-intervals. Sets the elCell innerHTML to the number of days, hours, minutes, and seconds represented by the cell value
* @method YAHOO.widget.DataTable.Formatter.secondsToDHMS
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} unix epoch seconds
*/
YwDF.secondsToDHMS =  function(elCell, oRecord, oColumn, oData) {
  if( !oData ) { elCell.innerHTML = '-'; }
  else         { elCell.innerHTML = PxUf.secondsToDHMS(oData); }
};

/** A custom formatter for byte-counts. Sets the elCell innerHTML to the smallest reasonable representation of oData, with units
* @method YAHOO.widget.DataTable.Formatter.customBytes
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} number of bytes
*/
YwDF.customBytes = function(elCell, oRecord, oColumn, oData) {
  if(oData != null) { elCell.innerHTML = PxUf.bytes(oData); }
};

/** A custom formatter for rates. Sets the elCell innerHTML to the smallest reasonable representation of oData, with units
* @method YAHOO.widget.DataTable.Formatter.customBytes
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} number of bytes
*/
YwDF.customRate = function(elCell, oRecord, oColumn, oData) {
  if(oData != null) { elCell.innerHTML = PxUf.bytes(oData) + '/s'; }
};

/** A custom formatter for floating-point. Sets the elCell innerHTML to a fixed-mantissa representation of oData
* @method YAHOO.widget.DataTable.Formatter.customFixed
* @param mantissa {integer} number of decimal places to show
*/
YwDF.customFixed = function(mantissa) {
  var fn = PxUf.toFixed(mantissa);
  return function(elCell, oRecord, oColumn, oData) {
    if(oData != null) { elCell.innerHTML = fn(oData); }
  }
};

/** A custom formatter for percentages. Sets the elCell innerHTML to a fixed-mantissa representation of oData, with optional colour-coding to show different value-ranges
* @method YAHOO.widget.DataTable.Formatter.percentMap
* @param mantissa {integer} number of decimal places to show
* @param classMap {array} an array of <strong>{min:float, max:float, className:string}</strong> entries to css-code the field. An entry is applied to a field if it is => min and <= max. Either min or max may be omitted to specify an open range, or both may be omitted to set a global default. The first matching entry is taken, so it's up to the coder to make sure the fields don't overlap, or that they give the desired result if they do
*/
YwDF.percentMap = function(mantissa,classMap) {
  var fn = PxUf.toFixed(mantissa),
      Dom = YAHOO.util.Dom;
  return function(elCell, oRecord, oColumn, oData) {
    var className, item, i, value = fn(oData);
    if ( oData != null ) {
      for ( i in classMap ) {
        item = classMap[i];
        if ( item.min && value < item.min ) { continue; }
        if ( item.max && value > item.max ) { continue; }
        className = item.className;
        break;
      }
      if ( className ) { Dom.addClass(elCell,className); }
      elCell.innerHTML = value;
    }
//     if ( value == 0 ) { value = '-'; }
  }
};

/** A custom formatter for string data. Sets the elCell class according to a map of values
* @method YAHOO.widget.DataTable.Formatter.colourMap
* @param mantissa {integer} number of decimal places to show
* @param classMap {array} an array of <strong>{min:float, max:float, className:string}</strong> entries to css-code the field. An entry is applied to a field if it is => min and <= max. Either min or max may be omitted to specify an open range, or both may be omitted to set a global default. The first matching entry is taken, so it's up to the coder to make sure the fields don't overlap, or that they give the desired result if they do
*/
YwDF.colourMap = function(colourMap) {
  var Dom = YAHOO.util.Dom;
  return function(elCell, oRecord, oColumn, oData) {
    var item, i;
    if ( oData != null ) {
      for ( i in colourMap ) {
        item = colourMap[i];
        if ( item.key == oData ) {
          Dom.addClass(elCell,item.className);
        } else {
          Dom.removeClass(elCell,item.className);
        }
      }
    }
    elCell.innerHTML = oData;
  }
};

/** A custom formatter for string data. Builds a link from a template, using the cell data to complete it.
* @method YAHOO.widget.DataTable.Formatter.linkTo
* @param template {string} template for link
* @param regex {regex} expression to match in the template, to substitute for the cell value
* @param ifNull {string} string to use if the cell data is null
*/
YwDF.linkTo = function(template,regex,ifNull) {
  return function(elCell, oRecord, oColumn, oData) {
    if ( oData != null ) {
      oData = "<a href='"+template.replace(regex,oData)+"'>"+oData+"</a>";
    } else {
      if ( ifNull ) { oData = ifNull; }
    }
    elCell.innerHTML = oData;
  }
};

/**
* This class is called by PHEDEX.Component.ContextMenu to create the correct handler for datatable context menus.
* @namespace PHEDEX.DataTable
* @class ContextMenu
* @param obj {object} reference to the parent PHEDEX.DataTable object that this context-menu applies to.
* @param args {object} reference to an object that specifies details of how the control should operate.
*/
PHEDEX.DataTable.ContextMenu = function (obj, args) {
    var p = args.payload;
    if (!p.config) { p.config = {}; }
    if (!p.config.trigger) {
        var temp = [];
        temp.push(obj.dataTable.getTbodyEl());
        p.config.trigger = temp;
    }
    if (!p.typeNames) { p.typeNames = []; }
    p.typeNames.push('datatable');
    var fn = function (opts, el) {
        log('hideField: ' + el.col.label, 'info', 'component-contextmenu');
        el.obj.meta.hide[el.col.label] = 1; // have to pick up 'obj' this way, not from current outer scope. Don't know why!
        el.obj.dataTable.hideColumn(el.col);
    }
    PHEDEX.Component.ContextMenu.Add('datatable', 'Hide This Field', fn);

    var fnDump = function(opts,el) {
//    for some obscure reason, YAHOO.lang.JSON.stringify fails on data for datatable objects. It doesn't spit the dummy, it just returns empty arrays.
//    manually performing a deep-copy gets round this problem. Note that this manual deep copy is not perfect, it converts arrays into objects, but
//    that is OK for now. We won't want to re-load this data into this application, so this will do.
//    N.B. This is not a YAHOO bug, it's a feature of either Firefox or JSON itself. An array with named keys returns a length of zero, which screws
//    the stringifier.
      var w = window.open('', 'Window_'+PxU.Sequence(), 'width=640,height=480,scrollbars=yes'),
          d = el.obj.data,
          t, fn;
      fn = function(d1) {
//    I can avoid having to do the deep-copy if, in _processData, the Row is made an object, instead of an array...
//    ... except that, if _processData isn't called, and the data-service returned an array to the JSON formatter, this still goes
//    toes-up. So do this regardless. Wasteful, but only in this unusual circumstance.
        if ( typeof(d1) == 'object' || typeof(d1) == 'array' ) {
          var d2 = {};
          for (var i in d1) { d2[i] = fn(d1[i]); }
          return d2;
        }
        return d1;
      };
      try {
        var dd = fn(d),
        t = Ylang.JSON.stringify(dd);
      } catch (e) { alert(e.message); }
      w.document.writeln(t);
    };
    PHEDEX.Component.ContextMenu.Add('datatable','Show table data (JSON)', fnDump);

    // This function gets the column object from main or nested datatable and also indicates if the column is in main or nested datatable.
    var _getDTColumn = function (target) {
        var columnDetails = { nested: false },
            elCol = obj.dataTable.getColumn(target), indx,
            nestedTables = obj.nestedtables;
        if (!elCol) {
          for (indx in nestedTables) {
            elCol = nestedTables[indx].getColumn(target);
            if (elCol) {
              columnDetails.nested = true;
              columnDetails.elCol = elCol;
              return columnDetails; // Found the column. So, go out.
            }
          }
        }
        columnDetails.elCol = elCol;
        return columnDetails;
    }

    return {
        getExtraContextTypes: function () {
            var cArgs = p.obj.meta.ctxArgs, cUniq = {}, i;
            for (i in cArgs) {
                cUniq[cArgs[i]] = 1;
            }
            return cUniq;
        },

        // Context-menu handlers: onContextMenuBeforeShow allows to (re-)build the menu based on the element that is clicked.
        onContextMenuBeforeShow: function (target, typeNames) {
            var columnDetails, elCol, label, ctx=p.obj.meta.ctxArgs, indx;
            if (!ctx) { return typeNames; }
            columnDetails = _getDTColumn(target); // Get the column object from the datatable (main or nested)
            if ( elCol = columnDetails.elCol ) {
              label = elCol.label;
              if (!ctx[label]) {
                // Check if the column is in nested table. If so, don't show 'Hide this field' menu item
                if (columnDetails.nested) { return []; }
                return typeNames;
              }
            }
            if (columnDetails.nested) {
                // Check if the column is in nested table. If so, don't show 'Hide this field' menu item along with other menu items
                var temp = [];
                temp.unshift(ctx[label]);
                return temp;
            }
            typeNames.unshift(ctx[label]);
            return typeNames;
        },

        /**
        * click-handler for the context menu. Deduces the column, the row, and data-record that was selected, then calls the specific menu-handler associated with the item that was selected. The handler is passed two parameters: <strong>opts</strong> is a key:value map of the table-values in the selected row, driven by the <strong>args.payload.typeMap</strong> structure which defines the fields and their mapping. The second argument contains pointers to the datatable, the row, column, and record that were selected. This should probably not be used by clients because it represents rather deep and personal knowledge about the object.
        * @method onContextMenuClick
        * @private
        */
        onContextMenuClick: function (p_sType, p_aArgs, obj) {
          log('ContextMenuClick for ' + obj.me, 'info', 'datatable');
          var columnDetails, menuitem=p_aArgs[1], tgt, opts={}, elCol, elRow, oRecord, ctx, key, label, nt, dt;
          if (menuitem) {
            dt = obj.dataTable;
            nt = obj.nestedtables;
            //Extract which <tr> triggered the context menu
            tgt = this.contextEventTarget;
            columnDetails = _getDTColumn(tgt);
            elCol = columnDetails.elCol;
            elRow = dt.getTrEl(tgt);
            if (elRow) {
              opts = {};
              oRecord = dt.getRecord(elRow);
              if (!oRecord) {
                // Check if the record is in nested table (if user did right-click in nested table)
                var indx;
                for (indx in nt) {
                  oRecord = nt[indx].getRecord(elRow);
                  if (oRecord) {
                    break;
                  }
                }
              }
              //Map types to column names in order to prepare our options
              ctx = p.obj.meta.ctxArgs;
              if (ctx) {
                for (label in ctx) {
                  if (ctx[label] != ctx[elCol.label] || label == elCol.label) {
                    key = p.obj._getKeyByKeyOrLabel(label);
                    opts[ctx[label]] = oRecord.getData(key);
                  }
                }
              }
              menuitem.value.fn(opts, { obj: obj, row: elRow, col: elCol, record: oRecord });
            }
          }
        }
    };
}

/** This class is invoked by PHEDEX.Module to create the correct handler for datatable mouse-over events.
* @namespace PHEDEX.DataTable
* @class MouseOver
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object (unused)
* @param args {object} reference to an object that specifies details of how the control should operate. Only <strong>args.payload.obj.dataTable</strong> is used, to subscribe to the <strong>onRowMouseOver</strong> and >strong>onRowMouseOut</strong> events.
*/
PHEDEX.DataTable.MouseOver = function(sandbox,args) {
    var obj = args.payload.obj,
        _sbx = sandbox;
    /**
    * Reset the background-colour of the row after the mouse leaves it
    * @method onRowMouseOut
    * @private
    */
    var onRowMouseOut = function(event) {
        // Would like to use the DOM, but this gets over-ridden by yui-dt-odd/even, so set colour explicitly.
        // Leave this next line here in case phedex-drow-highlight ever becomes a useful class (e.g. when we do our own skins)
        // YuD.removeClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = null;
    }

    /**
    * Gratuitously set the background colour to yellow when the mouse goes over the rows
    * @method onRowMouseOver
    * @private
    */
    var onRowMouseOver = function(event) {
        //YuD.addClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = 'yellow';
    }
    obj.dataTable.subscribe('rowMouseoverEvent',onRowMouseOver);
    obj.dataTable.subscribe('rowMouseoutEvent', onRowMouseOut);
    // return the functions, so they can be overridden if needed without having to redo the event subscription

    _construct = function() {
      return {
        id: 'mouseover_' + PxU.Sequence(),

        _init: function() {
          this.selfHandler = function(o) {
            return function(ev,arr) {
              var action = arr[0],
                  value = arr[1];
              switch (action) {
                case 'addContextElement': {
                  value.subscribe('rowMouseoverEvent',onRowMouseOver);
                  value.subscribe('rowMouseoutEvent', onRowMouseOut);
                  break;
                }
              }
            }
          }(this);
          _sbx.listen(this.id,this.selfHandler);
        }
      };
    };
    Yla(this,_construct(this),true);
    this._init();
    return this; // { onRowMouseOut:onRowMouseOut, onRowMouseOver:onRowMouseOver};
};

PHEDEX.DataTable.Filter = function (sandbox, obj) {
    _construct = function () {
        return {
            /**
            * Resets the filter in the module.
            * @method resetFilter
            * @param arg {Object} The array of column keys with user entered filter values.
            * @private
            */
            resetFilter: function (args) {
                obj.sortNeeded = true;
                obj.fillDataSource(obj.data);
            },

            /**
            * This applies filter on a single row data and says if there is a match or not.
            * @method filterData
            * @param rowdata {Object} is the row data.
            * @param args {Object} is the filter columns definitions.
            * @param nested {Boolean} indicates if the current analyzed row is a nested row or not.
            * @param pathcache {Object} is the array of column fields which are converted in to walkpath.
            * @private
            */
            filterData: function (rowdata, args, nested, pathcache) {
                var j, a, field, status, fValue, kValue, keep = true;
                for (j in args) {
                    a = args[j];
                    field = this.meta._filter.fields[j];
                    fValue = a.values;
                    kValue = rowdata[obj._getKeyByKeyOrLabel(field.original)];
                    if (a.preprocess) { kValue = a.preprocess(kValue); }
                    status = this.Apply[field.type](fValue, kValue);
                    if (a.negate) { status = !status; }
                    if (!status) { // Don't add this element to filter result
                        keep = false;
                        break;
                    }
                }
                return keep;
            },

            /**
            * This gets the expanded rows currently in the table.
            * @method getExpandedRows
            * @private
            */
            getExpandedRows: function () {
                var recsetNested = obj.dataTable.getRecordSet(),
                    nLength = recsetNested.getLength(),
                    indx, objNested, rowNested, nUniqueID, arrExpanded = {};
                for (indx = 0; indx < nLength; indx++) {
                    rowNested = recsetNested.getRecord(indx);
                    objNested = rowNested.getData('__NESTED__');
                    if (objNested && objNested.expanded) {
                        nUniqueID = rowNested.getData('uniqueid');
                        arrExpanded[nUniqueID] = true;
                    }
                }
                return arrExpanded;
            },

            /**
            * This is to fire the cell click event on first column to show the nested tables.
            * @method showNestedTables
            * @private
            */
            showNestedTables: function (arrExpanded) {
                var recsetNested = obj.dataTable.getRecordSet(),
                    nLength = recsetNested.getLength(),
                    indx, rowNested, nUniqueID;
                for (indx = 0; indx < nLength; indx++) {
                    rowNested = recsetNested.getRecord(indx);
                    nUniqueID = rowNested.getData('uniqueid');
                    if (arrExpanded[nUniqueID]) {
                        rowNested = obj.dataTable.getRow(indx);
                        // Now fire the event for each row in the filtered datatable to show nested tables
                        obj.dataTable.fireEvent("cellClickEvent", { target: rowNested.cells[0], event: obj.dataTable.__yui_events.cellClickEvent });
                    }
                }
            },

            /**
            * Filters the module based on user input.
            * @method applyFilter
            * @param arg {Object} The array of column keys with user entered filter values.
            * @private
            */
            applyFilter: function (args) {
                // Parse the cached data to filter it and form new data that feeds the datasource
                var activeArgs = {}, activeNestedArgs = {}, keep, tableindx = 0, arrExpanded, row,
                pathcache = {}, table = [], arrNData = [], i, j, field, filterresult, bAnyMain = false, bAnyNested = false;
                if (!args) { args = this.args; }
                this.count = 0;
                for (j in args) { // quick explicit check for valid arguments, nothing to do if no filter is set
                    if (typeof (args[j].values) == 'undefined') { continue; }
                    field = this.meta._filter.fields[j];
                    if (field.nested) {
                        activeNestedArgs[j] = args[j];
                        bAnyNested = true;
                    }
                    else {
                        activeArgs[j] = args[j];
                        bAnyMain = true;
                    }
                }
                if (!bAnyMain && !bAnyNested) { return; }

                for (i in obj.data) {
                    row = obj.data[i];
                    keep = true; // This variable says if this row (including nested table rows) has a match or not?
                    // Check if main row has any match
                    if (bAnyMain) {
                        keep = this.filterData(row, activeArgs, false, pathcache);
                    }
                    // Check if nested table rows have any match only if there is a match in main row
                    if (bAnyNested && keep) {
                        var indx = 0, nkeep, arrNested = row['nesteddata'], nNestedLen = arrNested.length;
                        arrNData = [];
                        keep = false; // This is made false now and becomes true below when the nested table has match
                        for (indx = 0; indx < nNestedLen; indx++) {
                            nkeep = false;
                            nkeep = this.filterData(arrNested[indx], activeNestedArgs, true, pathcache);
                            if (nkeep) //Add this particular nested row to result
                            {
                                keep = true; //Add this nested data to result parent table
                                arrNData.push(arrNested[indx]);
                            }
                        }
                    }
                    if (keep) {
                        // Copy of the object is created because there might be changes in nested data.
                        // If the row object is not cloned and when new arrNData[] is assigned, 
                        // then 'nesteddata' values get overridden in cache which shouldn't happen.
                        var i, objClone = {};
                        for (i in row) {
                          objClone[i] = row[i];
                        }
                        table.push(objClone);
                        if (arrNData.length > 0) {
                            table[tableindx]['nesteddata'] = arrNData; // Assign the filter nested table rows
                        }
                        tableindx++;
                    } else {
                      this.count++;
                    }
                }
                obj.sortNeeded = true;
                arrExpanded = this.getExpandedRows(); // Get the current list of rows that are expanded
                obj.fillDataSource(table);
                obj.nestedtables = []; // Clear the previously added nested table's DOM object
                this.showNestedTables(arrExpanded); // Show nested tables (if were expanded) also after applying filter
                this.updateGUIElements(this.count);
                return;
            }
        };
    };
    Yla(this, _construct(this), true);
    return this;
};

log('loaded...', 'info', 'datatable');
