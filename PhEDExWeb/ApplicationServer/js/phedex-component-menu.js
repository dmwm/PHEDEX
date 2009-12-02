/**
 * This class creates a pulldown menu. Typical interaction with the partner would be for the partner to declare a map for an event that it notifies, mapping it to a method in the menu. This control would then listen for the notification and call the method with the arguments provided. Methods are provided to add items to the menu or to refresh the button on-screen, these can all be mapped to events in the partner.
 * @namespace PHEDEX.Component
 * @class Menu
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate.
 */

/** The partner object. This is added by the core. The control should only use this to take the <strong>obj.id</strong> of the partner, so it can set up a listener for events from that specific partner.
 * @property args.payload.obj {PHEDEX.Module, or derivative thereof}
 */
/** The text-label for this control.
 * @property args.payload.name {string}
 */
/** the name of an event to notify the partner with when the control is initialised. Used to allow the partner to know that the control is there, so it can do things that it would not do otherwise. E.g, using a split-button to manage showing of hidden fields is good, but until the control is there, the partner should not hide anything. Providing the <strong>onInit</strong> property with the name of a function that will hide the default fields allows them to be hidden only when the control is instantiated.
 * @property args.payload.onInit {string}
 */
/** Name of the HTML container-element for the button. Assumed to exist in the <strong>args.payload.obj.dom</strong> namespace</strong>
 * @property args.payload.container {string}
 */
/** map of event-names to methods, i.e. a map of string-to-string values. When the partner fires a notification for an event which matches one of the keys in this map, the control will call the argument named in the value, with all the arguments passed through.
 * @property args.payload.map {object}
 */
PHEDEX.namespace('Component');
PHEDEX.Component.Menu = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'Component-Menu',
      _sbx = sandbox,
      partner = args.partner,
//       menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence()),
//       button = new YAHOO.widget.Button(
//           {
//             label: args.payload.name || args.name,
//             name: 'Menu_'+PHEDEX.Util.Sequence(),
//             menu: menu,
//             container: args.payload.obj.dom[args.payload.container],
//             disabled:true
//           }
//         );

  _construct = function() {
    return {
      me: _me,
      payload: {},

/** Add an item to the menu. Called from the generic module-handler that listens for the partner, hence the complicated arguments
 * @method addMenuItem
 * @param args {array} array of arguments. The first item in the array must be an object with <strong>text</strong> and <strong>value</strong> fields, which are passed to the menu <strong>addItem</strong> function.
 */
       addMenuItem: function(args) {
//          column_menu.addItem({text:args[0].text, value:args[0].value});
//          this.refreshButton();
       },

/** refresh the button on-screen. Render it, and set the 'disabled' property depending on the number of items in the menu.
 * @method refreshButton
 */
      refreshButton: function() {
//         column_menu.render(document.body);
//         button.set('disabled', column_menu.getItems().length === 0);
      },

      _menu: [],
      _bin: args.payload.initial || -1,

/**
 * Initialise the control. Called internally. Sets up the buttons' event-handlers. There are two:<br />
 * the <strong>click</strong> handler will notify the partner with the value of every item in the menu, one by one (with a <strong>menuSelectItem</strong> message). Then it will clear the menu and refresh the button. It then notifies the partner to <strong>resizePanel</strong>, assuming that the partner will have changed on-screen as a result of all this. This is all somewhat specific behaviour, other split-buttons might not want to do that when the button is clicked.<br />
 * the <strong>appendTo</strong> handler creates a subscription to the menu.click event which will notify the partner (with a <strong>menuSelectItem</strong> message) about the particular element that has been selected. It then removes that item from the menu, refreshes the button, and notifies the parther to <strong>resizePanel</strong>, as for the click-handler. This is also somewhat specific, and may need factoring out at some point.<br />
 * This function also sets up the listener for the partner-module, translating event-notifications into local actions.
 * @method _init
 * @private
 * @param args {object} the arguments passed into the contructor
 */
      _init: function(args) {
        var p = args.payload;
        for (var i in p) { this.payload[i] = p[i]; }
        if ( p.obj ) { partner = p.obj.id; }

        var changeBin = function(obj) {
          return function(e) {
            if ( obj._bin == this.value ) { return; }
            obj._bin = this.value;
            if ( p.map.onChange ) {
              _sbx.notify(partner,p.map.onChange,this.value);
            }
          }
        }(this),

            onSelectedMenuItemChange = function(obj) {
          return function(e) {
            var oMenuItem = e.newValue,
                text = oMenuItem.cfg.getProperty("text");
            log('onSelectedMenuItemChange: new value: '+text,'info',_me);
            this.set("label", text);
          }
        }(this);

        for (var i in p.menu)
        {
          var q = p.menu[i], key, value;
          if ( typeof(q) == 'object' ) {
            key = q.key;
            value = q.text;
          } else {
            key = i;
            value = q;
          }
          if ( p.initial == key ) { this._value=value; }
          this._menu.push({ text: value, value:key, onclick: { fn: changeBin} });
        }
//         this._button = new YAHOO.widget.Button({
//           type: 'menu',
//           label: p.menu[p.initial] || p.label || 'Select a value',
//           name: 'menu_'+PxU.Sequence();,
//           menu: this._menu,
//           container: p.obj.dom[p.container]
//         });
//         var label, l = p.menu[p.initial] || p.label || 'Select a value';
//         if ( typeof(l) == 'object' ) {
//           label = l.text;
//         } else {
//           label = l;
//         }
        var x = {
          type: 'menu',
          label: this._value,
          name: 'menu_' + PxU.Sequence(),
          menu: this._menu,
          container: p.obj.dom[p.container]
        };
        this._button = new YAHOO.widget.Button(x);
        this._button.on('selectedMenuItemChange', onSelectedMenuItemChange);

// these two button-handlers could be factored out as extensions to the basic type...?
//         button.on("click", function (obj) {
//           return function() {
//             var m = column_menu.getItems();
//             for (var i = 0; i < m.length; i++) {
//               _sbx.notify(partner,'menuSelectItem',m[i].value,obj.id);
//             }
//             column_menu.clearContent();
//             obj.refreshButton();
//             _sbx.notify(partner,'resizePanel');
//           }
//         }(this));

//         button.on("appendTo", function (obj) {
//           return function() {
//             var m = this.getMenu();
//             m.subscribe("click", function onMenuClick(sType, oArgs) {
//               var oMenuItem = oArgs[1];
//               if (oMenuItem) {
//                 _sbx.notify(partner,'menuSelectItem',oMenuItem.value);
//                 m.removeItem(oMenuItem.index);
//                 obj.refreshButton();
//               }
//             _sbx.notify(partner,'resizePanel');
//             });
//           }
//         }(this));

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
  if ( args.payload.onInit ) { _sbx.notify(partner,args.payload.onInit); }
  return this;
};