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
      },
      init: function(args) {
        var type = args.type, el;
        if ( type == 'xfer' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Xfer(_sbx,args));
        } else if ( type == 'delete' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Delete(_sbx,args));
        } else if ( !type ) {
        } else {
          throw new Error('type is defined but unknown: '+type);
        }
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
        var ft=this.dom.ft, Reset, Validate, Cancel, Accept;
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
        label='Accept', id='button'+label;
        Accept = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
        var onAcceptSubmit = function(obj) {
          return function(id,action) {
debugger;
          }
        }(this);
        Accept.on('click', onAcceptSubmit);
        var onResetSubmit = function(obj) {
          return function(id,action) {
            var dbs=obj.dbs,
                dom=obj.dom,
                data_items=dom.data_items,
                menu, menu_items;

try {
// Data Items
            data_items.value = '';
            data_items.onblur();

debugger;
// DBS
            dbs.value.innerHTML = dbs.default;
            menu       = dbs.MenuButton.getMenu();
            menu_items = menu.getItems();
            menu.activeItem = menu_items[dbs.defaultId];
//            menu.select(dbs.defaultId);

// Destination
// Site Custodial
// Subscription Type
// Transfer Type
// Priority
// User Group
// Start Time
// Email
// Comments
            dom.comments.value = '';
            dom.comments.onblur();
} catch(ex) {
var a = ex;
debugger;
}
          }
        }(this);
        Reset.on('click', onResetSubmit);
      }
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
          form, el, label, control;
      hd.innerHTML = 'Subscribe data';

      form = document.createElement('form');
      form.id   = 'subscribe_data';
      form.name = 'subscribe_data';
      mb.appendChild(form);

// Subscription level
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Subscription Level</div>" +
                        "<div id='subscription_level' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='subscription_level' value='0' checked>dataset</input></div>" +
                          "<div><input type='radio' name='subscription_level' value='1'>block</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.subscription_level = Dom.get('subscription_level');

// Dataset/block name(s)
      this.data_items = {};
      var data_items = this.data_items;
      data_items.txt = "enter one or more block/data-set names, separated by white-space or commas."; //\n\nNo wild-cards!"
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Data Items</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + data_items.txt + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.data_items = Dom.get('data_items');
      d.data_items.onfocus = function() {
        if ( this.value == data_items.txt ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.data_items.onblur=function() {
        if ( this.value == '' ) {
          this.value = data_items.txt;
          Dom.setStyle(this,'color',null);
        }
      }

// DBS
      this.dbs = {};
      var dbs = this.dbs;
      dbs.instanceDefault = {
            prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
            dev:'',
            debug:''
          };
      dbs.default = dbs.instanceDefault ['prod']; // TODO pick up the instance correctly!
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='dbs_selected'>" + "<span id='dbs_value'>" + dbs.default + "</span>" +
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
            dbsMenuButton.set('label', '<em>'+sText+'</em>');
          };
          dbsList = data.dbs;
          for (i in dbsList ) {
            dbsEntry = dbsList[i];
            if ( dbsEntry.name == dbs.default ) {
              dbsEntry.name = '<strong>'+dbsEntry.name+'</strong>';
              dbs.defaultId = i;
            }
            dbsMenuItems.push( { text:dbsEntry.name, value:dbsEntry.id, onclick:{ fn:onMenuItemClick } } );
          }
          dbs.menu.innerHTML = '';
          dbs.MenuButton = new YAHOO.widget.Button({  type: 'menu',
                                  label: '<em>'+dbs.default+'</em>',
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
          obj.gotDBSMenu = true;
        }
      }(this);

      onChangeDBSClick = function(obj) {
        return function() {
          if ( !obj.gotDBSMenu ) {
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
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form-element');
      el.innerHTML = "<div id='destination-container' class='phedex-nextgen-form-element'>" + "</div>";
      form.appendChild(el);
      d.destinationContainer = el;
      var makeNodePanel = function(obj) {
        return function(data,context) {
          var nodes=[], node, i, j, k, el=document.createElement('div'), pDiv=pDiv=document.createElement('div'), cont=d.destinationContainer;
          Dom.addClass(el,'phedex-nextgen-label');
          el.innerHTML = 'Destination';

          for ( i in data.node ) {
            node = data.node[i].name;
            if ( node.match(/^T(0|1|2|3)_/) ) { nodes.push(node ); }
          }
          nodes = nodes.sort();

          Dom.addClass(pDiv,'phedex-nextgen-control phedex-nextgen-nodepanel');
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            node.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              pDiv.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            pDiv.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input type='checkbox' name='"+node+"' />"+node+"</div>";
          }
          cont.appendChild(el);
          cont.appendChild(pDiv);
        }
      }(this);
      PHEDEX.Datasvc.Call({ api:'nodes', callback:makeNodePanel });

// Custodiality
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Site Custodial</div>" +
                        "<div id='isCustodial' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='site_custodial' value='0'>yes</input></div>" +
                          "<div><input type='radio' name='site_custodial' value='1' checked>no</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.isCustodial = Dom.get('isCustodial');

// Subscription type
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Subscription Type</div>" +
                        "<div id='subscription_type' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='subscription_type' value='0' checked>growing</input></div>" +
                          "<div><input type='radio' name='subscription_type' value='1'>static</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.subscription_type = Dom.get('subscription_type');

// Transfer type
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Transfer Type</div>" +
                        "<div id='transfer_type' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='transfer_type' value='0' checked>replica</input></div>" +
                          "<div><input type='radio' name='transfer_type' value='1'>move</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.transfer_type = Dom.get('transfer_type');

// Priority
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Priority</div>" +
                        "<div id='priority' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='priority' value='2'>high</input></div>" +
                          "<div><input type='radio' name='priority' value='1'>medium</input></div>" +
                          "<div><input type='radio' name='priority' value='0' checked>low</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.priority = Dom.get('priority');

// User group
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>User Group</div>" +
                        "<div id='group_menu' class='phedex-nextgen-control'>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      el = Dom.get('group_menu');

      var makeGroupMenu = function(obj) {
        return function(data,context) {
          var onMenuItemClick, groupMenuItems=[], groupList, group, i;
          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
            groupMenuButton.set('label', sText);
            obj.group = sText;
          };
          groupList = data.group;
          for (i in groupList ) {
            group = groupList[i];
            if ( !group.name.match(/^deprecated-/) ) {
              groupMenuItems.push( { text:group.name, value:group.id, onclick:{ fn:onMenuItemClick } } );
            }
          }
          var groupMenuButton = new YAHOO.widget.Button({ type: 'menu',
                                  label: '<em>Choose a group</em>',
                                  id:   'groupMenuButton',
                                  name: 'groupMenuButton',
                                  menu:  groupMenuItems,
                                  container: 'group_menu' });
        }
      }(this);
      PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// Start time
      var start_time_text = 'YYYY/MM/DD [hh:mm:ss]';
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Start Time</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><input type='text' id='start_time' name='start_time' class='phedex-nextgen-text' value='" + start_time_text + "' /></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.start_time = Dom.get('start_time');
      Dom.setStyle(d.start_time,'width','170px')
      d.start_time.onfocus = function() {
        if ( this.value == start_time_text ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.start_time.onblur=function(obj) {
        return function() {
          if ( this.value == '' ) {
            obj.start_time = this.value = start_time_text;
            Dom.setStyle(this,'color',null)
          }
        }
      }(this);

// Email
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Email</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='email_selector'>" +
                            "<span id='email_value'></span>" +
                            "<span>&nbsp;</span>" +
                            "<a id='change_email' class='phedex-nextgen-form-link' href='#'>change</a>" +
                          "</div>" +
                          "<div><input type='text' id='email_input' name='email' class='phedex-nextgen-text phedex-invisible' value='' /></div>" +
                        "</div>" +
                      "</div>";

      form.appendChild(el);
      d.email = {};
      var email = d.email, onEmailInput, kl;
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
            email.value.innerHTML = '(unknown)';
          }
          if ( !email ) { return; }
          email.value.innerHTML = email.input.value = address;
        };
      }(this);
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:gotAuthData })

// Comments
      this.comments = {};
      var comments = this.comments;
      comments.txt = 'enter any additional comments here';
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Comments</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='comments' name='comments' class='phedex-nextgen-textarea'>" + comments.txt + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.comments = Dom.get('comments');
      d.comments.onfocus = function() {
        if ( this.value == comments.txt ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.comments.onblur=function() {
        if ( this.value == '' ) {
          this.value = comments.txt;
          Dom.setStyle(this,'color',null)        }
      }
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
// debugger;
}

log('loaded...','info','nextgen-request-create');

