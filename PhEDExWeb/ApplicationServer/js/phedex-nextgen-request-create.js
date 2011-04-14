PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.Create = function(sandbox) {
  var string = 'nextgen-request-create',
      _sbx = sandbox,
      Dom = YAHOO.util.Dom;
  Yla(this,new PHEDEX.Module(_sbx,string));

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      options: {
        width:500,
        height:200,
        minwidth:600,
        minheight:50
      },
      /**
       * Properties used for configuring the module.
       * @property meta
       * @type Object
       */
      meta: {
        table: { columns: [{ key:'dataset',       label:'Dataset', className:'align-left' },
                           { key:'blocks',        label:'Blocks',  className:'align-right', parser:'number' },
                           { key:'bytes',         label:'Bytes',   className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'time_create',   label:'Creation time', className:'align-right', formatter:'UnixEpochToGMT', parser:'number' },
                           { key:'is_open',       label:'Open' }],
            nestedColumns:[{ key:'block',         label:'Block', className:'align-left' },
                           { key:'b_files',       label:'Files', className:'align-right', parser:'number' },
                           { key:'b_bytes',       label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'b_time_create', label:'Creation time', formatter:'UnixEpochToGMT', parser:'number' },
                           { key:'b_is_open',     label:'Open' }]
                },
      },
      waitToEnableAccept:2,
      useElement: function(el) {
        var d = this.dom;
        d.target = el;
        d.container  = document.createElement('div'); d.container.className  = 'phedex-nextgen-container'; d.container.id = 'doc2';
        d.hd         = document.createElement('div'); d.hd.className         = 'phedex-nextgen-hd';        d.hd.id = 'hd';
        d.bd         = document.createElement('div'); d.bd.className         = 'phedex-nextgen-bd';        d.bd.id = 'bd';
        d.ft         = document.createElement('div'); d.ft.className         = 'phedex-nextgen-ft';        d.ft.id = 'ft';
        d.main       = document.createElement('div'); d.main.className       = 'yui-main';
        d.main_block = document.createElement('div'); d.main_block.className = 'yui-b phedex-nextgen-main-block';

        d.bd.appendChild(d.main);
        d.main.appendChild(d.main_block);
        d.container.appendChild(d.hd);
        d.container.appendChild(d.bd);
        d.container.appendChild(d.ft);
        el.innerHTML = '';
        el.appendChild(d.container);

        d.floating_help = document.createElement('div'); d.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible';
        document.body.appendChild(d.floating_help);
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
      init: function(args) {
        if ( !args ) { args={}; }
        var type=args.type, el;
        if ( type == 'xfer' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Xfer(_sbx,args));
        } else if ( type == 'delete' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Delete(_sbx,args));
        } else if ( !type ) {
        } else {
          throw new Error('type is defined but unknown: '+type);
        }
        this.useElement(args.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr[1];
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action](value);
            }
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
        this.initSub();
        this.initButtons();
      },
      initButtons: function() {
        var ft=this.dom.ft, Reset, //, Validate, Cancel;
            el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-left');
        el.id='buttons-left';
        ft.appendChild(el);

        el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-centre');
        el.id='buttons-centre';
        ft.appendChild(el);

        el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-right');
        el.id='buttons-right';
        ft.appendChild(el);

        var label='Reset', id='button'+label;
        Reset = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-left' });
        label='Preview', id='button'+label;
        this.Preview = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
//         this.Preview.set('disabled',true);
        this.Preview.on('click', this.onPreviewSubmit);
        label='Accept', id='button'+label;
        this.Accept = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
        this.Accept.set('disabled',true);
        this.Accept.on('click', this.onAcceptSubmit);

        this.onResetSubmit = function(obj) {
          return function(id,action) {
            var dbs = obj.dbs,
                dom = obj.dom,
                user_group  = obj.user_group,
                email       = obj.email,
                time_start  = dom.time_start,
                data_items  = dom.data_items,
                comments    = dom.comments,
                menu, menu_items,
                tmp, elList, _default, el, i;

// Subscription level: hardwired to 'block' in the request

// Data Items
            data_items.value = '';
            data_items.onblur();

// DBS
            if ( dbs.gotMenu ) {
              dbs.value.innerHTML = dbs._default;
              menu       = dbs.MenuButton.getMenu();
              menu_items = menu.getItems();
              menu.activeItem = menu_items[dbs.defaultId];
            }

// Destination
            elList = obj.destination.elList;
            for (i in elList) {
              elList[i].checked = false;
            }
            obj.destination.selected = {};

// Remove Subscription
            if ( tmp = obj.remove_subscription ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Site Custodial
            if ( tmp = obj.site_custodial ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Subscription Type
            if ( tmp = obj.subscription_type ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Transfer Type
            if ( tmp = obj.transfer_type ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Priority
            if ( tmp = obj.priority ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// User Group
            if ( user_group ) {
              user_group.MenuButton.set('label', user_group._default);
              user_group.value = null;
            }

// Time Start
// TODO need to reset the calendar YUI module too
            if ( time_start ) {
              time_start.value = '';
              time_start.onblur();
            }

// Email
            if ( email ) {
              email.value.innerHTML = email.input.value = email._default;
            }

// Comments
            if ( comments ) {
              comments.value = '';
              comments.onblur();
            }

            obj.Accept.set('disabled',false);
            dom.preview_text.innerHTML = dom.preview_label.innerHTML = '';
            Dom.addClass(dom.preview,'phedex-invisible');
            Dom.addClass(dom.results,'phedex-invisible');
          }
        }(this);
        Reset.on('click', this.onResetSubmit);
      },
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
      previewCallback: function(data,context) {
        var rid, api=context.api, Table=[], Row, Nested, unique=0, ds, block, nFiles, nBytes, tDatasets=0, tBlocks=0, tFiles=0, tBytes=0;
        switch (api) {
          case 'data': {
            var dom=this.dom, datasets=data.dbs, ds, dsName, blocks, block, i, j, n,
                t=this.meta.table, cDef;
            Dom.removeClass(dom.preview,'phedex-box-yellow');
            if ( !datasets ) {
              dom.preview_text.innerHTML = 'Error retrieving information from the data-service';
              Dom.addClass(dom.preview,'phedex-box-red');
              return;
            }
            if ( datasets.length == 0 ) {
              dom.preview_text.innerHTML = 'No data found matching your selection';
              Dom.addClass(dom.preview,'phedex-box-red');
              return;
            }
            Dom.removeClass(dom.preview,'phedex-box-red');
            dom.preview_label.innerHTML = 'Preview:';
            dom.preview_text.innerHTML = "<div id='phedex-preview-summary'></div><div id='phedex-preview-table'></div>";
            dom.preview_summary = Dom.get('phedex-preview-summary');
            dom.preview_table   = Dom.get('phedex-preview-table');
            datasets = datasets[0].dataset;
            for (i in datasets) {
              Nested = [];
              ds = datasets[i];
              Row = { dataset:ds.name, block:0, time_create:ds.time_create, is_open:ds.is_open };
              Row.uniqueid = unique++;
              nFiles = nBytes = 0;
              for (j in ds.block ) {
                block = ds.block[j];
                nFiles += parseInt(block.files);
                nBytes += parseInt(block.bytes);
                Nested.push({ block:block.name, b_time_create:block.time_create, b_is_open:block.is_open, b_files:block.files, b_bytes:block.bytes });
              }
              if ( Nested.length > 0 ) {
                tBlocks += Nested.length;
                tFiles  += nFiles;
                tBytes  += nBytes;
                Row.blocks = Nested.length;
                Row.nesteddata = Nested;
                Row.bytes = nBytes;
              }
              Table.push(Row);
            }
            tDatasets = datasets.length;
            dom.preview_summary.innerHTML = tDatasets+' datasets, '+tBlocks+' blocks, '+tFiles+' files, '+PxUf.bytes(tBytes);
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
            var oCallback = {
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
              // This is to maintain the list of created nested tables that would be used in context menu
              if ( !o.nestedtables ) {
                o.nestedtables = {};
              }
              o.nestedtables[dt.getId()] = dt;
            }, this);
            this.dataSource.sendRequest('', oCallback);

            var column = this.dataTable.getColumn('dataset');
            this.dataTable.sortColumn(column, YAHOO.widget.DataTable.CLASS_ASC);
            break;
          }
        }
      },
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

PHEDEX.Nextgen.Request.Xfer = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
  return {
    initSub: function() {
      var d = this.dom,
          mb = d.main_block,
          hd = d.hd,
          form, elList, el, label, control, i, ctl;
      hd.innerHTML = 'Subscribe data';

      form = document.createElement('form');
      form.id   = 'subscribe_data';
      form.name = 'subscribe_data';
      mb.appendChild(form);

// Subscription level

// Dataset/block name(s)
      this.data_items = {
        text:'enter one or more block/data-set names, separated by white-space or commas.',
        help_text:"<p><strong>/Primary/Processed/Tier</strong> or<br/><strong>/Primary/Processed/Tier#Block</strong></p><p>Use an asterisk (*) as wildcard, and either whitespace or a comma as a separator between multiple entries</p><p>Even if wildcards are used, the dataset path separators '/' are required. E.g. to subscribe to all 'Higgs' datasets you would have to write '/Higgs/*/*', not '/Higgs*'.</p>"
      };
      var data_items = this.data_items;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-data-items'>Data Items <a class='phedex-nextgen-help' id='phedex-help-data-items' href='#'>[?]</a></div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + data_items.text + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      data_items.help_align = Dom.get('phedex-label-data-items');
      Dom.get('phedex-help-data-items').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','data_items');");

      d.data_items = Dom.get('data_items');
      d.data_items.onfocus = function(obj) {
        return function() {
          if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
          if ( this.value == data_items.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
          }
        }
      }(this);
      d.data_items.onblur=function() {
        if ( this.value == '' ) {
          this.value = data_items.text;
          Dom.setStyle(this,'color',null);
        }
      }

// Preview
      el = document.createElement('div');
      el.innerHTML = "<div id='phedex-nextgen-preview'>" + // class='phedex-invisible'>" +
                       "<div class='phedex-nextgen-form-element'>" +
                          "<div id='phedex-nextgen-preview-label' class='phedex-nextgen-label'></div>" +
                          "<div class='phedex-nextgen-control'>" +
                            "<div id='phedex-nextgen-preview-text'></div>" +
                          "</div>" +
                        "</div>" +
                        "<div class='phedex-nextgen-preview-button'><div id='preview-button-right' class='phedex-nextgen-buttons-right'></div></div>" +
                      "</div>";
      form.appendChild(el);
      d.preview = Dom.get('phedex-nextgen-preview');
      d.preview_label  = Dom.get('phedex-nextgen-preview-label');
      d.preview_text   = Dom.get('phedex-nextgen-preview-text');
      d.preview_button = Dom.get('preview-button-right');

// DBS
      this.dbs = {
        instanceDefault:{
          prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          test:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          debug:'LoadTest',
          tbedi:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          tbedii:'test',
          tony:'test'
        }
      };

      var dbs = this.dbs,
          instance = PHEDEX.Datasvc.Instance();
      dbs._default = dbs.instanceDefault[instance.instance] || '(not defined)';

      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='dbs_selected'>" + "<span id='dbs_value'>" + dbs._default + "</span>" +
                            "<span>&nbsp;</span>" + "<a id='change_dbs' class='phedex-nextgen-form-link' href='#'>change</a>" +
                          "</div>" +
                        "<div id='dbs_menu''></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      dbs.menu     = Dom.get('dbs_menu');
      dbs.value    = Dom.get('dbs_value');
      dbs.selected = Dom.get('dbs_selected');
      Dom.setStyle(dbs.value,'color','grey');

      var makeDBSMenu = function(obj) {
        return function(data,context) {
          var onMenuItemClick, onChangeDBSClick, dbsMenuItems=[], dbsList, dbsEntry, i;
          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
            if ( sText.match(/<strong>(.*)<\/strong>/) ) { sText = RegExp.$1; }
            dbs.MenuButton.set('label', '<em>'+sText+'</em>');
          };
          dbsList = data.dbs;
          for (i in dbsList ) {
            dbsEntry = dbsList[i];
            if ( dbsEntry.name == dbs._default ) {
              dbsEntry.name = '<strong>'+dbsEntry.name+'</strong>';
              dbs.defaultId = i;
            }
            dbsMenuItems.push( { text:dbsEntry.name, value:dbsEntry.id, onclick:{ fn:onMenuItemClick } } );
          }
          dbs.menu.innerHTML = '';
          dbs.MenuButton = new YAHOO.widget.Button({  type: 'menu',
                                  label: '<em>'+dbs._default+'</em>',
                                  id:   'dbsMenuButton',
                                  name: 'dbsMenuButton',
                                  menu:  dbsMenuItems,
                                  container: 'dbs_menu' });
          dbs.MenuButton.on('selectedMenuItemChange',function(event) {
            var menuItem = event.newValue,
                value    = menuItem.cfg.getProperty('text');
                if ( value.match(/<strong>(.*)</) ) { value = RegExp.$1; }
            dbs.value.innerHTML = value;
            Dom.removeClass(dbs.selected,'phedex-invisible');
            Dom.setStyle(dbs.MenuButton,'display','none');
          });
          obj.dbs.gotMenu = true;
        }
      }(this);

      onChangeDBSClick = function(obj) {
        return function() {
          if ( !obj.dbs.gotMenu ) {
            PHEDEX.Datasvc.Call({ api:'dbs', callback:makeDBSMenu });
            dbs.menu.innerHTML = '<em>loading menu, please wait...</em>';
            Dom.addClass(dbs.selected,'phedex-invisible');
          } else {
            Dom.setStyle(dbs.MenuButton,'display',null);
            Dom.addClass(dbs.selected,'phedex-invisible');
          }
        };
      }(this);
      Event.on(Dom.get('change_dbs'),'click',onChangeDBSClick);

// Destination
      this.destination = { nodes:[], selected:[] };
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form-element');
      el.innerHTML = "<div id='destination-container' class='phedex-nextgen-form-element'>" +
                       "<div class='phedex-nextgen-label'>Destination</div>" +
                       "<div id='destination-panel' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
                         "<em>loading destination list...</em>" +
                       "</div>" +
                     "</div>";
      form.appendChild(el);
      d.destination = Dom.get('destination-container');
      var makeNodePanel = function(obj) {
        return function(data,context) {
          var nodes=[], node, i, j, k, pDiv, destination=d.destination;

          for ( i in data.node ) {
            node = data.node[i].name;
            if ( instance.instance != 'prod' ) { nodes.push(node ); }
            else {
              if ( node.match(/^T(0|1|2|3)_/) && !node.match(/^T[01]_.*_(Buffer|Export)$/) ) { nodes.push(node ); }
            }
          }
          nodes = nodes.sort();
          pDiv = Dom.get('destination-panel');
          pDiv.innerHTML = '';
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            node.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              pDiv.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            pDiv.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input class='phedex-checkbox' type='checkbox' name='"+node+"' />"+node+"</div>";
            obj.destination.nodes.push(node);
          }
          destination.appendChild(pDiv);
          obj.destination.elList = Dom.getElementsByClassName('phedex-checkbox','input',destination);
          var onDestinationClick =function(event, matchedEl, container) {
                if (Dom.hasClass(matchedEl, 'phedex-checkbox')) {
                  obj.Accept.set('disabled',false);
                }
              };
          YAHOO.util.Event.delegate(destination, 'click', onDestinationClick, 'input');

          if ( --obj.waitToEnableAccept == 0 ) { obj.Accept.set('disabled',false); }
        }
      }(this);
      setTimeout( function() { PHEDEX.Datasvc.Call({ api:'nodes', callback:makeNodePanel }); }, 5000);

// Site Custodial
      this.site_custodial = {
        values:['yes','no'],
        _default:1,
        help_text:'<p>Whether or not the target node(s) have a custodial responsibility for the data in this request.</p><p>Only T1s and the T0 maintain custodial copies, T2s and T3s never have custodial responsibility</p>'
      };
      var site_custodial = this.site_custodial;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-site-custodial'>Site Custodial <a class='phedex-nextgen-help' id='phedex-help-site-custodial' href='#'>[?]</a></div>" +
                        "<div id='site_custodial' class='phedex-nextgen-control'>" +
                          "<div><input class='phedex-radio' type='radio' name='site_custodial' value='0'>yes</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='site_custodial' value='1' checked>no</input></div>" +
                       "</div>" +
                     "</div>";
      form.appendChild(el);
      site_custodial.help_align = Dom.get('phedex-label-site-custodial');
      Dom.get('phedex-help-site-custodial').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','site_custodial');");
      site_custodial.elList = elList = Dom.getElementsByClassName('phedex-radio','input',d.site_custodial);

// Subscription type
      this.subscription_type = {
        values:['growing','static'],
        _default:0,
        help_text:'<p>A <strong>growing</strong> subscription downloads blocks/files added to open datasets/blocks as they become available, until the dataset/block is closed.</p><p>Also, wildcard patterns will be re-evaluated to match new datasets/blocks which become available.</p><p>A <strong>static</strong> subscription will expand datasets into block subscriptions.</p><p>Wildcard patterns will not be re-evaluated. A static subscription is a snapshot of blocks available now</p>'
      };
      var subscription_type = this.subscription_type;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-subscription-type'>Subscription Type <a class='phedex-nextgen-help' id='phedex-help-subscription-type' href='#'>[?]</a></div>" +
                        "<div id='subscription_type' class='phedex-nextgen-control'>" +
                          "<div><input class='phedex-radio' type='radio' name='subscription_type' value='0' checked>growing</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='subscription_type' value='1'>static</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      subscription_type.help_align = Dom.get('phedex-label-subscription-type');
      Dom.get('phedex-help-subscription-type').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','subscription_type');");
      d.subscription_type = Dom.get('subscription_type');
      subscription_type.elList = elList = Dom.getElementsByClassName('phedex-radio','input',d.subscription_type);

// Transfer type
      this.transfer_type = {
        values:['replica','move'],
        _default:0,
        help_text:'<p>A <strong>replica</strong> replicates data from the source to the destination, creating a new copy of the data.</p><p>A <strong>move</strong> replicates the data then deletes the data at the source. The deletion will be automatic if the source data is unsubscribed; if it is subscribed, the source site will be asked to approve or disapprove the deletion.</p><p>Note that moves are only used for moving data from T2s to T1s</p>'
      };
      var transfer_type = this.transfer_type;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-transfer-type'>Transfer Type <a class='phedex-nextgen-help' id='phedex-help-transfer-type' href='#'>[?]</a></div>" +
                        "<div id='transfer_type' class='phedex-nextgen-control'>" +
                          "<div><input class='phedex-radio' type='radio' name='transfer_type' value='0' checked>replica</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='transfer_type' value='1'>move</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      transfer_type.help_align = Dom.get('phedex-label-transfer-type');
      Dom.get('phedex-help-transfer-type').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','transfer_type');");
      d.transfer_type = Dom.get('transfer_type');
      transfer_type.elList = elList = Dom.getElementsByClassName('phedex-radio','input',d.transfer_type);

// Priority
      this.priority = {
        values:['high','normal','low'],
        _default:2,
        help_text:'<p>Priority is used to determine which data items get priority when resources are limited.</p><p>Setting high priority does not mean your transfer will happen faster, only that it will be considered first if there is congestion causing a queue of data to build up.</p><p>Use <strong>low</strong> unless you have a good reason not to</p>'
      }; // !TODO note the default is actually 'low'!
      var priority = this.priority;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-priority'>Priority <a class='phedex-nextgen-help' id='phedex-help-priority' href='#'>[?]</a></div>" +
                        "<div id='priority' class='phedex-nextgen-control'>" +
                          "<div><input class='phedex-radio' type='radio' name='priority' value='0'>high</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='priority' value='1'>normal</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='priority' value='2' checked>low</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      priority.help_align = Dom.get('phedex-label-priority');
      Dom.get('phedex-help-priority').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','priority');");
      d.priority = Dom.get('priority');
      priority.elList = elList = Dom.getElementsByClassName('phedex-radio','input',d.priority);

// User group
      this.user_group = {
        _default:'<em>Choose a group</em>',
        help_text:'<p>The group which is requesting this data. Used for accounting purposes.</p><p>This field is now mandatory, whereas previously it could be left undefined.</p>'
      };
      var user_group = this.user_group;
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-user-group'>User Group <a class='phedex-nextgen-help' id='phedex-help-user-group' href='#'>[?]</a></div>" +
                        "<div id='user_group_menu' class='phedex-nextgen-control'>" + "<em>loading list of groups...</em>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      user_group.help_align = Dom.get('phedex-label-user-group');
      Dom.get('phedex-help-user-group').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','user_group');");

      var makeGroupMenu = function(obj) {
        return function(data,context) {
          var onMenuItemClick, groupMenuItems=[], groupList, group, i;
          Dom.get('user_group_menu').innerHTML = '';
          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
            user_group.MenuButton.set('label', sText);
            user_group.value = sText;
            if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
          };
          groupList = data.group;
          for (i in groupList ) {
            group = groupList[i];
            if ( !group.name.match(/^deprecated-/) ) {
              groupMenuItems.push( { text:group.name, value:group.id, onclick:{ fn:onMenuItemClick } } );
            }
          }
          user_group.MenuButton = new YAHOO.widget.Button({ type: 'menu',
                                    label: user_group._default,
                                    id:   'groupMenuButton',
                                    name: 'groupMenuButton',
                                    menu:  groupMenuItems,
                                    container: 'user_group_menu' });
          user_group.MenuButton.getMenu().cfg.setProperty('scrollincrement',5);
          if ( --obj.waitToEnableAccept == 0 ) { obj.Accept.set('disabled',false); }
       }
      }(this);
      PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// Time Start
      this.time_start = {
        text:'YYYY-MM-DD [hh:mm:ss]',
        help_text:'<p>Subscribe only <strong>data injected since</strong> a certain time. This field is optional.</p><p><strong>N.B.</strong> This does not affect the transfer scheduling, only the selection of a time-window of data. Data will still be transferred as soon as it can be queued to your destination.</p><p>If you do not specify a time, all the data will be subscribed.</p><p>You can enter a date & time in the box, or select a date from the calendar</p><p>The time will be rounded down to the latest block-boundary before the time you specify. I.e. you will receive whole blocks, starting from the block that contains the start-time you specify</p><p>The time is interpreted as UT, not as your local time.</p>'
      };
      var time_start = this.time_start;
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-time-start'>Data injected since <a class='phedex-nextgen-help' id='phedex-help-time-start' href='#'>[?]</a></div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><input type='text' id='time_start' name='time_start' class='phedex-nextgen-text' value='" + time_start.text + "' />" +
                          "<img id='phedex-nextgen-calendar-icon' width='18' height='18' src='" + PxW.BaseURL + "/images/calendar_icon.gif' style='vertical-align:middle; padding:0 0 0 2px;' />" +
                          "</div>" +
                        "</div>" +
                      "</div>" +
                      "<div id='phedex-nextgen-calendar-el' class='phedex-invisible'></div>";
      form.appendChild(el);
      time_start.help_align = Dom.get('phedex-label-time-start');
      Dom.get('phedex-help-time-start').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','time_start');");
      d.calendar_icon = Dom.get('phedex-nextgen-calendar-icon');
      d.calendar_el   = Dom.get('phedex-nextgen-calendar-el');

      var mySelectHandler = function(o) {
        return function(type,args,obj) {
          var selected = args[0][0];
          o.dom.time_start.value = selected[0]+'-'+selected[1]+'-'+selected[2]+' 00:00:00';
          if ( o.formFail ) { o.Accept.set('disabled',false); o.formFail=false; }
          Dom.setStyle(o.dom.time_start,'color','black');
          YuD.addClass(elCal,'phedex-invisible');
        }
      }(this);
      var cal = new YAHOO.widget.Calendar( 'cal'+PxU.Sequence(), d.calendar_el); //, {maxdate:now.month+'-'+now.day+'-'+now.year } );
          cal.cfg.setProperty('MDY_YEAR_POSITION', 1);
          cal.cfg.setProperty('MDY_MONTH_POSITION', 2);
          cal.cfg.setProperty('MDY_DAY_POSITION', 3);
          cal.selectEvent.subscribe( mySelectHandler, cal, true);
          cal.render();

      YuE.addListener(d.calendar_icon,'click',function() {
        if ( YuD.hasClass(d.calendar_el,'phedex-invisible') ) {
          var elRegion = Dom.getRegion(d.time_start);
          YuD.removeClass(d.calendar_el,'phedex-invisible');
          Dom.setX(d.calendar_el,elRegion.left);
          Dom.setY(d.calendar_el,elRegion.bottom);
        } else {
          YuD.addClass(d.calendar_el,'phedex-invisible');
        }
      }, this, true);

      d.time_start = Dom.get('time_start');
      Dom.setStyle(d.time_start,'width','170px')
      d.time_start.onfocus=function(obj) {
        return function() {
          if ( this.value == time_start.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
          }
          if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
        }
      }(this);
      d.time_start.onblur=function(obj) {
        return function() {
          if ( this.value == '' ) {
            this.value = time_start.text;
            delete time_start.time_start;
            Dom.setStyle(this,'color',null)
          }
        }
      }(this);

      this.getTimeStart = function() {
        var time_start=this.time_start, el=this.dom.time_start, str=el.value, arr=[], year, day, month, hour, minute, second, now=PxU.now();
        if ( str == time_start.text ) { return; } // no date specified!
        if ( !str.match(/^(\d\d\d\d)\D+(\d\d?)\D+(\d\d?)(\D+)?(.*)$/) ) {
          this.onAcceptFail('Illegal date format. Must be YYYY-MM-DD HH:MM:SS (HH:MM:SS optional)');
          return;
        }
        year  = parseInt(RegExp.$1);
        month = parseInt(RegExp.$2);
        day   = parseInt(RegExp.$3);
        str   = RegExp.$5;
        hour = minute = second = 0;
        if ( str != '' ) {
          str.match(/^(\d\d?)(\D+(\d\d?))?(\D+(\d\d?))?$/);
          hour   = parseInt(RegExp.$1);
          minute = parseInt(RegExp.$3 || 0);
          second = parseInt(RegExp.$5 || 0);
        }
        time_start.time_start = Date.UTC(year,month-1,day,hour,minute,second)/1000; // Month counts from zero in Javascript Data object
      }

// Email
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
// TODO take away phedex-invisible if we really need this, or suppress this field entirely if we don't
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Email</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='email_selector'>" +
                            "<span id='email_value'></span>" +
                            "<span>&nbsp;</span>" +
                            "<a id='change_email' class='phedex-nextgen-form-link phedex-invisible' href='#'>change</a>" + // Do we want to change this?
                          "</div>" +
                          "<div><input type='text' id='email_input' name='email' class='phedex-nextgen-text phedex-invisible' value='' /></div>" +
                        "</div>" +
                      "</div>";

      form.appendChild(el);
      this.email = { _default:'(unknown)' };
      var email = this.email, onEmailInput, kl;
      email.selector = Dom.get('email_selector');
      email.input    = Dom.get('email_input');
      email.value    = Dom.get('email_value');
      Dom.setStyle(email.input,'width','170px')
      Dom.setStyle(email.input,'color','black');
      Dom.setStyle(email.value,'color','grey');

      onChangeEmailClick = function(obj) {
        return function() {
          Dom.addClass(   email.selector,'phedex-invisible');
          Dom.removeClass(email.input,   'phedex-invisible');
          email.input.focus();
        };
      }(this);
      Event.on(Dom.get('change_email'),'click',onChangeEmailClick);

      onEmailInput = function(obj) {
        return function() {
          Dom.removeClass(email.selector,'phedex-invisible');
          Dom.addClass(   email.input,   'phedex-invisible');
          email.value.innerHTML = email.input.value;
        }
      }(this);
      email.input.onblur = onEmailInput;

      kl = new YAHOO.util.KeyListener(email.input,
                               { keys:YAHOO.util.KeyListener.KEY.ENTER },
                               { fn:function(obj){ return function() { onEmailInput(); } }(this),
                               scope:this, correctScope:true } );
     kl.enable();

      var gotAuthData = function(obj) {
        return function(data,context) {
          var address = '';
          try { address = data.auth[0].email; }
          catch(ex) {
// AUTH failed, don't know what address to put in!
            email.value.innerHTML = email._default;
          }
          if ( !address ) { return; }
          email.value.innerHTML = email.input.value = email._default = address;
        };
      }(this);
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:gotAuthData })

// Comments
      this.comments = { text:'enter any additional comments here' };
      var comments = this.comments;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Comments</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='comments' name='comments' class='phedex-nextgen-textarea'>" + comments.text + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.comments = Dom.get('comments');
      d.comments.onfocus = function() {
        if ( this.value == comments.text ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.comments.onblur=function() {
        if ( this.value == '' ) {
          this.value = comments.text;
          Dom.setStyle(this,'color',null);
        }
      }

// // Preview
//       el = document.createElement('div');
//       el.innerHTML = "<div id='phedex-nextgen-preview' class='phedex-invisible'>" +
//                        "<div class='phedex-nextgen-form-element'>" +
//                           "<div id='phedex-nextgen-preview-label' class='phedex-nextgen-label'>Preview</div>" +
//                           "<div class='phedex-nextgen-control'>" +
//                             "<div id='phedex-nextgen-preview-text'></div>" +
//                           "</div>" +
//                         "</div>" +
//                       "</div>";
//       form.appendChild(el);
//       d.preview = Dom.get('phedex-nextgen-preview');
//       d.preview_label = Dom.get('phedex-nextgen-preview-label');
//       d.preview_text  = Dom.get('phedex-nextgen-preview-text');

// Results
      el = document.createElement('div');
      el.innerHTML = "<div id='phedex-nextgen-results' class='phedex-invisible'>" +
                       "<div class='phedex-nextgen-form-element'>" +
                          "<div id='phedex-nextgen-results-label' class='phedex-nextgen-label'>Results</div>" +
                          "<div class='phedex-nextgen-control'>" +
                            "<div id='phedex-nextgen-results-text'></div>" +
                          "</div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.results = Dom.get('phedex-nextgen-results');
      d.results_label = Dom.get('phedex-nextgen-results-label');
      d.results_text  = Dom.get('phedex-nextgen-results-text');

// Set up the Accept and Reset handlers
      this.requestCallback = function(obj) {
        return function(data,context) {
          var dom = obj.dom, str, msg, rid;
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML = '';
          Dom.removeClass(dom.results,'phedex-box-yellow');
          if ( data.message ) { // indicative of failure~
            str = "Error when making call '" + context.api + "':";
            msg = data.message.replace(str,'').trim();
            obj.onAcceptFail(msg);
            obj.Accept.set('disabled',false);
          }
          if ( rid = data.request_created[0].id ) {
            obj.onResetSubmit();
            var uri = location.href;
            uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
            uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
            uri = uri.replace(/\/[^/]*$/g,'/');

            dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
              "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
            Dom.addClass(dom.results,'phedex-box-green');
            Dom.removeClass(dom.results,'phedex-invisible');
            d.preview_text.innerHTML = d.preview_label.innerHTML = '';
            Dom.addClass(dom.preview,'phedex-invisible');
          }
        }
      }(this);
      this.onAcceptFail = function(obj) {
        return function(text) {
          var dom = obj.dom;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-red');
          dom.results_label.innerHTML = 'Error:';
          if ( dom.results_text.innerHTML ) {
            dom.results_text.innerHTML += '<br />';
          }
          dom.results_text.innerHTML += text;
          obj.formFail = true;
        }
      }(this);
      this.onAcceptSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              user_group = obj.user_group,
              email      = obj.email,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;
          this.set('disabled',true);

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// DBS - done directly in the xml

// Destination
          elList = obj.destination.elList;
          args.node = [];
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.node.push(obj.destination.nodes[i]); }
          }
          if ( args.node.length == 0 ) {
            obj.onAcceptFail('No Destination nodes specified');
          }

// Site Custodial
          tmp = obj.site_custodial;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.custodial = ( tmp.values[el.value] == 'yes' ? 'y' : 'n' ); }
          }

// Subscription Type
          tmp = obj.subscription_type;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args['static'] = ( tmp.values[el.value] == 'static' ? 'y' : 'n' ); }
          }

// Transfer Type
          tmp = obj.transfer_type;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.move = ( tmp.values[el.value] == 'move' ? 'y' : 'n' ); }
          }

// Priority
          tmp = obj.priority;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.priority = tmp.values[el.value]; }
          }

// User Group
          if ( ! user_group.value ) {
            obj.onAcceptFail('No User-Group specified');
          }
          args.group = user_group.value;

// Time Start
          obj.getTimeStart();
          if ( time_start.time_start ) {
            args.time_start = time_start.time_start;
          }

// Email TODO check field?
//           args.email = email.value.innerHTML;

// Comments
          if ( dom.comments.value && dom.comments.value != obj.comments.text ) { args.comments = dom.comments.value; }

// Never subscribe automatically from this form
          args.request_only = 'y';

          args.no_mail = 'n';

// Hardwired, for best practise!
          args.level = 'block';

// If there were errors, I can give up now!
          if ( obj.formFail ) {
            this.set('disabled',true);
            return;
          }

// Now build the XML!
          xml = '<data version="2.0"><dbs name="' + dbs.value.innerHTML + '">';
          for ( dataset in data.datasets ) {
            xml += '<dataset name="'+dataset+'" is-open="dummy">';
            for ( block in data.datasets[dataset] ) {
              xml += '<block name="'+block+'" is-open="dummy" />';
            }
            xml += '</dataset>';
          }
          xml += '</dbs></data>';
          args.data = xml;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-yellow');
          dom.results_label.innerHTML = 'Status:';
          dom.results_text.innerHTML  = 'Submitting request (please wait)' +
          '<br/>' +
          "<img src='http://us.i1.yimg.com/us.yimg.com/i/us/per/gr/gp/rel_interstitial_loading.gif'/>";
          PHEDEX.Datasvc.Call({ api:'subscribe', method:'post', args:args, callback:function(data,context) { obj.requestCallback(data,context); } });
        }
      }(this);

      this.onPreviewSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// Time Start
          obj.getTimeStart();
          if ( time_start.time_start ) {
            args.block_create_since = time_start.time_start;
          }

// If there were errors, I can give up now!
          if ( obj.formFail ) { return; }

// Now build the args!
          if ( data.datasets ) {
            args.dataset = [];
            for ( dataset in data.datasets ) {
              args.dataset.push(dataset);
            }
          }
          Dom.removeClass(dom.preview,'phedex-invisible');
          Dom.addClass(dom.preview,'phedex-box-yellow');
          dom.preview_label.innerHTML = 'Status:';
          dom.preview_text.innerHTML  = 'Calculating request (please wait)' +
          '<br/>' +
          "<img src='" + PxW.BaseURL + "images/barbers_pole_loading.gif'/>";
          args.level = 'block';
          PHEDEX.Datasvc.Call({ api:'data', args:args, callback:function(data,context) { obj.previewCallback(data,context); } });
        }
      }(this);
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
  return {
    initSub: function() {
      var d = this.dom,
          mb = d.main_block,
          hd = d.hd,
          form, elList, el, label, control, i, ctl;
      hd.innerHTML = 'Delete data';

      form = document.createElement('form');
      form.id   = 'subscribe_data';
      form.name = 'subscribe_data';
      mb.appendChild(form);

// Dataset/block name(s)
      this.data_items = { text:'enter one or more block/data-set names, separated by white-space or commas.' };
      var data_items = this.data_items;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Data Items</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + data_items.text + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.data_items = Dom.get('data_items');
      d.data_items.onfocus = function(obj) {
        return function() {
          if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
          if ( this.value == data_items.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
          }
        }
      }(this);
      d.data_items.onblur=function() {
        if ( this.value == '' ) {
          this.value = data_items.text;
          Dom.setStyle(this,'color',null);
        }
      }

// DBS
      this.dbs = {
        instanceDefault:{
          prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          test:'LoadTest',
          debug:'LoadTest',
          tbedi:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          tbedii:'test',
          tony:'test'
        }
      };

      var dbs = this.dbs,
          instance = PHEDEX.Datasvc.Instance();
      dbs._default = dbs.instanceDefault[instance.instance] || '(not defined)';

      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='dbs_selected'>" + "<span id='dbs_value'>" + dbs._default + "</span>" +
                            "<span>&nbsp;</span>" + "<a id='change_dbs' class='phedex-nextgen-form-link' href='#'>change</a>" +
                          "</div>" +
                        "<div id='dbs_menu''></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      dbs.menu     = Dom.get('dbs_menu');
      dbs.value    = Dom.get('dbs_value');
      dbs.selected = Dom.get('dbs_selected');
      Dom.setStyle(dbs.value,'color','grey');

      var makeDBSMenu = function(obj) {
        return function(data,context) {
          var onMenuItemClick, onChangeDBSClick, dbsMenuItems=[], dbsList, dbsEntry, i;
          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
            if ( sText.match(/<strong>(.*)<\/strong>/) ) { sText = RegExp.$1; }
            dbs.MenuButton.set('label', '<em>'+sText+'</em>');
          };
          dbsList = data.dbs;
          for (i in dbsList ) {
            dbsEntry = dbsList[i];
            if ( dbsEntry.name == dbs._default ) {
              dbsEntry.name = '<strong>'+dbsEntry.name+'</strong>';
              dbs.defaultId = i;
            }
            dbsMenuItems.push( { text:dbsEntry.name, value:dbsEntry.id, onclick:{ fn:onMenuItemClick } } );
          }
          dbs.menu.innerHTML = '';
          dbs.MenuButton = new YAHOO.widget.Button({  type: 'menu',
                                  label: '<em>'+dbs._default+'</em>',
                                  id:   'dbsMenuButton',
                                  name: 'dbsMenuButton',
                                  menu:  dbsMenuItems,
                                  container: 'dbs_menu' });
          dbs.MenuButton.on('selectedMenuItemChange',function(event) {
            var menuItem = event.newValue,
                value    = menuItem.cfg.getProperty('text');
                if ( value.match(/<strong>(.*)</) ) { value = RegExp.$1; }
            dbs.value.innerHTML = value;
            Dom.removeClass(dbs.selected,'phedex-invisible');
            Dom.setStyle(dbs.MenuButton,'display','none');
          });
          obj.dbs.gotMenu = true;
        }
      }(this);

      onChangeDBSClick = function(obj) {
        return function() {
          if ( !obj.dbs.gotMenu ) {
            PHEDEX.Datasvc.Call({ api:'dbs', callback:makeDBSMenu });
            dbs.menu.innerHTML = '<em>loading menu, please wait...</em>';
            Dom.addClass(dbs.selected,'phedex-invisible');
          } else {
            Dom.setStyle(dbs.MenuButton,'display',null);
            Dom.addClass(dbs.selected,'phedex-invisible');
          }
        };
      }(this);
      Event.on(Dom.get('change_dbs'),'click',onChangeDBSClick);

// Destination
      this.destination = { nodes:[], selected:[] };
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form-element');
      el.innerHTML = "<div id='destination-container' class='phedex-nextgen-form-element'>" +
                       "<div class='phedex-nextgen-label'>Destination</div>" +
                       "<div id='destination-panel' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
                         "<em>loading destination list...</em>" +
                       "</div>" +
                     "</div>";
      form.appendChild(el);
      d.destination = Dom.get('destination-container');
      var makeNodePanel = function(obj) {
        return function(data,context) {
          var nodes=[], node, i, j, k, pDiv, destination=d.destination;

          for ( i in data.node ) {
            node = data.node[i].name;
            if ( instance.instance != 'prod' ) { nodes.push(node ); }
            else {
              if ( node.match(/^T(0|1|2|3)_/) && !node.match(/^T[01]_.*_(Buffer|Export)$/) ) { nodes.push(node ); }
            }
          }
          nodes = nodes.sort();
          pDiv = Dom.get('destination-panel');
          pDiv.innerHTML = '';
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            node.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              pDiv.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            pDiv.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input class='phedex-checkbox' type='checkbox' name='"+node+"' />"+node+"</div>";
            obj.destination.nodes.push(node);
          }
          destination.appendChild(pDiv);
          obj.destination.elList = Dom.getElementsByClassName('phedex-checkbox','input',destination);
          var onDestinationClick =function(event, matchedEl, container) {
                if (Dom.hasClass(matchedEl, 'phedex-checkbox')) {
                  obj.Accept.set('disabled',false);
                }
              };
          YAHOO.util.Event.delegate(destination, 'click', onDestinationClick, 'input');

          obj.Accept.set('disabled',false);
        }
      }(this);
      setTimeout( function() { PHEDEX.Datasvc.Call({ api:'nodes', callback:makeNodePanel }); }, 5000);

// Remove Subscriptions?
      this.remove_subscription = { values:['yes','no'], _default:0 };
      var remove_subscription = this.remove_subscription;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Remove Subscriptions?</div>" +
                        "<div id='remove_subscription' class='phedex-nextgen-control'>" +
                          "<div><input class='phedex-radio' type='radio' name='remove_subscription' value='0' checked>yes</input></div>" +
                          "<div><input class='phedex-radio' type='radio' name='remove_subscription' value='1'>no</input></div>" +
                       "</div>" +
                     "</div>";
      form.appendChild(el);
      remove_subscription.elList = Dom.getElementsByClassName('phedex-radio','input',d.remove_subscription);


// Email
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
// TODO take away phedex-invisible if we really need this, or suppress this field entirely if we don't
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Email</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='email_selector'>" +
                            "<span id='email_value'></span>" +
                            "<span>&nbsp;</span>" +
                            "<a id='change_email' class='phedex-nextgen-form-link phedex-invisible' href='#'>change</a>" +
                          "</div>" +
                          "<div><input type='text' id='email_input' name='email' class='phedex-nextgen-text phedex-invisible' value='' /></div>" +
                        "</div>" +
                      "</div>";

      form.appendChild(el);
      this.email = { _default:'(unknown)' };
      var email = this.email, onEmailInput, kl;
      email.selector = Dom.get('email_selector');
      email.input    = Dom.get('email_input');
      email.value    = Dom.get('email_value');
      Dom.setStyle(email.input,'width','170px')
      Dom.setStyle(email.input,'color','black');
      Dom.setStyle(email.value,'color','grey');

      onChangeEmailClick = function(obj) {
        return function() {
          Dom.addClass(   email.selector,'phedex-invisible');
          Dom.removeClass(email.input,   'phedex-invisible');
          email.input.focus();
        };
      }(this);
      Event.on(Dom.get('change_email'),'click',onChangeEmailClick);

      onEmailInput = function(obj) {
        return function() {
          Dom.removeClass(email.selector,'phedex-invisible');
          Dom.addClass(   email.input,   'phedex-invisible');
          email.value.innerHTML = email.input.value;
        }
      }(this);
      email.input.onblur = onEmailInput;

      kl = new YAHOO.util.KeyListener(email.input,
                               { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
                               { fn:function(obj){ return function() { onEmailInput(); } }(this),
                               scope:this, correctScope:true } );
     kl.enable();

      var gotAuthData = function(obj) {
        return function(data,context) {
          var address = '';
          try { address = data.auth[0].email; }
          catch(ex) {
// AUTH failed, don't know what address to put in!
            email.value.innerHTML = email._default;
          }
          if ( !address ) { return; }
          email.value.innerHTML = email.input.value = email._default = address;
        };
      }(this);
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:gotAuthData })

// Comments
      this.comments = { text:'enter any additional comments here' };
      var comments = this.comments;
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Comments</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='comments' name='comments' class='phedex-nextgen-textarea'>" + comments.text + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.comments = Dom.get('comments');
      d.comments.onfocus = function() {
        if ( this.value == comments.text ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.comments.onblur=function() {
        if ( this.value == '' ) {
          this.value = comments.text;
          Dom.setStyle(this,'color',null);
        }
      }

// Preview
      el = document.createElement('div');
      el.innerHTML = "<div id='phedex-nextgen-preview' class='phedex-invisible'>" +
                       "<div class='phedex-nextgen-form-element'>" +
                          "<div id='phedex-nextgen-preview-label' class='phedex-nextgen-label'>Preview</div>" +
                          "<div class='phedex-nextgen-control'>" +
                            "<div id='phedex-nextgen-preview-text'></div>" +
                          "</div>" +
                        "</div>" +
                        "<div id='phedex-nextgen-preview-button'></div>" +
                      "</div>";
      form.appendChild(el);
      d.preview = Dom.get('phedex-nextgen-preview');
      d.preview_label = Dom.get('phedex-nextgen-preview-label');
      d.preview_text  = Dom.get('phedex-nextgen-preview-text');

// Results
      el = document.createElement('div');
      el.innerHTML = "<div id='phedex-nextgen-results' class='phedex-invisible'>" +
                       "<div class='phedex-nextgen-form-element'>" +
                          "<div id='phedex-nextgen-results-label' class='phedex-nextgen-label'>Results</div>" +
                          "<div class='phedex-nextgen-control'>" +
                            "<div id='phedex-nextgen-results-text'></div>" +
                          "</div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.results = Dom.get('phedex-nextgen-results');
      d.results_label = Dom.get('phedex-nextgen-results-label');
      d.results_text  = Dom.get('phedex-nextgen-results-text');

      this.requestCallback = function(obj) {
        return function(data,context) {
          var dom = obj.dom, str, msg, rid;
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML = '';
          Dom.removeClass(dom.results,'phedex-box-yellow');
          if ( data.message ) { // indicative of failure~
            str = "Error when making call '" + context.api + "':";
            msg = data.message.replace(str,'').trim();
//             obj.onAcceptFail('The call failed for some reason. Please ask an expert to consult the logfiles');
            obj.onAcceptFail(msg);
            obj.Accept.set('disabled',false);
          }
          if ( rid = data.request_created[0].id ) {
            obj.onResetSubmit();
            var uri = location.href;
            uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
            uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
            uri = uri.replace(/\/[^/]*$/g,'/');

            dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
              "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
            Dom.addClass(dom.results,'phedex-box-green');
            Dom.removeClass(dom.results,'phedex-invisible');
          }
        }
      }(this);
      this.onAcceptFail = function(obj) {
        return function(text) {
          var dom = obj.dom;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-red');
          dom.results_label.innerHTML = 'Error:';
          if ( dom.results_text.innerHTML ) {
            dom.results_text.innerHTML += '<br />';
          }
          dom.results_text.innerHTML += text;
          obj.formFail = true;
        }
      }(this);
      this.onAcceptSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              user_group = obj.user_group,
              email      = obj.email,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;
          this.set('disabled',true);

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// DBS - done directly in the xml

// Destination
          elList = obj.destination.elList;
          args.node = [];
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.node.push(obj.destination.nodes[i]); }
          }
          if ( args.node.length == 0 ) {
            obj.onAcceptFail('No Destination nodes specified');
          }

// Remove Subscriptions
          tmp = obj.remove_subscription;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.rm_subscriptions = ( tmp.values[el.value] == 'yes' ? 'y' : 'n' ); }
          }

// Email TODO check field?
//           args.email = email.value.innerHTML;

// Comments
          if ( dom.comments.value && dom.comments.value != obj.comments.text ) { args.comments = dom.comments.value; }

          args.no_mail = 'n';

// Hardwired, for best practise!
          args.level = 'block'; // TODO is this right for deletions?

// If there were errors, I can give up now!
          if ( obj.formFail ) {
            this.set('disabled',true);
            return;
          }

// Now build the XML!
          xml = '<data version="2.0"><dbs name="' + dbs.value.innerHTML + '">';
          for ( dataset in data.datasets ) {
            xml += '<dataset name="'+dataset+'" is-open="dummy">';
            for ( block in data.datasets[dataset] ) {
              xml += '<block name="'+block+'" is-open="dummy" />';
            }
            xml += '</dataset>';
          }
          xml += '</dbs></data>';
          args.data = xml;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-yellow');
          dom.results_label.innerHTML = 'Status:';
          dom.results_text.innerHTML  = 'Submitting request (please wait)' +
          "<br/>" +
          "<img src='http://us.i1.yimg.com/us.yimg.com/i/us/per/gr/gp/rel_interstitial_loading.gif'/>";
          PHEDEX.Datasvc.Call({ api:'delete', method:'post', args:args, callback:function(data,context) { obj.requestCallback(data,context); } });
        }
      }(this);

      this.onPreviewSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// If there were errors, I can give up now!
          if ( obj.formFail ) { return; }

          Dom.removeClass(dom.preview,'phedex-invisible');
          Dom.addClass(dom.preview,'phedex-box-yellow');
          dom.preview_label.innerHTML = 'Status:';
          dom.preview_text.innerHTML  = 'Calculating request (please wait)' +
          '<br/>' +
          "<img src='http://us.i1.yimg.com/us.yimg.com/i/us/per/gr/gp/rel_interstitial_loading.gif'/>";
//           PHEDEX.Datasvc.Call({ api:'data', method:'post', args:args, callback:function(data,context) { obj.requestCallback(data,context); } });
        }
      }(this);

    }
  }
}

log('loaded...','info','nextgen-request-create');
