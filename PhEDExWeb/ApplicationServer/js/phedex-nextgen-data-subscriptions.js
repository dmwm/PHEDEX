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
                value  = arr[1];
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action](value);
              return;
            }
            switch (action) {
              case 'SelectAllColumns': {
debugger;
//                 for ( i in nodePanel.elList ) { nodePanel.elList[i].checked = true; }
                break;
              }
              case 'DeselectAllColumns': {
debugger;
//                 for ( i in nodePanel.elList ) { nodePanel.elList[i].checked = false; }
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
        this.initButtons();
      },
      initButtons: function() {
//         var ft=this.dom.ft, Reset, //, Validate, Cancel;
//             el = document.createElement('div');
//         Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-left');
//         el.id='buttons-left';
//         ft.appendChild(el);
// 
//         el = document.createElement('div');
//         Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-centre');
//         el.id='buttons-centre';
//         ft.appendChild(el);
// 
//         el = document.createElement('div');
//         Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-right');
//         el.id='buttons-right';
//         ft.appendChild(el);
// 
//         var label='Reset', id='button'+label;
//         Reset = new YAHOO.widget.Button({
//                                 type: 'submit',
//                                 label: label,
//                                 id: id,
//                                 name: id,
//                                 value: id,
//                                 container: 'buttons-left' });
//         label='Accept', id='button'+label;
//         this.Accept = new YAHOO.widget.Button({
//                                 type: 'submit',
//                                 label: label,
//                                 id: id,
//                                 name: id,
//                                 value: id,
//                                 container: 'buttons-right' });
//         this.Accept.set('disabled',true);
//         this.Accept.on('click', this.onAcceptSubmit);
// 
//         this.onResetSubmit = function(obj) {
//           return function(id,action) {
//             var dbs = obj.dbs,
//                 dom = obj.dom;
//           }
//         }(this);
//         Reset.on('click', this.onResetSubmit);
      },
      initSub: function() {
        var d = this.dom,
            mb = d.main_block,
            hd = d.hd,
            form, el, seq=PxU.Sequence();

        el = document.createElement('div');
        el.innerHTML = "<div id='doc3'>" +
                         "<a id='phedex-options-control' class='phedex-nextgen-form-link' href='#'>Show options</a>" +
                         "<div id='phedex-options-panel' class='phedex-invisible phedex-silver-border'></div>" +
                       "</div>";
        mb.appendChild(el);
        d.options = { panel:Dom.get('phedex-options-panel'), ctl:Dom.get('phedex-options-control') };
        onShowOptionsClick = function(obj) {
          return function() {
            var opts=d.options, tabView, SelectAll, DeselectAll, Apply, el;
            if ( Dom.hasClass(opts.panel,'phedex-invisible') ) {
              Dom.removeClass(opts.panel,'phedex-invisible');
              opts.ctl.innerHTML = 'Hide options';
            } else {
              Dom.addClass(opts.panel,'phedex-invisible');
              opts.ctl.innerHTML = 'Show options';
            }
            if ( !opts.tabView ) {
              tabView = opts.tabView = new YAHOO.widget.TabView();
              tabView.addTab( new YAHOO.widget.Tab({
                label: 'Columns',
                content:
                      "<div id='phedex-columnpanel-container' class='phedex-nextgen-form-element'>" +
                        "<div id='phedex-columnlabel-"+seq+"' class='phedex-nextgen-label'>" +
                          "<div class='phedex-vertical-buttons' id='phedex-selectall-columns-"+seq+"'></div>" +
                          "<div class='phedex-vertical-buttons' id='phedex-deselectall-columns-"+seq+"'></div>" +
                        "</div>" +
                        "<div id='phedex-columnpanel-"+seq+"' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
                        "</div>" +
                      "</div>",
                active: true
              }));
              SelectAll   = new YAHOO.widget.Button({ label:'Select all columns',   id:'selectallcolumns',   container:'phedex-selectall-columns-'+seq });
              SelectAll.on(  'click', function() { _sbx.notify(obj.id,'SelectAllColumns'); } );
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all columns', id:'deselectallcolumns', container:'phedex-deselectall-columns-'+seq });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllColumns'); } );

              tabView.addTab( new YAHOO.widget.Tab({
                label: 'Nodes',
                content:
                      "<div id='phedex-nodepanel-container' class='phedex-nextgen-form-element'>" +
                        "<div id='phedex-nodelabel-"+seq+"' class='phedex-nextgen-label'>" +
                          "<div class='phedex-vertical-buttons' id='phedex-selectall-nodes-"+seq+"'></div>" +
                          "<div class='phedex-vertical-buttons' id='phedex-deselectall-nodes-"+seq+"'></div>" +
                        "</div>" +
                        "<div id='phedex-nodepanel-"+seq+"' class='phedex-nextgen-control phedex-nextgen-nodepanel'>" +
                          "<em>loading node list...</em>" +
                        "</div>" +
                      "</div>"
              }));
              SelectAll   = new YAHOO.widget.Button({ label:'Select all nodes',   id:'selectallnodes',   container:'phedex-selectall-nodes-'+seq });
              SelectAll.on(  'click', function() { _sbx.notify(obj.id,'SelectAllNodes'); } );
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all nodes', id:'deselectallnodes', container:'phedex-deselectall-nodes-'+seq });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllNodes'); } );

              tabView.addTab( new YAHOO.widget.Tab({
                label: 'Filters',
                content:
                      "<div id='phedex-filterpanel-container' class='phedex-nextgen-form-element'>" +
                        "<div id='phedex-filterlabel-"+seq+"' class='phedex-nextgen-label'>" +
                          "<div class='phedex-vertical-buttons' id='phedex-deselectall-filters-"+seq+"'></div>" +
                        "</div>" +
                        "<div id='phedex-filterpanel-"+seq+"' class='phedex-nextgen-control'>" +
                          "<div id='phedex-filterpanel-requests'>requests</div>" +
                          "<div id='phedex-filterpanel-dataitems'>data items</div>" +
                          "<div id='phedex-filterpanel-priority'>priority</div>" +
                          "<div id='phedex-filterpanel-active'>active/suspended</div>" +
                          "<div id='phedex-filterpanel-custodial'>custodial</div>" +
                          "<div id='phedex-filterpanel-group'>group</div>" +
                        "</div>" +
                      "</div>"
              }));
              DeselectAll = new YAHOO.widget.Button({ label:'Reset filters', id:'deselectallfilters', container:'phedex-deselectall-filters-'+seq });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllColumns'); } );

              tabView.appendTo(opts.panel); // need to attach elements to DOM before further manipulation

              var field, Field; // oh boy, I'm asking for trouble here...
              el = Dom.get('phedex-filterpanel-requests');
              field=el.innerHTML, Field=PxU.initialCaps(field); // oh boy, I'm asking for trouble here...
              el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                        "<div class='phedex-nextgen-filter'>" +
                          "<div><textarea id='phedex-filterpanel-ctl-"+field+"' name='"+field+"' class='phedex-filter-inputbox'>" + "" + "</textarea></div>" +
                        "</div>" +
                      "</div>";

              el = Dom.get('phedex-filterpanel-dataitems');
              field=el.innerHTML, Field=PxU.initialCaps(field); // oh boy, I'm asking for trouble here...
              el.innerHTML = "<div class='phedex-nextgen-filter-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                        "<div class='phedex-nextgen-filter'>" +
                          "<div><textarea id='phedex-filterpanel-ctl-"+field+"' name='"+field+"' class='phedex-filter-inputbox'>" + "" + "</textarea></div>" +
                        "</div>" +
                      "</div>";

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

              var makeGroupMenu = function(o) {
                return function(data,context) {
                  var groupList=data.group, menu, button, i, e;
                  e = Dom.get('phedex-filterpanel-ctl-'+field);
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
                    id:          'menubutton-'+field,
                    name:        'menubutton-'+field,
                    label:       "<em class='yui-button-label'>"+menu[0].text+'</em>',
                    type:        'menu',
                    lazyloadmenu: false,
                    menu:         menu,
                    container:    e
                  });
                  button.on('selectedMenuItemChange', onSelectedMenuItemChange(field));
                  button.getMenu().cfg.setProperty('scrollincrement',5);
                };
              }(obj);
              PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// Node panel...
              obj.nodePanel = PHEDEX.Nextgen.Util.NodePanel( obj, Dom.get('phedex-nodepanel-'+seq) );

// 'Apply' button...
              el = document.createElement('div');
              el.id = 'phedex-filter-apply';
              opts.panel.appendChild(el);
              Apply   = new YAHOO.widget.Button({ label:'Apply', id:'apply', container:el });
              Apply.on('click', function() {
 _sbx.notify(obj.id,'Apply'); } );
              var e, x, y, h, cRegion=Dom.getRegion('phedex-columnpanel-container');
              x = cRegion.right;
              y = cRegion.bottom;
              Dom.setX(el,x+5);
              Dom.setY(el,y-28-5); // 28 is the height of the button, but that's not rendered yet so I can't calculate it from the DOM

//            now fiddle with the bounding panel. Yuck!
              e = Dom.get('phedex-options-panel');
              h = e.offsetHeight - 29;
              e.style.height = h+'px';
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