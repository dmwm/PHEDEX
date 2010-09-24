/**
 * This class creates a DOM element, for example, a link to further information about the module.
 * @namespace PHEDEX.Component
 * @class Dom
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
PHEDEX.Component.Dom = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-dom',
      _sbx = sandbox,
      partner = args.partner,
      ap = args.payload,

  _construct = function() {
    return {
      me: _me,
      payload: {},

/**
 * Initialise the control. Called internally. Simply creates the link object.
 * @method _init
 * @private
 * @param args {object} the arguments passed into the contructor
 */
      _init: function(args) {
        var el, i, attributes = ap.attributes, style = ap.style, handler = ap.handler;
        if ( !ap.type ) { ap.type = 'a'; }
        this.id = this.me+'_'+PxU.Sequence();
        el = document.createElement(ap.type);
        for (var i in attributes) {
          el[i] = attributes[i];
        }
        for (var i in style) {
          el.style[i] = style[i];
        }
        if ( handler ) {
          if ( typeof(handler) == 'string' ) {
            ap.obj.allowNotify[handler] = 1;
            _sbx.notify(ap.obj.id,handler,el);
          }
          else if ( typeof(handler) == 'function' ) {
            handler(el);
          }
        }
        this.el = el;
      }
    }
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
};

log('loaded...','info','component-dom');
