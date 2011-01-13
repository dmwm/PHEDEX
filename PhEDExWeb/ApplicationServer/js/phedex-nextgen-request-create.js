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
        d.container.className = /*'yui-t3*/ 'phedex-nextgen-container';
//         d.container.style.margin = '0';
//         d.container.style.padding = '0 0 0 0'; //110px';
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
type='xfer';
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
debugger;
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
          form, el, label, control, txt;
      hd.innerHTML = 'Subscribe data';

      form = document.createElement('form');
      form.name = 'subscribe_data';
      mb.appendChild(form);

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

      txt = "enter one or more block/data-set names, separated by white-space or commas.\n\nNo wild-cards!"
      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Data Items</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><textarea id='data_items' name='data_items' class='phedex-nextgen-textarea'>" + txt + "</textarea></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);

      el = d.data_items = document.getElementById('data_items');
      el.onfocus = function() {
        if ( this.value == txt ) {
          this.value = '';
          this.style.color = 'black';
        }
      }
      el.onblur=function() {
        if ( this.value == '' ) {
          this.value = txt;
          this.style.color = null;
        }
      }

      el = document.createElement('hr');
      el.className = 'phedex-nextgen-hr';
      form.appendChild(el);

      el = document.createElement('div');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>DBS</div>" +
                        "<div id='dbs_menu' class='phedex-nextgen-control'>" +
//                           "<div><input type='textbox' name='dbs' value=''>block</input></div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      el = document.getElementById('dbs_menu');

    var onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
      var sText = p_oItem.cfg.getProperty("text");
      YAHOO.log("[MenuItem Properties] text: " + sText + ", value: " + p_oItem.value);
        dbsMenuButton.set("label", sText);
    },
        dbsMenuItems = [
          { text: "One", value: 1, onclick: { fn: onMenuItemClick } },
          { text: "Two", value: 2, onclick: { fn: onMenuItemClick } },
          { text: "Three", value: 3, onclick: { fn: onMenuItemClick } }
        ],
        dbsMenuButton = new YAHOO.widget.Button({  type: "menu",
                            label: "Choose a DBS",
                            name: "mymenubutton",
                            menu: dbsMenuItems,
                            container: 'dbs_menu' });
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
// debugger;
}

log('loaded...','info','nextgen-request-create');

