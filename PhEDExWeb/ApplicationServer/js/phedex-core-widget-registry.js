/* PHEDEX.Core.Widget.Registry
 * A global object for registering widgets according to types of
 * information they can display. Used for filling menus and instantiating
 * widgets.
*/
// TODO: bind together with Core.ContextMenu.  i.e. if it's registered
//       here it should also be registered there...  or just have it access this object?
PHEDEX.namespace("Core.Widget.Registry");
PHEDEX.Core.Widget.Registry=(function() {
  // private data
  // widget lists keyed by input type
  var _widgets = {};

  // types of information widgets can construct by
  var _validTypes = { node     :1,
		      link     :1,
		      dataset  :1,
		      block    :1,
		      file     :1,
		      timespan :1,
		      group    :1,
		      user     :1,
		      request  :1,
		      none     :1 };

  return {
    // public methods
    
    // add a new widget to the registry
    add: function(widget, inputType, label, constructor, extrakeys ) {
      if (!_validTypes[inputType]) { 
	throw new Error("input type '"+inputType+"' is not valid"); 
      }
      if (!_widgets[inputType]) { _widgets[inputType] = {}; }
      if (_widgets[inputType][widget]) {
	throw new Error("widget '"+widget+"' already registered for input type '"+inputType+"'");
      }
      var w = { 'widget': widget, 'label': label, 'construct': constructor };
      if (extrakeys) {
	for (var k in extrakeys) {
	  w[k] = extrakeys[k];
	}
      }
      _widgets[inputType][widget] = w;
    },

    // get a list of inputTypes that have registered widgets
    getInputTypes: function() {
      var types = [];
      for (var t in _widgets) {
	types.push(t);
      }
      return types;
    },

    // get a list of registered widgets by an inputType
    getWidgetsByInputType: function(inputType) {
      if (_widgets[inputType]) { 
	var widgets = [];
	for (var w in _widgets[inputType]) {
	  widgets.push(_widgets[inputType][w]);
	}
	return widgets;
      }
      else { return null; }
    },
    
    // build a registered widget
    construct: function(widget, inputType, inputData, divid, args) {
      if (!_widgets[inputType][widget]) {
	throw new Error("cannot construct unregistered widget '"+widget+"' by input type '"+inputType+"'");
      }
      var w = _widgets[inputType][widget];
      return w.construct(inputData, divid, args);
    }
  };
})();
