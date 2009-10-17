/* PHEDEX.Navigator
 * Navigation widget for the application.  Allows user to input PhEDEx
 * entities ("Targets") and view widgets ("Pages") associated with them.
 * Uses PHEDEX.Core.Widget.Registry to build menus and construct
 * widgets.  Also defines the "Global Filter", which allows the user to
 * type in name:value pairs which are passed to the active widget to
 * apply filters.
*/
PHEDEX.namespace("Navigator");
PHEDEX.Navigator = (function() {
    // package aliases
    var PxU = PHEDEX.Util;
    var PxR = PHEDEX.Core.Widget.Registry;
    var PxD = PHEDEX.Datasvc;

    //========================= Private Properties ======================
    var _instances = {};    //To store the instances information
    var _cur_instance = ""; //The current selected instance

    // _target_types
    // hash of targets keyed by the target type name
    // value is an object with the following properties:
    //   name    : (string) the target name
    //   label   : (string) visible label for this target type
    var _target_types = {};
    var _cur_target_type = ""; // the current target type

    var _cur_target = "";          // the current target, set by the target selector
    var _target_selector_ids = {}; // map of type => div id of selector

    var _cur_widget;       // The current widget (Core.Widget.Registry object)
    var _widget_menu;      // Reference to YUI menu object for widgets
    var _cur_widget_obj;   // Current widget object
    // FIXME: save *only* the current widget object, use Core.Widget to get other info?

    var _cur_filter = "";     // a string containing filter arguments
    var _parsed_filter = {};  // a hash containing the parsed filter key-value pairs

    //========================= Private Methods =========================
    // The following are defined dynamically below
    var _updateTargetTypeGUI = function() { };
    var _updateTargetGUI = function() { };
    var _updateInstanceGUI = function() { };
    var _updateLinkGUI = function() { };

    var _initInstanceSelector = function(el) {
        var instances = PxD.Instances(); // Get current instances
        if (!instances) { return; } //Something is wrong.. So dont process further..
        var typediv = PxU.makeChild(el, 'div', { id: 'phedex-nav-instance', className: 'phedex-nav-component' });
        var menu_items = [];
        var indx = 0;
        for (indx = 0; indx < instances.length; indx++) {
            var jsonInst = instances[indx];
            _instances[jsonInst.instance] = jsonInst;
            menu_items.push({ 'text': jsonInst.name, 'value': jsonInst.instance });
        }

        _cur_instance = menu_items[0].value;
        var label = menu_items[0].text;

        var menu = new YAHOO.widget.Button({ type: "menu",
            label: label,
            menu: menu_items,
            container: typediv
        });

        var onSelectedMenuItemChange = function(event) {
            var menu_item = event.newValue;
            var instanceVal = menu_item.value;
            _addToHistory({ 'instance': instanceVal });
        };

        _updateInstanceGUI = function() {
            menu.set("label", _instances[_cur_instance].name);
        };
        menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
    };


    var _initTypeSelector = function(el, cfg) {
        var typediv = PxU.makeChild(el, 'div', { id: 'phedex-nav-type',
            className: 'phedex-nav-component'
        });

        // get registered target types and store them with optional config params
        var types = PxR.getInputTypes();
        for (var type in types) {
            type = types[type];
            var obj = { 'name': type, 'label': type, 'order': Number.POSITIVE_INFINITY };
            var opts = cfg[type] || {};
            YAHOO.lang.augmentObject(obj, opts, true);
            _target_types[type] = obj;
        }

        // sort types by object params
        YAHOO.log('types 1: ' + YAHOO.lang.dump(types));
        types.sort(function(a, b) {
            return _target_types[a].order - _target_types[b].order;
        });
        YAHOO.log('types 2: ' + YAHOO.lang.dump(types));

        // build menu items in sorted order
        var menu_items = [];
        for (var type in types) {
            type = types[type];
            var obj = _target_types[type];
            menu_items.push({ 'text': obj.label, 'value': obj.name });
        }

        _cur_target_type = menu_items[0].value;
        var label = menu_items[0].text;

        var menu = new YAHOO.widget.Button({ type: "menu",
            label: label,
            menu: menu_items,
            container: typediv
        });
        var onSelectedMenuItemChange = function(event) {
            var menu_item = event.newValue;
            var type = menu_item.value;
            _addToHistory({ 'type': type });
        };

        _updateTargetTypeGUI = function() {
            menu.set("label", _target_types[_cur_target_type].label);
        };
        menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
    };

    var _initTargetSelectors = function(el) {
        var targetdiv = PxU.makeChild(el, 'div', { id: 'phedex-nav-target',
            className: 'phedex-nav-component phedex-nav-target'
        });
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

    var _buildNodeEvent = new YAHOO.util.CustomEvent('BuildNode');
    _buildNodeEvent.subscribe(function(type, args) { _afterBuild(); });

    /**
    * @method _afterBuild
    * @description This is called after datatable is rendered or modified.
    */
    var _afterBuild = function() {
        var currentState = YAHOO.util.History.getCurrentState("page"); //Get the current state
        if (currentState) {
            _setState(currentState); //Set the current state on page
        }
        else {
            _fireNavChange(); //Fire the page to load the current settings
        }
    };

    var _node_ds; // YAHOO.util.LocalDataSource
    var _initNodeSelector = function(el) {
        var id = 'phedex-nav-target-nodesel';
        var nodesel = PxU.makeChild(el, 'div', { 'id': id,
            'className': 'phedex-nav-component'
        });
        var makeNodeList = function(data) {
            data = data.node;
            var nodelist = [];
            for (var node in data) {
                nodelist.push(data[node].name);
            }
            _node_ds = new YAHOO.util.LocalDataSource(nodelist);
            _buildNodeSelector(nodesel);
            _buildNodeEvent.fire(); //Now the data service call is answered. So, set the status of page.
        };
        PHEDEX.Datasvc.Call({ api: 'nodes', callback: makeNodeList });
        return id;
    };

    var _buildNodeSelector = function(div) {
        var input = PxU.makeChild(div, 'input', { type: 'text' });
        var container = PxU.makeChild(div, 'div');
        var auto_comp = new YAHOO.widget.AutoComplete(input, container, _node_ds);
        auto_comp.prehighlightClassName = "yui-ac-prehighlight";
        auto_comp.useShadow = true;
        auto_comp.forceSelection = true;
        auto_comp.queryMatchCase = false;
        auto_comp.queryMatchContains = true;
        var nodesel_callback = function(type, args) {
            var node = args[2];
            _addToHistory({ 'target': node });
        }
        auto_comp.itemSelectEvent.subscribe(nodesel_callback);

        _updateTargetGUI = function() {
            input.value = _cur_target;
        };
    };

    var _initNoneSelector = function(el) {
        var id = 'phedex-nav-target-none';
        var sel = PxU.makeChild(el, 'div', { 'id': id, 'className': 'phedex-nav-component' });
        _updateTargetGUI = function() {
            _cur_target = 'none';
        };
        return id;
    };

    var _initTextSelector = function(el, type) {
        var id = 'phedex-nav-target-' + type;
        var sel = PxU.makeChild(el, 'div', { 'id': id, 'className': 'phedex-nav-component' });
        var input = PxU.makeChild(sel, 'input', { type: 'text' });
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
            menu_items.push({ text: w.label, value: w });
        }
        return menu_items;
    };

    var _initWidgetSelector = function(el) {
        var widgetdiv = PxU.makeChild(el, 'div', { id: 'phedex-nav-widget', className: 'phedex-nav-component' });

        var menu_items = _getWidgetMenuItems(_cur_target_type);
        _cur_widget = menu_items[0].value;
        var label = menu_items[0].text;

        _widget_menu = new YAHOO.widget.Button({ 'type': "menu",
            'label': label,
            'menu': menu_items,
            'container': widgetdiv
        });

        // update state on menu selections
        var onSelectedMenuItemChange = function(event) {
            var menu_item = event.newValue;
            var widget = menu_item.value;
            _addToHistory({ 'widget': widget });
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
    PHEDEX.Event.CreateGlobalFilter.fire(el);
  };

    var _initPermaLink = function(el) {
        var linkdiv = PxU.makeChild(el, 'div', { id: 'phedex-nav-link',
            className: 'phedex-nav-component phedex-nav-link'
        });
        var a = PxU.makeChild(linkdiv, 'a',
			  { id: 'phedex-nav-filter-link',
			      innerHTML: 'Link',
			      href: '#'
			  });
        _updateLinkGUI = function() {
            a.href = document.location.href; //Update the link with current browser URL
        };
    };

    var _defaultPageState = "";

    /**
    * @method _getWidget
    * @description This gets the widget given the state and widget name.
    */
    var _getWidget = function(state) {
        var indx = 0;
        var menu_items = _getWidgetMenuItems(state.type);
        for (indx = 0; indx < menu_items.length; indx++) {
            if (menu_items[indx].value.widget == state.widget) {
                return menu_items[indx].value;
            }
        }
        return null;
    };

    /**
    * @method _setState
    * @description This sets the state of the navigator. If the state has changed, fire _fireNavChange event.  
    * The changes to navigator state must pass through this function!is called by history navigate functinality 
    * to set the status in web page.
    * @param {String} pgstate String specifying the state of the page to be set.
    */
    var _setState = function(pgstate) {
        var state = null;
        if (!pgstate) {
            pgstate = _defaultPageState; //Set the state to default state
        }
        if (pgstate) {
            state = _parseQueryString(pgstate); //Parse the current history state and get the key and its values
            if (state.widget) {
                state.widget = _getWidget(state); //Get the widget given the widget name
            }
        }
        if (!state) { return; } //Do Nothing and return
        var changed = 0;
        if (state.instance) { changed = _setInstance(state) || changed; } //Update the instance state
        if (state.type) { changed = _setTargetType(state) || changed; }   //Update the target type state
        changed = _setTarget(state) || changed;                           //Update the target node state
        if (state.widget) { changed = _setWidget(state) || changed; }     //Update the widget state
        if (changed || (!changed && !_cur_widget_obj)) {
            _fireNavChange(); //Build widgte if there is any change in state
        }
    };

    /**
    * @method _parseQueryString
    * @description This parses the page query and return the key and its values.  
    * @param {String} strQuery specifies the state of the page to be set.
    */
    var _parseQueryString = function(strQuery) {
        var strTemp = "", indx = 0;
        var arrResult = {};
        var arrQueries = strQuery.split("&");
        for (indx = 0; indx < arrQueries.length; indx++) {
            strTemp = arrQueries[indx].split("=");
            if (strTemp[1].length > 0) {
                arrResult[strTemp[0]] = unescape(strTemp[1]);
            }
        }
        return arrResult;
    };

    var _initialPageState = YAHOO.util.History.getBookmarkedState("page") || '';
    YAHOO.util.History.register("page", _initialPageState, _setState);

    /**
    * @method _getCurrentState
    * @description This gets the current state of the web page for history maintenance.  
    * @param {Object} state specifies the current change made to the web page that has to be processed.
    */
    var _getCurrentState = function(state) {
        var strInstance = _cur_instance;
        var strType = _cur_target_type;
        var strTarget = _cur_target;
        var strWidget = '';
        if (_cur_widget) {
            strWidget = _cur_widget.widget; //Initialize with current widget value
        }
        if (state) {
            if (state.type) {
                strType = state.type;
                var menu_items = _getWidgetMenuItems(state.type); //This call is made to get default widget for the type
                if (menu_items) {
                    strWidget = menu_items[0].value.widget;
                }
            }
            if (state.instance) { strInstance = state.instance; }  //Update instance value if present
            if (state.target) { strTarget = state.target; }        //Update target value if present
            if (state.widget) { strWidget = state.widget.widget; } //Update widget value if present
        }
        var newState = 'instance=' + strInstance + '&type=' + strType + '&target=' + strTarget + '&widget=' + strWidget + '&filter=' + _cur_filter; //Form the query string
        return newState; // Return the string that specifies the state of the page
    }

    /**
    * @method _addToHistory
    * @description This adds the current state of the web page to history for further navigation.
    * @param {Object} state specifies the current change made to the web page that has to be processed.
    */
    var _addToHistory = function(state) {
        var newState, currentState;
        try {
            newState = _getCurrentState(state);
            currentState = YAHOO.util.History.getCurrentState("page");
            if (newState !== currentState) //Check if previous and current state are different to avoid looping
            {
                YAHOO.util.History.navigate("page", newState); //Add current state to history and set values
            }
        }
        catch (e) {
            _setState(newState); //In case YUI History doesnt work
        }
    };

    /**
    * @method _fireNavChange
    * @description This fires the navigator change event with the current state.
    */
    var _fireNavChange = function() {
        _updateLinkGUI(); //Update the permalink
        _navChangeEvent.fire({ 'type': _cur_target_type,
            'target': _cur_target,
            'widget': _cur_widget,
            'filter': _cur_filter
        });
    };

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
        else { _cur_target_type = type; }

        if (old != _cur_target_type) {
            var new_widget = _updateWidgetMenu(type);     // make a new widget menu, returns the default selection
            if (!state.widget) { state.widget = new_widget; }
            var new_target = _updateTargetSelector(type); // get a new target selector, returns default selection
            if (!state.target) { state.target = new_target; }
            _updateTargetSelector(_cur_target_type);
            _updateTargetTypeGUI();
            _targetTypeChangeEvent.fire({ 'old': old, 'cur': _cur_target_type });
            return 1;
        } else { return 0; }
    };

    var _updateTargetSelector = function(type) {
        var div = document.getElementById('phedex-nav-target');
        // Hide all selectors
        var children = YAHOO.util.Dom.getChildren(div);
        YAHOO.util.Dom.batch(children, function(c) { c.style.visibility = 'hidden'; c.style.position = 'absolute' });
        // Show the one we want
        var id = _target_selector_ids[type];
        var el = document.getElementById(id);
        el.style.visibility = 'visible';
        el.style.position = 'relative';
        // TODO: return value of active selector
        return null;
    };

    var _setInstance = function(state) {
        var old = _cur_instance;
        _cur_instance = state.instance;

        if (old != _cur_instance) {
            PxD.Instance(_cur_instance);
            _updateInstanceGUI();
            return 1;
        } else { return 0; }
    };

    var _setTarget = function(state) {
        if (!state.target) {
            state.target = "";
        }
        var old = _cur_target;
        _cur_target = state.target;

        if (old != _cur_target) {
            _updateTargetGUI();
            _targetChangeEvent.fire({ 'old': old, 'cur': _cur_target });
            return 1;
        } else { return 0; }
    };

    var _setWidget = function(state) {
        var widget = state.widget;
        var old = _cur_widget;
        if (!widget) { widget = _cur_widget; }
        else { _cur_widget = widget; }

        if (old != _cur_widget) {
            _updateWidgetGUI(_cur_widget);
            _widgetChangeEvent.fire({ 'old': old, 'cur': _cur_widget });
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
    var _parseFilter = function() { };

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
        YAHOO.log("NavChange:  type=" + args.type + " target=" + args.target +
	      " widget=" + args.widget.widget + " filter=" + args.filter,
	      'info', 'Navigator');

        // out with the old...
        if (_cur_widget_obj) {
            _cur_widget_obj.destroy();
            _cur_widget_obj = null;
        }

        // in with the new... (maybe)
        if (_validConstruction()) {
            YAHOO.log("NavChange:  construct type=" + _cur_target_type + " target=" + _cur_target +
		" widget=" + _cur_widget.widget,
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
        YAHOO.log("heard beforeConstruct for widget=" + args.widget.widget + " type=" + args.type + " data=" + args.data,
	      'info', 'Navigator');

        _addToHistory({ 'type': args.type,
            'widget': args.widget,
            'target': args.data
        });
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

            // Build the YUI menu button for instance selection
            _initInstanceSelector(el); 

            // Build the type selection menu
            _initTypeSelector(el, cfg.typecfg);

            // Build TargetType selector for each type
            _initTargetSelectors(el);

            // Build Widget Selector for each type
            _initWidgetSelector(el, cfg.widgetcfg);

            // Build GlobalFilter
            _initGlobalFilter(el);

            // Build Permalink
            _initPermaLink(el);

            // Get the current state that would also be default state for the page
            _defaultPageState = _getCurrentState(null); 
        },

        // TODO:  is there a use case for any of these?
        // public methods
        addTarget: function(target) { },
        addWidget: function(widget) { },

        getTarget: function() { },
        getWidget: function() { },

        // call to change the target and/or widget
        // this is used when  e.g. a context menu item within a widget is selected
        change: function(target, widget) { },

        //========================= Public Events ===========================
        // fired when the filter changes, passes (filter)
        filterChangeEvent: new YAHOO.util.CustomEvent('FilterChange')
    };
})();

//Use the Browser History Manager onReady method to initialize the application.
YAHOO.util.History.onReady(function() {
    CreateNavigator(); //Initializes the form
});

var divNav, cfgNav; //To store the navigator element and its configuration

/**
* @method InitializeNavigator
* @description This initializes the browser history management library.
* @param {HTML element} el element specifies element the navigator should be built in
* @param {Object} cfg Object specifies options for the navigator, takes the following:
* 'typeconfig'   : an array of objects for organizing the type menu.
* 'widgetconfig' : an array of objects for organizing the widget menu.
*/
function InitializeNavigator(el, cfg) {
    try {
        divNav = el;
        cfgNav = cfg;
        YAHOO.util.History.initialize("yui-history-field", "yui-history-iframe");
    }
    catch (e) {
        CreateNavigator();
    }
}

/**
* @method CreateNavigator
* @description This initializes the creation of navigator by passing the required parameters.
*/
function CreateNavigator() {
    PHEDEX.Navigator.init(divNav, cfgNav);
}