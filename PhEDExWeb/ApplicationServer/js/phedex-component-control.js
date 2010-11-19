/**
 * A PHEDEX.Component.object is a decorator, applied to an on-screen element to add some subsidiary functionality. There is no concrete PHEDEX.Component base-class, but since all such components have common initialisation, it is described here. The module that is being decorated is referred to as the <strong>partner</strong>.<br />
 * @namespace PHEDEX
 * @class Component
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate.
 */

/** An arbitrary name for this control. Used to index the <strong>this.ctl</strong> object with a reference to the created control
 * @property args.name {string}
 */
/** Name of the module to load, if any. Prefix 'phedex-' is assumed, if not specified.
 * @property args.source {string}
 */
/** (optional) name of the parent element to which this control will be attached. This is expected to be an element that exists in the <strong>obj.dom</strong> structure of the partner object. Not used by the control itself, the core will attach the component when it is ready.
 * @property args.parent {string}
 */
/** Control-specific attributes, vary from one control-type to another.
 * @property args.payload {object}
 */

/**
 * This class creates a clickable element that can be used to drive showing/hiding of other fields, or other custom actions. For example, it is used for the 'Extra' information, for showing the 'filter' panel, or for a 'Refresh' button. It is used to decorate modules or other on-screen elements.<br />
 * Typically, there will be two DOM elements involved, one for rendering the control, one that is controlled by the control (though this one is optional).
 * The control will set up two sandbox-listeners, one to listen for events with its own <strong>id</strong>, and one to listed to events with the <strong>id</strong> of the partner-object. This allows it to respond to the partner or to messages to the partner, without having to call the partner directly.
 * @namespace PHEDEX.Component
 * @class Control
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate. See PHEDEX.Component for a description of the common parts of this object.
 */

/** The name (in the <strong>obj.dom</strong> partner-object) of the element that is to be controlled by this control.
 * @property args.payload.target {string}
 */
/** Controls are enabled by default. Setting <strong>args.payload.disabled</strong> to <strong>true</strong> will cause it to start disabled.
 * @property args.payload.disabled {boolead}
 */
/** Controls are shown by default. Setting <strong>args.payload.hidden</strong> to <strong>true</strong> will cause it to be hidden at creation-time.
 * @property args.payload.hidden {boolead}
 */
/** The handler, either a function-reference or an event-name, that will be called or invoked (via the sandbox) when the controlled element is to be shown. Our architectural model frowns upon using a function, as objects should not call each other, so it's better to use the string form. The partner object will then receive a notification from the sandbox with the following three arguments:<br />
 * - <strong>expand</strong>, so the partner should listen for this keyword<br />
 * - <strong>handler</strong>, the name of the handler, used for dismbiguating multiple controls in a single partner<br />
 * - <strong>this.id</strong>, so the partner can signal something back to this component if it chooses<br />
 * @property args.payload.handler {string|function}
 */
/** Animate or not (default: not) the hiding of the controlled element.
 * @property args.payload.animate {boolean}
 */
/** Controls may be activated by clicking or by extended mouse-hovering. To activate mouse-hovering, set this parameter to the number of miliseconds of hovering that are required.
 * @property args.payload.hover_timeout {integer}
 */
/** Map to trigger dialogue between the control and the partner via the sandbox. The map is a hash of string keys and string values. The idea is that the control will listen for the keys emanating from their partner object (and only from it!), and will respond by calling its own member-functions (the values) when it receives them. The map-values are strings rather than function-references because the decorator arguments are defined in the parent object, before this code is even loaded, so the parent cannot have a valid function reference at that time.<br />
 * An example, a control to 'Refresh' the data for a module might disable itself when the module gets fresh data, then re-enable itself when that data has expired, as a prompt to the user that they can get new data. That would look like this:
 <pre>
 map: {
   gotData:     'Disable',
   dataExpires: 'Enable',
 },
 </pre>
 * @property args.payload.map {object}
 */
/** The partner object. This is added by the core. The control should only use this to take the <strong>obj.id</strong> of the partner, so it can set up a listener for events from that specific partner.
 * @property args.payload.obj {PHEDEX.Module, or derivative thereof}
 */
/** Text to use to label the on-screen representation of the control. By default, the <strong>args.name</strong> will be used, but this allows you to set a different value.
 * @property args.payload.text {string}
 */
PHEDEX.namespace('Component');
PHEDEX.Component.Control = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-control',
      _sbx = sandbox,
      partner = args.partner,
      ap = args.payload,

      _defTitle = {
        Filter:   'Show the filter-panel, which allows you to filter the data shown in this module',
        Headers:  'Show the header-tree, which shows you what the data-fields are, and allows you to resize fields by dragging the header-element',
        Extra:    'Show extra details about this data',
        Refresh:  'Refresh this module with new data from the dataservice',
        Subscribe:'Show the subscription panel. This control is only enabled if you have selected datasets or blocks to make a transfer request for'
      },

/**
 * Handle click events, by toggling the visibility of the controlled element.
 * This is a standard YUI custom event handler, so it takes the usual two arguments:
 * @method _clickHandler
 * @param ev {event} the event that triggered the handler
 * @param obj {object} the module or object this control is attached to (i.e. what it's decorating)
 * @private
 */
  _clickHandler=function(ev,obj) {
    if ( obj.isHidden() ) { obj.Show(); }
    else { obj.Hide(); }
  };
/**
 * Handle mouse-over events.<br />
 * If <strong>hover_timeout</strong> is set, start a timer to prepare to Show() the hidden element.
 * This is a standard YUI custom event handler, so it takes the usual two arguments:
 * @method _mouseoverHandler
 * @param ev {event} the event that triggered the handler
 * @param obj {object} the module or object this control is attached to (i.e. what it's decorating)
 * @private
 */
  _mouseoverHandler = function(ev,obj) {
    if ( this.payload.tooltip ) {
      this.el.title = this.payload.tooltip() || this.tooltip;
    }
    var timeout = obj.payload.hover_timeout;
    if ( !timeout ) { return; }
    obj.payload.timer = setTimeout(function() { if ( obj.Show ) { obj.Show(); } },timeout);
  }
/**
 * Handle mouse-out events.<br />
 * Cancel any timer that was set by <strong>_mouseoverHandler</strong>.
 * This is a standard YUI custom event handler, so it takes the usual two arguments:
 * @method _mouseoutHandler
 * @param ev {event} the event that triggered the handler
 * @param obj {object} the module or object this control is attached to (i.e. what it's decorating)
 * @private
 */
  _mouseoutHandler=function(ev,obj) {
    if ( obj.payload.timer ) {
      clearTimeout(obj.payload.timer);
      obj.payload.timer = null;
    }
  }

/**
 * construct a PHEDEX.Component.Control object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      enabled: 1,
      payload: {},

/** Wrap the sandbox notifications in a check to see if we are associated with a partner. Adds the partner-name to the argument list
 * @method notify
 * @param arr {array} array of arguments to pass to the sandbox notification method
 * @private
 */
      notify: function() {
        if ( !partner ) { return; }
        var arr = Array.apply(null,arguments);
        arr.unshift(partner);
        _sbx.notify.apply(null,arr);
      },
/**
 * Initialise the component
 * @method _init
 * @param args {object} pointer to object containing configuration parameters
 * @private
 */
      _init: function(args) {
        var p = this.payload, name;
        if ( !ap.type ) { ap.type = 'a'; }
        this.id = this.me+'_'+PxU.Sequence();
        this.el = document.createElement(ap.type);
        this.name = name = ap.text || args.name;
        if ( ap.type == 'img' ) {
          this.el.src = args.src;
        } else if ( ap.type == 'a' ) {
          this.el.appendChild(document.createTextNode(name));
        }
        this.tooltip = this.el.title = ap.title || _defTitle[name] || '';
        for (var i in ap) { p[i] = ap[i]; }
        if ( p.obj ) { partner = p.obj.id; }
        if ( p.target ) {
          if ( p.obj ) {
            if ( typeof(p.target) != 'object' ) {  p.target = p.obj.dom[p.target]; }
          }
          if ( typeof(p.target) != 'object' ) { p.target = document.getElementById(p.target); }
          YuD.addClass(p.target,'phedex-invisible');
        }
        this.el.className = ap.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
        if ( !args.events ) {
          args.events = [
                    {event:'mouseover', handler:_mouseoverHandler},
                    {event:'mouseout',  handler:_mouseoutHandler},
                    {event:'click',     handler:_clickHandler}];
        }
        for (var i in args.events) {
          var ev = args.events[i].event,
              fn = args.events[i].handler || PHEDEX.Component.Control.clickHandler,
              el = args.events[i].element || this.el;
          YuE.addListener(el,ev,fn,this,true);
        }
        if ( ap.hidden )   { this.Hide(); }
        if ( ap.disabled ) { this.Disable(); }
        else { this.Enable(); }
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value = arr[1];
            switch (action) {
              case 'activate': {
                var tgt = obj.payload.target;
                if ( tgt ) {
                  var eHeight = tgt.offsetHeight;
                  obj.notify('show target',eHeight);
                } else {
                  if ( value == 'done' ) { obj.Hide(); }
                }
                break;
              }
              case 'Show': {
                obj.Show();
                break;
              }
              case 'Hide': {
                obj.Hide();
                break;
              }
              default: { log('unhandled event: '+action,'warn',_me); break; }
            }
          }
        }(this);
        _sbx.listen(this.id,selfHandler);

        if ( p.obj ) {
          var moduleHandler = function(obj) {
            return function(ev,arr) {
              var action = arr[0], args=[], fnName, map=obj.payload.map, i;
              if ( !map || !action ) { return; }
              fnName = map[action];
              if ( !fnName ) { return; }
              for (i in arr) { args[i] = arr[i]; }
              args.shift();
              obj[fnName](args);
            }
          }(this);
          _sbx.listen(p.obj.id,moduleHandler);
        }
      },
/**
 * Show the controlled element, and trigger the '<strong>partner</strong>' module (that which is being decorated) to put something in it
 * If the control is not <strong>enabled</strong>, do nothing</br />
 * If the target element does not have the CSS class <strong>phedex-invisible</strong>, do nothing<br />
 * If it survives both those tests, do the following things:<br />
 * - remove the <strong>phedex-invisible</strong> CSS class from the target element,<br />
 * - remove the <strong>phedex-core-control-widget-inactive</strong> CSS class, add <strong>phedex-core-control-widget-active</strong> in its place<br />
 * - invoke the handler in the partner.<br />
 * The handler is either a function (which is called directly, with no arguments) or a string (which is used to notify the partner. See the <strong>args.payload.handler</strong> property for documentation.
 * @method Show
 */
      Show: function() {
        var p   = this.payload,
            tgt = p.target, eHeight;
        if ( !this.enabled ) { return; }
        if ( tgt && !YuD.hasClass(tgt,'phedex-invisible') ) { return; }
        if ( p.handler ) {
          if ( typeof(p.handler) == 'string' ) {
            this.notify('activate',p.handler,this.id);
          }
          else if ( typeof(p.handler) == 'function' ) {
            p.handler();
          }
        }

        if ( tgt ) { YuD.removeClass(tgt,'phedex-invisible'); }
        YuD.removeClass(this.el,'phedex-core-control-widget-inactive');
        YuD.addClass   (this.el,'phedex-core-control-widget-active');
        eHeight = tgt.offsetHeight;
        this.notify('show target',eHeight);
      },
/**
 * Hide the controlled element
 * - add the <strong>phedex-invisible</strong> CSS class to the target element,<br />
 * - remove the <strong>phedex-core-control-widget-active</strong> CSS class, add <strong>phedex-core-control-widget-inactive</strong> in its place<br />
 * - if required, the hiding will be animated
 * @method Hide
 */
      Hide: function() {
        var tgt = this.payload.target,
            ani = this.payload.animate,
            eHeight, reallyHide;
        if ( tgt ) {
          eHeight = tgt.offsetHeight;
          reallyHide=function(ctl) {
            return function() {
              var tgt = ctl.payload.target;
              YuD.addClass(tgt,'phedex-invisible');
              YuD.removeClass(tgt,'phedex-hide-overflow');
              tgt.style.height=null;
              ctl.notify('hide target',eHeight);
              YuD.addClass   (ctl.el,'phedex-core-control-widget-inactive');
              YuD.removeClass(ctl.el,'phedex-core-control-widget-active');
            };
          }(this);
        } else {
          reallyHide=function(ctl) {
            return function() {
              YuD.addClass   (ctl.el,'phedex-core-control-widget-inactive');
              YuD.removeClass(ctl.el,'phedex-core-control-widget-active');
            };
          }(this);
        }

        if ( ani ) {
          var attributes = { height: { to: 0 }  }; 
          if ( typeof(ani) == 'object' ) { attributes = ani.attributes; }
          var duration = ani.duration_hide || ani.duration || 0.5,
              anim = new Yu.Anim(tgt, attributes, duration);
          YuD.addClass(tgt,'phedex-hide-overflow');
          anim.onComplete.subscribe(reallyHide);
          anim.animate();
        } else {
          reallyHide();
        }
      },
/**
 * helper function to determine if the element is supposedly visible or not, by looking for the <strong>phedex-invisible</strong> class
 * @method isHidden
 * @return {boolean} true if the controlled element is hidden from display
 */
      isHidden: function() {
        var tgt = this.payload.target;
        if ( !tgt ) { return 1; }
        return YuD.hasClass(tgt,'phedex-invisible');
      },
/**
 * apply a label to the control. Used in the constructor, can also be used to change the label of the control in response to external conditions
 * @method Label
 */
      Label: function(text) {
        this.el.innerHTML = text;
      },
/**
 * enable the control. Remove the CSS class <strong>phedex-core-control-widget-disabled</strong>, set the <strong>enabled</strong> property to 1, and set the cursor to 'pointer' for this element.
 * @method Enable
 */
      Enable: function(opts) {
        YuD.removeClass(this.el,'phedex-core-control-widget-disabled');
        this.enabled = 1;
        this.el.style.cursor = 'pointer';
        if ( opts ) {
          if ( opts.resetTT ) {
            this.el.title = this.tooltip;
          }
        }
      },
/**
 * disable the control. Add the CSS class <strong>phedex-core-control-widget-disabled</strong>, set the <strong>enabled</strong> property to 0, and set the cursor to normal
 * @method Disable
 */      Disable: function() {
        YuD.addClass(this.el,'phedex-core-control-widget-disabled');
        this.enabled = 0;
        this.el.style.cursor = '';
      },
/**
 * add or remove the <strong>phedex-core-control-widget-applied</strong> CSS class depending on the input argument (true ==> add). Used to show that 'something' has happened, such as a module has had a filter applied to it. Gives visual indication of state without the controlled element having to be visible.
 * @method setApplied
 * @param isApplied {boolean}
 */
      setApplied: function(isApplied) {
        if ( typeof(isApplied) == 'undefined' ) { return; }
        if ( isApplied ) { YuD.addClass   (this.el,'phedex-core-control-widget-applied'); }
        else             { YuD.removeClass(this.el,'phedex-core-control-widget-applied'); }
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  _sbx.notify(this.me,this.id,this.name);
  return this;
}

log('loaded...','info','component-control');
