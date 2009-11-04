PHEDEX.namespace('Component');

PHEDEX.Component.SplitButton = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'Component-SplitButton',
      _sbx = sandbox,
      partner = args.partner,
      column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence()),
      button = new YAHOO.widget.Button(
          {
            type: "split",
            label: args.payload.name,
            name: 'splitButton_'+PHEDEX.Util.Sequence(),
            menu: column_menu,
            container: args.payload.obj.dom[args.payload.container],
            disabled:true
          }
        );


  _construct = function() {
    return {
      me: _me,
      payload: {},

       addMenuItem: function(args) {
         column_menu.addItem({text:args[0].text, value:args[0].value});
         this.refreshButton();
       },

      refreshButton: function() {
        column_menu.render(document.body);
        button.set('disabled', column_menu.getItems().length === 0);
      },

      _init: function(args) {
        for (var i in args.payload) { this.payload[i] = args.payload[i]; }
        if ( this.payload.obj ) { partner = this.payload.obj.id; }

        button.on("click", function (obj) {
          return function() {
            var m = column_menu.getItems();
            for (var i = 0; i < m.length; i++) {
              _sbx.notify(partner,'menuSelectItem',m[i].value,obj.id);
            }
            column_menu.clearContent();
            obj.refreshButton();
            _sbx.notify(partner,'resizePanel');
          }
        }(this));

        button.on("appendTo", function (obj) {
          return function() {
            var m = this.getMenu();
            m.subscribe("click", function onMenuClick(sType, oArgs) {
              var oMenuItem = oArgs[1];
              if (oMenuItem) {
                _sbx.notify(partner,'menuSelectItem',oMenuItem.value);
                m.removeItem(oMenuItem.index);
                obj.refreshButton();
              }
            _sbx.notify(partner,'resizePanel');
            });
          }
        }(this));

//         var selfHandler = function(obj) {
//           return function(ev,arr) {
//             var action = arr[0],
//                 value = arr[1];
//             switch (action) {
//               default: { log('unhandled event: '+action,'warn',me); break; }
//             }
//           }
//         }(this);
//         _sbx.listen(this.id,selfHandler);

        var moduleHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0];
            if ( action && obj.payload.map[action] ) {
              arr.shift();
              obj[obj.payload.map[action]](arr);
            }
          }
        }(this);
        _sbx.listen(partner,moduleHandler);

      },
    }
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
};