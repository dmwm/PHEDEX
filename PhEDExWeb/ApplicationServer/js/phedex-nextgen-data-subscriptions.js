PHEDEX.namespace('Nextgen.Data');
PHEDEX.Nextgen.Data.Subscriptions = function(sandbox) {
  var string = 'nextgen-data-subscriptions',
      _sbx = sandbox,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
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
        var d = this.dom;
        d.target = el;
        d.container  = document.createElement('div'); d.container.className  = 'phedex-nextgen-container'; d.container.id = 'doc3';
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
        this.useElement(args.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr[1], i;
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action](value);
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
        this.initSub();
      },
      initSub: function() {
        var d = this.dom,
            mb = d.main_block,
            hd = d.hd,
            form, el;

        el = document.createElement('div');
        el.innerHTML = "<div id='doc3'>" +
                         "<a id='phedex-options-control' class='phedex-nextgen-form-link' href='#'>Show options</a>" +
                         "<div id='phedex-options-panel' class='phedex-invisible phedex-silver-border'></div>" +
                       "</div>";
        mb.appendChild(el);
        d.options = { panel:Dom.get('phedex-options-panel'), ctl:Dom.get('phedex-options-control') };
        onShowOptionsClick = function(obj) {
          return function() {
            var opts=d.options, tab, tabView, SelectAll, DeselectAll, Reset, Apply, el, apply=obj.dom.apply;
            if ( Dom.hasClass(opts.panel,'phedex-invisible') ) {
              Dom.removeClass(opts.panel,'phedex-invisible');
              if ( apply ) { Dom.removeClass(apply,'phedex-invisible'); }
              opts.ctl.innerHTML = 'Hide options';
            } else {
              Dom.addClass(opts.panel,'phedex-invisible');
              if ( apply ) { Dom.addClass(apply,'phedex-invisible'); }
              opts.ctl.innerHTML = 'Show options';
            }
            if ( !opts.tabView ) {
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
              SelectAll   = new YAHOO.widget.Button({ label:'Select all columns',   id:'selectallcolumns',   container:'phedex-selectall-columns' });
              SelectAll.on(  'click', function() { _sbx.notify(obj.id,'SelectAll-columns'); } );
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all columns', id:'deselectallcolumns', container:'phedex-deselectall-columns' });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAll-columns'); } );
              Reset      = new YAHOO.widget.Button({ label:'Reset to defaults', id:'resetcolumns', container:'phedex-reset-columns' });
              Reset.on(      'click', function() { _sbx.notify(obj.id,'Reset-columns'); } );

              SelectAll   = new YAHOO.widget.Button({ label:'Select all nodes',   id:'selectallnodes',   container:'phedex-selectall-nodes' });
              SelectAll.on(  'click', function() { _sbx.notify(obj.id,'SelectAllNodes'); } );
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all nodes', id:'deselectallnodes', container:'phedex-deselectall-nodes' });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllNodes'); } );

              tab = new YAHOO.widget.Tab({
                label: 'Select Data',
                content:
//                       "<div class='phedex-tab-container'>" +
//                         "<div class='phedex-tab-header'></div>" +
//                         "<div class='phedex-tab-content-wrapper'>" +
//                           "<div class='phedex-tab-centre'>" +
//                             "<div id='phedex-filterpanel-wrapper' style='border:1px solid red'>" +
//                               "<div class='phedex-filterpanel-left' style='border:1px solid yellow'>left...</div>" +
//                               "<div class='phedex-filterpanel-right' style='border:1px solid blue'>right...</div>" +
//                             "</div>" +
//                             "<div id='phedex-nodepanel' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
//                               "<em>loading node list...</em>" +
//                             "</div>" +
//                             "<div id='phedex-filterpanel-requests'>requests</div>" +
//                             "<div id='phedex-filterpanel-dataitems'>data items</div>" +
//                             "<div id='phedex-filterpanel-custodial'>custodiality</div>" +
//                             "<div id='phedex-filterpanel-group'>group</div>" +
//                             "<div id='phedex-filterpanel-active'>active/suspended</div>" +
//                             "<div id='phedex-filterpanel-priority'>priority</div>" +
//                           "</div>" +
//                         "</div>" +
//                         "<div class='phedex-tab-left'>" +
//                           "<div class='phedex-vertical-buttons' id='phedex-selectall-nodes'></div>" +
//                           "<div class='phedex-vertical-buttons' id='phedex-deselectall-nodes'></div>" +
//                           "<div class='phedex-vertical-buttons' id='phedex-deselectall-filters'></div>" +
//                           "<div class='phedex-vertical-buttons' id='phedex-reset-filters'></div>" +
//                         "</div>" +
//                         "<div class='phedex-tab-right'></div>" +
//                         "<div class='phedex-tab-footer'></div>" +
//                       "</div>"

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
//                           "<div id='phedex-filterpanel-completion'>Completion</div>" +
                        "</div>" +
                      "</div>"
              });
              tabView.addTab(tab);
              Reset      = new YAHOO.widget.Button({ label:'Reset filters', id:'resetfilters', container:'phedex-reset-filters' });
              Reset.on(      'click', function() { _sbx.notify(obj.id,'Reset-filters'); } );

//               tab = new YAHOO.widget.Tab({
//                 label: 'Testing',
//                 content:
//                       "<div class='phedex-tab-container'>" +
//                         "<div class='phedex-tab-header'></div>" +
//                         "<div class='phedex-tab-content-wrapper'>" +
//                           "<div class='phedex-tab-centre'></div>" +
//                         "</div>" +
//                         "<div class='phedex-tab-left'></div>" +
//                         "<div class='phedex-tab-right'></div>" +
//                         "<div class='phedex-tab-footer'></div>" +
//                       "</div>"
//               });
//               tabView.addTab(tab);

              tabView.appendTo(opts.panel); // need to attach elements to DOM before further manipulation

              var setupRowFilterTab = function(o) {
                return function(ev) {
//              Put the 'Reset Filters' button in the right place...
                  var cRegion=Dom.getRegion('phedex-label-requests'),
                      el=Dom.get('phedex-reset-filters'),
                      x, y, h;
                  Dom.setY(el,cRegion.top);
//                ...then add the 'Apply' button
                  o.dom.apply = el = document.createElement('span');
                  el.id = 'phedex-filter-apply';
                  Dom.get('doc3').appendChild(el);
                  Apply   = new YAHOO.widget.Button({ label:'Apply', id:'apply', container:el });
                  cRegion=Dom.getRegion('phedex-columnpanel-container');
                  x = cRegion.right;
                  if ( x<0 ) { throw new Error('Looks like someone forgot to update the cRegion to a visible object?'); }
                  y = cRegion.bottom;
                  Dom.setX(el,x+5);
                  Dom.setY(el,y-28-5); // 28 is the height of the button, but that's not rendered yet so I can't calculate it from the DOM
                  Apply.on('click', function() { _sbx.notify(obj.id,'Apply'); } );
                }
              }(obj);
              tab.on('activeChange',function(ev) {
                if ( !ev.newValue ) { return; }
                setupRowFilterTab(ev);
                setupRowFilterTab = function(){
};
                });

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
              obj._default[field] = function(e,t) {
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
              PHEDEX.Nextgen.Util.makeResizable('phedex-nextgen-filter-resize-'+field,'phedex-data-subscriptions-input-'+field);

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
              obj._default[field] = function(e,t) {
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
              PHEDEX.Nextgen.Util.makeResizable('phedex-nextgen-filter-resize-'+field,'phedex-data-subscriptions-input-'+field);

// Generic for all buttons...
              var menu, button, Button = YAHOO.widget.Button,
                  onSelectedMenuItemChange = function(_field) {
                    return function(event) {
                      var oMenuItem = event.newValue,
                          text = oMenuItem.cfg.getProperty('text'),
                          value = oMenuItem.value,
                          previous;
                          if ( event.prevValue ) { previous = event.prevValue.value; }
                      if ( value == previous ) { return; }
                      this.set('label', ("<em class='yui-button-label'>" + text + '</em>'));
                      _sbx.notify(obj.id,_field,value,text);
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
              obj.ctl[field] = button = new Button({
                id:          'menubutton-'+field,
                name:        'menubutton-'+field,
                label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
                type:        'menu',
                lazyloadmenu: false,
                menu:         menu,
                container:   'phedex-filterpanel-ctl-'+field
              });
              button.on('selectedMenuItemChange', onSelectedMenuItemChange(field));
              obj._default[field] = function(_button,_field,index) {
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
              button.on('selectedMenuItemChange', onSelectedMenuItemChange(field));
              obj._default[field] = function(_button,_field,index) {
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
              button.on('selectedMenuItemChange', onSelectedMenuItemChange(field));
              obj._default[field] = function(_button,_field,index) {
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
                  button.on('selectedMenuItemChange', onSelectedMenuItemChange(f));
                  button.getMenu().cfg.setProperty('scrollincrement',5);
                  o._default[f] = function(_button,_f,index) {
                    return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
                  }(button,f,0);
                };
              }(obj,field);
              PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// // Completion - dropdown (inc 'any')
//               el = Dom.get('phedex-filterpanel-completion');
//               field=el.innerHTML, Field=PxU.initialCaps(field);
//               el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
//                         "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
//                         "<div class='phedex-nextgen-filter'>" +
//                           "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
//                         "</div>" +
//                       "</div>";
//               menu = [
//                 { text: 'any',        value: 'any' },
//                 { text: 'complete',   value: 'complete' },
//                 { text: 'incomplete', value: 'incomplete' }
//               ];
//               button = new Button({
//                 id:          'menubutton-'+field,
//                 name:        'menubutton-'+field,
//                 label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
//                 type:        'menu',
//                 lazyloadmenu: false,
//                 menu:         menu,
//                 container:   'phedex-filterpanel-ctl-'+field
//               });
//               button.on('selectedMenuItemChange', onSelectedMenuItemChange(field));
//               obj._default[field] = function(_button,_field,index) {
//                 return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
//               }(button,field,0);

// for the Node tab...
              obj.nodePanel = PHEDEX.Nextgen.Util.NodePanel( obj, Dom.get('phedex-nodepanel') );
              PHEDEX.Nextgen.Util.makeResizable('phedex-data-subscriptions-nodepanel-wrapper','phedex-nodepanel');

// for the Columns tab...
              var items = [
                {label:'Select',           checked:true},
                {label:'Priority',         checked:true},
                {label:'% Files',          checked:false},
                {label:'Time Create',      checked:true},
                {label:'Request',          checked:true},
                {label:'Custodial',        checked:true},
                {label:'% Bytes',          checked:true},
                {label:'Time Complete',    checked:false},
                {label:'Data Level',       checked:true},
                {label:'Group',            checked:true},
                {label:'Replica/Move',     checked:true},
                {label:'Time Done',        checked:false},
                {label:'Data Item',        checked:true},
                {label:'Node Files',       checked:true},
                {label:'Active/Suspended', checked:true},
//                 {label:'Time Move Auth.',  checked:true},
                {label:'Node',             checked:true},
                {label:'Node Bytes',       checked:true},
                {label:'Item Open',        checked:false}
              ];
              obj.columnPanel = PHEDEX.Nextgen.Util.CBoxPanel( obj, Dom.get('phedex-columnpanel'), { items:items, name:'columns' } );
            }
          };
        }(this);
        Event.on(d.options.ctl,'click',onShowOptionsClick);

        form = document.createElement('form');
        form.id   = 'data_subscriptions';
        form.name = 'data_subscriptions';
        mb.appendChild(form);
      }
    }
  }
  Yla(this,_construct(this),true);
  return this;
}

log('loaded...','info','nextgen-data-subscription');