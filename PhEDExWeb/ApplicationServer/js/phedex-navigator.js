/* PHEDEX.Navigator
 * Navigation widget for the application.  Allows user to input PhEDEx
 * entities ("Targets") and view widgets ("Pages") associated with them.
 * Uses PHEDEX.Core.Widget.Registry to build menus and construct
 * widgets.  Also defines the "Global Filter", which allows the user to
 * type in name:value pairs which are passed to the active widget to
 * apply filters.
*/
PHEDEX.namespace("Navigator");
PHEDEX.Navigator=(function() {
  // private properties
  
  // _target_types
  // hash of targets keyed by the target type name
  // value is an object with the following properties:
  //   name    : (string) the target name
  //   label   : (string) visible label for this target type
  var _target_types = {};
  var _cur_target_type = "";

  // _cur_target
  // the current target, set by the target selector
  var _cur_target = "";

  // _filter_str
  // a string containing filter arguments
  var _filter_str = "";
  // a hash containing the parsed filter key-value pairs
  var _filter = {};

  // private methods
  // parse _filter_str and set _filter
  var _parseFilter = function() {};

  // private events
  // fired whenever any navigation change occurs, passes (target, page, filter)
  var _navChangeEvent = new YAHOO.util.CustomEvent('NavChange');
  // fired when the target changed, passes (targetType, targetValue)
  var _targetChangeEvent = new YAHOO.util.CustomEvent('TargetChange');
  // fired when the page changed, passes (page)
  var _pageChangeEvent = new YAHOO.util.CustomEvent('PageChange');

  return {
    // public properties
    // init(el)
    // called when this object is created, takes the div element the navigator should be built in
    init: function(el) {
      // get registered target types
      // build TargetType selector for each type
      //   (get list of nodes from datasvc for node menu)
      //   (get list of groups from datasvc for group menu)
      // build GlobalFilter
      // get desired page state (or use defaults)
      // instantiate a widget
    },    
    // public methods
    addTarget: function(target) {},
    addPage: function(page) {},

    getTarget: function() {},
    getPage:   function() {},

    // call to change the target and/or page
    // this is used when  e.g. a context menu item within a widget is selected
    change: function(target, page) {},

    // public events
    // fired when the filter changes, passes (filter)
    filterChangeEvent: new YAHOO.util.CustomEvent('FilterChange')
  };
})();
