PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.Create = function(sandbox) {
  var string = 'nextgen-request-create';
  Yla(this,new PHEDEX.Module(sandbox,string));

  var _sbx = sandbox;
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
        d.container = document.createElement('div');
        d.hd = document.createElement('div');
        d.bd = document.createElement('div');
        d.ft = document.createElement('div');
        d.main = document.createElement('div');
        d.main_block = document.createElement('div');

        d.container.id = 'doc2';
        d.container.className = 'phedex-nextgen-container';
        d.hd.id = 'hd'; d.hd.className = 'phedex-nextgen-hd';
        d.bd.id = 'bd'; d.bd.className = 'phedex-nextgen-bd';
        d.ft.id = 'ft'; d.ft.className = 'phedex-nextgen-ft';
        d.main.className = 'yui-main';
        d.main_block.className = 'yui-b phedex-nextgen-main-block';

        d.bd.appendChild(d.main);
        d.main.appendChild(d.main_block);
        d.container.appendChild(d.hd);
        d.container.appendChild(d.bd);
        d.container.appendChild(d.ft);
        el.innerHTML = '';
        el.appendChild(d.container);
      },
      init: function(args) {
        var type = args.type;
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
        try {
          this.initSub();
        } catch(ex) {
          var _ex = ex;
        }
      }
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

PHEDEX.Nextgen.Request.Xfer = function(_sbx,args) {
  return {
    initSub: function() {
      var d = this.dom,
          mb = d.main_block,
          hd = d.hd,
          form, el, label, control;
      hd.innerHTML = 'Subscribe data';

      form = document.createElement('form');
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
      d.subscription_level = document.getElementById('subscription_level');

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

      d.data_items = document.getElementById('data_items');
      d.data_items.onfocus = function() {
        if ( this.value == data_items_txt ) {
          this.value = '';
          this.style.color = 'black';
        }
      }
      d.data_items.onblur=function() {
        if ( this.value == '' ) {
          this.value = data_items_txt;
          this.style.color = null;
        }
      }

      el = document.createElement('hr');
      el.className = 'phedex-nextgen-hr';
      form.appendChild(el);

// DBS
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div id='dbs_menu' class='phedex-nextgen-control'>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      el = document.getElementById('dbs_menu');

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

// Destination TODO this doesn't work properly yet!
      el = document.createElement('div');
      el.className = 'phedex-nextgen-form-element';
      el.innerHTML = "<div id='destination-container' class='phedex-nextgen-form-element'>" + "</div>";
      form.appendChild(el);
      d.destinationContainer = el;
      var makeNodePanel = function(obj) {
        return function(data,context) {
          var nodes=[], node, i, j, k, el=document.createElement('div'), cont=d.destinationContainer;
          for ( i in data.node ) {
            node = data.node[i].name;
            if ( node.match(/^T(0|1|2|3)_/) ) { nodes.push(node ); }
          }
          nodes = nodes.sort();

          el.innerHTML = "<div class='phedex-nextgen-label'>Destination</div><div class='phedex-nextgen-control phedex-nextgen-nodepanel'>";
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            node.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              el.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            el.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input type='checkbox' name='"+node+"' />"+node+"</div>";
          }
          el.innerHTML += "</div>";
          cont.appendChild(el);
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
      d.isCustodial = document.getElementById('isCustodial');

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
      d.subscription_type = document.getElementById('subscription_type');

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
      d.transfer_type = document.getElementById('transfer_type');

// Priority
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Priority</div>" +
                        "<div id='priority' class='phedex-nextgen-control'>" +
                          "<div><input type='radio' name='priority' value='0' checked>low</input></div>" +
                          "<div><input type='radio' name='priority' value='1'>medium</input></div>" +
                          "<div><input type='radio' name='priority' value='2'>high</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      d.priority = document.getElementById('priority');

// User group
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>User Group</div>" +
                        "<div id='group_menu' class='phedex-nextgen-control'>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      el = document.getElementById('group_menu');

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
            groupMenuItems.push( { text:group.name, value:group.id, onclick:{ fn:onMenuItemClick } } );
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

      d.comments = document.getElementById('comments');
      d.comments.onfocus = function() {
        if ( this.value == comments_txt ) {
          this.value = '';
          this.style.color = 'black';
        }
      }
      d.comments.onblur=function() {
        if ( this.value == '' ) {
          this.value = comments_txt;
          this.style.color = null;
        }
      }

// action buttons
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
// debugger;
}

log('loaded...','info','nextgen-request-create');

