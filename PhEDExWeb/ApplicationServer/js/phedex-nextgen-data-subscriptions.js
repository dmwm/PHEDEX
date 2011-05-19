PHEDEX.namespace('Nextgen.Data');
PHEDEX.Nextgen.Data.Subscriptions = function(sandbox) {
  var string = 'nextgen-data-subscriptions',
      _sbx = sandbox,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Button = YAHOO.widget.Button;
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
      _default:{}, // default values for various DOM fields, extracted as they are built
      waitToEnableAccept:2,
      meta: {
        table: { columns:[ { key:'block',        label:'Block', className:'align-left' },
                           { key:'b_files',      label:'Files', className:'align-right', parser:'number' },
                           { key:'b_bytes',      label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' },
                           { key:'b_replicas',   label:'# Replicas', parser:'number'}],
            nestedColumns:[{ key:'node',         label:'Node', className:'align-left' },
                           { key:'r_complete',   label:'Complete' },
                           { key:'r_custodial',  label:'Custodial' },
                           { key:'r_group',      label:'Group' },
                           { key:'r_files',      label:'Files', className:'align-right', parser:'number' },
                           { key:'r_bytes',      label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' }]
                },
      },
      useElement: function(el) {
        var d = this.dom, form;
        d.target = el;
        d.container  = document.createElement('div'); d.container.className  = 'phedex-nextgen-container'; d.container.id = 'doc3';
        d.hd         = document.createElement('div'); d.hd.className         = 'phedex-nextgen-hd';        d.hd.id = 'hd';
        d.bd         = document.createElement('div'); d.bd.className         = 'phedex-nextgen-bd';        d.bd.id = 'bd';
        d.ft         = document.createElement('div'); d.ft.className         = 'phedex-nextgen-ft';        d.ft.id = 'ft';
        d.main       = document.createElement('div'); d.main.className       = 'yui-main';
        d.main_block = document.createElement('div'); d.main_block.className = 'yui-b phedex-nextgen-main-block';
        d.selector   = document.createElement('div'); d.selector.id          = 'phedex-data-subscriptions-selector';
        d.dataform   = document.createElement('div'); d.dataform.id          = 'phedex-data-subscriptions-dataform';
        d.datatable  = document.createElement('div'); d.datatable.id         = 'phedex-data-subscriptions-datatable';
        form = document.createElement('form');
        form.id   = 'data-subscriptions-action';
        form.name = 'data-subscriptions-action';
        form.method = 'post';
        form.action = location.pathname;
        this.data_subscriptions_action = form;

        d.bd.appendChild(d.main);
        d.main.appendChild(d.main_block);
        d.container.appendChild(d.hd);
        d.container.appendChild(d.bd);
        d.container.appendChild(d.ft);
        d.container.appendChild(d.selector);
        d.container.appendChild(d.dataform);
        d.dataform.appendChild(form);
        d.dataform.appendChild(d.datatable);
        el.innerHTML = '';
        el.appendChild(d.container);

        d.floating_help = document.createElement('div'); d.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible'; d.floating_help.id = 'phedex-help-'+PxU.Sequence();
        document.body.appendChild(d.floating_help);
      },
      gotAuthData: function(data,context) {
        if ( !data.auth ) { return; }
        var auth, roles, role, i;

        obj.auth = auth = data.auth[0];
        auth.isAdmin = false;
        auth.can = [];
        try {
          roles = auth.role;
        } catch(ex) { }// AUTH call failed, proceed regardless...
        for ( i in roles ) {
          role = roles[i];
          if ( ( role.name == 'Admin' && role.group == 'phedex' ) ||
               ( role.name == 'PADA Admin'   ) ||
               ( role.name == 'Data Manager' ) ||
               ( role.name == 'Site Admin'   ) ) {
            auth.can.push('suspend');
            auth.isAdmin = true;
          }
          if ( ( role.name == 'Admin' && role.group == 'phedex' ) ||
               ( role.name == 'Data Manager' ) ) {
            auth.can.push('priority');
          }

        }
        if (  auth.isAdmin ) { _sbx.notify(obj.id,'isAdmin'); }
        if ( !auth.isAdmin ) { _sbx.notify(obj.id,'isNotAdmin'); }
      },
      isNotAdmin: function() {
//      User has no administrative rights. Add a link explaining why.
        var el = document.createElement('a'),
            auth = obj.auth,
            d=obj.dom, container=d.container,
            toggle, id=PxU.Sequence();
        el.id = 'phedex-help-anchor-'+id;
        el.href = '#';
        el.innerHTML = 'Privileged Activities Help';
        container.appendChild(el);
        toggle = "var s = new PHEDEX.Sandbox(); s.notify('"+obj.id+"','Help','privilegedActivity');";
        obj.privilegedActivity = {
            text: "<a id='close-anchor-"+id+"' class='float-right' href='#'>[close]</a>" +
                  "<p><strong>Privileged Activities:</strong></p>" +
                  PHEDEX.Nextgen.Util.authHelpMessage(
                    { to:'change priorities of subscriptions and manage groups', need:'cert', role:['Data Manager', 'Admin'] },
                    { to:'suspend/unsuspend subscriptions',                      need:'any',  role:['Data Manager', 'Site Admin', 'PADA Admin', 'Admin'] }
                  ),
            el:el,
            close:'close-anchor-'+id,
            toggle:toggle
          };
        el.setAttribute('onclick',toggle);
        return; // Do this here so I don't need the 'else' for isAdmin...
      },
      isAdmin: function() {
//     User has administrative rights, add the menus!
        var auth=obj.auth,
            i, j, k, d=obj.dom, container=d.container, selector=d.selector, form=obj.data_subscriptions_action,
            id=PxU.Sequence(),
            field, el, button,
            admin_opts = {
                   suspend:     'Suspend subscriptions',
                   unsuspend:   'Unsuspend subscriptions',
                   priorityhi:  'Make high priority',
                   prioritymd:  'Make normal priority',
                   prioritylo:  'Make low priority',
                   groupchange: 'Change group'
                 },
            admin_grps = {
                   'suspend':['suspend', 'unsuspend'],
                   'priority':['priorityhi', 'prioritymd', 'prioritylo', 'groupchange']
                 },
            admin_menu=[];
        for ( i in auth.can ) {
          j=admin_grps[auth.can[i]];
          for ( k in j ) { admin_menu.push({ value:j[k], text:admin_opts[j[k]] }); }
        }
        if ( admin_menu.length ) {
          el=document.createElement('div');
          el.innerHTML = "<div class='phedex-data-subscriptions-action'>" +
                           "<span class='phedex-nextgen-label' id='phedex-data-subscriptions-label-select'>Selections:</span>" +
                           "<span id='phedex-data-subscriptions-ctl-select-all'></span>" +
                           "<span id='phedex-data-subscriptions-ctl-clear-all'></span>" +
// TW this is what it used to look like...
//                          "<input type='button' value='Select all' onclick=\"select_all('subsform', 's_value', '1')\"/>" +
//                          "<input type='button' value='Select none' onclick=\"select_all('subsform', 's_value', '0')\"/>" +
                         "</div>";
          selector.appendChild(el);
          var onSelectAllOrNone = function(val) {
            return function(obj) {
              return function() {
                var elList;
debugger; // TW have to find the 'select' column and act on it... Better build the table first :-)
              }
            }(this);
          };
          button = new Button({ label:'Select all',  id:'phedex-data-subscriptions-select-all',  container:'phedex-data-subscriptions-ctl-select-all'  });
          button.on('click',onSelectAllOrNone(1));
          button = new Button({ label:'Clear all', id:'phedex-data-subscriptions-clear-all', container:'phedex-data-subscriptions-ctl-clear-all' });
          button.on('click',onSelectAllOrNone(0));

          i = document.createElement('input');
          i.type = 'hidden'
          i.name = 'priority';
          i.value = this.params.priority;
          form.appendChild(i);
          i = document.createElement('input');
          i.type = 'hidden'
          i.name = 'suspended';
          i.value = this.params.suspended;
          form.appendChild(i);

          field='action';
          el = document.createElement('span');
          el.id = 'phedex-subscription-action-'+id;
//           el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
//                     "<div class='phedex-nextgen-label' id='phedex-data-subscriptions-label-"+field+"'>Action:</div>" +
//                     "<div class='phedex-nextgen-filter'>" +
//                       "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
//                     "</div>" +
//                   "</div>";
          el.innerHTML = "<div class='phedex-data-subscriptions-action'>" +
                           "<span class='phedex-nextgen-label' id='phedex-data-subscriptions-label-action'>Action:</span>" +
                           "<span id='phedex-data-subscriptions-ctl-action'></span>" +
                           "<span id='phedex-data-subscriptions-ctl-update'></span>" +
                         "</div>";
          form.appendChild(el);
          this.ctl[field] = button = new Button({
            id:          'phedex-data-subscriptions-action',
            name:        'phedex-data-subscriptions-action',
            label:       "<em class='yui-button-label'>"+admin_menu[0].text+'</em>',
            type:        'menu',
            lazyloadmenu: false,
            menu:         admin_menu,
            container:   'phedex-data-subscriptions-ctl-action'
          });
          button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
          this._default[field] = function(_button,_field,index) {
            return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
          }(button,field,0);
          this.onUpdate = function() {
            var elList;
debugger; // TW have to find the 'select' column and act on it... Better build the table first :-)
          };
          button = new Button({ label:'Apply changes',  id:'phedex-data-subscriptions-update',  container:'phedex-data-subscriptions-ctl-update'  });
          button.on('click',this.onUpdate);

//       my $target = $self->myurl();
//       print { $$self{CONTENT} }
//       "<form id='subsform' method='post' action='$target'>",
//       # Save view parameters
//       $self->saveform(),
//       "<input type='hidden' name='priority' value='$priofilter'/>",
//       "<input type='hidden' name='suspended' value='$suspfilter'/>",
//       "<p>\n",
//       "<label>Actions:</label>\n",
//       "<select class='labeled' name='subsaction' onchange='return hideshowdropdown(this)'>\n";
//       foreach my $auth (@admin_auth) {
//           foreach my $opt (@{$admin_grps{$auth}}) {
//               print { $$self{CONTENT} }
//               "<option value='$opt'>$admin_opts{$opt}</option>\n";
//           }
//       }
//       print { $$self{CONTENT} }
//       "</select>\n",
//       popup_menu(-name=>'groupchange', -values=>$$self{GROUP_LIST}, -id=>'groupchange', -style=>'display:none'),
//       "<input type='submit' value='Update'/>\n",
//       "</p>\n"
//       ;

        }
      },
      Help:function(item) {
        item = this[item];
        var elRegion = Dom.getRegion(item.el),
            elHelp   = this.dom.floating_help;
        elHelp.innerHTML = item.text;
        if ( Dom.hasClass(elHelp,'phedex-invisible') ) {
          Dom.removeClass(elHelp,'phedex-invisible');
          Dom.setX(elHelp,elRegion.right+10);
          Dom.setY(elHelp,elRegion.top);
        } else {
          Dom.addClass(elHelp,'phedex-invisible');
        }
        if ( item.close && item.toggle ) {
          Dom.get(item.close).setAttribute('onclick',item.toggle);
        }
      },
      init: function(params) {
        if ( !params ) { params={}; }
        this.params = params;
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr[1], i;
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              arr.shift();
              obj[action].apply(obj,arr);
              return;
            }
            switch (action) {
              case 'Reset-filters': {
                for ( i in obj._default ) { obj._default[i](); }
                break;
              }
              default: {
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
        this.initFilters();
        this.initSub();
        _sbx.notify(this.id,'buildOptionsTabview');
        PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })
      },
      initFilters: function() {
        var p=this.params, i, j, requests, columns, col, label,
            _default =
              {
                item:      '.*',
                priority:  'any',
                suspended: 'any',
                custodial: 'any',
                group:     'any'
              };
        for ( i in _default ) {
          if ( !p[i] ) { p[i] = _default[i]; }
        }

        if ( p.requests ) {
          requests = p.requests.split(/(\s*,*\s+|\s*,+\s*)/);
          p.requests = [];
          for ( i in requests ) {
            if ( requests[i].match(/^\d+$/) ) {
              p.requests.push(requests[i]);
            }
          }
        } else {
          p.requests = [];
        }

        columns = this.columns = [
          {label:'Select',           _default:true},
          {label:'Request',          _default:true},
          {label:'Data Level',       _default:true},
          {label:'Data Item',        _default:true},
          {label:'Node',             _default:true},
          {label:'Priority',         _default:true},
          {label:'Custodial',        _default:true},
          {label:'Group',            _default:true},
          {label:'Node Files',       _default:true},
          {label:'Node Bytes',       _default:true},
          {label:'% Files',          _default:false},
          {label:'% Bytes',          _default:true},
          {label:'Replica/Move',     _default:true},
          {label:'Active/Suspended', _default:true},
          {label:'Item Open',        _default:false},
          {label:'Time Create',      _default:true},
          {label:'Time Complete',    _default:false},
          {label:'Time Done',        _default:false}
        ];

        if ( p.col ) {
          if ( typeof(p.col) != 'object'  ) {
            p.col = [ p.col ];
          }
          for ( i in p.col ) {
            label = p.col[i];
            label = label.replace(/pct/,'%');
            for (j in columns) {
              col = columns[j];
              if ( col.label == label ) {
                col.checked = true;
                continue;
              }
            }
          }
        }
      },
      initSub: function() {
        var d=this.dom, mb=d.main_block, el, b, ctl=this.ctl, id='image-'+PxU.Sequence(), container=d.container;
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-options-control'></div>" +
                       "<div id='phedex-data-subscriptions-options-panel' class='phedex-invisible'></div>";
        mb.appendChild(el);
        ctl.options = {
            panel:Dom.get('phedex-data-subscriptions-options-panel'),
            label_show:"<img id='"+id+"' src='"+PxW.BaseURL+"/images/icon-wedge-green-down.png' style='vertical-align:top'>Show options",
            label_hide:"<img id='"+id+"' src='"+PxW.BaseURL+"/images/icon-wedge-green-up.png'   style='vertical-align:top'>Hide options",
          };
        ctl.options.button = b = new Button({
                                          label:ctl.options.label_show,
                                          id:'phedex-options-control-button',
                                          container:'phedex-options-control' });
        var onShowOptionsClick = function(obj) {
          return function() {
            var ctl=obj.ctl, opts=ctl.options, tab, tabView, SelectAll, DeselectAll, Reset, Apply, el, apply=obj.dom.apply;
            if ( Dom.hasClass(opts.panel,'phedex-invisible') ) {
              Dom.removeClass(opts.panel,'phedex-invisible');
              if ( apply ) { Dom.removeClass(apply,'phedex-invisible'); }
              opts.button.set('label',opts.label_hide);
            } else {
              Dom.addClass(opts.panel,'phedex-invisible');
              if ( apply ) { Dom.addClass(apply,'phedex-invisible'); }
              opts.button.set('label',opts.label_show);
            }
            if ( !opts.tabView ) { obj.buildOptionsTabview(); }
          }
        }(this);
        b.on('click',onShowOptionsClick);
      },
      buildOptionsTabview: function() {
        var d=this.dom, ctl = this.ctl, mb=d.main_block, form, el,
            opts=ctl.options, tab, tabView, SelectAll, DeselectAll, Reset, Apply, apply=this.dom.apply;
        if ( opts.tabview ) { return; }
        form = document.createElement('form');
        form.id   = 'data-subscriptions-filter';
        form.name = 'data-subscriptions-filter';
        form.method = 'get';
        this.data_subscriptions_filter = form;
        opts.panel.appendChild(form);
        tabView = opts.tabView = new YAHOO.widget.TabView();
        tab = new YAHOO.widget.Tab({
          label: 'Show/hide Columns',
          content:
                "<div id='phedex-columnpanel-container' class='phedex-nextgen-form-element'>" +
                  "<div id='phedex-columnlabel' class='phedex-nextgen-label'>" +
                    "<div class='phedex-vertical-buttons' id='phedex-selectall-columns'></div>" +
                    "<div class='phedex-vertical-buttons' id='phedex-deselectall-columns'></div>" +
                    "<div class='phedex-vertical-buttons' id='phedex-reset-columns'></div>" +
                  "</div>" +
                  "<div id='phedex-columnpanel' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
                  "</div>" +
                "</div>",
          active: true
        });
        tabView.addTab(tab);
        SelectAll   = new Button({ label:'Select all',   id:'selectallcolumns',   container:'phedex-selectall-columns' });
        SelectAll.on(  'click', function(obj) { return function() { _sbx.notify(obj.id,'SelectAll-columns'); } }(this) );
        DeselectAll = new Button({ label:'Clear all', id:'deselectallcolumns', container:'phedex-deselectall-columns' });
        DeselectAll.on('click', function(obj) { return function() { _sbx.notify(obj.id,'DeselectAll-columns'); } }(this) );
        Reset       = new Button({ label:'Reset to defaults', id:'resetcolumns', container:'phedex-reset-columns' });
        Reset.on(      'click', function(obj) { return function() { _sbx.notify(obj.id,'Reset-columns'); } }(this) );

        SelectAll   = new Button({ label:'Select all Nodes',   id:'selectallnodes',   container:'phedex-selectall-nodes' });
        SelectAll.on(  'click', function(obj) { return function() { _sbx.notify(obj.id,'SelectAllNodes'); } }(this) );
        DeselectAll = new Button({ label:'Clear all Nodes', id:'deselectallnodes', container:'phedex-deselectall-nodes' });
        DeselectAll.on('click', function(obj) { return function() { _sbx.notify(obj.id,'DeselectAllNodes'); } }(this) );

        tab = new YAHOO.widget.Tab({
          label: 'Select Data',
          content:
                "<div id='phedex-filterpanel-container' class='phedex-nextgen-filterpanel'>" +
                  "<div id='phedex-filterlabel' class='phedex-nextgen-label float-left'>" +
                    "<div class='phedex-vertical-buttons' id='phedex-selectall-nodes'></div>" +
                    "<div class='phedex-vertical-buttons' id='phedex-deselectall-nodes'></div>" +
                    "<div class='phedex-vertical-buttons' id='phedex-deselectall-filters'></div>" +
                    "<div class='phedex-vertical-buttons' id='phedex-reset-filters'></div>" +
                  "</div>" +
                  "<div id='phedex-filterpanel' class='phedex-nextgen-control'>" +
                    "<div class='phedex-nextgen-label' id='phedex-label-node'>"+''+"</div>" +
                    "<div id='phedex-data-subscriptions-nodepanel-wrapper'>" +
                      "<div class='phedex-nextgen-nodepanel' id='phedex-nodepanel'>" +
                        "<em>loading node list...</em>" +
                      "</div>" +
                    "</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-requests'>requests</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-dataitems'>data items</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-custodial'>custodiality</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-group'>group</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-active'>active/suspended</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-priority'>priority</div>" +
//                     "<div id='phedex-filterpanel-completion'>Completion</div>" +
                  "</div>" +
                "</div>" +
                "<div id='phedex-data-subscriptions-apply-filters''>" +
                "</div>"
        });
        tabView.addTab(tab);
        Apply = new Button({ label:'Apply', id:'apply', container:'phedex-data-subscriptions-apply-filters' });
        Apply.on('click', function(obj) { return function() { _sbx.notify(obj.id,'Apply'); } }(this) );

//         tabView.appendTo(opts.panel); // need to attach elements to DOM before further manipulation
        tabView.appendTo(form); // need to attach elements to DOM before further manipulation

// for the Filter tab
        var field, Field; // oh boy, I'm asking for trouble here...
// Requests
        el = Dom.get('phedex-filterpanel-requests');
        field=el.innerHTML, Field=PxU.initialCaps(field); // oh boy, I'm asking for trouble here...
        el.innerHTML = "<div class='phedex-nextgen-filter-element-x'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-nextgen-filter-resize-"+field+"'><textarea id='phedex-data-subscriptions-input-"+field+"' name='"+field+"' class='phedex-filter-inputbox'>" + "List of request-IDs" + "</textarea></div>" +
                  "</div>" +
                "</div>";
        d[field] = el = Dom.get('phedex-data-subscriptions-input-'+field);
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
        PHEDEX.Nextgen.Util.makeResizable('phedex-nextgen-filter-resize-'+field,'phedex-data-subscriptions-input-'+field,{maxWidth:1000, minWidth:100});

// Data items
        el = Dom.get('phedex-filterpanel-dataitems');
        field=el.innerHTML, Field=PxU.initialCaps(field);
        field = field.replace(/ /,'');
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-nextgen-filter-resize-"+field+"'><textarea id='phedex-data-subscriptions-input-"+field+"' name='"+field+"' class='phedex-filter-inputbox'>" + "Block name or Perl reg-ex" + "</textarea></div>" +
                  "</div>" +
                "</div>";
        d[field] = el = Dom.get('phedex-data-subscriptions-input-'+field);
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
        PHEDEX.Nextgen.Util.makeResizable('phedex-nextgen-filter-resize-'+field,'phedex-data-subscriptions-input-'+field,{maxWidth:1000, minWidth:100});

// Generic for all buttons...
        var menu, button;
        this.onSelectedMenuItemChange = function(_field) {
              return function(event) {
                var oMenuItem = event.newValue,
                    text = oMenuItem.cfg.getProperty('text'),
                    value = oMenuItem.value,
                    previous;
                if ( event.prevValue ) { previous = event.prevValue.value; }
                if ( value == previous ) { return; }
                  this.set('label', ("<em class='yui-button-label'>" + text + '</em>'));
                _sbx.notify(this.id,_field,value,text);
              };
            }

// Priority...
        el = Dom.get('phedex-filterpanel-priority');
        field=el.innerHTML, Field=PxU.initialCaps(field); // oh boy, I'm asking for trouble here...
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
                  "</div>" +
                "</div>";
        menu = [
          { text: 'any',    value: 'any' },
          { text: 'low',    value: 'low' },
          { text: 'normal', value: 'normal' },
          { text: 'high',   value: 'high' }
        ];
        this.ctl[field] = button = new Button({
          id:          'menubutton-'+field,
          name:        'menubutton-'+field,
          label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
          type:        'menu',
          lazyloadmenu: false,
          menu:         menu,
          container:   'phedex-filterpanel-ctl-'+field
        });
        button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
        this._default[field] = function(_button,_field,index) {
          return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
        }(button,field,0);

// Active/Suspended...
        el = Dom.get('phedex-filterpanel-active');
        field=el.innerHTML, Field=PxU.initialCaps(field);
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
                  "</div>" +
                "</div>";
        menu = [
          { text: 'any',       value: 'any' },
          { text: 'active',    value: 'active' },
          { text: 'suspended', value: 'suspended' }
        ];
        button = new Button({
          id:          'menubutton-'+field,
          name:        'menubutton-'+field,
          label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
          type:        'menu',
          lazyloadmenu: false,
          menu:         menu,
          container:   'phedex-filterpanel-ctl-'+field
        });
        button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
        this._default[field] = function(_button,_field,index) {
          return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
        }(button,field,0);

// Custodial - dropdown (inc 'any')
        el = Dom.get('phedex-filterpanel-custodial');
        field=el.innerHTML, Field=PxU.initialCaps(field);
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
                  "</div>" +
                "</div>";
        menu = [
          { text: 'any',           value: 'any' },
          { text: 'custodial',     value: 'custodial' },
          { text: 'non-custodial', value: 'non-custodial' }
        ];
        button = new Button({
          id:          'menubutton-'+field,
          name:        'menubutton-'+field,
          label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
          type:        'menu',
          lazyloadmenu: false,
          menu:         menu,
          container:   'phedex-filterpanel-ctl-'+field
        });
        button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
        this._default[field] = function(_button,_field,index) {
          return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
        }(button,field,0);

// Group - dropdown (inc 'any')
        el = Dom.get('phedex-filterpanel-group');
        field=el.innerHTML, Field=PxU.initialCaps(field);
        el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                        "<div class='phedex-nextgen-filter'>" +
                          "<div id='phedex-filterpanel-ctl-"+field+"'>" +
                            "<em>loading group list...</em>" +
                          "</div>" +
                        "</div>" +
                      "</div>";

        var makeGroupMenu = function(o,f) {
          return function(data,context) {
            var groupList=data.group, menu, button, i, e;
            e = Dom.get('phedex-filterpanel-ctl-'+f);
            if ( !groupList ) {
              e.innerHTML = '&nbsp;<strong>Error</strong> loading group names, cannot continue';
              Dom.addClass(e,'phedex-box-red');
              _sbx.notify(o.id,'abort');
              return;
            }
            e.innerHTML='';
            menu = [ { text:'any', value:0 } ];
            for (i in groupList ) {
              group = groupList[i];
              if ( !group.name.match(/^deprecated-/) ) {
                menu.push( { text:group.name, value:group.id } );
              }
            }
            button = new Button({
              id:          'menubutton-'+f,
              name:        'menubutton-'+f,
              label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
              type:        'menu',
              lazyloadmenu: false,
              menu:         menu,
              container:    e
            });
            button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(f));
            button.getMenu().cfg.setProperty('scrollincrement',5);
            o._default[f] = function(_button,_f,index) {
              return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
            }(button,f,0);
          };
        }(this,field);
        PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// // Completion - dropdown (inc 'any')
//         el = Dom.get('phedex-filterpanel-completion');
//         field=el.innerHTML, Field=PxU.initialCaps(field);
//         el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
//                          "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
//                          "<div class='phedex-nextgen-filter'>" +
//                            "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
//                          "</div>" +
//                        "</div>";
//         menu = [
//           { text: 'any',        value: 'any' },
//           { text: 'complete',   value: 'complete' },
//           { text: 'incomplete', value: 'incomplete' }
//         ];
//         button = new Button({
//           id:          'menubutton-'+field,
//           name:        'menubutton-'+field,
//           label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
//           type:        'menu',
//           lazyloadmenu: false,
//           menu:         menu,
//           container:   'phedex-filterpanel-ctl-'+field
//         });
//        button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
//          this._default[field] = function(_button,_field,index) {
//           return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
//         }(button,field,0);

// for the Node tab...
        this.nodePanel = PHEDEX.Nextgen.Util.NodePanel( this, Dom.get('phedex-nodepanel') );
        PHEDEX.Nextgen.Util.makeResizable('phedex-data-subscriptions-nodepanel-wrapper','phedex-nodepanel',{maxWidth:1000, minWidth:100});

// for the Columns tab...
        this.columnPanel = PHEDEX.Nextgen.Util.CBoxPanel( this, Dom.get('phedex-columnpanel'), { items:this.columns, name:'columns' } );
      }
    }
  }
  Yla(this,_construct(this),true);
  return this;
}

log('loaded...','info','nextgen-data-subscriptions');
