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
// TODO: The Registry consists of a set of global data and some API to access it. It would
// be better to have the API constructible as an object that augments the objects that use
// it, rather than as a separate object that they all communicate with via the sandbox.
// That way, we can avoid a lot of fiddling around with the sandbox and synchronising
// things, but still maintain clean separation of functionality.
PHEDEX.Registry = function(sandbox) {
  // private data
  var _sbx = sandbox,
      _me  = 'registry',

  // widget lists keyed by input type
      _widgets = {},

  // list of types for known widgets
      _inputTypes = {},

  // types of information widgets can construct by
      _validTypes = {
                      node     :1,
                      link     :1,
                      dataset  :1,
                      block    :1,
                      file     :1,
                      timespan :1,
                      group    :1,
                      user     :1,
                      request  :1,
                     'static'  :1,
                      none     :1,
                      activity :1
                    };
  this.id = _me+'_'+PxU.Sequence();

  var _construct = function() {
    return {
/** add a new widget to the registry
 * @method add
 * @param widget {string} the name of the module, e.g. phedex-module-agents
 * @param inputType {string} the input-type of this module, i.e. the type of information it expects (node, group...)
 * @param label {string} the label to display on-screen to represent this module
 * @param extrakeys {object} any additional keys needed to work with this object.
 */
      add: function(widget, inputType, label, extrakeys ) {
        if (!_validTypes[inputType]) {
          throw new Error("input type '"+inputType+"' is not valid");
        }
        if (!_widgets[inputType]) {
          _widgets[inputType] = {};
          _sbx.notify('Registry','InputTypes',this.getInputTypes());
        }
        if (!_widgets[inputType][widget]) {
          _widgets[inputType][widget] = {};
        }
        if (_widgets[inputType][widget][label]) {
          throw new Error("widget '"+widget+"' already registered for input type '"+inputType+"'");
        }
        // TODO the 'widget' key is probably redundant, test that hypothesis at some point
        var k, w = { widget:widget, short_name:widget, type:inputType, label:label, id:PxU.Sequence() };
        if ( widget.match('^phedex-module-(.+)$') ) { w.short_name = RegExp.$1; }
        w.short_name = w.short_name.toLowerCase();
        if (extrakeys) {
          for (k in extrakeys) {
            w[k] = extrakeys[k];
          }
        }
        _widgets[inputType][widget][label] = w;
        if ( !_inputTypes[w.short_name] ) {
          _inputTypes[w.short_name] = {};
        }
        _inputTypes[w.short_name][inputType] = 1;
      },

/** get a list of inputTypes that have registered widgets
 * @method getInputTypes
 * @return {array} array of names of registered input-types
 */
      getInputTypes: function() {
        var t, types = [];
        for (t in _widgets) {
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
          var w, l, widgets = [];
          for (w in _widgets[inputType]) {
            for (l  in _widgets[inputType][w]) {
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
            log('selfHandler: ev='+ev+' args='+Ylangd(arr,1),'info',_me);
            var action = arr[0], value;
            switch (action) {
              case 'add': {
                obj[action](arr[1],arr[2],arr[3],arr[4]);
                break;
              }
              case 'getWidgetsByInputType': {
                value = obj[action](arr[1]);
                _sbx.notify(arr[2],'WidgetsByInputType',arr[1],value);
                break;
              }
              case 'getInputTypes': {
                value = obj[action]();
                _sbx.notify(arr[1],'InputTypes',value);
                break;
              }
              case 'getTypeOfModule': {
                try { value = _inputTypes[arr[1].toLowerCase()]; } catch (ex) {};
                if ( value ) {
                  _sbx.notify(arr[2],'TypeOfModule',value);
                }
                break;
              }
            }
          }
        }(this);
        _sbx.listen('Registry',this.selfHandler);
      }
    }
  };
  Yla(this,_construct(this),true);
  YtP.registerObject('Registry',this);
  return this;
};

log('loaded...','info','registry');
