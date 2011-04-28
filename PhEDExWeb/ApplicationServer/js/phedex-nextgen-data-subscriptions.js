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
        el.innerHTML = "<div class='phedex-nextgen-form-element-xx' id='doc3'>" +
                         "<span>&nbsp;</span>" + "<a id='phedex-options-control' class='phedex-nextgen-form-link' href='#'>Show options</a>" +
                         "<div id='phedex-options-panel' class='phedex-invisible phedex-silver-border'></div>" +
                       "</div>";
        mb.appendChild(el);
        d.options = { panel:Dom.get('phedex-options-panel'), ctl:Dom.get('phedex-options-control') };
        onShowOptionsClick = function(obj) {
          return function() {
            var opts = d.options, tabView, SelectAll, DeselectAll;
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
                      "<div id='phedex-columnpanel-container-"+seq+"' class='phedex-nextgen-form-element'>" +
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
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all columns', id:'deselectallcolumns', container:'phedex-deselectall-columns-'+seq });
              SelectAll.on(  'click', function() { _sbx.notify(obj.id,'SelectAllColumns'); } );
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllColumns'); } );

              tabView.addTab( new YAHOO.widget.Tab({
                label: 'Nodes',
                content:
                      "<div id='phedex-nodepanel-container-"+seq+"' class='phedex-nextgen-form-element'>" +
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
              DeselectAll = new YAHOO.widget.Button({ label:'Deselect all nodes', id:'deselectallnodes', container:'phedex-deselectall-nodes-'+seq });
              SelectAll.on('click', function() { _sbx.notify(obj.id,'SelectAllNodes'); } );
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllNodes'); } );

              tabView.addTab( new YAHOO.widget.Tab({
                label: 'Filters',
                content:
                      "<div id='phedex-filterpanel-container-"+seq+"' class='phedex-nextgen-form-element'>" +
                        "<div id='phedex-filterlabel-"+seq+"' class='phedex-nextgen-label'>" +
                          "<div class='phedex-vertical-buttons' id='phedex-deselectall-filters-"+seq+"'></div>" +
                        "</div>" +
                        "<div id='phedex-filterpanel-"+seq+"' class='phedex-nextgen-control phedex-nextgen-filterpanel'>" +
//                           "<em>loading group list...</em>" +
                        "</div>" +
                      "</div>",
              }));

// Requests - textfield 
// Data items - textfield (default: '.*')
// Priority - dropdown (inc 'any')
// Active/Suspended - dropdown (inc 'any')
// Custodial - dropdown (inc 'any')
// Group - dropdown (inc 'any')

              DeselectAll = new YAHOO.widget.Button({ label:'Reset filters', id:'deselectallfilters', container:'phedex-deselectall-filters-'+seq });
              DeselectAll.on('click', function() { _sbx.notify(obj.id,'DeselectAllColumns'); } );

              tabView.appendTo(opts.panel);
try { // TW take out the try-catch
              obj.nodePanel = PHEDEX.Nextgen.Util.NodePanel( obj, Dom.get('phedex-nodepanel-'+seq) );
} catch(ex) {
var _ex = ex;
debugger;
}
            }
          };
        }(this);
        Event.on(d.options.ctl,'click',onShowOptionsClick);

        form = document.createElement('form');
        form.id   = 'data_subscriptions';
        form.name = 'data_subscriptions';
        mb.appendChild(form);

// Dataset/block name(s)
//       this.data_items = { text:'enter one or more block/data-set names, separated by white-space or commas.' };
//       var data_items = this.data_items;
//       el = document.createElement('div');
//       el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
//                         "<div class='phedex-nextgen-label'>Data Items</div>" +
//                         "<div class='phedex-nextgen-control'>" +
//                           "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + data_items.text + "</textarea></div>" +
//                         "</div>" +
//                       "</div>";
//       form.appendChild(el);
//
//       d.data_items = Dom.get('data_items');
//       d.data_items.onfocus = function(obj) {
//         return function() {
//           if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
//           if ( this.value == data_items.text ) {
//             this.value = '';
//             Dom.setStyle(this,'color','black');
//             obj.Preview.set('disabled',false);
//           }
//         }
//       }(this);
//       d.data_items.onblur=function(obj) {
//         return function() {
//           if ( this.value == '' ) {
//             this.value = data_items.text;
//             Dom.setStyle(this,'color',null);
//             obj.Preview.set('disabled',true);
//           }
//         }
//       }(this);

// Results
//       el = document.createElement('div');
//       el.innerHTML = "<div id='phedex-nextgen-results' class='phedex-invisible'>" +
//                        "<div class='phedex-nextgen-form-element'>" +
//                           "<div id='phedex-nextgen-results-label' class='phedex-nextgen-label'>Results</div>" +
//                           "<div class='phedex-nextgen-control'>" +
//                             "<div id='phedex-nextgen-results-text'></div>" +
//                           "</div>" +
//                         "</div>" +
//                       "</div>";
//       form.appendChild(el);
//       d.results = Dom.get('phedex-nextgen-results');
//       d.results_label = Dom.get('phedex-nextgen-results-label');
//       d.results_text  = Dom.get('phedex-nextgen-results-text');

//       this.requestCallback = function(obj) {
//         return function(data,context) {
//           var dom = obj.dom, str, msg, rid;
//           dom.results_label.innerHTML = '';
//           dom.results_text.innerHTML = '';
//           Dom.removeClass(dom.results,'phedex-box-yellow');
//           if ( data.message ) { // indicative of failure~
//             str = "Error when making call '" + context.api + "':";
//             msg = data.message.replace(str,'').trim();
//             obj.onAcceptFail(msg);
//             obj.Accept.set('disabled',false);
//           }
//           if ( rid = data.request_created[0].id ) {
//             obj.onResetSubmit();
//             var uri = location.href;
//             uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
//             uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
//             uri = uri.replace(/\/[^/]*$/g,'/');
//
//             dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
//               "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
//             Dom.addClass(dom.results,'phedex-box-green');
//             Dom.removeClass(dom.results,'phedex-invisible');
//           }
//         }
//       }(this);
//       this.onAcceptFail = function(obj) {
//         return function(text) {
//           var dom = obj.dom;
//           Dom.removeClass(dom.results,'phedex-invisible');
//           Dom.addClass(dom.results,'phedex-box-red');
//           dom.results_label.innerHTML = 'Error:';
//           if ( dom.results_text.innerHTML ) {
//             dom.results_text.innerHTML += '<br />';
//           }
//           dom.results_text.innerHTML += text;
//           obj.formFail = true;
//         }
//       }(this);
//       this.onAcceptSubmit = function(obj) {
//         return function(id,action) {
//           var dbs = obj.dbs,
//               dom = obj.dom;
//
// // Prepare the form for output messages, disable the button to prevent multiple clicks
//           Dom.removeClass(obj.dom.results,'phedex-box-red');
//           dom.results_label.innerHTML = '';
//           dom.results_text.innerHTML  = '';
//           obj.formFail = false;
//           this.set('disabled',true);
//
//           dom.results_text.innerHTML  = 'Submitting request (please wait)' +
//           '<br/>' +
//           "<img src='" + PxW.BaseURL + "images/barbers_pole_loading.gif'/>";
// //           PHEDEX.Datasvc.Call({ api:'delete', method:'post', args:args, callback:function(data,context) { obj.requestCallback(data,context); } });
//         }
//       }(this);

      }
    }
  }
  Yla(this,_construct(this),true);
  return this;
}

log('loaded...','info','nextgen-data-subscription');