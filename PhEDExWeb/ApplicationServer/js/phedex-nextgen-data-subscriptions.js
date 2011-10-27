PHEDEX.namespace('Nextgen.Data');
PHEDEX.Nextgen.Data.Subscriptions = function(sandbox) {
  var string = 'nextgen-data-subscriptions',
      _sbx = sandbox, dom,
      NUtil = PHEDEX.Nextgen.Util,
      Icon  = PxU.icon,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Yw = YAHOO.widget,
      Button = Yw.Button;
  Yla(this,new PHEDEX.Module(_sbx,string));
  dom = this.dom;

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
      _filter: { node:[], request:[], data_items:[] }, // values set by the filter tab, updated as they are changed
      meta: {
        showColumns:
        [
          {label:'Request',       _default:true},
          {label:'Data Level',    _default:true},
          {label:'Data Item',     _default:true},
          {label:'Node',          _default:true},
          {label:'Priority',      _default:true},
          {label:'Custodial',     _default:true},
          {label:'Group',         _default:true},
          {label:'Node Files',    _default:true},
          {label:'Node Bytes',    _default:true},
          {label:'% Files',       _default:false},
          {label:'% Bytes',       _default:true},
          {label:'Replica/Move',  _default:true},
          {label:'Suspended',     _default:true},
          {label:'Open',          _default:false},
          {label:'Time Create',   _default:true},
//           {label:'Time Complete', _default:false},
          {label:'Time Done',     _default:false}
        ],
        map:
        {
          custodial:{custodial:'y', 'non-custodial':'n'},
          suspended:{suspended:'y', active:'n'},
          create_since:{'1 month':1, '2 months':2, '3 months':3, '6 months':6, '1 year':12, '2 years':24, forever:0}, // months...
        },
        filterMap:
        {
          fields:
          {
             custodiality:      'custodial',
            'active/suspended': 'suspended',
             priority:          'priority',
             group:             'group'
          },
          values:
          {
            custodial:{custodial:'y', 'non-custodial':'n'},
            suspended:{suspended:'y', active:'n'},
           'created since':{'1 month':1, '2 months':2, '3 months':3, '6 months':6, '1 year':12, '2 years':24, forever:0} // months...
          },
        },
        selected:{},
        nSelected:0,
        admin:
        {
          opts:
          {
            suspend:     'Suspend subscriptions',
            unsuspend:   'Unsuspend subscriptions',
            priorityhi:  'Make high priority',
            priorityno:  'Make normal priority',
            prioritylo:  'Make low priority',
            groupchange: 'Change group',
            deletedata:  'Delete this data'
          },
          groups:
          {
            'suspend':['suspend', 'unsuspend'],
            'priority':['priorityhi', 'priorityno', 'prioritylo', 'groupchange']
          }
        },
        maxRowsDefault:500
      },
      useElement: function(el) {
        var form;
        dom.target = el;
        dom.permalink  = document.createElement('div'); dom.permalink.className = 'float-right'; dom.permalink.id = 'phedex-permalink';
        dom.container  = document.createElement('div'); dom.container.className  = 'phedex-nextgen-container'; dom.container.id = 'doc3';
        dom.hd         = document.createElement('div'); dom.hd.className         = 'phedex-nextgen-hd';        dom.hd.id = 'hd';
        dom.bd         = document.createElement('div'); dom.bd.className         = 'phedex-nextgen-bd';        dom.bd.id = 'bd';
        dom.ft         = document.createElement('div'); dom.ft.className         = 'phedex-nextgen-ft';        dom.ft.id = 'ft';
        dom.main       = document.createElement('div'); dom.main.className       = 'yui-main';
        dom.main_block = document.createElement('div'); dom.main_block.className = 'yui-b phedex-nextgen-main-block';
        dom.selector   = document.createElement('div'); dom.selector.id          = 'phedex-data-subscriptions-selector';
        dom.dataform   = document.createElement('div'); dom.dataform.id          = 'phedex-data-subscriptions-dataform';
        dom.messages   = document.createElement('div'); dom.messages.id          = 'phedex-data-subscriptions-messages';
        dom.messages.style.padding = '5px';
        dom.datatable  = document.createElement('div'); dom.datatable.id         = 'phedex-data-subscriptions-datatable';
        form = document.createElement('form');
        form.id   = 'data-subscriptions-action';
        form.name = 'data-subscriptions-action';
        form.method = 'post';
        form.action = location.pathname;
        this.data_subscriptions_action = form;

//      Would like to just float-right the div, but then the link doesn't behave correctly with mouse-over events
        dom.permalink.style.position = 'absolute';
        dom.permalink.style.right    = '1em';
        dom.permalink.style.zIndex   = 1;
        dom.permalink.innerHTML = "<a href='#' id='phedex-page-permalink'>permalink</a> to this pages' state";
        dom.bd.appendChild(dom.permalink);

        dom.bd.appendChild(dom.main);
        dom.main.appendChild(dom.main_block);
        dom.container.appendChild(dom.hd);
        dom.container.appendChild(dom.bd);
        dom.container.appendChild(dom.ft);
        dom.container.appendChild(dom.selector);
        dom.container.appendChild(dom.dataform);
        dom.dataform.appendChild(form);
        dom.dataform.appendChild(dom.messages);
        dom.dataform.appendChild(dom.datatable);
        el.innerHTML = '';
        el.appendChild(dom.container);

        dom.floating_help = document.createElement('div'); dom.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible'; dom.floating_help.id = 'phedex-help-'+PxU.Sequence();
        document.body.appendChild(dom.floating_help);
      },
      gotAuthData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        if ( !data.auth ) { return; }
        var auth, roles, role, i;

        obj.auth = auth = data.auth[0];
        if ( typeof(auth) != 'object' ) { auth = {}; } // AUTH call failed, proceed regardless...
        auth.isAdmin = false;
        auth.can = [];
        roles = auth.role;
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
        if ( auth.isAdmin ) { _sbx.notify(obj.id,'isAdmin'); }
        else                { _sbx.notify(obj.id,'isNotAdmin'); }
      },
      isNotAdmin: function() {
//      User has no administrative rights. Add a link explaining why.
        var el = document.createElement('a'),
            auth = obj.auth,
            container = dom.container,
            toggle, id=PxU.Sequence();
        el.id = 'phedex-help-anchor-'+id;
        el.href = '#';
        el.innerHTML = 'Privileged Activities Help';
        container.appendChild(el);
        toggle = "var s = new PHEDEX.Sandbox(); s.notify('"+obj.id+"','Help','privilegedActivity');";
        obj.privilegedActivity = {
            text: "<a id='close-anchor-"+id+"' class='float-right' href='#'>[close]</a>" +
                  "<p><strong>Privileged Activities:</strong></p>" +
                  NUtil.authHelpMessage(
                    { to:'change priorities of subscriptions and manage groups', need:'cert', role:['Data Manager', 'Admin'] },
                    { to:'suspend/unsuspend subscriptions',                      need:'any',  role:['Data Manager', 'Site Admin', 'PADA Admin', 'Admin'] }
                  ),
            el:el,
            close:'close-anchor-'+id,
            toggle:toggle
          };
        el.setAttribute('onclick',toggle);
        return;
      },
      isAdmin: function() {
//     User has administrative rights, add the menus!
        var auth=obj.auth,
            i, j, k, container=dom.container, selector=dom.selector, form=obj.data_subscriptions_action,
            id=PxU.Sequence(),
            field, el, button,
            admin_opts = this.meta.admin.opts,
            admin_grps = this.meta.admin.groups,
            admin_menu=[];

//      Notify the table that it can show the select column
        if ( this.subscriptionsId ) {
          _sbx.notify(this.subscriptionsId,'setColumnVisibility',[{label:'Select', show:true}]);
        }

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
                         "</div>";
          selector.appendChild(el);
          this.onSelectAllOrNone = function(val) {
            var elList, i, elUpdate=[];
            elList = Dom.getElementsByClassName('phedex-checkbox','input',dom.datatable);
            for (i in elList) {
              if ( elList[i].checked != val ) {
                elUpdate.push(elList[i]);
              }
            }
            if ( elUpdate.length ) {
              _sbx.notify(this.subscriptionsId,'checkboxSelect',elUpdate,val);
            }
            i = elList.length;
            if ( val ) { this.setSummary('OK',   'Selected '+i+' subscription'+(i==1?'':'s')); }
            else       { this.setSummary('OK','De-selected '+i+' subscription'+(i==1?'':'s')); }
          };
          button = new Button({ label:'Select all',  id:'phedex-data-subscriptions-select-all',  container:'phedex-data-subscriptions-ctl-select-all'  });
          button.on('click',function() { obj.onSelectAllOrNone(true) });
          button.set('disabled',true);
          this.ctl.selectAll = button;
          button = new Button({ label:'Clear all', id:'phedex-data-subscriptions-clear-all', container:'phedex-data-subscriptions-ctl-clear-all' });
          button.on('click',function() { obj.onSelectAllOrNone(false) });
          button.set('disabled',true);
          this.ctl.selectNone = button;

          i = document.createElement('input');
          i.type = 'hidden'
          i.name = 'priority';
          i.value = this._filter.priority;
          form.appendChild(i);
          i = document.createElement('input');
          i.type = 'hidden'
          i.name = 'suspended';
          i.value = this._filter.suspended;
          form.appendChild(i);

          field='action';
          el = document.createElement('span');
          el.id = 'phedex-subscription-action-'+id;
          el.innerHTML = "<div class='phedex-data-subscriptions-action'>" +
                           "<span class='phedex-nextgen-label' id='phedex-data-subscriptions-label-action'>Action:</span>" +
                           "<span id='phedex-data-subscriptions-ctl-action'></span>" +
                           "<span id='phedex-data-subscriptions-ctl-group' 'class='phedex-invisible'><em>loading group list</em></span>" +
                           "<span id='phedex-data-subscriptions-ctl-update'></span>" +
                           "<span id='phedex-data-subscriptions-ctl-interrupt' class='phedex-invisible'></span>" +
                         "</div>";
          form.appendChild(el);
          this.ctl[field] = button = new Button({
            id:          'phedex-data-subscriptions-action',
            name:        'phedex-data-subscriptions-action',
            label:       'Choose an action',
            type:        'menu',
            lazyloadmenu: false,
            menu:         admin_menu,
            container:   'phedex-data-subscriptions-ctl-action'
          });
          button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field));
          this._default[field] = function(_button,_field,index) {
            return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
          }(button,field,0);
          this.onUpdate = function(obj) {
            return function() {
              var elList, action, param, selected=obj.meta.selected, i, j, n=obj.meta.nSelected, msg, args={}, item, level, fn,
                  pending=[], tmp;
              action = obj.update.action;
              if ( !n ) {
                obj.setSummary('error','You did not select any subscriptions to modify');
                return;
              }
              msg = '"'+obj.meta.admin.opts[action]+'"';
              if ( action == 'groupchange' ) {
                msg += ' to "'+obj.update.group+'"';
              }
              obj.setSummary('OK','Apply '+msg+' to '+n+' subscription'+(n==1?'':'s'));
              switch (action) {
                case 'group':      { args.group = obj.update.group;   break; }
                case 'suspend':    { args.suspend_until = 9999999999; break; }
                case 'unsuspend':  { args.suspend_until = 0;          break; }
                case 'prioritylo': { args.priority = 'low';           break; }
                case 'priorityno': { args.priority = 'normal';        break; }
                case 'priorityhi': { args.priority = 'high';          break; }
              }
              obj.nResponse = { OK:0, fail:0 };
              for (i in selected) {
                item = selected[i];
                delete args.block;
                delete args.dataset;
                args.node = item.node;
                level = item.level.toLowerCase();
                args[level] = item.item;
                fn = function(id) {
                  return function(data,context,response) { obj.gotActionReply(data,context,response,id,n); }
                }(i);
                tmp={};
                for ( j in args ) { tmp[j] = args[j]; }
                pending.push({ fn:fn, args:tmp, cbox:parseInt(i.match(/^cbox_([0-9]*)$/)[1]) });
                delete args[level];
              }
              obj.pending = pending.sort( function(a,b) { return YAHOO.util.Sort.compare(a.cbox,b.cbox); } );
              obj.interrupted = false;
              obj.changedRows = 0;
              obj.dispatchUpdate();
            };
          }(this);
          button = new Button({ label:'Apply changes', id:'phedex-data-subscriptions-update', container:'phedex-data-subscriptions-ctl-update' });
          button.on('click',this.onUpdate);
          button.set('disabled',true);
          this.ctl.applyChanges = button;
          button = new Button({ label:'Interrupt processing', id:'phedex-data-subscriptions-interrupt', container:'phedex-data-subscriptions-ctl-interrupt' });
          button.on('click',this.interruptProcessing);
          this.ctl.interrupt = button;
          dom.interrupt_container = this.ctl.interrupt.get('container');
        }
      },
      interruptProcessing: function() {
        delete obj.pending;
        obj.setSummary('warn','Processing interrupted');
        _sbx.notify(obj.id,'setUIIdle');
        _sbx.notify(obj.id,'setApplyChangesState');
        obj.interrupted = true;
      },
      dispatchUpdate: function() {
        var i, fn, args, pending=this.pending, item;
        if ( !this.queued ) {
          this.queued = 0;
        }
        while ( pending.length ) {
          item = pending.shift();
          fn   = item.fn;
          args = item.args;
          PHEDEX.Datasvc.Call({method:'POST', api:'updatesubscription', args:args, callback:fn});
          this.queued++;
          if ( this.queued >= 5 ) { break; }
        }
        if ( this.queued ) {
          this.ctl.applyChanges.set('disabled',true);
          _sbx.notify(obj.id,'setUIBusy');
        }
      },
      gotActionReply: function(data,context,response,cbox,total) {
        var status='OK',
            nResponse = this.nResponse,
            nSelected = this.meta.nSelected,
            sum, msg, row, now, etc;
        this.queued--;
        _sbx.notify(this.id,'dispatchUpdate');
        if ( response ) {
          nResponse.fail++;
        } else {
          nResponse.OK++;
          _sbx.notify(this.subscriptionsId,'updateRow',cbox,data.dataset[0]);
        }
        if ( nResponse.fail ) { status = 'error'; }
        msg = nResponse.fail+' failure'+(nResponse==1?'':'s')+', '+
              nResponse.OK+' success'+(nResponse.OK==1?'':'es')+
             ' out of '+total+' subscription'+(total==1?'':'s');
        sum = nResponse.OK+nResponse.fail;
        if ( sum == total ) {
          if ( nResponse.fail == 0 ) {
            msg = 'All subscriptions successfully updated';
          } else {
            msg = 'Finished with '+msg;
          }
          _sbx.notify(this.id,'setApplyChangesState');
          _sbx.notify(obj.id,'setUIIdle');
        } else {
          if ( total > 20 && sum > 10 ) {
            now = new Date().getTime()/1000;
            etc = Math.floor((now-this.UIbusy)*(total-sum)/sum);
            msg += ' | Estimate '+etc+' second'+(etc==1?'':'s')+' remaining';
          }
        }
        if ( this.interrupted ) {
          status = 'warn';
          msg += ' (Interrupted by user)';
        }
        this.setSummary(status,msg);
      },
      setSummary: function(status,text) {
        var map = {error:'phedex-box-red', warn:'phedex-box-yellow', OK:'phedex-box-green'}, i;
        dom.messages.innerHTML = text;
        for ( i in map ) {
          Dom.removeClass(dom.messages,map[i]);
        }
        if ( map[status] ) {
          Dom.addClass(dom.messages,map[status]);
        }
      },
      setValueFor: function(label,value) {
        value = value.replace(/\n|,/g,' ');
        if ( value.match(/^ *$/) ) {
          this._filter[label] = [];
        } else {
          this._filter[label]  = value.split(/ |\n|,/);
        }
      },
      unsetValueFor: function(label) {
        this._filter[label] = [];
      },
      Help:function(item) {
        item = this[item];
        var elRegion = Dom.getRegion(item.el),
            elHelp   = dom.floating_help;
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
        var i, hideThese=[], columns=this.meta.showColumns, el;
        if ( !params ) { params={}; }
        this.params = params;
        this.meta.maxRows = this.meta.maxRowsDefault;
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action=arr[0], i, value, field, _filter, filterMap, _filterField, ctl=obj.ctl;
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              arr.shift();
              obj[action].apply(obj,arr);
              return;
            }
            _filter = obj._filter;
            filterMap = obj.meta.filterMap;
            switch (action) {
              case 'Reset-filters': {
                for ( i in obj._default ) { obj._default[i](); }
                break;
              }
              case 'menuChange_action': {
                if ( !obj.update ) {
                  obj.update = {};
                }
                if ( arr[3] == 'groupchange' ) {
                  obj.ctl.group.set('disabled',false);
                } else {
                  obj.ctl.group.set('disabled',true);
                }
                obj.update.action = arr[3];
                _sbx.notify(obj.id,'setApplyChangesState');
                break;
              }
              case 'menuChange_group': {
                obj.update.group = arr[2];
                _sbx.notify(obj.id,'setApplyChangesState');
                break;
              }
              case 'menuChange_filter': {
                field = filterMap.fields[arr[1]];
                if ( field ) {
                  if ( arr[2] == 'any' ) {
                    delete _filter[field];
                  } else {
                    _filterField = filterMap.values[field];
                    if ( _filterField ) { _filter[field] = _filterField[arr[2]]; }
                    else                { _filter[field] = arr[2]; }
                    if ( _filter[field] == null ) { delete _filter[field]; }
                  }
                  break;
                }

//              special cases
                if ( arr[1] == 'completion' ) {
                  delete _filter.percent_min;
                  delete _filter.percent_max;
                  if ( arr[2] == 'complete' )   { _filter.percent_min=100; }
                  if ( arr[2] == 'incomplete' ) { _filter.percent_max=99.99999; }
                  break;
                }
// another special case. Note the finesse here, create_since=0 is valid, means forever, and does not get subtracted from 'now'
                if ( arr[1] == 'created since' ) {
                  i = filterMap.values[arr[1]][arr[2]];
                  if ( i ) {
                    _filter.create_since = new Date().getTime()/1000 - filterMap.values[arr[1]][arr[2]]*86400*30;
                  } else {
                    _filter.create_since = 0;
                  }
                }
                break;
              }
              case 'SelectAllNodes': {
                obj._filter.node = obj.nodePanel.nodes;
                break;
              }
              case 'DeselectAllNodes': {
                obj._filter.node = [];
                break;
              }
              case 'NodeSelected': {
                var i, nodes=obj._filter.node;
                for (i in nodes) {
                  if ( nodes[i] == arr[1] ) {
                    if ( arr[2] ) { break; }
                    nodes.splice(i,1);
                    break;
                  }
                }
                if ( arr[2] ) {
                  nodes.push(arr[1]);
                }
                break;
              }
              case 'CBoxPanel-selected': {
                var label=arr[1], show=arr[2];
                _sbx.notify(obj.subscriptionsId,'setColumnVisibility',[ {label:label,show:show} ]);
                break;
              }
              case 'DoneSelectAll-columns':   // deliberate fall-through
              case 'DoneDeselectAll-columns': // deliberate fall-through
              case 'DoneReset-columns': {
                obj.setHiddenColumns();
                break;
              }
              case 'setUIBusy': {
                Dom.removeClass(dom.interrupt_container,'phedex-invisible');
                ctl.selectAll.set( 'disabled',true);
                ctl.selectNone.set('disabled',true);
                ctl.options.button.set('disabled',true);
                if ( !obj.UIbusy ) { obj.UIbusy = new Date().getTime()/1000; }
                break;
              }
              case 'setUIIdle': {
                Dom.addClass(dom.interrupt_container,'phedex-invisible');
                ctl.selectAll.set( 'disabled',false);
                ctl.selectNone.set('disabled',false);
                ctl.options.button.set('disabled',false);
                obj.UIbusy = 0;
                if ( obj.changedRows ) {
                  obj.setSummary('OK',obj.changedRows+' subscription'+(obj.changedRows==1?' was':'s were')+' changed');
                } else {
                  obj.setSummary('error','Nothing was changed!');
                }
                break;
              }
              case 'setApplyChangesState': {
                var update = obj.update, pending = obj.pending;
                if ( obj.meta.nSelected &&
                     update &&
                     (
                       (update.action == 'groupchange' && update.group) ||
                       (update.action != 'groupchange' && update.action != null)
                     )
                   ) {
                  obj.ctl.applyChanges.set('disabled',false);
                } else {
                  obj.ctl.applyChanges.set('disabled',true);
                }
                break;
              }
              case 'goToFilter': {
                obj.onShowOptionsClick();
                obj.ctl.options.tabView.selectTab(1);
                break;
              }
              case 'changeMaxRows': {
                var el = Dom.get('phedex-setMaxRows-popup'),
                    parent = Dom.get('phedex-setMaxRows'),
                    elRegion = Dom.getRegion('phedex-setMaxRows'),
                    id = PxU.Sequence(), button;
                if ( el ) {
                  Dom.removeClass(el,'phedex-invisible');
                } else {
                  el = document.createElement('div');
                  el.innerHTML =
                      "<div id='phedex-setMaxRows-popup' style='width:20em; border:1px solid blue; background-color:#f8ffff; text-align:left; padding:0 0 0 5px;'>" +
                        "<a id='close-anchor-"+id+"' class='float-right' href='#'>[close]</a>" +
                        "<div style='clear:both;'>" +
                          "How many rows do you want to see?" +
                          "<br/>N.B. 1000 rows is a safe limit" +
                          "<br/><input id='phedex-setMaxRows-input' type='text' style='margin:6px; width:10em'>" +
                          "<div class='float-right' id='phedex-setMaxRows-apply'></div>" +
                        "<div>" +
                      "<div>";
                  document.body.appendChild(el);
                  Dom.get('close-anchor-'+id).setAttribute('onclick', "var d=YAHOO.util.Dom;d.addClass(d.get('phedex-setMaxRows-popup'),'phedex-invisible');");
                  button = new YAHOO.widget.Button({
                                 label: 'Apply',
                                 id: 'apply-setMaxRows',
                                 container: 'phedex-setMaxRows-apply' });
                  button.on('click',function() {
                    _sbx.notify(obj.id,'maxRowsChanged',Dom.get('phedex-setMaxRows-input').value);
                  });
                }
                Dom.setX(el,elRegion.left);
                Dom.setY(el,elRegion.bottom);
                Dom.get('phedex-setMaxRows-input').focus();
                break;
              }
              case 'maxRowsChanged': {
                value = arr[1];
                if ( !value.match(/^[0-9]+$/) ) { break; }
                value = parseInt(value);
                if ( !value ) { break; }
                if ( value == obj.meta.maxRows ) { break; }
                obj.meta.maxRows = value;
                _sbx.notify(obj.subscriptionsId,'setMaxRows',obj.meta.maxRows);
                obj.gotSubscriptions(obj.data,obj.context);
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
        this.initHistory();
        PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })
        PHEDEX.Datasvc.Call({ api:'groups', callback:this.gotGroupMenu });

        _sbx.notify('SetModuleConfig','subscriptions-table',
                        { parent:dom.datatable,
                          autoDestruct:false,
                          noDecorators:true,
                          noExtraDecorators:true,
                          noHeader:true,
                          meta:{maxRows:this.meta.maxRows}
                        });
        _sbx.notify('CreateModule','subscriptions-table',{notify:{who:this.id, what:'gotSubscriptionsId'}});
        this.getSubscriptions();
        _sbx.notify(this.id,'buildOptionsTabview');
      },
      initHistory: function() {
// set up the History management
        var handler = function(ev,arr) {
          switch (arr[0]) {
            case 'stateChange': {
              break;
            }
            case 'initialiseApplication': {
              break;
            }
            case 'permalink': { // separate handler for notifying me that the permalink has changed. I use this to set a link on the page
              Dom.get('phedex-page-permalink').setAttribute('href',arr[1]);
              break;
            }
            default: {
              break;
            }
          }
        };
        _sbx.listen('History',handler);
        new PHEDEX.History({ module:'state' });
      },
      setHistory: function(args) {
        var state={}, i;
        for ( i in args ) { state[i] = args[i]; }
        if ( this.meta.maxRows != this.meta.maxRowsDefault ) {
          state.rows = this.meta.maxRows;
        }
        _sbx.notify('History','navigate',state);
      },
      setHiddenColumns: function() {
        var el, elList=this.columnPanel.elList, i, columns=[], auth;
        for ( i in elList ) {
          el = elList[i];
          columns.push({label:el.name, show:el.checked});
        }
        auth = false;
        if ( this.auth ) { auth = this.auth.isAdmin; }
        columns.push({label:'Select', show:auth});
        _sbx.notify(this.subscriptionsId,'setColumnVisibility',columns);
      },
      gotSubscriptionsId: function(arg) {
        this.subscriptionsId = arg;
        var handler = function(obj) {
          return function(ev,arr) {
            var action = arr[0];
            switch (action) {
              case 'destroy': {
                delete this.previewId;
                break;
              }
              case 'initDerived': { // module is live, set the hidden fields!
                obj.subscriptionsModuleIsReady = true;
                obj.setHiddenColumns();
                break;
              }
              case 'checkbox-select': {
                var id=arr[1], meta=obj.meta, selected=meta.selected, i;
                if ( arr[2] ) {
                  selected[id] = arr[3];
                  meta.nSelected++;
                  if ( meta.nSelected == 1 ) { _sbx.notify(obj.id,'setApplyChangesState'); } // minor optimisation!
                } else {
                  delete selected[id];
                  meta.nSelected--;
                }
                break;
              }
              case 'rowUpdated': {
                obj.changedRows++;
                if ( !obj.UIbusy ) {
                  if ( obj.changedRows ) {
                    obj.setSummary('OK',obj.changedRows+' subscription'+(obj.changedRows==1?'':'s')+' changed');
                  } else {
                    obj.setSummary('error','Nothing was changed!');
                  }
                }
                break;
              }
              case 'datatable_renderEvent': {
                obj.ctl.selectAll.set( 'disabled',false);
                obj.ctl.selectNone.set('disabled',false);
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.subscriptionsId,handler);
      },
      getSubscriptions: function() {
        var args = {collapse:'y', create_since:new Date().getTime()/1000 - 30*86400 /* 1 month */},
            i, _filter=this._filter, f, map=this.meta.map,
            datasets, blocks, data, level;
        for (i in _filter) {
          f = _filter[i];
          if ( typeof(f) == 'array' || typeof(f) == 'object' ) {
            if ( f.length ) {
              args[i] = f;
            }
          } else {
            args[i] = f;
          }
        }
        for (i in args.data_items) {
          data = args.data_items[i];
          level = NUtil.parseBlockName(data);
          if ( level == 'BLOCK' ) {
            if ( !blocks ) { blocks = []; }
            blocks.push(data);
            continue;
          }
          if ( level == 'DATASET' ) {
            if ( !datasets ) { datasets = []; }
            datasets.push(data);
            continue;
          }
          this.setSummary('error','Data-item not valid');
          return;
        }
        if ( datasets  ) { args.dataset = datasets; }
        if ( blocks    ) { args.block   = blocks; }
        if ( args.data_items ) { delete args.data_items; }
        if ( args.requests ) {
          args.request = args.requests;
          delete args.requests;
        }
        dom.messages.innerHTML = PxU.stdLoading('loading subscriptions data...');
        PHEDEX.Datasvc.Call({
                              api:'subscriptions',
                              args:args,
                              callback:function(data,context,response) { obj.gotSubscriptions(data,context,response); }
                            });
        this.setHistory(args);
      },
      gotSubscriptions:function(data,context,response) {
        var datasets=data.dataset, i, j, dataset, subscriptions, nSubs=0, summary, tmp;
        if ( response ) {
          this.setSummary('error','Error retrieving subscriptions data');
          return;
        }

        if ( !this.subscriptionsId ) {
          _sbx.delay(25,'module','*','lookingForA',{moduleClass:'subscriptions-table', callerId:this.id, callback:'gotSubscriptionsId'});
          _sbx.delay(50, this.id, 'gotSubscriptions',data,context,response);
          return;
        }
        if ( !this.subscriptionsModuleIsReady ) {
          _sbx.delay(50, this.id, 'gotSubscriptions',data,context,response);
          return;
        }
        _sbx.notify(this.subscriptionsId,'doGotData',data,context,response);
        if ( !datasets || !datasets.length ) {
          this.setSummary('error','No data found matching your query!');
          return;
        }
        this.data = data; // keep these in case the user changes the number of rows!
        this.context = context;

        for (i in datasets) {
          dataset = datasets[i];
          subscriptions = dataset.subscription;
          if ( subscriptions ) {
            nSubs += subscriptions.length;
          }
          for (j in dataset.block) {
            subscriptions = dataset.block[j].subscription;
            if ( subscriptions ) {
              nSubs += subscriptions.length;
            }
          }
        }
        tmp = context.args.create_since;
        if ( tmp ) { tmp = new Date().getTime()/1000 - tmp; }
        summary = 'Showing subscriptions created since '+PxUf.secondsToYMD(tmp) +
                  '<br />' + datasets.length+' data-item'+(datasets.length==1?'':'s')+' found, ' +
                  nSubs+' subscription'+(nSubs==1?'':'s');
        if ( nSubs >= this.meta.maxRows ) {
          summary += "<br/>"+Icon.Warn+"Table is truncated at "+this.meta.maxRows+" rows. You can "+
                     "<a href='#' onclick=\"PxS.notify('"+this.id+"','goToFilter')\">filter the data</a> " +
                     "to reduce the number of rows, or you can " +
                     "<a id='phedex-setMaxRows' href='#' onclick=\"PxS.notify('"+this.id+"','changeMaxRows')\">change the limit</a> " +
                     "to see more data";
        }
        this.setSummary('OK',summary);
      },
      initFilters: function() {
        var p=this.params, i, j, tmp, columns, col, label, label_lc, _f=this._filter;

// special case for reqfilter (map to 'requests') and filter (map to 'data_items')
        _f.requests = [];
        if ( p.reqfilter ) { p.requests = p.reqfilter; }
        if ( p.requests ) {
          tmp = p.requests.split(/(\s*,*\s+|\s*,+\s*)/);
          for ( i in tmp ) {
            if ( tmp[i].match(/^\d+$/) ) { // only accept numeric IDs.
              _f.requests.push(tmp[i]);
            } else {
// TW should post an error here
            }
          }
        }

// special case for create_since
        if ( p.create_since ) {
          _f.create_since = parseInt(p.create_since);
          tmp = new Date().getTime()/1000;
          if ( _f.create_since > tmp ) {
            this.setSummary('error','You have specified a value for "create since" that is in the future. Come back at '+PxUf.UnixEpochToUTC(_f.create_since)+'!');
            throw new Error ("User cannot tell the time");
          }
          if ( _f.create_since < 0 ) {
            _f.create_since = tmp + _f.create_since;
          }
        }

// special case for data_items
        _f.data_items = [];
        if ( p.filter ) { p.data_items = p.filter; }
        if ( p.data_items ) {
          tmp = p.data_items .split(/(\s*,*\s+|\s*,+\s*)/);
          p.data_items  = [];
          for ( i in tmp ) {
            p.data_items .push(tmp[i]);
          }
        }

// special case for columns
        columns = this.meta.showColumns;
        if ( p.col ) {
          if ( typeof(p.col) != 'object'  ) {
            p.col = [ p.col ];
          }
          for (j in columns) {
            columns[j]._default = false;
          }
          for ( i in p.col ) {
            label = p.col[i];
            label_lc = label.toLowerCase().replace(/_/g,' ');
            for (j in columns) {
              col = columns[j];
              if ( col.label == label || col.label.toLowerCase() == label_lc ) {
                col._default = true;
                continue;
              }
            }
          }
        }

        if ( p.node ) {
          if ( typeof(p.node) == 'object' ) { _f.node = p.node; }
          else { _f.node = [ p.node ]; }
        }
        if ( p.rows ) { this.meta.maxRows = p.rows; }
      },
      initSub: function() {
        var mb=dom.main_block, el, b, ctl=this.ctl, id='image-'+PxU.Sequence(), container=dom.container;
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-options-control'></div>" +
                       "<div id='phedex-data-subscriptions-options-panel' class='phedex-invisible'></div>";
        mb.appendChild(el);
        ctl.options = {
          panel:Dom.get('phedex-data-subscriptions-options-panel'),
          label_show:"<img id='"+id+"' src='"+PxW.WebAppURL+"/images/icon-wedge-green-down.png' style='vertical-align:middle'>Show options",
          label_hide:"<img id='"+id+"' src='"+PxW.WebAppURL+"/images/icon-wedge-green-up.png'   style='vertical-align:middle'>Hide options",
        };
        ctl.options.button = b = new Button({
                                          label:ctl.options.label_show,
                                          id:'phedex-options-control-button',
                                          container:'phedex-options-control' });
        this.onShowOptionsClick = function(obj) {
          return function() {
            var ctl=obj.ctl, opts=ctl.options, apply=obj.dom.apply;
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
        b.on('click',this.onShowOptionsClick);
      },

      onSelectedMenuItemChange: function(_field,action) {
        if ( !action ) { action = _field; }
        return function(event) {
          var oMenuItem = event.newValue,
              text = oMenuItem.cfg.getProperty('text'),
              value = oMenuItem.value,
              previous;
          if ( event.prevValue ) { previous = event.prevValue.value; }
          if ( value == previous ) { return; }
          this.set('label', text);
          _sbx.notify(obj.id,'menuChange_'+action,_field,text,value);
        };
      },
      makeControlTextbox: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, resize, helpStr='',
            textareaClassName = config.textareaClassName || 'phedex-nextgen-textarea';
        labelForm = labelForm.replace(/-/,'_');
        el = document.createElement('div');
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelCss+"' href='#'>[?]</a>";
        }
        el.innerHTML = "<div>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+labelCss+"'>"+label+helpStr+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-nextgen-filter-resize-"+labelCss+"'>" +
                      "<textarea id='"+labelForm+"' name='"+labelForm+"' class='"+textareaClassName+"'>" + (config.initial_text || config.text) + "</textarea>" +
                    "</div>" +
                  "</div>" +
                "</div>";
        parent.appendChild(el);
        if ( config.help_text ) {
          config.help_align = Dom.get('phedex-label-'+labelCss);
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }

        resize = config.resize || {maxWidth:745, minWidth:100};
        NUtil.makeResizable('phedex-nextgen-filter-resize-'+labelCss,labelLower,resize);

        d[labelForm] = Dom.get(labelForm);
        d[labelForm].onfocus = function() {
          if ( this.value == config.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
            PxS.notify(obj.id,'setValueFor',labelForm);
          }
        }
        d[labelForm].onblur=function() {
          if ( this.value == '' ) {
            this.value = config.text;
            Dom.setStyle(this,'color',null);
            PxS.notify(obj.id,'unsetValueFor',labelForm);
          } else {
            PxS.notify(obj.id,'setValueFor',labelForm,this.value);
          }
        }
        if ( config.initial_text ) {
          Dom.setStyle(d[labelForm],'color','black');
          PxS.notify(this.id,'setValueFor',labelForm,config.initial_text);
        }
      },
      buildOptionsTabview: function() {
        var ctl=this.ctl, mb=dom.main_block, form, el, elBlur, menu, button, _default, _filter=this._filter,
            opts=ctl.options, tab, tabView, SelectAll, DeselectAll, Reset, Apply, apply=dom.apply;
        if ( opts.tabview ) { return; }
        form = document.createElement('form');
        form.id   = 'data-subscriptions-filter';
        form.name = 'data-subscriptions-filter';
        form.method = 'get';
        this.data_subscriptions_filter = form;
        opts.panel.appendChild(form);
        tabView = opts.tabView = new Yw.TabView();
        tab = new Yw.Tab({
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

        tab = new Yw.Tab({
          label: 'Select Data',
          content:
                "<div id='phedex-filterpanel-container' class='phedex-nextgen-filterpanel'>" +
                  "<div id='phedex-filterlabel' class='phedex-nextgen-label float-left'>" +
                  "</div>" +
                  "<div id='phedex-filterpanel' /*class='phedex-nextgen-control'*/>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-nodes'>" +
                      "<div class='phedex-nextgen-label' id='phedex-label-node'>"+
                        "<div class='phedex-vertical-buttons' id='phedex-selectall-nodes'></div>" +
                        "<div class='phedex-vertical-buttons' id='phedex-deselectall-nodes'></div>" +
                      "</div>" +
                      "<div id='phedex-data-subscriptions-nodepanel-wrapper'>" +
                        "<div class='phedex-nextgen-nodepanel' id='phedex-nodepanel'>" +
                          "<em>loading node list...</em>" +
                        "</div>" +
                      "</div>" +
                    "</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-requests'></div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-dataitems'></div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-custodial'>custodiality</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-group'>group</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-active'>active/suspended</div>" +
                    "<div class='phedex-clear-both' id='phedex-filterpanel-priority'>priority</div>" +
                    "<div id='phedex-filterpanel-completion'>completion</div>" +
                    "<div id='phedex-filterpanel-create-since'>created since</div>" +
                  "</div>" +
                "</div>" +
                "<div id='phedex-data-subscriptions-apply-filters'>" +
                "</div>"
        });
        tabView.addTab(tab);
        Apply = new Button({ label:'Apply', id:'apply', container:'phedex-data-subscriptions-apply-filters' });
        Apply.on('click', function(obj) { return function() { _sbx.notify(obj.id,'getSubscriptions'); } }(this) );

        tabView.appendTo(form); // need to attach elements to DOM before further manipulation

// for the Filter tab
        var field, Field;
// Requests
        this.request_ids = {
          text:'List of request-IDs, separated by white-space or commas.',
          label:'Requests',
          textareaClassName:'phedex-nextgen-text'
        };
        if ( _filter.requests.length ) { this.request_ids.initial_text = _filter.requests.join(' '); }
        this.makeControlTextbox(this.request_ids,Dom.get('phedex-filterpanel-requests'));

// Data items
        this.data_items = {
          text:'enter one or more block/data-set names, separated by white-space or commas.',
          label:'Data Items'
        };
        if ( _filter.data_items.length ) { this.data_items.initial_text = _filter.data_items.join(' '); }
        this.makeControlTextbox(this.data_items,Dom.get('phedex-filterpanel-dataitems'));

// Priority...
        menu = [
          { text: 'any',    value: 'any' },
          { text: 'low',    value: 'low' },
          { text: 'normal', value: 'normal' },
          { text: 'high',   value: 'high' }
        ];
        switch (_filter.priority) {
          case 'high':   { _default = 'high';   break; }
          case 'normal': { _default = 'normal'; break; }
          case 'low':    { _default = 'low';    break; }
          default:       { _default = 'any';    break; }
        }
        this.filterButton('phedex-filterpanel-priority',menu,_default);

// Active/Suspended...
        menu = [
          { text: 'any',       value: 'any' },
          { text: 'active',    value: 'active' },
          { text: 'suspended', value: 'suspended' }
        ];
        switch (_filter.suspended) {
          case 'y':
          case 'suspended': { _default = 'suspended'; break; }
          case 'n':
          case 'active':    { _default = 'active';    break; }
          default:          { _default = 'any';       break; }
        }
        this.filterButton('phedex-filterpanel-active',menu,_default);

// Custodial - dropdown (inc 'any')
        menu = [
          { text: 'any',           value: 'any' },
          { text: 'custodial',     value: 'custodial' },
          { text: 'non-custodial', value: 'non-custodial' }
        ];
        switch (_filter.custodial) {
          case 'y':
          case 'custodial':     { _default = 'custodial';     break; }
          case 'n':
          case 'non-custodial': { _default = 'non-custodial'; break; }
          default:              { _default = 'any';           break; }
        }
        this.filterButton('phedex-filterpanel-custodial',menu,_default);

// Group - dropdown (inc 'any')
        el = Dom.get('phedex-filterpanel-group');
        field=el.innerHTML; Field=PxU.initialCaps(field);
        el.innerHTML = "<div>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                        "<div class='phedex-nextgen-filter'>" +
                          "<div id='phedex-filterpanel-ctl-"+field+"'>" +
                            "<em>loading group list...</em>" +
                          "</div>" +
                        "</div>" +
                      "</div>";

// Completion - dropdown (inc 'any')
        menu = [
          { text: 'any',        value: 'any' },
          { text: 'complete',   value: 'complete' },
          { text: 'incomplete', value: 'incomplete' }
        ];
        switch (_filter.complete) {
          case 'y':
          case 'complete':   { _default = 'complete';   break; }
          case 'n':
          case 'incomplete': { _default = 'incomplete'; break; }
          default:           { _default = 'any';        break; }
        }
        this.filterButton('phedex-filterpanel-completion',menu,_default);

// Created-since - dropdown
        var m=this.meta.map.create_since, i;
        menu=[];
        for (i in m) {
          menu.push({text:i, value:m[i]});
        }
        this.filterButton('phedex-filterpanel-create-since',menu);

// for the Node tab...
        this.nodePanel = NUtil.NodePanel( this, Dom.get('phedex-nodepanel'), _filter.node );
        NUtil.makeResizable('phedex-data-subscriptions-nodepanel-wrapper','phedex-nodepanel',{maxWidth:1000, minWidth:100});

// for the Columns tab...
        this.columnPanel = NUtil.CBoxPanel( this, Dom.get('phedex-columnpanel'), { items:this.meta.showColumns, name:'columns' } );
      },
      filterButton: function(el,menu,_default) {
        var id=PxU.Sequence(), field, Field, i, index;
        if ( _default ) {
          for (i in menu) {
            if ( menu[i].text == _default ) {
              index = i;
              break;
            }
          }
        } else {
          _default = menu[0].text;
          index=0;
        }
        if ( typeof(el) == 'string' ) { el = Dom.get(el); }
        field=el.innerHTML; Field=PxU.initialCaps(field);
        el.innerHTML = "<div>" +
                         "<div class='phedex-nextgen-label' id='phedex-label-"+field+"'>"+Field+":</div>" +
                         "<div class='phedex-nextgen-filter'>" +
                           "<div id='phedex-filterpanel-ctl-"+field+"'></div>" +
                         "</div>" +
                       "</div>";
        button = new Button({
          id:          'menubutton-'+id,
          name:        'menubutton-'+id,
          label:        _default,
          type:        'menu',
          lazyloadmenu: false,
          menu:         menu,
          container:    'phedex-filterpanel-ctl-'+field
        });
        button.on('selectedMenuItemChange', this.onSelectedMenuItemChange(field,'filter'));
        this._default[field] = function(_button,_index) {
          return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(_index||index)); };
        }(button,0);
      },
      makeGroupMenu: function(el,menu,_default) {
        var groups=this.groups, menu, button, i, id=PxU.Sequence();
        if ( typeof(el) == 'string' ) { el = Dom.get(el); }
        if ( !groups ) {
          el.innerHTML = '&nbsp;<strong>Error</strong> loading group names, cannot continue';
          Dom.addClass(el,'phedex-box-red');
          _sbx.notify(this.id,'abort');
          return;
        }
        el.innerHTML='';
        if ( !menu ) { menu = []; }
        for (i in groups ) {
          group = groups[i];
          if ( !group.name.match(/^deprecated-/) ) {
            menu.push( { text:group.name, value:group.id } );
          }
        }
        if ( !_default ) { _default = menu[0].text; }
        button = new Button({
          id:          'menubutton-'+id,
          name:        'menubutton-'+id,
          label:       _default,
          type:        'menu',
          lazyloadmenu: false,
          menu:         menu,
          container:    el
        });
        button.getMenu().cfg.setProperty('scrollincrement',5);
        return button;
      },
      gotGroupMenu: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
// I have two group menus on this form, one in the filter-panel, one in the update-subscription form
        var button, field;
// use 'obj', not 'this', because I am the datasvc callback. Scope is different...
        obj.groups = data.group;
        field = 'phedex-filterpanel-ctl-group';
        button = obj.makeGroupMenu(field, [{ text:'any', value:0 }], obj._filter.group );
        button.on('selectedMenuItemChange', obj.onSelectedMenuItemChange('group','filter'));
        obj._default['group'] = function(_button,index) {
          return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
        }(button,0);

        field = 'phedex-data-subscriptions-ctl-group';
        button = obj.makeGroupMenu(field,[], 'Choose a group');
        button.on('selectedMenuItemChange', obj.onSelectedMenuItemChange('group'));
        button.set('disabled',true);
        obj.ctl.group = button;
      }
    }
  }
  Yla(this,_construct(this),true);
  return this;
}

log('loaded...','info','nextgen-data-subscriptions');
