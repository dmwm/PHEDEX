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

  // private properties
  
  // _target_types
  // hash of targets keyed by the target type name
  // value is an object with the following properties:
  //   name    : (string) the target name
  //   label   : (string) visible label for this target type
  var _target_types = {};
  var _cur_target_type = "";
  var _update_target_type_gui = function() {};

  // _cur_target
  // the current target, set by the target selector
  var _cur_target = "";

  // function reference: sets the graphical representation to _cur_target
  var _update_target_gui = function() {};

  // _cur_widget
  // the current widget, set by the widget selector
  var _cur_widget = "";
  var _cur_widget_obj;
  var _update_widget_gui = function() {};

  // _cur_filter
  // a string containing filter arguments
  var _cur_filter = "";
  // a hash containing the parsed filter key-value pairs
  var _parsed_filter = {};

  // private methods
  var _initTypeSelector = function(el) {
    var typediv = PxU.makeChild(el, 'div', { id: 'phedex-nav-type', className:'phedex-nav-component'});
    
    // get registered target types
    var types = PxR.getInputTypes();
    types = ['node', 'group', 'block', 'blah']; // XXX TEST
    var menu_data = [];
    for (var t in types) {
      var text = types[t];
      _target_types[text] = { name: text, label: text };
      menu_data.push({ text:text, value:text } );
    }
    _cur_target_type = types[0];

    var menu = new YAHOO.widget.Button({ type:"menu",
					 label:_cur_target_type,
					 menu:menu_data,
					 container:typediv });
    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      var type = oMenuItem.cfg.getProperty("text");
      _setTargetType(type);
    };

    _update_target_type_gui = function() {
      menu.set("label", _cur_target_type);
    };
    menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _initTargetSelectors = function(el) {
    var targetdiv = PxU.makeChild(el, 'div', {id:'phedex-nav-target', className:'phedex-nav-component phedex-nav-target'});
    for (var t in _target_types) {
      // TODO:  possible to call a vairable function name?
      if (t == 'node') {
	_initNodeSelector(targetdiv);
      } else {
	_initTextSelector(targetdiv, t);
      }
    }
  };

  // Function to get the current target from whatever control is active
  var _getTarget = function() { throw new Error("_getTarget not defined"); };

  var _node_ds; // YAHOO.util.LocalDataSource
  var _initNodeSelector = function(el) {
    var nodesel = PxU.makeChild(el, 'div', {id:'phedex-nav-target-nodesel', className:'phedex-nav-component'});
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
      _setTarget(node);
    }
    auto_comp.itemSelectEvent.subscribe(nodesel_callback);

    _update_target_gui = function() {
      input.value = _cur_target;
    };
  };

  var _initTextSelector = function(el, type) {
    var sel = PxU.makeChild(el, 'div', {id:'phedex-nav-target-'+type, className:'phedex-nav-component'});
    var input = PxU.makeChild(sel, 'input', { type:'text' });
    _update_target_gui = function() {
      input.value = _cur_target;
    };
  };

  var _initWidgetSelector = function(el) {
    var widgetdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-widget', className:'phedex-nav-component' });

    var widgets = PxR.getWidgetsByInputType(_cur_target_type);
    YAHOO.log('widgets='+YAHOO.lang.dump(widgets));
    var menu_data = [];
    for (var w in widgets) {
      w = widgets[w];
      menu_data.push({ text:w.label, value:w } );
    }
    _cur_widget = widgets[0].widget;

    var menu = new YAHOO.widget.Button({ type:"menu",
					 label:widgets[0].label,
					 menu:menu_data,
					 container:widgetdiv });
    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      var widget = oMenuItem.value.widget;
      _setWidget(widget);
    };

    _update_widget_gui = function() {
      var label;
      /* FIXME: ugly... I have to iterate through the menu_data to get
        the relation between widget name (_cur_widget) and widget label, which
        is all the menu understands... */
      for (var m in menu_data) {
	m = menu_data[m];
	if (m.value.widget == _cur_widget) {
	  menu.set("label", m.text);
	}
      }
    };
    menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _initGlobalFilter = function(el) {
    var filterdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter', className:'phedex-nav-component phedex-nav-filter' });
    var input = PxU.makeChild(filterdiv, 'input', 
			      { id: 'phedex-nav-filter-input', className:'phedex-nav-filter-input',
				type: 'text' });
    var filterpaneldiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter-panel', className:'phedex-nav-component phedex-nav-link', innerHTML:'(Global Filter Control Placeholder)' });
  };

  var _initPermaLink = function(el) {
    var linkdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-link', className:'phedex-nav-component phedex-nav-link' });
    var a = PxU.makeChild(linkdiv, 'a',
			  { id:'phedex-nav-filter-link',
			    innerHTML:'Link',
			    href:'#' });
  };

  /* TODO: hidden/visible a wise way to manage these elements? I don't
     want to rebuild them on every target-chagne, but maybe there's a
     better way to put them out of the way... */
  var _setTargetType = function(type) {
    var old = _cur_target_type;
    if (!type) { type = _cur_target_type; }
    else       { _cur_target_type = type; }

    var div = document.getElementById('phedex-nav-target');
    // Hide all selectors
    var children = YAHOO.util.Dom.getChildren(div);
    YAHOO.util.Dom.batch(children, function(c) { c.style.visibility = 'hidden'; c.style.position = 'absolute'});
    // Show the one we want
    var id;
    if (type == 'node') { id = 'phedex-nav-target-nodesel'; }
    else                { id = 'phedex-nav-target-'+type }
    var el = document.getElementById(id);
    el.style.visibility = 'visible';
    el.style.position = 'relative';
    
    if (old != _cur_target_type) {
      _update_target_type_gui();
      _targetTypeChangeEvent.fire({'old':old,'cur':_cur_target_type});
    }
  };

  var _setTarget = function(target) {
    var old = _cur_target;
    if (!target) { target = _cur_target; }
    else       { _cur_target = target; }

    if (old != _cur_target) {
      _update_target_gui();
      _targetChangeEvent.fire({'old':old,'cur':_cur_target});
    }
  };

  var _setWidget = function(widget) {
    var old = _cur_widget;
    if (!widget) { widget = _cur_widget; }
    else       { _cur_widget = widget; }

    if (old != _cur_target_type) {
      _update_widget_gui();
      _widgetChangeEvent.fire({'old':old,'cur':_cur_widget});
    }
  };

  // parse _cur_filter and set _filter
  var _parseFilter = function() {};

  // private events
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

  // event binding
  var _fireNavChange = function() { 
    _navChangeEvent.fire({'type':_cur_target_type,
			  'target':_cur_target,
			  'widget':_cur_widget,
			  'filter':_cur_filter});
  }
  _targetTypeChangeEvent.subscribe(_fireNavChange);
  _targetChangeEvent.subscribe(_fireNavChange);
  _widgetChangeEvent.subscribe(_fireNavChange);
  _filterChangeEvent.subscribe(_fireNavChange);

  // on nav change, validate current values and (maybe) instantiate widget
  var _nav_construct = false;
  _navChangeEvent.subscribe(function(evt, args) {
    args = args[0];
    YAHOO.log("NavChange:  type="+args.type+" target="+args.target+
	      " widget="+args.widget+" filter="+args.filter,
	      'info', 'Navigator');
    // TODO: careful validation goes here...
    if (_cur_widget && _cur_target_type && _cur_target) {
      YAHOO.log("NavChange:  construct type="+_cur_target_type+" target="+_cur_target+
		" widget="+_cur_widget,
		'info', 'Navigator');
      if (_cur_widget_obj) { _cur_widget_obj.destroy(); }
      _nav_construct = true; // prevent interception of our own construct event
      var widget = PxR.construct(_cur_widget, _cur_target_type, _cur_target, 
				 'phedex-main', { window: false });
      _nav_construct = false;
      _cur_widget_obj = widget;
      widget.update();
    }
  });

  PxR.beforeConstructEvent.subscribe(function(evt, args) {
    if (_nav_construct) { return true; } // prevent interception of our own construct event
    args = args[0];
    YAHOO.log("heard beforeConstruct for widget="+args.widget+" type="+args.type+" data="+args.data,
	      'info', 'Navigator');
    // TODO:  change the navigator GUI elements
    _setWidget(args.widget);
    _setTargetType(args.type);
    _setTarget(args.data);
    return false; // prevents Core.Widget.Registry from constructing
  });

  return {
    // public properties
    // init(el)
    // called when this object is created, takes the div element the navigator should be built in
    init: function(el) {
      // build the type selection menu
      _initTypeSelector(el);

      // build TargetType selector for each type
      _initTargetSelectors(el);
      _setTargetType();

      // build Widget Selector for each type
      _initWidgetSelector(el);

      // build GlobalFilter
      _initGlobalFilter(el);

      // build Permalink
      _initPermaLink(el);

      // get desired widget state (or use defaults)
      // instantiate a widget
    },    
    // public methods
    addTarget: function(target) {},
    addWidget: function(widget) {},

    getTarget: function() {},
    getWidget:   function() {},

    // call to change the target and/or widget
    // this is used when  e.g. a context menu item within a widget is selected
    change: function(target, widget) {},

    // public events
    // fired when the filter changes, passes (filter)
    filterChangeEvent: new YAHOO.util.CustomEvent('FilterChange')
  };
})();
