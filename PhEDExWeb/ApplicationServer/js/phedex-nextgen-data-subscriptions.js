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
      _filter: {
        node:[],
        request:[],
        data_items:[],
        create_since_orig:Math.floor(new Date().getTime()/1000) - 30*86400 /* 1 month */
      },
      meta: {
        showColumns:
        [
          { label:'Request',      _default: true },
          { label:'Data Level',   _default: true },
          { label:'Data Item',    _default: true },
          { label:'Node',         _default: true },
          { label:'Priority',     _default: true },
          { label:'Custodial',    _default: true },
          { label:'Group',        _default: true },
          { label:'Node Files',   _default: true },
          { label:'Node Bytes',   _default: true },
          { label:'% Files',      _default:false },
          { label:'% Bytes',      _default: true },
          { label:'Replica/Move', _default: true },
          { label:'Suspended',    _default: true },
          { label:'Open',         _default:false },
          { label:'Time Create',  _default: true },
          { label:'Time Done',    _default:false }
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
            'replica/move':     'move',
             priority:          'priority',
             group:             'group'
          },
          values:
          {
            custodial:{custodial:'y', 'non-custodial':'n'},
            suspended:{suspended:'y', active:'n'},
            move:{move:'y', replica:'n'},
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
            'priority':['priorityhi', 'priorityno', 'prioritylo', 'groupchange'],
            'delete':['deletedata']
          }
        },
        maxRowsDefault:500
      },
      useElement: function(el) {
        var form;
        dom.target = el;
        dom.container  = document.createElement('div'); dom.container.className  = 'phedex-nextgen-container'; dom.container.id = 'doc3';
        dom.hd         = document.createElement('div'); dom.hd.className         = 'phedex-nextgen-hd';        dom.hd.id = 'hd';
        dom.bd         = document.createElement('div'); dom.bd.className         = 'phedex-nextgen-bd';        dom.bd.id = 'bd';
        dom.ft         = document.createElement('div'); dom.ft.className         = 'phedex-nextgen-ft';        dom.ft.id = 'ft';
        dom.main       = document.createElement('div'); dom.main.className       = 'yui-main';
        dom.main_block = document.createElement('div'); dom.main_block.className = 'yui-b phedex-nextgen-main-block';
        dom.selector   = document.createElement('div'); dom.selector.id          = 'phedex-data-subscriptions-selector';
        dom.dataform   = document.createElement('div'); dom.dataform.id          = 'phedex-data-subscriptions-dataform';
        dom.errors     = document.createElement('div'); dom.errors.id            = 'phedex-data-subscriptions-errors';
        dom.errors.className = 'phedex-invisible';
        dom.messages   = document.createElement('div'); dom.messages.id          = 'phedex-data-subscriptions-messages';
        dom.messages.style.padding = '5px';
        dom.datatable  = document.createElement('div'); dom.datatable.id         = 'phedex-data-subscriptions-datatable';
        form = document.createElement('form');
        form.id   = 'data-subscriptions-action';
        form.name = 'data-subscriptions-action';
        form.method = 'post';
        form.action = location.pathname;
        this.data_subscriptions_action = form;

        dom.bd.appendChild(dom.main);
        dom.main.appendChild(dom.main_block);
        dom.container.appendChild(dom.hd);
        dom.container.appendChild(dom.bd);
        dom.container.appendChild(dom.ft);
        dom.container.appendChild(dom.selector);
        dom.container.appendChild(dom.dataform);
        dom.dataform.appendChild(form);
        dom.dataform.appendChild(dom.errors);
        dom.dataform.appendChild(dom.messages);
        dom.dataform.appendChild(dom.datatable);
        el.innerHTML = '';
        el.appendChild(dom.container);

        dom.floating_help = document.createElement('div'); dom.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible'; dom.floating_help.id = 'phedex-help-'+PxU.Sequence();
        document.body.appendChild(dom.floating_help);
      },
      gotAuthData: function(data,context,response) {
// use 'obj', not 'this', because I am a datasvc callback. Scope is different...
        if ( response ) {
          obj.setError('Could not get your authentication information, continuing without it. Some features may not be available');
          return;
        }
        if ( !data.auth ) { return; }
        var auth, roles, role, i;

        obj.auth = auth = data.auth[0];
        if ( typeof(auth) != 'object' ) { auth = {}; } // AUTH call failed, proceed regardless...
        auth.isAdmin = false;
        auth.can = [];
        roles = auth.role;
        for ( i in roles ) {
          role = roles[i];
          role.name  = role.name.toLowerCase();
          role.group = role.group.toLowerCase();
        }
        for ( i in roles ) {
          role = roles[i];
          if ( ( role.name == 'admin' && role.group == 'phedex' ) ||
               ( role.name == 'data manager' ) ||
               ( role.name == 'site admin'   ) ) {
            auth.can.push('suspend');
            auth.isAdmin = true;
            break;
          }
        }
        for ( i in roles ) {
          role = roles[i];
          if ( ( role.name == 'admin' && role.group == 'phedex' ) ||
               ( role.name == 'data manager' ) ) {
            auth.can.push('priority');
            auth.can.push('delete');
            break;
          }
        }
        if ( auth.isAdmin ) { _sbx.notify(obj.id,'isAdmin'); }
        else                { _sbx.notify(obj.id,'isNotAdmin'); }
      },
      isNotAdmin: function() {
//      User has no administrative rights. Add a link explaining why.
        var el = document.createElement('a'),
            auth = obj.auth,
            container = Dom.get('phedex-options-control'), //dom.container,
            toggle, id=PxU.Sequence();
        el.id = 'phedex-help-anchor-'+id;
        el.href = '#';
        el.style.paddingLeft = '1em';
        el.innerHTML = "Why can't I modify subscriptions?"; //Privileged Activities Help';
        container.appendChild(el);
        toggle = "var s = new PHEDEX.Sandbox(); s.notify('"+obj.id+"','Help','privilegedActivity');";
        obj.privilegedActivity = {
            text: "<a id='close-anchor-"+id+"' class='float-right' href='#'>[close]</a>" +
                  "<p><strong>Privileged Activities:</strong></p>" +
                  NUtil.authHelpMessage(
                    { to:'change priorities of subscriptions and manage groups', need:'cert', role:['Data Manager', 'Admin'] },
                    { to:'suspend/unsuspend subscriptions',                      need:'any',  role:['Data Manager', 'Site Admin', 'Admin'] }
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
        if ( ! admin_menu.length ) { return; }
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
          i = elUpdate.length;
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
                         "<span id='phedex-data-subscriptions-ctl-refresh' style='margin-left:400px'></span>" +
                       "</div>";
        form.appendChild(el);
        if ( obj.groups ) { // if I already have the groups, just build the menu...
          obj.gotGroupMenu({group:obj.groups});
        } else { // ...otherwise, get the groups, then do it
          PHEDEX.Datasvc.Call({ api:'groups', callback:this.gotGroupMenu });
        }
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

        button = new Button({ label:'Refresh data', id:'phedex-data-subscriptions-refresh', container:'phedex-data-subscriptions-ctl-refresh' });
        button.set('disabled',true);
        this.ctl.refresh = button;
        this.enableRefresh = function() { this.ctl.refresh.set('disabled',false); }
        button.on('click', function(obj) {
          return function() {
            _sbx.notify(obj.id,'getSubscriptions');
            obj.ctl.refresh.set('disabled',true);
          }
        }(this) );
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
            if ( action == 'deletedata' ) {
//            create a hidden form and submit it
              obj.setSummary('OK','Redirecting you to the checkout, please get your credit card ready');
              var form = Dom.get('phedex-deletion-shopping-cart');
              if ( form ) {
                form.innerHTML = '';
              } else {
                form = document.createElement('form');
                form.id = 'phedex-deletion-shopping-cart';
                form.action = PxW.WebURL+PHEDEX.Datasvc.Instance().instance+'/Data::BulkDelete';
                form.method = 'post';
                document.body.appendChild(form);
              }
              for (i in selected) {
                item = selected[i];
                form.innerHTML += "<input type='hidden' name='dataspec' value='"+item.node+":"+item.level+":"+item.item+"'>";
              }
              form.submit();
              return;
            }
            switch (action) {
              case 'groupchange': { args.group = obj.update.group;   break; }
              case 'suspend':     { args.suspend_until = 9999999999; break; }
              case 'unsuspend':   { args.suspend_until = 0;          break; }
              case 'prioritylo':  { args.priority = 'low';           break; }
              case 'priorityno':  { args.priority = 'normal';        break; }
              case 'priorityhi':  { args.priority = 'high';          break; }
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
        button = this.ctl.applyChanges;
        if ( !button ) {
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
            sum, msg, row, now, etc, why;
        this.queued--;
        _sbx.notify(this.id,'dispatchUpdate');
        if ( response ) {
          nResponse.fail++;
          why = response.responseText;
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
          _sbx.notify(obj.id,'setUIIdle',why);
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
      setError: function(text) {
        var el = dom.errors,
            initialText = el.innerHTML,
            now = new Date().getTime()/1000,
            timeout = 15;
        if ( initialText ) { text = initialText + '<br>' + text; }
        el.innerHTML = text;
        el.style.padding = '5px';
        Dom.addClass(el,'phedex-box-red');
        Dom.removeClass(el,'phedex-invisible');
        this.errorTimer = now;
        setTimeout( function(obj) {
          return function() {
            var el = dom.errors, anim,
                now = new Date().getTime()/1000;
            el.style.overflowY = 'hidden';
            anim = new YAHOO.util.Anim(el, {height:{to:0}, padding:{to:0}}, 1);
            anim.onComplete.subscribe( function() {
              el.innerHTML='';
              el.style.height='';
              Dom.addClass(el,'phedex-invisible');
            });
            anim.animate();
          }
        }(this), timeout * 1000);
      },
      setValueFor: function(label,value) {
        value = value.replace(/\n/g,' ');
        value = value.replace(/\s\s+/g,' ');
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
        if ( !params ) { params={}; }
        this.params = params;
        this.meta.maxRows = this.meta.maxRowsDefault;
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action=arr[0], i, el, value, field, _filter, filterMap, _filterField, ctl=obj.ctl;
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
                if ( !obj.update ) { obj.update = {}; }
                if ( arr[3] == 'groupchange' ) {
                  ctl.group.set('disabled',false);
                } else {
                  ctl.group.set('disabled',true);
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
                    _filter.create_since = Math.floor(new Date().getTime()/1000) - filterMap.values[arr[1]][arr[2]]*86400*30;
                  } else {
                    _filter.create_since = 0;
                  }
                  _filter.create_since_orig = _filter.create_since;
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
                var columns = obj.meta.showColumns, column=columns[arr[1]];
                column.show = arr[2];
                _sbx.notify(obj.subscriptionsId,'setColumnVisibility',[column]);
                obj.setHistory();
                break;
              }
              case 'DoneSelectAll-columns':   // deliberate fall-through
              case 'DoneDeselectAll-columns': // deliberate fall-through
              case 'DoneReset-columns': {
                obj.setHiddenColumns();
                obj.setHistory();
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
                  var msg = 'Nothing was changed.';
                  if ( arr[1] ) {
                    msg += ' (reason: ' + arr[1].replace(/\\n/,'') + ')';
                  }
                  obj.setSummary('error',msg);
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
                  ctl.applyChanges.set('disabled',false);
                } else {
                  ctl.applyChanges.set('disabled',true);
                }
                break;
              }
              case 'goToFilter': {
                obj.onShowOptionsClick();
                ctl.options.tabView.selectTab(1);
                break;
              }
              case 'changeMaxRows': {
                var el = dom.setMaxRowsPopup,
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
                  dom.setMaxRowsPopup = Dom.get('phedex-setMaxRows-popup');
                  Event.addListener('close-anchor-'+id,'click',function(ev) {
                    Event.preventDefault(ev);
                    Dom.addClass(dom.setMaxRowsPopup,'phedex-invisible');
                  });
                  button = new YAHOO.widget.Button({
                                 label: 'Apply',
                                 id: 'apply-setMaxRows',
                                 container: 'phedex-setMaxRows-apply' });
                  button.on('click',function() {
                    _sbx.notify(obj.id,'maxRowsChanged',Dom.get('phedex-setMaxRows-input').value);
                    Dom.addClass(dom.setMaxRowsPopup,'phedex-invisible');
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
                obj.setHistory();
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
        this.initSub();
        this.initHistory();
        PHEDEX.Datasvc.Call({ api:'groups', callback:this.gotGroupMenu });
        PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })

        _sbx.notify('SetModuleConfig','subscriptions-table',
                        { parent:dom.datatable,
                          autoDestruct:false,
                          noDecorators:true,
                          noExtraDecorators:true,
                          noHeader:true,
                          meta:{maxRows:this.meta.maxRows}
                        });
        _sbx.notify('CreateModule','subscriptions-table',{notify:{who:this.id, what:'gotSubscriptionsId'}});
//         _sbx.notify(this.id,'buildOptionsTabview');
      },
      initHistory: function() {
// set up the History management
        var handler = function(ev,arr) {
          switch (arr[0]) {
            case 'stateChange': {
              if ( obj.href == arr[2] ) { return; }
              obj.href = arr[2];
              if ( obj.setState(arr[1]) ) {
                obj.getSubscriptions();
              }
              break;
            }
            case 'initialiseApplication': {
              obj.setState(arr[1]);
              obj.buildOptionsTabview();
              obj.getSubscriptions();
              break;
            }
            case 'navigatedTo': { // bookkeeping, to suppress double-calls
              obj.href = arr[1];
              _sbx.notify('History','permalink',arr[1]);
              break;
            }
            default: {
              break;
            }
          }
        };
        _sbx.listen('History',handler);
        new PHEDEX.History({ el:'phedex-permalink', container:'phedex-permalink-container' });
      },
      setHistory: function(args) {
        var state={}, i, showMe, allDefault=true, label, column, columns=this.meta.showColumns;
        if ( args ) {
          for ( i in args ) { state[i] = args[i]; }
        } else {
          state = this.getArgs();
        }
        if ( state.dataset ) {
          state.filter = state.dataset.join(' ');
          delete state.dataset;
        }
        if ( state.block ) {
          if ( !state.filter ) { state.filter = ''; }
          state.filter = state.block.join(' ');
          delete state.block;
        }
        delete state.collapse;          // no need to show this in the state
        if ( this.meta.maxRows != this.meta.maxRowsDefault ) {
          state.rows = this.meta.maxRows;
          if ( obj.subscriptionsId ) {
            _sbx.notify(obj.subscriptionsId,'setMaxRows',obj.meta.maxRows);
          }
        }
        state.col = [];
        for (label in columns) {
          if ( label == 'Select' ) { continue; } // not needed in the state fragment
          column = columns[label];
          showMe = false;
          if ( typeof(column.show) != 'undefined' ) {
            showMe = column.show;
            if ( showMe != column._default ) { allDefault = false; }
          } else {
            showMe = column._default;
          }
          if ( showMe ) {
            label = label.replace(/%/g,'pct_');
            state.col.push(label);
          }
        }
        if ( !state.col.length ) { // nothing to show, need special sentinel
          state.col.push('none');
        }
        if ( allDefault ) { delete state.col; }
        _sbx.notify('History','navigate',state);
      },
      setHiddenColumns: function() {
        var el, elList=this.columnPanel.elList, label, i, column, columns=this.meta.showColumns, auth;
        for ( i in elList ) {
          el = elList[i];
          column = columns[el.name];
          column.show = el.checked;
        }
        if ( !columns.Select ) {
          auth = false;
          if ( this.auth ) { auth = this.auth.isAdmin; }
          columns.Select = {label:'Select', _default:auth, show:auth};
        }
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
        _sbx.notify(obj.subscriptionsId,'setMaxRows',this.meta.maxRows);
      },
      getArgs: function() {
        var args = {collapse:'y'},
            i, _f=this._filter, f, map=this.meta.map,
            datasets, blocks, data, level;
        for (i in _f) {
          f = _f[i];
          if ( typeof(f) == 'array' || typeof(f) == 'object' ) {
            if ( f.length ) {
              args[i] = f;
            }
          } else {
            args[i] = f;
          }
        }
        args.create_since = _f.create_since_orig;
        delete args.create_since_orig;
        if ( args.request ) { args.create_since=0; }
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
          this.setSummary('error','Data-item not valid (does not match /A/B/C, where A, B and C must all be given, even if they are wildcards)');
          return;
        }
        if ( datasets  ) { args.dataset = datasets; }
        if ( blocks    ) { args.block   = blocks; }
        if ( args.data_items ) { delete args.data_items; }
        return args;
      },
      getSubscriptions: function() {
        var args = this.getArgs(),
            _f = this._filter;
        if ( !args ) { return; }
        if ( _f.create_since < 0 ) { args.create_since = Math.floor(new Date().getTime()/1000) + _f.create_since; }
        dom.messages.innerHTML = PxU.stdLoading('loading subscriptions data...');
        PHEDEX.Datasvc.Call({
                              api:'subscriptions',
                              args:args,
                              callback:function(data,context,response) { obj.gotSubscriptions(data,context,response); }
                            });
        args.create_since = _f.create_since_orig;
        this.setHistory(args);

//      delete the previous row-selection, if any...
        this.meta.nSelected = 0;
        this.meta.selected  = [];
      },
      gotSubscriptions:function(data,context,response) {
        var datasets=data.dataset, i, j, dataset, subscriptions, nSubs=0, summary, since;
        _sbx.delay(10000,this.id,'enableRefresh');
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
        since = context.args.create_since*1;
        if ( since ) {
          since = new Date().getTime()/1000 - since;
          since = PxUf.secondsToYMD(since);
        } else {
          since = 'forever';
        }
        _sbx.notify(this.subscriptionsId,'doGotData',data,context,response);
        _sbx.notify(this.subscriptionsId,'doPostGotData');
        if ( !datasets || !datasets.length ) {
          this.setSummary('error','No data found matching your query!' +
              ( since == 'forever' ? '' : ' (Hint: showing data created since '+since+')' ) );
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
        summary = 'Showing subscriptions created since '+ since +
                  '<br />' + datasets.length+' dataset'+(datasets.length==1?'':'s')+' found, ' +
                  nSubs+' subscription'+(nSubs==1?'':'s');
        if ( nSubs >= this.meta.maxRows ) {
          summary += "<br/>"+Icon.Warn+"Table is truncated at "+this.meta.maxRows+" rows. You can "+
                     "<a id='phedex-goToFilter'href='#'>filter the data</a> " +
                     "to reduce the number of rows, or you can " +
                     "<a id='phedex-setMaxRows' href='#'>change the limit</a> " +
                     "to see more data";
        }
        this.setSummary('OK',summary);
        if ( nSubs >= this.meta.maxRows ) { // need to do this after setSummary, so the DOM is correct!
          Event.addListener('phedex-setMaxRows','click',function(ev) {
            Event.preventDefault(ev);
            _sbx.notify(obj.id,'changeMaxRows');
          });
          Event.addListener('phedex-goToFilter','click',function(ev) {
            Event.preventDefault(ev);
            _sbx.notify(obj.id,'goToFilter');
          });
        }
      },
      setState: function(state) {
        var i, j, label, tmp, columns, col, columnsOrig={}, columnsChanged=false, _f=this._filter, changed=false, tmp, now, scale, c_s;
        if ( state.custodial   ) { _f.custodial    = state.custodial; }
        if ( state.group       ) { _f.group        = state.group; }
        if ( state.suspended   ) { _f.suspended    = state.suspended; }
        if ( state.move        ) { _f.move         = state.move; }
        if ( state.priority    ) { _f.priority     = state.priority; }
        if ( state.percent_min ) { _f.percent_min  = state.percent_min; }
        if ( state.percent_max ) { _f.percent_max  = state.percent_max; }

//      special case for reqfilter (map to 'requests')
        _f.request = [];
        if ( state.reqfilter ) { state.request = state.reqfilter; delete state.reqfilter; }
        if ( state.request ) {
          if ( Ylang.isArray(state.request) ) {
            tmp = state.request;
          } else {
            tmp = state.request.split(/(\s*,*\s+|\s*,+\s*)/);
          }
          for ( i in tmp ) {
            if ( tmp[i].match(/^\d+$/) ) { // only accept numeric IDs.
              _f.request.push(tmp[i]);
            } else {
// TW should post an error here
              this.setSummary('error','non-numeric request-IDs in URL, aborting');
              return false;
            }
          }
          changed = true;
        }

//      special case for create_since. Handle negative dates too
        c_s = state.create_since;
        if ( typeof(c_s) != 'undefined' && c_s != _f.create_since ) {
          scale = c_s.match(/[dDmMyY]$/);
          if ( scale ) {
            scale = scale[0].toLowerCase();
            c_s = c_s.replace(/[dDmMyY]$/,'');
            if ( scale == 'd' ) { scale = 86400; }
            if ( scale == 'm' ) { scale = 86400 * 30; }
            if ( scale == 'y' ) { scale = 86400 * 365; }
          }
          tmp = parseInt(c_s);
          if ( scale ) { tmp *= scale; }
          now = Math.floor(new Date().getTime()/1000);
          if ( tmp > now ) {
            this.setSummary('error','You have specified a value for "create since" that is in the future. Come back at '+PxUf.UnixEpochToUTC(tmp)+'!');
            throw new Error ("User cannot tell the time");
          }
          _f.create_since = tmp;
          _f.create_since_orig = state.create_since;
          changed = true;
        }

//      special case for data_items
        _f.data_items = [];
        if ( state.filter ) { state.data_items = state.filter; delete state.filter; }
        if ( state.data_items ) {
          tmp = state.data_items.replace(/,/g,' ');
          tmp = tmp.replace(/ +/g,' ');
          tmp = tmp.split(/ /)
          state.data_items  = [];
          for ( i in tmp ) {
            state.data_items.push(tmp[i]);
               _f.data_items.push(tmp[i]);
          }
          changed = true;
        }

//      special case for columns
        columns = this.meta.showColumns;
        for ( label in columns ) {
          columnsOrig[label] = columns[label].show;
        }
        if ( state.col ) {
          if ( typeof(state.col) != 'object'  ) {
            state.col = [ state.col ];
          }
          delete state.col.none;
          for (label in columns) {
            columns[label].show = false;
          }
          for ( i in state.col ) {
            j = state.col[i].toLowerCase()
                            .replace(/_/g,' ')
                            .replace(/pct_/g,'%');
            for (label in columns) {
              if ( label == 'Select' ) { continue; } // not needed in the state fragment
              col = columns[label];
              if ( j == col.label.toLowerCase() ) {
                col.show = true;
                continue;
              }
            }
          }
        } else {
          for (label in columns) {
            columns[label].show = columns[label]._default;
          }
        }
//      Now notify change in shown columns only if there is one!
        for (label in columns) {
          if ( columns[label].show != columnsOrig[label] ) { columnsChanged=true; break; }
        }
        if ( columnsChanged ) {
          for (label in columns) {
            _sbx.notify(obj.id,'CBox-set-columns',label,columns[label].show);
          }
          _sbx.notify(this.subscriptionsId,'setColumnVisibility',columns);
        }

//      special case for nodes
        if ( state.node ) {
          if ( typeof(state.node) == 'object' ) { _f.node = state.node; }
          else { _f.node = [ state.node ]; }
        }
        return changed;
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
          }
        }(this);
        b.on('click',this.onShowOptionsClick);
        b.set('disabled',true);
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
            filterTag  = config.filterTag || labelForm,
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
          }
        }
        d[labelForm].onblur=function() {
          var tmp = this.value;
          if ( tmp.match(/^\s*$/) ) {
            this.value = config.text;
            Dom.setStyle(this,'color',null);
            PxS.notify(obj.id,'unsetValueFor',filterTag);
          } else {
            tmp = tmp.replace(/^\s+/,'');
            tmp = tmp.replace(/\s+$/,'');
            tmp = tmp.replace(/,/g,'');
            tmp = tmp.replace(/\s\s+/g,' ');
            this.value = tmp;
            PxS.notify(obj.id,'setValueFor',filterTag,tmp);
          }
        }
        if ( config.initial_text ) {
          Dom.setStyle(d[labelForm],'color','black');
          PxS.notify(this.id,'setValueFor',filterTag,config.initial_text);
        }
      },
      buildOptionsTabview: function() {
        var ctl=this.ctl, opts=ctl.options, mb=dom.main_block, form, el, elBlur, menu, button, _default, _filter=this._filter,
            tab, tabView, SelectAll, DeselectAll, Reset, Apply, apply=dom.apply, columns=this.meta.showColumns, label, i, tmp;
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
                    "<div class='phedex-clear-both' id='phedex-filterpanel-move'>replica/move</div>" +
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
          filterTag:'request',
          textareaClassName:'phedex-nextgen-text'
        };
        if ( _filter.request.length ) { this.request_ids.initial_text = _filter.request.join(' '); }
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

// Move/Replica...
        menu = [
          { text: 'any',     value: 'any' },
          { text: 'move',    value: 'move' },
          { text: 'replica', value: 'replica' }
        ];
        switch (_filter.move) {
          case 'y':
          case 'move':    { _default = 'move';    break; }
          case 'n':
          case 'replica': { _default = 'replica'; break; }
          default:        { _default = 'any';     break; }
        }
        this.filterButton('phedex-filterpanel-move',menu,_default);

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
        for ( i in columns ) {
          columns[i].show = columns[i]._default;
        }
        this.columnPanel = NUtil.CBoxPanel( this, Dom.get('phedex-columnpanel'), { items:this.meta.showColumns, name:'columns' } );
        tmp={};
        for (i in columns) {
          tmp[columns[i].label] = columns[i];
        }
        this.meta.showColumns = tmp;
        ctl.options.button.set('disabled',false);
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
      makeGroupMenu: function(el,menu,_default,allowDeprecated) {
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
          if ( allowDeprecated || !group.name.match(/^deprecated-/) ) {
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
// use 'obj', not 'this', because I am a datasvc callback. Scope is different...
        var button, field;
        if ( response ) {
          obj.setError('Could not get group information. Reload the page if you need it');
          return;
        }

// I have two group menus on this form, one in the filter-panel, one in the update-subscription form
// check if they exist before building them, because I may call this function twice. If the 'groups'
// API returns data before the 'auth' API does, I need to (re-) build the group menu for the admin
// options, which means coming here again.
        obj.groups = data.group;
        var button, field;
        if ( !obj._default.group ) {
          field = 'phedex-filterpanel-ctl-group';
          button = obj.makeGroupMenu(field, [{ text:'any', value:0 }], obj._filter.group, true );
          button.on('selectedMenuItemChange', obj.onSelectedMenuItemChange('group','filter'));
          obj._default.group = function(_button,index) {
            return function() { _button.set('selectedMenuItem',_button.getMenu().getItem(index||0)); };
          }(button,0);
        }

        if ( !obj.ctl.group ) {
//       'auth' API not yet returned, or user not authorised to manipulate subscriptions
          field = Dom.get('phedex-data-subscriptions-ctl-group');
          if ( field ) {
            button = obj.makeGroupMenu(field,[], 'Choose a group');
            button.on('selectedMenuItemChange', obj.onSelectedMenuItemChange('group'));
            button.set('disabled',true);
            obj.ctl.group = button;
          }
        }
      }
    }
  }
  Yla(this,_construct(this),true);
  PxU.protectMe(this);
  return this;
}

log('loaded...','info','nextgen-data-subscriptions');
