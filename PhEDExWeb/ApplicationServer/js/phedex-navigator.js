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

  // _cur_target
  // the current target, set by the target selector
  var _cur_target = "";

  // _cur_page
  // the current page, set by the page selector
  var _cur_page = "";

  // _cur_filter
  // a string containing filter arguments
  var _cur_filter = "";
  // a hash containing the parsed filter key-value pairs
  var _parsed_filter = {};

  // private methods
  var _initTypeSelector = function(el) {
    var typediv = PxU.makeChild(el, 'div', { id: 'phedex-nav-type'});
    
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
      this.set("label", type);
      _setTargetType(type);
    };
    menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _initTargetSelectors = function(el) {
    var targetdiv = PxU.makeChild(el, 'div', {id:'phedex-nav-target'});
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
    var nodesel = PxU.makeChild(el, 'div', {id:'phedex-nav-target-nodesel'});
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
  };

  var _initTextSelector = function(el, type) {
    var sel = PxU.makeChild(el, 'div', {id:'phedex-nav-target-'+type});
    var input = PxU.makeChild(sel, 'input', { type:'text' });
  };

  var _initPageSelector = function(el) {
    var pagediv = PxU.makeChild(el, 'div', { id:'phedex-nav-page' });
    
    var widgets = PxR.getWidgetsByInputType(_cur_target_type);
    YAHOO.log('widgets='+YAHOO.lang.dump(widgets));
    var menu_data = [];
    for (var w in widgets) {
      w = widgets[w];
      menu_data.push({ text:w.label, value:w } );
    }
    _cur_page = widgets[0].widget;

    var menu = new YAHOO.widget.Button({ type:"menu",
					 label:widgets[0].label,
					 menu:menu_data,
					 container:pagediv });
    var onSelectedMenuItemChange = function (event) {
      var oMenuItem = event.newValue;
      this.set("label", oMenuItem.cfg.getProperty("text"));
      var page = oMenuItem.value.widget;
      _setPage(page);
    };
    menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _initGlobalFilter = function(el) {
    var filterdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter' });
    var input = PxU.makeChild(filterdiv, 'input', 
			      { id: 'phedex-nav-filter-input',
				type: 'text' });
  };

  var _initPermaLink = function(el) {
    var linkdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-link' });
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
      _targetTypeChangeEvent.fire({'old':old,'cur':_cur_target_type});
    }
  };

  var _setTarget = function(target) {
    var old = _cur_target;
    if (!target) { target = _cur_target; }
    else       { _cur_target = target; }

    if (old != _cur_target_type) {
      _targetChangeEvent.fire({'old':old,'cur':_cur_target});
    }
  };

  var _setPage = function(page) {
    var old = _cur_page;
    if (!page) { page = _cur_page; }
    else       { _cur_page = page; }

    if (old != _cur_target_type) {
      _pageChangeEvent.fire({'old':old,'cur':_cur_page});
    }
  };

  // parse _cur_filter and set _filter
  var _parseFilter = function() {};

  // private events
  // fired whenever any navigation change occurs, passes the new (type, target, page, filter)
  var _navChangeEvent = new YAHOO.util.CustomEvent('NavChange');
  // fired when the target type changed, passes {prev:, cur:}
  var _targetTypeChangeEvent = new YAHOO.util.CustomEvent('TargetTypeChange');
  // fired when the target changed, passes {prev:, cur:}
  var _targetChangeEvent = new YAHOO.util.CustomEvent('TargetChange');
  // fired when the page changed, passes {prev:, cur:}
  var _pageChangeEvent = new YAHOO.util.CustomEvent('PageChange');
  // fired when the filter changed, passes (old_page, new_page)
  var _filterChangeEvent = new YAHOO.util.CustomEvent('FilterChange');

  // event binding
  var _fireNavChange = function() { 
    _navChangeEvent.fire({'type':_cur_target_type,
			  'target':_cur_target,
			  'page':_cur_page,
			  'filter':_cur_filter});
  }
  _targetTypeChangeEvent.subscribe(_fireNavChange);
  _targetChangeEvent.subscribe(_fireNavChange);
  _pageChangeEvent.subscribe(_fireNavChange);
  _filterChangeEvent.subscribe(_fireNavChange);

  // on nav change, validate current values and (maybe) instantiage widget
  _navChangeEvent.subscribe(function(evt, args) {
    args = args[0];
    YAHOO.log("NavChange:  type="+args.type+" target="+args.target+
	      " page="+args.page+" filter="+args.filter,
	      'info', 'Navigator');
    // TODO: careful validation goes here...
    if (_cur_page && _cur_target_type && _cur_target) {
    YAHOO.log("NavChange:  construct type="+_cur_target_type+" target="+_cur_target+
	      " widget="+_cur_page,
	      'info', 'Navigator');
      var widget = PxR.construct(_cur_page, _cur_target_type, _cur_target, 'phedex-main');
      widget.update();
    }
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

      // build Page Selector for each type
      _initPageSelector(el);

      // build GlobalFilter
      _initGlobalFilter(el);
      
      // build Permalink
      _initPermaLink(el);

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
