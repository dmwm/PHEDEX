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
  // package aliases
  var PxU = PHEDEX.Util;
  var PxR = PHEDEX.Core.Widget.Registry;

  //========================= Private Properties ======================
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
  var _target_selector_ids = {}; // map of type => div id of selector

  var _cur_widget;       // the current widget (Core.Widget.Registry object)
  var _widget_menu;      // Reference to YUI menu object for widgets
  var _cur_widget_obj;   // Current widget
  // FIXME: save *only* the current widget object, use Core.Widget to get other info?

  // _cur_filter
  // a string containing filter arguments
  var _cur_filter = "";
  // a hash containing the parsed filter key-value pairs
  var _parsed_filter = {};

  //========================= Private Methods =========================
  // The following are defined dynamically below
  var _updateTargetTypeGUI = function() {};
  var _updateTargetGUI     = function() {};

  var _initTypeSelector = function(el, cfg) {
    var typediv = PxU.makeChild(el, 'div', { id: 'phedex-nav-type', 
					     className:'phedex-nav-component'});
    
    // get registered target types and store them with optional config
    // params
    var types = PxR.getInputTypes();
    for (var type in types) {
      type = types[type];
      var obj = { 'name': type, 'label': type, 'order': Number.POSITIVE_INFINITY };
      var opts = cfg[type] || {};
      YAHOO.lang.augmentObject(obj, opts, true);
      _target_types[type] = obj;
    }

    // sort types by object params
    YAHOO.log('types 1: '+YAHOO.lang.dump(types));
    types.sort(function(a,b) {
      return _target_types[a].order - _target_types[b].order;
    });
    YAHOO.log('types 2: '+YAHOO.lang.dump(types));

    // build menu items in sorted order
    var menu_items = [];
    for (var type in types) {
      type = types[type];
      var obj = _target_types[type];
      menu_items.push({ 'text':obj.label, 'value':obj.name } );
    }

    _cur_target_type = menu_items[0].value;
    var label = menu_items[0].text;

    var menu = new YAHOO.widget.Button({ type:"menu",
					 label:label,
					 menu:menu_items,
					 container:typediv });
    var onSelectedMenuItemChange = function (event) {
      var menu_item = event.newValue;
      var type = menu_item.value;
      _setState({'type':type});
    };

    _updateTargetTypeGUI = function() {
      menu.set("label", _target_types[_cur_target_type].label);
    };
    menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _initTargetSelectors = function(el) {
    var targetdiv = PxU.makeChild(el, 'div', {id:'phedex-nav-target', 
					      className:'phedex-nav-component phedex-nav-target'});
    for (var t in _target_types) {
      // TODO:  possible to call a vairable function name?
      var id;
      if (t == 'node') {
	id = _initNodeSelector(targetdiv);
      } else if (t == 'none') {
	id = _initNoneSelector(targetdiv);
      } else {
	id = _initTextSelector(targetdiv, t);
      }
      _target_selector_ids[t] = id;
    }
    _updateTargetSelector(_cur_target_type);
  };
  
  var _node_ds; // YAHOO.util.LocalDataSource
  var _initNodeSelector = function(el) {
    var id = 'phedex-nav-target-nodesel';
    var nodesel = PxU.makeChild(el, 'div', {'id':id, 
					    'className':'phedex-nav-component'});
    var makeNodeList = function(data) {
      data = data.node;
      var nodelist = [];
      for (var node in data) {
	nodelist.push(data[node].name);
      }
      _node_ds = new YAHOO.util.LocalDataSource(nodelist);
      _buildNodeSelector(nodesel);
    };
    PHEDEX.Datasvc.Call({ api: 'nodes', callback: makeNodeList });
    return id;
  };

  var _buildNodeSelector = function(div) {
    var input = PxU.makeChild(div, 'input', { type:'text' });
    var container = PxU.makeChild(div, 'div');
    var auto_comp = new YAHOO.widget.AutoComplete(input, container, _node_ds);
    auto_comp.prehighlightClassName = "yui-ac-prehighlight";
    auto_comp.useShadow = true;
    auto_comp.forceSelection = true;
    auto_comp.queryMatchCase = false;
    auto_comp.queryMatchContains = true;
    var nodesel_callback = function(type, args) {
      var node = args[2];
      _setState({'target':node});
    }
    auto_comp.itemSelectEvent.subscribe(nodesel_callback);

    _updateTargetGUI = function() {
      input.value = _cur_target;
    };
  };

  var _initNoneSelector = function(el) {
    var id = 'phedex-nav-target-none';
    var sel = PxU.makeChild(el, 'div', {'id':id, 'className':'phedex-nav-component'});
    _updateTargetGUI = function() {
      _cur_target = 'none';
    };
    return id;
  };

  var _initTextSelector = function(el, type) {
    var id = 'phedex-nav-target-'+type;
    var sel = PxU.makeChild(el, 'div', {'id':id, 'className':'phedex-nav-component'});
    var input = PxU.makeChild(sel, 'input', { type:'text' });
    _updateTargetGUI = function() {
      input.value = _cur_target;
    };
    return id;
  };
  
  var _getWidgetMenuItems = function(type) {
    var widgets = PxR.getWidgetsByInputType(type);
    var menu_items = [];
    for (var w in widgets) {
      w = widgets[w];
      menu_items.push({ text:w.label, value:w } );
    }
    return menu_items;
  };
  
  var _initWidgetSelector = function(el) {
    var widgetdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-widget', className:'phedex-nav-component' });

    var menu_items = _getWidgetMenuItems(_cur_target_type);
    _cur_widget = menu_items[0].value;
    var label =   menu_items[0].text;

    _widget_menu = new YAHOO.widget.Button({ 'type':"menu",
					     'label':label,
					     'menu':menu_items,
					     'container':widgetdiv });
    
    // update state on menu selections
    var onSelectedMenuItemChange = function (event) {
      var menu_item = event.newValue;
      var widget = menu_item.value;
      _setState({'widget':widget});
    };
    _widget_menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _updateWidgetGUI = function(widget) {
    _widget_menu.set("label", widget.label);
  };
  
  var _updateWidgetMenu = function(type) {
//    YAHOO.log('type: '+type);
    var menu_items = _getWidgetMenuItems(type);
//    YAHOO.log('menu_items: '+YAHOO.lang.dump(menu_items));
    var widget = menu_items[0].value; // save first value now; passing to addItems alters structure
    var menu = _widget_menu.getMenu(); // _widget_menu is actually a button...
    if (YAHOO.util.Dom.inDocument(menu.element)) {
      menu.clearContent();
      menu.addItems(menu_items);
      menu.render();
//      YAHOO.log('menu rebuild: '); //+YAHOO.lang.dump(menu.itemData));
    } else {
//      YAHOO.log('menu assign: '); //+YAHOO.lang.dump(menu.itemData));
      menu.itemData = menu_items;
    }
    _updateWidgetGUI(widget); // set menu to first item
    return widget;
  };

  var _initGlobalFilter = function(el) {
    var filterdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter', 
					       className:'phedex-nav-component phedex-nav-filter' });
    var input = PxU.makeChild(filterdiv, 'input', 
			      { id: 'phedex-nav-filter-input', 
				className:'phedex-nav-filter-input',
				type: 'text' });
    var filterpaneldiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter-panel', 
						    className:'phedex-nav-component phedex-nav-link'});
  };

  var _initPermaLink = function(el) {
    var linkdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-link', 
					     className:'phedex-nav-component phedex-nav-link' });
    var a = PxU.makeChild(linkdiv, 'a',
			  { id:'phedex-nav-filter-link',
			    innerHTML:'Link',
			    href:'#' });
  };

  /* Set the state of the navigator.  If the state has changed, fire
     the _fireNavChange event.  Note: changes to navigator state *must*
     pass through this function! */
  var _setState = function(state) {
    var changed = 0;
    if (state.type)   { changed = _setTargetType(state) || changed; }
    if (state.target) { changed = _setTarget(state)     || changed; }
    if (state.widget) { changed = _setWidget(state)     || changed; }
    if (changed)      { _fireNavChange(); }
  };

  /* Fire the navigator change event with the current state */
  var _fireNavChange = function() { 
    _navChangeEvent.fire({'type'  :_cur_target_type,
			  'target':_cur_target,
			  'widget':_cur_widget,
			  'filter':_cur_filter});
  }

  /* Below are the individual _set{state} funcitons.  They must not be
     called execpt through _setState, otherwise widget construction is
     bypassed! */

  /* TODO: hidden/visible a wise way to manage these elements? I don't
     want to rebuild them on every target-chagne, but maybe there's a
     better way to put them out of the way... */
  var _setTargetType = function(state) {
    var type = state.type;
    var old = _cur_target_type;
    if (!type) { type = _cur_target_type; }
    else       { _cur_target_type = type; }
    
    if (old != _cur_target_type) {
      var new_widget = _updateWidgetMenu(type);     // make a new widget menu, returns the default selection
      if (!state.widget) { state.widget = new_widget; }
      var new_target = _updateTargetSelector(type); // get a new target selector, returns default selection
      if (!state.target) { state.target = new_target; }
      _updateTargetSelector(_cur_target_type);
      _updateTargetTypeGUI();
      _targetTypeChangeEvent.fire({'old':old,'cur':_cur_target_type});
      return 1;
    } else { return 0; }
  };

  var _updateTargetSelector = function(type) {
    var div = document.getElementById('phedex-nav-target');
    // Hide all selectors
    var children = YAHOO.util.Dom.getChildren(div);
    YAHOO.util.Dom.batch(children, function(c) { c.style.visibility = 'hidden'; c.style.position = 'absolute'});
    // Show the one we want
    var id = _target_selector_ids[type];
    var el = document.getElementById(id);
    el.style.visibility = 'visible';
    el.style.position = 'relative';
    // TODO: return value of active selector
    return null;
  };

  var _setTarget = function(state) {
    var target = state.target;
    var old = _cur_target;
    if (!target) { target = _cur_target; }
    else         { _cur_target = target; }

    if (old != _cur_target) {
      _updateTargetGUI();
      _targetChangeEvent.fire({'old':old,'cur':_cur_target});
      return 1;
    } else { return 0; }
  };

  var _setWidget = function(state) {
    var widget = state.widget;
    var old = _cur_widget;
    if (!widget) { widget = _cur_widget; }
    else         { _cur_widget = widget; }

    if (old != _cur_widget) {
      _updateWidgetGUI(_cur_widget);
      _widgetChangeEvent.fire({'old':old,'cur':_cur_widget});
      return 1;
    } else { return 0; }
  };

  // For now, just check that all parameters are set
  var _validConstruction = function() {
    if (_cur_target_type == 'none') {
      if (_cur_target_type && _cur_widget) { return true; }
      else { return false; }
    } else {
      // TODO:  careful validation of targets goes here...  function from the registry?
      if (_cur_target_type && _cur_target && _cur_widget) { return true; }
      else { return false; }
    }
  };

  // parse _cur_filter and set _filter
  var _parseFilter = function() {};

  //========================= Private Events ==========================
  // TODO:  Make public?
  // fired whenever any navigation change occurs, passes the new (type, target, widget, filter)
  var _navChangeEvent = new YAHOO.util.CustomEvent('NavChange');
  // fired when the target type changed, passes {prev:, cur:}
  var _targetTypeChangeEvent = new YAHOO.util.CustomEvent('TargetTypeChange');
  // fired when the target changed, passes {prev:, cur:}
  var _targetChangeEvent = new YAHOO.util.CustomEvent('TargetChange');
  // fired when the widget changed, passes {prev:, cur:}
  var _widgetChangeEvent = new YAHOO.util.CustomEvent('WidgetChange');
  // fired when the filter changed, passes (old_widget, new_widget)
  var _filterChangeEvent = new YAHOO.util.CustomEvent('FilterChange');

  //========================= Event Subscriptions =====================
  // _navChangeEvent : on this event, we build a widget!
  var _nav_construct = false;
  _navChangeEvent.subscribe(function(evt, args) {
    args = args[0];
    YAHOO.log("NavChange:  type="+args.type+" target="+args.target+
	      " widget="+args.widget.widget+" filter="+args.filter,
	      'info', 'Navigator');

    // out with the old...
    if (_cur_widget_obj) { 
      _cur_widget_obj.destroy();
      _cur_widget_obj = null;
    }

    // in with the new... (maybe)
    if (_validConstruction()) {
      YAHOO.log("NavChange:  construct type="+_cur_target_type+" target="+_cur_target+
		" widget="+_cur_widget.widget,
		'info', 'Navigator');
      _nav_construct = true; // prevent interception of our own construct event
      var widget = PxR.construct(_cur_widget.widget, _cur_target_type, _cur_target, 
				 'phedex-main', { window: false });
      _nav_construct = false;
      _cur_widget_obj = widget;
      widget.update();
    }
  });

  /* PHEDEX.Core.Registry.beforeConstructEvent :
     On this event, something triggered a widget change.  If it was
     us, do nothing.  If it was something else, (e.g. context menu click)
     then we need to update our state and GUI elements.  We do this by
     intercepting the construct event, returning false to cancel the
     construct(), and triggering our own construct event after we've
     updated */
  PxR.beforeConstructEvent.subscribe(function(evt, args) {
    if (_nav_construct) { return true; } // prevent interception of our own construct event
    args = args[0];
    YAHOO.log("heard beforeConstruct for widget="+args.widget.widget+" type="+args.type+" data="+args.data,
	      'info', 'Navigator');
    _setState({'type':args.type, 
	       'widget':args.widget, 
	       'target':args.data });
    return false; // prevents Core.Widget.Registry from constructing
  });

  return {
    //========================= Public Methods ==========================
    // init(el, opts)
    //   called when this object is created
    //   div: element the navigator should be built in
    //   opts:  options for the navigator, takes the following:
    //     'typeconfig'   : an array of objects for organizing the type menu.
    //     'widgetconfig' : an array of objects for organizing the widget menu.
    init: function(el, cfg) {
      // build the type selection menu
      _initTypeSelector(el, cfg.typecfg);

      // build TargetType selector for each type
      _initTargetSelectors(el);

      // build Widget Selector for each type
      _initWidgetSelector(el, cfg.widgetcfg);

      // build GlobalFilter
      _initGlobalFilter(el);

      // build Permalink
      _initPermaLink(el);

      // get desired widget state (or use defaults)
      // TODO:  get from HistoryManager

      // instantiate a widget
      YAHOO.log("initial state type="+_cur_target_type+" target="+_cur_target+
		" widget="+_cur_widget.widget,
		'info', 'Navigator');
      _fireNavChange();
    },

    // TODO:  is there a use case for any of these?
    // public methods
    addTarget: function(target) {},
    addWidget: function(widget) {},

    getTarget: function() {},
    getWidget:   function() {},

    // call to change the target and/or widget
    // this is used when  e.g. a context menu item within a widget is selected
    change: function(target, widget) {},

    //========================= Public Events ===========================
    // fired when the filter changes, passes (filter)
    filterChangeEvent: new YAHOO.util.CustomEvent('FilterChange')
  };
})();
