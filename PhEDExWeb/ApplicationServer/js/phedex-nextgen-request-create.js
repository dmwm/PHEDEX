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
//            switch ( action ) {
//              case 'useElement':{
//                obj.useElement(value);
//                break;
//              }
//            };
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

        Reset = new YAHOO.widget.Button({
                                type: 'submit',
                                label: 'Reset',
                                id: 'buttonReset',
                                name: 'buttonReset',
                                value: 'buttonReset',
                                container: 'buttons-left' });
        Cancel = new YAHOO.widget.Button({
                                type: 'submit',
                                label: 'Cancel',
                                id: 'buttonCancel',
                                name: 'buttonCancel',
                                value: 'buttonCancel',
                                container: 'buttons-right' });
        Accept = new YAHOO.widget.Button({
                                type: 'submit',
                                label: 'Accept',
                                id: 'buttonAccept',
                                name: 'buttonAccept',
                                value: 'buttonAccept',
                                container: 'buttons-right' });
        var onExampleSubmit = function(id,action) {
//           var bSubmit = window.confirm('Are you sure you want to submit this form?');
//           if(!bSubmit) {
//             YAHOO.util.Event.preventDefault(p_oEvent);
//           }
        }
        Accept.on('click', onExampleSubmit);
        Cancel.on('click', onExampleSubmit);
        Reset.on('click', onExampleSubmit);
      }
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

PHEDEX.Nextgen.Request.Xfer = function(_sbx,args) {
  var Dom = YAHOO.util.Dom;
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
                        "<div class='phedex-nextgen-label'>Subscription level</div>" +
                        "<div id='subscription_level' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='subscription_level' value='0' checked>dataset</input></div>" +
                          "<div><input type='radio' name='subscription_level' value='1'>block</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.subscription_level = Dom.get('subscription_level');

// Dataset/block name(s)
      data_items_txt = "enter one or more block/data-set names, separated by white-space or commas.\n\nNo wild-cards!"
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Data Items</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + data_items_txt + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.data_items = Dom.get('data_items');
      d.data_items.onfocus = function() {
        if ( this.value == data_items_txt ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.data_items.onblur=function() {
        if ( this.value == '' ) {
          this.value = data_items_txt;
          Dom.setStyle(this,'color',null);
        }
      }

// DBS TODO make it a text-element with a 'change' option next to it
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div id='dbs_menu' class='phedex-nextgen-control'>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      el = Dom.get('dbs_menu');

      var makeDBSMenu = function(obj) {
        return function(data,context) {
          var onMenuItemClick, dbsMenuItems=[], dbsList, dbs, i, defaultDbs, instanceDefault;

          instanceDefault = {
            prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
            dev:'',
            debug:''
          };
          defaultDbs = instanceDefault['prod']; // TODO pick up the instance correctly!
          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
              if ( sText.match(/<strong>(.*)<\/strong>/) ) { sText = RegExp.$1; }
              dbsMenuButton.set('label', '<em>'+sText+'</em>');
          };
          dbsList = data.dbs;
          for (i in dbsList ) {
            dbs = dbsList[i];
            if ( dbs.name == defaultDbs ) {
              dbs.name = '<strong>'+dbs.name+'</strong>';
            }
            dbsMenuItems.push( { text:dbs.name, value:dbs.id, onclick:{ fn:onMenuItemClick } } );
          }
          var dbsMenuButton = new YAHOO.widget.Button({  type: 'menu',
                                  label: '<em>'+defaultDbs+'</em>',
                                  id:   'dbsMenuButton',
                                  name: 'dbsMenuButton',
                                  menu:  dbsMenuItems,
                                  container: 'dbs_menu' });
        }
      }(this);
      PHEDEX.Datasvc.Call({ api:'dbs', callback:makeDBSMenu });

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
                        "<div class='phedex-nextgen-label'>&nbsp;</div>" +
                        "<div id='isCustodial' class='phedex-nextgen-control'>" +
                          "<div><input type='checkbox' name='isCustodial' /> Custodial request</div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.isCustodial = Dom.get('isCustodial');

// Subscription type
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Subscription type</div>" +
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
                        "<div class='phedex-nextgen-label'>Transfer type</div>" +
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
      d.start_time.onblur=function() {
        if ( this.value == '' ) {
          this.value = start_time_text;
          Dom.setStyle(this,'color',null)
        }
      }

// Comments
      var comments_txt = "enter any additional comments here"
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Comments</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='comments' name='comments' class='phedex-nextgen-textarea'>" + comments_txt + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      d.comments = Dom.get('comments');
      d.comments.onfocus = function() {
        if ( this.value == comments_txt ) {
          this.value = '';
          Dom.setStyle(this,'color','black');
        }
      }
      d.comments.onblur=function() {
        if ( this.value == '' ) {
          this.value = comments_txt;
          Dom.setStyle(this,'color',null)        }
      }

// action buttons
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
// debugger;
}

log('loaded...','info','nextgen-request-create');

