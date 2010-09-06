/**
 * This class creates a pulldown menu. Typical interaction with the partner would be for the partner to declare a map for an event that it notifies, mapping it to a method in the menu. This control would then listen for the notification and call the method with the arguments provided. Methods are provided to add items to the menu or to refresh the button on-screen, these can all be mapped to events in the partner.
 * @namespace PHEDEX.Component
 * @class Menu
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate.
 */
// TODO THese are common things that should be factored out...
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
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-menu',
      _sbx = sandbox,
      partner = args.partner,

  _construct = function() {
    return {
      me: _me,
      payload: {},
      _menu: [],
      _bin: -1,

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
        var p = args.payload,
            i, button_args;
        for (i in p) { this.payload[i] = p[i]; }
        if ( p.obj ) { partner = p.obj.id; }
        if ( p.initial ) {
          if ( typeof(p.initial) == 'function' ) { this._bin = p.initial(); }
          else { this._bin = p.initial; }
        }

        var selectBin = function(obj) {
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
            }(this),
            i, q, key, value;

        for (i in p.menu)
        {
          q = p.menu[i];
          if ( typeof(q) == 'object' ) {
            key = q.key;
            value = q.text;
          } else {
            key = i;
            value = q;
          }
          if ( p.prefix ) { value = p.prefix+' '+value; }
          if ( this._bin == key ) { this._value=value; }
          this._menu.push({ text:value, value:key, onclick:{ fn:selectBin } });
        }
        button_args = {
          type: 'menu',
          label: this._value,
          name: 'menu_' + PxU.Sequence(),
          menu: this._menu,
          container: p.obj.dom[p.container]
        };
        if ( p.title ) { button_args.title = p.title; }
        this._button = new Yw.Button(button_args);
        this._button.on('selectedMenuItemChange', onSelectedMenuItemChange);

        var moduleHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0], args=[], fn, fnName, map=obj.payload.map;
            if ( !action ) { return; }
            fn = this[action];
            if ( fn && typeof(fn) == 'function' ) {
              if ( arr[2] != args.name ) { return; }
              fn(arr[3]);
              return;
            }
            if ( !map ) { return; }
            fnName = map[action];
            if ( fnName ) {
              for (i in arr) { args[i] = arr[i]; }
              args.shift();
              obj[fnName](args);
              return;
            }
          }
        }(this);
        _sbx.listen(partner,moduleHandler);
      }
    }
  };
  Yla(this,_construct(this),true);
  this._init(args);
  if ( args.payload.onInit ) { _sbx.notify(partner,args.payload.onInit); }
  return this;
};

log('loaded...','info','component-menu');
