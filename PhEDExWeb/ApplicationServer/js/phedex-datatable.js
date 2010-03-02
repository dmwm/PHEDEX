/**
* This is the base class for all PhEDEx datatable-related modules. It extends PHEDEX.Module to provide the functionality needed for modules that use a YAHOO.Widget.DataTable.
* @namespace PHEDEX
* @class PHEDEX.Datatable
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.DataTable = function(sandbox, string) {
    YAHOO.lang.augmentObject(this, new PHEDEX.Module(sandbox, string));
    var _me = 'datatable', _sbx = sandbox;
   /**
    * Processes the response data so as to create a YAHOO.util.DataSource and display it on-screen.
    * @method _processData
    * @param moduledata {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
    * @param objtable {object} reference of datatable object that has column definitions and mapping information that is required for processing data
    * @private
    */
    var _processData = function(moduledata, objtable) {
        var table = [], i = moduledata.length, k = objtable.columnDefs.length, j;
        while (i > 0) {
            i--
            var a = moduledata[i], y = [];
            j = k;
            while (j > 0) {
                j--;
                var c = objtable.columnDefs[j], val = a[objtable.columnMap[c.key]];
                if (c.parser) {
                    if (typeof c.parser == 'function') { val = c.parser(val); }
                    else { val = YAHOO.util.DataSourceBase.Parser[c.parser](val); }
                }
                y[c.key] = val;
            }
            table.push(y);
        }
        objtable.needProcess = false; //No need to process data further
        return table;
    };

    /**
    * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
    * @method _construct
    * @private
    */
    _construct = function() {
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
            /** Initialise the data-table, using the parameters in this.meta.table, set in the module during construction
            * @method initDerived
            * @private
            */
            initDerived: function() {
                var m = this.meta, t = m.table, h = {}, i;
                for (i in m.hide ) { h[m.hide[i]] = 1; }
                m.hide = h;
                if (t) {
                    this.buildTable(t.columns, t.map, t.schema)
                    _sbx.notify(this.id, 'initDerived');
                }
                this.decorators.push(
                {
                    name: 'Filter',
                    source: 'component-filter',
                    payload: {
                        control: {
                            parent: 'control',
                            payload: {
                                disabled: false, //true,
                                hidden: true
                            },
                            el: 'content'
                        }
                    },
                    target: 'filter'
                });
              this.meta._filter = this.createFilterMeta();

              var moduleHandler = function(o) {
                return function(ev,arr) {
                  var action = arr[0];
                  switch ( action ) {
                    case 'gotData': {
                      o.postExpand();
                      break;
                    }
                  }
                }
              }(this);
              _sbx.listen(this.id,moduleHandler);
            },

            postExpand: function(step,node) {
              var steps = [], i, j;
              steps.push('doSort'); steps.push('doFilter'); steps.push('doResize'); steps.push('hideFields');
              //this.markOverflows();
              for (i in steps) { _sbx.notify(this.id,steps[i]); }
            },
            /**
            * Create a YAHOO.util.DataSource from the data-structure passed as argument, and display it on-screen.
            * @method fillDataSource
            * @param moduledata {object} tabular data (2-d array) used to fill the datatable. The structure is expected to conform to <strong>data[i][key] = value</strong>, where <strong>i</strong> counts the rows, and <strong>key</strong> matches a name in the <strong>columnDefs</strong> for this table.
            */
            fillDataSource: function(moduledata) {
                if (this.dsResponseSchema) {
                    this.fillDataSourceWithSchema(moduledata); //Fill datasource directly if schema is available
                    return;
                }
                if (this.needProcess) {
                    // Process the data if it is new to module and is not from filter
                    this.data = _processData(moduledata, this);
                    moduledata = this.data;     // Cache the processed data for further use by filter
                }
                this.dataSource = new YAHOO.util.DataSource(moduledata);
                var oCallback = {
                    success: this.dataTable.onDataReturnInitializeTable,
                    failure: this.dataTable.onDataReturnInitializeTable,
                    scope: this.dataTable
                };
                this.dataSource.sendRequest('', oCallback);
                var w = this.dataTable.getTableEl().offsetWidth;
                this.el.style.width = w + 'px';
                //_sbx.notify(this.id,'doFilter');
            },

            /**
            * hide all columns which have been declared to be hidden by default. Needed on initial rendering, on update, or after filtering. Uses <strong>this.options.hide</strong> to determine what to hide.
            * @method hideFields
            */
            hideFields: function() {
                if (this.meta.hide) {
                    for (var key in this.meta.hide) {
                        var column = this.dataTable.getColumn(key);
                        if (column) { this.dataTable.hideColumn(column); }
                    }
                }
                var w = this.dataTable.getTableEl().offsetWidth;
                if (this.options.minwidth && w < this.options.minwidth) { w = this.options.minwidth; }
                this.el.style.width = w + 'px';
            },

            /** Fill a data-source with JSON data, using a schema to describe it. Used internally by <strong>fillDataSource</strong> if a schema is provided
            * @method fillDataSourceWithSchema
            * @param jsonData {JSON data} a JSON object that contains the data for the table
            * @param dsSchema {YAHOO.util.DataSource.responseSchema} an object describing the contents of the JSON object
            * @private
            */
            fillDataSourceWithSchema: function(jsonData) {
                this.dataSource = new YAHOO.util.DataSource(jsonData);
                this.dataSource.responseSchema = this.dsResponseSchema;
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
                for (var i in args) {
                  delete this.meta.hide[args[i]];
                  this.dataTable.showColumn(this.dataTable.getColumn(args[i]));
                }
                _sbx.notify(this.id, 'updateHistory');
            },

            /**
            * Used to resize the panel when viewing modules in 'window' mode. Specifically, when the table is redrawn, either for new data or for a column being shown or hidden, this will make sure the width of the table is extended to show all the data.
            * @method resizePanel
            * @private
            */
            resizePanel: function() {
                var table = this.dataTable,
                old_width = table.getContainerEl().clientWidth,
                offset = this.dom.header.offsetWidth - this.dom.content.offsetWidth,
                x = table.getTableEl().offsetWidth + offset;
                if (x >= old_width) {
                    this.module.cfg.setProperty('width', x + 'px');
                    this.el.style.width = x + 'px';
                }
            },

            sort: function() {
                var s = this.meta.sort;
                if (!s.dir) { s.dir = YAHOO.widget.DataTable.CLASS_ASC; }
                if (s.field) {
                    if (s.sorted_field == s.field &&
                        s.sorted_dir   == s.dir &&
                       !this.sortNeeded) { return; } // break the chain!
                    s.sorted_field = s.field;
                    s.sorted_dir   = s.dir;
                    this.sortNeeded = false;
                    this.dataTable.sortColumn(this.dataTable.getColumn(s.field), s.dir);
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
            buildTable: function(columns, map, dsschema) {
                this.columnDefs = columns;
                this.needProcess = true;            //Process data by default
                this.columnMap = map || {};         //{table-column-name:JSON-field-name, ...};
                this.dsResponseSchema = dsschema;   //Stores the response schema for the datasource
                var i = this.columnDefs.length;
                while (i > 0) {
                    i--;
                    var cDef = this.columnDefs[i];
                    if (typeof cDef != 'object') { cDef = { key: cDef }; this.columnDefs[i] = cDef; }
                    if (!cDef.resizeable) { cDef.resizeable = true; }
                    if (!cDef.sortable) { cDef.sortable = true; }
                    if (!this.columnMap[cDef.key]) { this.columnMap[cDef.key] = cDef.key.toLowerCase(); }
                }
                this.dataSource = new YAHOO.util.DataSource();
                this.dataTable = new YAHOO.widget.DataTable(this.dom.content, this.columnDefs, this.dataSource, { draggableColumns: true, initialLoad: false });
                var w = this.dataTable.getTableEl().offsetWidth;
                this.el.style.width = w + 'px';

                this.dataTable.subscribe('columnSortEvent', function(obj) {
                    return function(ev) {
                        var column = obj.dataTable.getColumn(ev.column);
                        obj.meta.sort.field = column.key;
                        obj.meta.sort.dir = ev.dir;
                        _sbx.notify(obj.id,'updateHistory');
                    }
                } (this));

                this.dataTable.subscribe('columnHideEvent', function(obj) {
                    return function(ev) {
                        var column = obj.dataTable.getColumn(ev.column);
                        log('columnHideEvent: label:' + column.label + ' key:' + column.key, 'info', _me);
                        _sbx.notify(obj.id, 'hideColumn', { text: column.label || column.key, value: column.key });
                    }
                } (this));

                this.dataTable.subscribe('renderEvent', function(obj) {
                    return function() {
                        obj.resizePanel();
                        obj.sort();
                    }
                } (this));
                var w = this.dataTable.getTableEl().offsetWidth;
                if (this.options.minwidth && w < this.options.minwidth) { w = this.options.minwidth; }
                this.el.style.width = w + 'px';
            },
            
            /** return a boolean indicating if the module is in a fit state to be bookmarked
            * @method isStateValid
            * @return {boolean} <strong>false</strong>, must be over-ridden by derived types that can handle their separate cases
            */
            isStateValid: function() {
                if ( this.obj.data ) { return true; } // TODO is this good enough...? Use _needsParse...?
                return false;
            },
            
            /** return a string with the state of the object. The object must be capable of receiving this string and setting it's state from it
            * @method getState
            * @return {string} the state of the object, in any reasonable format that conforms to the navigator's parser
            */
            dirMap: function(dir) {
                var i, map = { 'yui-dt-asc':'asc', 'yui-dt-desc':'desc' };
                if ( map[dir] ) { return map[dir]; }
                for ( i in map ) {
                    if ( map[i] == dir ) { return i; }
                }
            }
       };
    };
    YAHOO.lang.augmentObject(this, _construct(), true);
    return this;
}

/** A custom formatter for unix-epoch dates. Sets the elCell innerHTML to the GMT representation of oDate
* @method YAHOO.widget.DataTable.Formatter.UnixEpochToGMT
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} unix epoch seconds
*/
YAHOO.widget.DataTable.Formatter.UnixEpochToGMT =  function(elCell, oRecord, oColumn, oData) {
    var gmt = new Date(oData*1000).toGMTString();
    elCell.innerHTML = gmt;
};

/** A custom formatter for byte-counts. Sets the elCell innerHTML to the smallest reasonable representation of oData, with units
* @method YAHOO.widget.DataTable.Formatter.customBytes
* @param elCell {HTML element} Cell for which the formatter must be applied
* @param oRecord {datatable record}
* @param oColumn {datatable column}
* @param oData {data-value} number of bytes
*/
YAHOO.widget.DataTable.Formatter.customBytes = function(elCell, oRecord, oColumn, oData) {
    if(oData)
    {
        elCell.innerHTML = PHEDEX.Util.format.bytes(oData);
    }
};

/**
* This class is called by PHEDEX.Component.ContextMenu to create the correct handler for datatable context menus.
* @namespace PHEDEX.DataTable
* @class ContextMenu
* @param obj {object} reference to the parent PHEDEX.DataTable object that this context-menu applies to.
* @param args {object} reference to an object that specifies details of how the control should operate.
*/
PHEDEX.DataTable.ContextMenu = function(obj,args) {
    var p = args.payload;
    if ( !p.config ) { p.config={}; }
    if ( !p.config.trigger ) { p.config.trigger = obj.dataTable.getTbodyEl(); }
    if ( !p.typeNames ) { p.typeNames=[]; }
    p.typeNames.push('datatable');
    var fn = function(opts, el) {
      log('hideField: ' + el.col.key, 'info', 'component-contextmenu');
      obj.meta.hide[el.col.key] = 1;
      el.table.hideColumn(el.col);
    }
    PHEDEX.Component.ContextMenu.Add('datatable','Hide This Field',fn);

    return {
        /**
        * click-handler for the context menu. Deduces the column, the row, and data-record that was selected, then calls the specific menu-handler associated with the item that was selected. The handler is passed two parameters: <strong>opts</strong> is a key:value map of the table-values in the selected row, driven by the <strong>args.payload.typeMap</strong> structure which defines the fields and their mapping. The second argument contains pointers to the datatable, the row, column, and record that were selected. This should probably not be used by clients because it represents rather deep and personal knowledge about the object.
        * @method onContextMenuClick
        * @private
        */
        onContextMenuClick: function(p_sType, p_aArgs, obj) {
            log('ContextMenuClick for ' + obj.me, 'info', 'ContextMenu');
            var menuitem = p_aArgs[1], tgt, opts={}, type;
            if (menuitem) {
                //Extract which <tr> triggered the context menu
                tgt = this.contextEventTarget,
                elCol = obj.dataTable.getColumn(tgt),
                elRow = obj.dataTable.getTrEl(tgt);
                if (elRow) {
                    opts = {};
                    oRecord = obj.dataTable.getRecord(elRow);
                    //Map types to column names in order to prepare our options
                    if (p.typeMap) {
                        for (type in p.typeMap) {
                            opts[type] = oRecord.getData(p.typeMap[type]);
                        }
                    }
                    menuitem.value.fn(opts, { table: obj.dataTable, row: elRow, col: elCol, record: oRecord });
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
    var obj = args.payload.obj;
    /**
    * Reset the background-colour of the row after the mouse leaves it
    * @method onRowMouseOut
    * @private
    */
    var onRowMouseOut = function(event) {
        // Would like to use the DOM, but this gets over-ridden by yui-dt-odd/even, so set colour explicitly.
        // Leave this next line here in case phedex-drow-highlight ever becomes a useful class (e.g. when we do our own skins)
        // YAHOO.util.Dom.removeClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = null;
    }

    /**
    * Gratuitously set the background colour to yellow when the mouse goes over the rows
    * @method onRowMouseOver
    * @private
    */
    var onRowMouseOver = function(event) {
        //YAHOO.util.Dom.addClass(event.target,'phedex-drow-highlight');
        event.target.style.backgroundColor = 'yellow';
    }
    obj.dataTable.subscribe('rowMouseoverEvent',onRowMouseOver);
    obj.dataTable.subscribe('rowMouseoutEvent', onRowMouseOut);
    // return the functions, so they can be overridden if needed without having to redo the event subscription
    return { onRowMouseOut:onRowMouseOut, onRowMouseOver:onRowMouseOver};
};

/** This class is invoked by PHEDEX.Module to create the correct handler for datatable mouse-over events.
* @namespace PHEDEX.DataTable
* @class Filter
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object (unused)
* @param obj {object} reference to the parent PHEDEX.DataTable object that this filter applies to.
*/
PHEDEX.DataTable.Filter = function(sandbox, obj) {
    // Function to convert the filter column field into walk path to find its value
    var _buildPath = function(needle) {
        var path = null, keys = [], i = 0;
        if (needle) {
            // Strip the ["string keys"] and [1] array indexes
            needle = needle.
                        replace(/\[(['"])(.*?)\1\]/g,
                        function(x, $1, $2) { keys[i] = $2; return '.@' + (i++); }).
                        replace(/\[(\d+)\]/g,
                        function(x, $1) { keys[i] = parseInt($1, 10) | 0; return '.@' + (i++); }).
                        replace(/^\./, ''); // remove leading dot

            // If the cleaned needle contains invalid characters, the
            // path is invalid
            if (!/[^\w\.\$@]/.test(needle)) {
                path = needle.split('.');
                for (i = path.length - 1; i >= 0; --i) {
                    if (path[i].charAt(0) === '@') {
                        path[i] = keys[parseInt(path[i].substr(1), 10)];
                    }
                }
            }
            else {
            }
        }
        return path;
    };

    // Function to walk a path and return the value
    var _walkPath = function(path, origin) {
        var v = origin, i = 0, len = path.length;
        for (; i < len && v; ++i) {
            v = v[path[i]];
        }
        return v;
    };

    _construct = function() {
      return {
        /**
        * Resets the filter in the module.
        * @method resetFilter
        * @param arg {Object} The array of column keys with user entered filter values.
        * @private
        */
        resetFilter: function(args) {
          obj.sortNeeded = true;
          if (obj.dsResponseSchema) {
            var filterresult = {};
            filterresult[obj.dsResponseSchema.resultsList] = obj.data;
            obj.fillDataSource(filterresult);
          }
          else {
            obj.fillDataSource(obj.data);
          }
        },

        /**
        * Filters the module based on user input.
        * @method applyFilter
        * @param arg {Object} The array of column keys with user entered filter values.
          * @private
          */
          applyFilter: function(args) {
            // Parse the cached data to filter it and form new data that feeds the datasource
            var keep, fValue, kValue, status, a, pathcache = {}, table = [], field, i, j, filterresult;
            if (!args) { args = this.args; }
            for (i in obj.data) {
                keep = true;
                for (j in args) {
                    a = args[j];
                    field = this.meta._filter.fields[j];
                    if (typeof (a.values) == 'undefined') { continue; }
                    fValue = a.values;
                    kValue = obj.data[i][field.original];
                    // If buildPath is true, then the column key has to be resolved to build complete path to get the value
                    if (field.buildPath) {
                        if (!pathcache[j]) {
                            pathcache[j] = _buildPath(j);
                        }
                        kValue = _walkPath(pathcache[j], obj.data[i]);
                    }
                    if (a.preprocess) { kValue = a.preprocess(kValue); }
                    status = this.Apply[field.type](fValue, kValue);
                    if (a.negate) { status = !status; }
                    if (!status) { // Keep the element if the match succeeded!
                        this.count++;
                        keep = false;
                    }
                }
                if (keep) { table.push(obj.data[i]); }
            }
            obj.sortNeeded = true;
            if (obj.dsResponseSchema) {
                filterresult = {};
                filterresult[obj.dsResponseSchema.resultsList] = table;
                obj.fillDataSource(filterresult);
            }
            else {
                obj.fillDataSource(table);
            }
            return this.count;
          },

      doFilter: function() {
        obj.applyFilter();
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  return this;
};

log('loaded...','info','datatable');