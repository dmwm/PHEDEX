/** PHEDEX.Registry
 * A global object for registering widgets according to types of
 * information they can display. Used for filling menus and instantiating
 * widgets.
 * @namespace PHEDEX
 * @class Registry
 * @static
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 */
// TODO: bind together with Core.ContextMenu.  i.e. if it's registered
//       here it should also be registered there...  or just have it access this object?
PHEDEX.Registry = function(sandbox) {
  // private data
  var _sbx = sandbox,

  // widget lists keyed by input type
      _widgets = {},

  // types of information widgets can construct by
      _validTypes = { node     :1,
                      link     :1,
                      dataset  :1,
                      block    :1,
                      file     :1,
                      timespan :1,
                      group    :1,
                      user     :1,
                      request  :1,
                      static   :1,
                      none     :1 };

  return {
    // public methods

/** add a new widget to the registry
 * @method add
 * @param widget
 * @param inputType
 * @param label
 * @param extrakeys
 */
    add: function(widget, inputType, label, extrakeys ) {
      if (!_validTypes[inputType]) {
        throw new Error("input type '"+inputType+"' is not valid");
      }
      if (!_widgets[inputType]) {
        _widgets[inputType] = {};
      }
      if (!_widgets[inputType][widget]) {
        _widgets[inputType][widget] = {};
      }
      if (_widgets[inputType][widget][label]) {
        throw new Error("widget '"+widget+"' already registered for input type '"+inputType+"'");
      }
      var w = { widget:widget, short_name:widget, type:inputType, label:label, id:PxU.Sequence() };
      if ( widget.match('^phedex-module-(.+)$') ) { w.short_name = RegExp.$1; }
      if (extrakeys) {
        for (var k in extrakeys) {
          w[k] = extrakeys[k];
        }
      }
      _widgets[inputType][widget][label] = w;
    },

/** get a list of inputTypes that have registered widgets
 * @method getInputTypes
 * @return {array} array of names of registered input-types
 */
    getInputTypes: function() {
      var types = [];
      for (var t in _widgets) {
        types.push(t);
      }
      return types;
    },

/** get a list of registered widgets by an inputType
 * @method getWidgetsByInputType
 * @param inputType {string}
 * @return {array} array of widgets matching the inputType, or null if no match is found
 */
    getWidgetsByInputType: function(inputType) {
      if (_widgets[inputType]) { 
        var widgets = [];
        for (var w in _widgets[inputType]) {
          for (var l  in _widgets[inputType][w]) {
            widgets.push(_widgets[inputType][w][l]);
          }
        }
        return widgets;
      }
      else { return null; }
    },

/** initialise the Registry. Or rather, invoke the sandbox to listen for events that will start the ball rolling. Until <strong>create</strong> is called, the Registry will sit there, doing nothing at all.
 * @method create
 */
    create: function() {
      _sbx.notify('RegistryExists',this.id);
/**
 * Handle messages sent directly to this module. This function is subscribed to listen for <strong>Registry</strong> events, and will take action accordingly.
 * @method selfHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event
 * @private
 */
      this.selfHandler = function(obj) {
        return function(ev,arr) {
          var action = arr[0];
          switch (action) {
            case 'add': {
              obj[action](arr[1],arr[2],arr[3],arr[4]);
              break;
            }
            case 'getWidgetsByInputType': {
              var value = obj[action](arr[1]);
              _sbx.notify(arr[2],action,arr[1],value);
              break;
            }
            case 'getInputTypes': {
              var value = obj[action]();
              _sbx.notify(arr[1],action,value);
              break;
            }
            case 'needRegistry': {
              _sbx.notify(arr[1],'RegistryExists',obj);
            }
          }
        }
      }(this);
      _sbx.listen('Registry',this.selfHandler);
    }
  };
};
