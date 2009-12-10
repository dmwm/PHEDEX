/* PHEDEX.Navigator
 * Navigation widget for the application.  Allows user to input PhEDEx
 * entities ("Targets") and view widgets ("Pages") associated with them.
 * Uses PHEDEX.Core.Widget.Registry to build menus and construct
 * widgets.  Also defines the "Global Filter", which allows the user to
 * type in name:value pairs which are passed to the active widget to
 * apply filters.
*/
PHEDEX.namespace('Navigator');
PHEDEX.Navigatornew = function(sandbox) {
  this.id = 'Navigator_'+PxU.Sequence();
  var _sbx = sandbox,
      PxD  = PHEDEX.Datasvc,

    //========================= Private Properties ======================
        _instances = {},    //To store the instances information
        _cur_instance = "", //The current selected instance

    // _target_types
    // hash of targets keyed by the target type name
    // value is an object with the following properties:
    //   name    : (string) the target name
    //   label   : (string) visible label for this target type
//         _target_types = {},
      _cur_target_type = "", // the current target type

      _cur_target = "",          // the current target, set by the target selector
//         _target_selector_ids = {}, // map of type => div id of selector

      _cur_widget,       // The current widget (Core.Widget.Registry object)
//         _widget_menu,      // Reference to YUI menu object for widgets
      _cur_widget_obj,   // Current widget object
    // FIXME: save *only* the current widget object, use Core.Widget to get other info?

      _cur_filter = "",     // a string containing filter arguments
      _parsed_filter = {},  // a hash containing the parsed filter key-value pairs

      _cur_widget_state,     // object that stores widget details obtained from permalink

      _hist_sym_sep = "+",    //This character separates the states in the history URL
      _hist_sym_equal = "~";  //This character indicates the state value

  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  this.state = {}; // plugins from decorators to access state-information easily (cheating a little)

    //========================= Private Methods =========================
    /**
    * @method _afterBuild
    * @description This is called after datatable is rendered or modified.
    */

//     var _initGlobalFilter = function(el) {
//         PHEDEX.Event.CreateGlobalFilter.fire(el);
//     };

    /**
    * @method _initPermaLink
    * @description This creates the permalink element and defines function to set the permalink URL.
    * @param {Object} el Object specifying the element in the HTML page to be used for permalink.
    */

    var _defaultPageState = "";

    /**
    * @method _getWidget
    * @description This gets the widget given the state and widget name.
    * @param {Object} state Object specifying the state of the page to be set.
    */
    var _getWidget = function(state) {
debugger;
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
    * The changes to navigator state must pass through this function! It is also called by history navigate functionality 
    * to set the status in web page.
    * @param {String} pgstate String specifying the state of the page to be set.
    */
    _setState = function(obj) {
      return function(pgstate) {
        var state = null, changed = 0, value;
        if (!pgstate) {
            pgstate = _defaultPageState; //Set the state to default state
        }
        if (pgstate) {
            state = _parseQueryString(pgstate); //Parse the current history state and get the key and its values
//             if (state.widget) {
//                 state.widget = _getWidget(state); //Get the widget given the widget name
//             }
        }
        if (!state) { return; } //Do Nothing and return
        for (var key in obj.state)
        {
          value = obj.state[key].state();
          if ( value != state[key] ) {
            log('setState: '+key+'( '+state[key]+' => '+value+')','info','Navigator');
            changed++;
          }
        }
        log('setState: '+changed+' changes w.r.t. currently known state','info','Navigator');
        if ( !changed ) { return; }
        _sbx.notify(obj.id,'StateChanged',state);
//         if (state.instance) { changed = _setInstance(state) || changed; } //Update the instance state
//         if (state.type) { changed = _setTargetType(state) || changed; }   //Update the target type state
//         changed = _setTarget(state) || changed;                           //Update the target node state
//         if (state.widget) { changed = _setWidget(state) || changed; }     //Update the widget state
//         if (changed || (!changed && !_cur_widget_obj)) {
//             if (state.hiddencolumns || state.sortcolumn) {
//                 _cur_widget_state = state;
//             }
//             _fireNavChange(); //Build widget if there is any change in state
//         }
      };
    }(this);

    /**
    * @method _setWidgetState
    * @description This sets the state of the widget after it has been constucted. The widget states are   
    * visible columns and sorted column 
    * @param {Object} wdgtstate Object specifying the state of the widget to be set.
    */
    var _setWidgetState = function() {
debugger;
        var indx = 0;
        var hiddencolumns = {};
        if (_cur_widget_state && _cur_widget_obj.dataTable) {
            if (_cur_widget_state.hiddencolumns) {
                var arrCols = _cur_widget_state.hiddencolumns.split("^");
                for (indx = 0; indx < arrCols.length; indx++) {
                    if (arrCols[indx]) {
                        hiddencolumns[arrCols[indx]] = 1;
                    }
                }
            }
            var dtColumnSet = _cur_widget_obj.dataTable.getColumnSet();
            var defnColumns = dtColumnSet.getDefinitions();
            for (indx = 0; indx < defnColumns.length; indx++) {
                if (hiddencolumns[defnColumns[indx].key]) {
                    if (!defnColumns[indx].hidden) {
                        var objColumn = _cur_widget_obj.dataTable.getColumn(defnColumns[indx].key); //Get the object of column
                        if (objColumn) {
                            _cur_widget_obj.dataTable.hideColumn(objColumn);
                        }
                    }

                }
                else if (defnColumns[indx].hidden) {
                    var objColumn = _cur_widget_obj.dataTable.getColumn(defnColumns[indx].key); //Get the object of column
                    if (objColumn) {
                        _cur_widget_obj.dataTable.showColumn(objColumn);
                        _cur_widget_obj.removeBtnMenuItem(defnColumns[indx].key);
                    }
                }
            }
        }
        if (_cur_widget_state && _cur_widget_obj.dataTable && _cur_widget_state.sortcolumn) {
            var objColumn = _cur_widget_obj.dataTable.getColumn(_cur_widget_state.sortcolumn); //Get the object of column
            if (objColumn) {
                _cur_widget_obj.dataTable.sortColumn(objColumn); //Sort in ascending order
                if (_cur_widget_state.sortdir.toLowerCase() == 'desc') {
                    _cur_widget_obj.dataTable.sortColumn(objColumn); //Sort again if descending order is the direction
                }
            }
        }
        _cur_widget_state = null; //Reset the widget state object
    }

    /**
    * @method _parseQueryString
    * @description This parses the page query and return the key and its values.  
    * @param {String} strQuery specifies the state of the page to be set.
    */
    var _parseQueryString = function(strQuery) {
        var strTemp = "", indx = 0;
        var arrResult = {};
        var arrQueries = strQuery.split(_hist_sym_sep);
        for (indx = 0; indx < arrQueries.length; indx++) {
            strTemp = arrQueries[indx].split(_hist_sym_equal);
            if (strTemp[1].length > 0) {
                arrResult[strTemp[0]] = strTemp[1];
            }
        }
        return arrResult;
    };

    var _initialPageState = YAHOO.util.History.getBookmarkedState("page") || '';
    YAHOO.util.History.register("page", _initialPageState, _setState);

    /**
    * @method _getCurrentState
    * @description This gets the current state of the web page for history maintenance.  
    */
    this._getCurrentState = function() {
      var newState = '';
      for (var key in this.state)
      {
        var value = this.state[key].state();
        if ( !value ) { log('State: key='+key+' got '+value,'warn','Navigator'); continue; }
        if ( newState ) { newState += _hist_sym_sep; }
        newState += key + _hist_sym_equal + value;
      }
      return newState;
    }

    /**
    * @method _addToHistory
    * @description This adds the current state of the web page to history for further navigation.
    */
    this._addToHistory = function() {
        var newState, currentState;
        try {
            newState = this._getCurrentState();
            currentState = YAHOO.util.History.getCurrentState("page");
            if (newState !== currentState) //Check if previous and current state are different to avoid looping
            {
                log('State: '+newState,'info','Navigator');
                YAHOO.util.History.navigate("page", newState); //Add current state to history and set values
            }
        }
        catch (ex) {
          banner(ex,'error');
          log(ex,'error','Navigator');
          _setState(newState); //In case YUI History doesnt work
        }
    };

    /**
    * @method _fireNavChange
    * @description This fires the navigator change event with the current state.
    */
    var _fireNavChange = function(obj) {
      return function() {
debugger;
        _sbx.notify(obj.id,'changed',{
            type:   _cur_target_type,
            target: _cur_target,
            widget: _cur_widget,
            filter: _cur_filter
        });
      };
    }(this);

    /**
    * @method _formPermalinkURL
    * @description This gets the datatable state and is used to update the permalink
    */
    var _formPermalinkURL = function() {
debugger;
        var baseURL = document.location.href;
        var hashindx = baseURL.indexOf('#');
        if (hashindx > -1) {
            baseURL = baseURL.substring(0, hashindx);
        }
        var currentState = YAHOO.util.History.getCurrentState("page"); //Get the current state
        currentState = currentState;
        if (!currentState) {
            currentState = _defaultPageState;
        }
        else {
            var state = _parseQueryString(currentState); //Parse the current history state and get the key and its values
            if (!state.target) {
                state.target = '';
            }
            if (!state.filter) {
                state.filter = '';
            }
            currentState = 'instance' + _hist_sym_equal + state.instance + _hist_sym_sep + 'type' + _hist_sym_equal + state.type + _hist_sym_sep +
                           'target' + _hist_sym_equal + state.target + _hist_sym_sep + 'widget' + _hist_sym_equal + state.widget + _hist_sym_sep +
                           'filter' + _hist_sym_equal + state.filter; //Form the query string
        }
        baseURL = '#page=' + currentState;

        var dtColumnSet = _cur_widget_obj.dataTable.getColumnSet();
        var defnColumns = dtColumnSet.getDefinitions();
        var indx = 0;
        var wdgtState = _hist_sym_sep + "hiddencolumns" + _hist_sym_equal;
        for (indx = 0; indx < defnColumns.length; indx++) {
            if (defnColumns[indx].hidden) {
                wdgtState = wdgtState + defnColumns[indx].key + '^';
            }
        }
        if (wdgtState.charAt(wdgtState.length - 1) == '^') {
            wdgtState = wdgtState.substring(0, wdgtState.length - 1);
        }
        baseURL = baseURL + wdgtState;
        wdgtState = '';

        var sortcolumn = _cur_widget_obj.dataTable.get('sortedBy');
        if (sortcolumn) {
            wdgtState = _hist_sym_sep + 'sortcolumn' + _hist_sym_equal + sortcolumn.key + _hist_sym_sep + 'sortdir' + _hist_sym_equal + sortcolumn.dir.substring(7);
        }
        baseURL = baseURL + wdgtState;
        _updateLinkGUI(baseURL);
    };

    /**
    * @method _afterRender
    * @description This gets called after datatable is formed. This is used to set inter widget state (if any) 
    * and later update the permalink
    */
    var _afterRender = function() {
debugger;
        _setWidgetState();
        _formPermalinkURL();
    }

    /* Below are the individual _set{state} functions. They must not be
    called except through _setState, otherwise widget construction is
    bypassed! */

    var _setTargetType = function(state) {
        var type = state.type;
        var old = _cur_target_type;
        if (!type) { type = _cur_target_type; }
        else { _cur_target_type = type; }

        if (old != _cur_target_type) {
            var new_widget = 'xyz';//_updateWidgetMenu(type);     // make a new widget menu, returns the default selection
            if (!state.widget) { state.widget = new_widget; }
            var new_target = 'pqr';//_updateTargetSelector(type); // get a new target selector, returns default selection
            if (!state.target) { state.target = new_target; }
//             _sbx.notify(this.id,'updateTargetTypeGUI',type);
debugger;
            _sbx.notify(this.id,'TargetType',type);
            return 1;
        } else { return 0; }
    };

    var _setInstance = function(state) {
debugger;
        var old = _cur_instance,
        i = PxD.Instance();
        _cur_instance = state.instance;

        if (old != _cur_instance) {
          _sbx.notify(this.id,'Instance',_cur_instance);
          return 1;
        } else { return 0; }
    };

    var _setTarget = function(state) {
debugger;
        if (!state.target) {
            state.target = "";
        }
        var old = _cur_target;
        _cur_target = state.target;

        if (old != _cur_target) {
            _sbx.notify(this.id,'updateTargetGUI',_cur_target);
            return 1;
        } else { return 0; }
    };

    var _setWidget = function(state) {
debugger;
        var widget = state.widget;
        var old = _cur_widget;
        if (!widget) { widget = _cur_widget; }
        else { _cur_widget = widget; }

        if (old != _cur_widget) {
          _sbx.notify(this.id,'updateWidgetGUI',_cur_widget);
            return 1;
        } else { return 0; }
    };

    // For now, just check that all parameters are set
    var _validConstruction = function() {
        if ((_cur_target_type == 'none') || (_cur_target_type == 'static')) {
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

    //========================= Event Subscriptions =====================
  var _nav_construct = false;

  this.selfHandler = function(obj) {
    return function(who, arr) {
      var action = arr[0],
          args   = arr[1];
      switch (action) {
        case 'afterBuild': {
//           var currentState = YAHOO.util.History.getCurrentState("page"); //Get the current state
//           if (currentState) {
//             _setState(currentState); //Set the current state on page
//           }
//           else {
//             _sbx.notify(who,'NavChange');
// //             _fireNavChange(); //Fire the page to load the current settings
//           }
        }
        case 'decoratorsReady': {
          _sbx.notify(who,'NavReset');
          break;
        }
        case 'statePlugin': {
          obj.state[args.key] = args;
          break;
        }

// These are to respond to changes in the decorations
//      case 'TargetType': Not needed! Setting TargetType always leads to WidgetSelected, so that is enough to do the job
        case 'NodeSelected':
        case 'WidgetSelected':
        case 'Instance': {
          obj._addToHistory();
          break;
        }

        case 'wassitallabout': {
debugger;
          YAHOO.log("NavChange:  type=" + args.type + " target=" + args.target +
              " widget=" + args.widget.widget + " filter=" + args.filter,
              'info', 'Navigator');

        // out with the old...
          _sbx.notify('module','*','destroy');
//         if (_cur_widget_obj) {
//             _cur_widget_obj.destroy();
//             _cur_widget_obj = null;
//         }

        // in with the new... (maybe)
          if (_validConstruction()) {
            YAHOO.log("NavChange:  construct type=" + _cur_target_type + " target=" + _cur_target +
                " widget=" + _cur_widget.widget,
                'info', 'Navigator');
            _nav_construct = true; // prevent interception of our own construct event
            var a = {};
            if ( _cur_target_type ) { a[_cur_target_type] = _cur_target; }
            _sbx.notify('CreateModule',_cur_widget.widget,a);

//             var widget = PxR.construct(_cur_widget.widget, _cur_target_type, _cur_target,
//                               'phedex-main', { window: false });
//             _nav_construct = false;
//             _cur_widget_obj = widget;
//             widget.update();
//             if (widget.dataTable) {
//                 widget.dataTable.subscribe('renderEvent', _afterRender);   //Assign the function to the event (after column gets sorted)
//                 widget.dataTable.subscribe('columnShowEvent', _formPermalinkURL);   //Assign the function to the event (after column gets sorted)
//             }
            }
          }
        };
      };
    }(this);
    /* PHEDEX.Core.Registry.beforeConstructEvent :
    On this event, something triggered a widget change.  If it was
    us, do nothing.  If it was something else, (e.g. context menu click)
    then we need to update our state and GUI elements.  We do this by
    intercepting the construct event, returning false to cancel the
    construct(), and triggering our own construct event after we've
    updated */
//     PxR.beforeConstructEvent.subscribe(function(evt, args) {
//         if (_nav_construct) { return true; } // prevent interception of our own construct event
//         args = args[0];
//         YAHOO.log("heard beforeConstruct for widget=" + args.widget.widget + " type=" + args.type + " data=" + args.data,
// 	      'info', 'Navigator');
// 
//         _addToHistory({ 'type': args.type,
//             'widget': args.widget,
//             'target': args.data
//         });
//         return false; // prevents Core.Widget.Registry from constructing
//     });

    _construct=function() {
      return {
        me:   'Navigator',
        type: 'Navigator',

        decorators: [
          {
            name:   'InstanceSelector',
            parent: 'navigator',
            payload:{
              type: 'menu',
            }
          },
          {
            name:   'TypeSelector',
            parent: 'navigator',
            payload:{
              type: 'menu',
            }
          },
          {
            name:   'TargetTypeSelector',
            parent: 'navigator',
          },
          {
            name:   'WidgetSelector',
            parent: 'navigator',
          },
          {
            name:   'Permalink',
            parent: 'navigator',
          },
        ],

        //========================= Public Methods ==========================
        // init(el, opts)
        //   called when this object is created
        //   div: element the navigator should be built in
        //   opts:  options for the navigator, takes the following:
        //     'typeconfig'   : an array of objects for organizing the type menu.
        //     'widgetconfig' : an array of objects for organizing the widget menu.
        init: function(args) {
            try {
              YAHOO.util.History.onReady( (function(obj) {
                return function() {
                  setTimeout(function() { obj.create(args); },0); //Initializes the form
                };
              })(this) );
              YAHOO.util.History.initialize("yui-history-field", "yui-history-iframe");
            } catch (ex) {
              log(ex,'error','Navigator')
              this.create(args);
            }
        },
        create: function(args) {
            this.el  = args.el;
            if ( typeof(this.el) != 'object' ) {
              this.el = document.getElementById(this.el);
            }
            if ( !this.el ) {
              throw new Error('Cannot find element for navigator');
            }

            this.dom.navigator = this.el; // needed for the decorators
            this.cfg = args.cfg;

            // Build TargetType selector for each type
//             _initTargetSelectors(this.el);

            // Build Widget Selector for each type
//             _initWidgetSelector(this.el, cfg.widgetcfg);

            // Build GlobalFilter
//             _initGlobalFilter(el);
//             _sbx.notify('Load','phedex-globalfilter',{el:el});

            // Build Permalink
//             _initPermaLink(this.el);

            // Get the current state that would also be default state for the page
//             _defaultPageState = _getCurrentState(null);

            _sbx.listen(this.id,this.selfHandler);
            _sbx.notify('ModuleExists',this); // let the Core drive my decorators etc
            _sbx.notify(this.id,'loadDecorators',this);
        },

        }
      };
    YAHOO.lang.augmentObject(this, _construct(), true);
};

PHEDEX.Navigator.WidgetSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _widget_menu,
      _cur_target_type = 'none',
      _widget; // the current widget name

  this.id = 'WidgetSelector';
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-widget';
  var _getWidgetMenuItems = function(type) {
    var widgets = PxR.getWidgetsByInputType(type);
    var menu_items = [];
    for (var w in widgets) {
      w = widgets[w];
      menu_items.push({ text: w.label, value: w });
    }
    return menu_items;
  };

  this.initWidgetSelector = function() {
    var menu_items = _getWidgetMenuItems(_cur_target_type);
    _cur_widget = menu_items[0].value;

    _widget_menu = new YAHOO.widget.Button({ 'type': "menu",
      'label': '(widget)',
      'menu': menu_items,
      'container': this.el
    });

    // update state on menu selections
    var onSelectedMenuItemChange = function(event) {
      var menu_item = event.newValue;
      var widget = menu_item.value;
      _updateWidgetGUI(widget);
      };
    _widget_menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  var _updateWidgetGUI = function(o) {
    return function(widget) {
      _widget_menu.set("label", widget.label);
      _widget = widget.widget;
      _sbx.notify(obj.id,'WidgetSelected',o.getState());
    };
  }(this);

  var _updateWidgetMenu = function(type) {
    var menu_items = _getWidgetMenuItems(type);
    var widget = menu_items[0].value; // save first value now; passing to addItems alters structure
    var menu = _widget_menu.getMenu(); // _widget_menu is actually a button...
    if (YAHOO.util.Dom.inDocument(menu.element)) {
      menu.clearContent();
      menu.addItems(menu_items);
      menu.render();
      } else {
        menu.itemData = menu_items;
      }
      _updateWidgetGUI(widget); // set menu to first item
      return widget;
  };
  this.getState = function() {
    var state = _widget;
    if ( state.match('^phedex-module-(.+)$') ) { return RegExp.$1; }
    if ( state.match('^phedex-(.+)$') ) { return RegExp.$1; }
    return state;
  }
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'NavReset': {
          break;
        }
        case 'StateChanged': {
          break;
        }
        case 'TargetType': {
          _updateWidgetMenu(value);
          break;
        }
//         case 'updateWidgetGUI': {
// debugger;
//           _updateWidgetGUI(value);
// //           _widget_menu_set('label',value);
//           break;
//         }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'widget',state:this.getState});
  this.initWidgetSelector();
  return this;
};

PHEDEX.Navigator.Permalink = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox;

  this.id = 'Permalink';
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-permalink';
//   var linkdiv = PxU.makeChild(el, 'div', { id: 'phedex-nav-link', className: 'phedex-nav-component phedex-nav-link' });
  var a = PxU.makeChild(this.el, 'a', { id: 'phedex-nav-filter-link', innerHTML: 'Link', href: '#' });
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value  = arr[1];
      switch (action) {
        case 'NavReset': {
          a.href = document.location.href;
          break;
        }
        case 'StateChanged': {
          break;
        }
        case 'UpdatePermaLink': {
debugger;
          if (value) {
            a.href = value; //Update the link with permalink URL
          } else {
            a.href = document.location.href; //Update the link with current browser URL
          }
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  return this;
};

PHEDEX.Navigator.TargetTypeSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _type; // The currently selected type

  this.id = 'TargetTypeSelector';
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-targettype';
// create the targetdiv here rather than in the initTargetSelectors to avoid racing for the DOM parent
  var targetdiv = PxU.makeChild(this.el, 'div', { className: 'phedex-nav-component phedex-nav-target' });

  this._initTargetSelectors = function(target_types) {
    if ( this.dom ) { return; }
    this.dom={};
    for (var t in target_types) {
      try {
        this.dom[t] = _selectors[t].init(targetdiv,t);
      } catch (ex) { log(ex,'error',this.id); banner('Error initialising Navigator, unknown type "'+t+'"!','error'); }
    }
  };

  _selectors = {
    none: {
      init: function(el) {
        return PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target-none' });
       },
      updateGUI: function() {
debugger;
        _type = 'none';
      }
    },
    text: {
      init: function(el, type) {
        var sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target' }),
           input = PxU.makeChild(sel, 'input', { type: 'text' });
        _selectors[type].updateGUI = function() {
debugger;
          input.value = _type;
        }
        return sel;
      },
    },

    node: {
      init: function(el,type) {
        var sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target-nodesel' }),
          makeNodeList = function(data) {
            data = data.node;
            var nodelist = [];
            for (var node in data) {
              nodelist.push(data[node].name);
            }
            _buildNodeSelector(sel,nodelist.sort());
            _sbx.notify(obj.id,'afterBuild'); //Now the data service call is answered. So, set the status of page.
          };
        PHEDEX.Datasvc.Call({ api: 'nodes', callback: makeNodeList });
        _selectors[type].updateGUI = function() {
debugger;
          input.value = _type;
        }
        return sel;
      }
    }

  };
  var _buildNodeSelector = function(div,nodelist) {
    var input     = PxU.makeChild(div, 'input', { type: 'text' }),
        container = PxU.makeChild(div, 'div'),
        node_ds  = new YAHOO.util.LocalDataSource(nodelist),
        cfg = {
          prehighlightClassName:"yui-ac-prehighlight",
          useShadow: true,
          forceSelection: true,
          queryMatchCase: false,
          queryMatchContains: true,
        },
        auto_comp = new YAHOO.widget.AutoComplete(input, container, node_ds, cfg);
    var nodesel_callback = function(type, args) {
      _sbx.notify(obj.id,'NodeSelected',args[2][0]);
    }
    auto_comp.itemSelectEvent.subscribe(nodesel_callback);
  };
  this._updateTargetSelector = function(type) {
    _type = type;
    for (var t in this.dom) {
      var el = this.dom[t];
      if ( t == type ) {
        el.style.visibility = 'visible';
        el.style.position = 'relative';
      } else {
        el.style.visibility = 'hidden';
        el.style.position = 'absolute';
      }
    }
    return;
  };

  this.getState = function() {
    return _type;
  }
/* Permit interaction with the navigator
 * @method partnerHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event
 * @private
 */
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'NavReset': {
          break;
        }
        case 'TargetType': {
          o._updateTargetSelector(value);
          break;
        }
        case 'TargetTypes': {
          o._initTargetSelectors(value);
          break;
        }
        case 'StateChanged': {
          break;
        }
        case 'updateTargetGUI': {
debugger;
          o[target_type].updateTargetGUI(value);
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'target',state:this.getState});
  return this;
};

PHEDEX.Navigator.TypeSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _target_types = {},
      _target_type,
      types = PxR.getInputTypes(),
      menu_items = [];

  this.id = 'TypeSelector';
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-type';

  // get registered target types and store them with optional config params
  for (var i in types) {
    type = types[i];
    var o = { 'name': type, 'label': type, 'order': Number.POSITIVE_INFINITY },
        opts = obj.cfg.typecfg[type] || {};
    YAHOO.lang.augmentObject(o, opts, true);
    _target_types[type] = o;
  }

  // sort types by object params
  types.sort(function(a, b) {
    return _target_types[a].order - _target_types[b].order;
  });

  // build menu items in sorted order
  for (var type in types) {
    var o = _target_types[types[type]];
    menu_items.push({ 'text': o.label, 'value': o.name });
  }

  this.menu = new YAHOO.widget.Button({ type: "menu",
    label: '(type)',
    menu: menu_items,
    container: this.el
  });
  var onSelectedMenuItemChange = function(event) {
    if ( event.prevValue && event.newValue.value == event.prevValue.value ) { return; }
    var type = event.newValue.value;
    _sbx.notify(obj.id,'TargetType',type);
  };
  this.menu.on("selectedMenuItemChange", onSelectedMenuItemChange);

  this.getState = function() {
    return _target_type;
  }
/* Permit interaction with the navigator
 * @method partnerHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event
 * @private
 */
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'NavReset': {
          _sbx.notify(obj.id,'TargetTypes',_target_types);
          _sbx.notify(obj.id,'TargetType',menu_items[0].value);
          break;
        }
        case 'TargetType': {
          _target_type = value;
          o.menu.set("label", _target_types[value].label);
          break;
        }
        case 'StateChanged': {
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'type',state:this.getState});
  return this;
};

PHEDEX.Navigator.InstanceSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      instances = PHEDEX.Datasvc.Instances(), // Get current instances
      _instances={}, menu_items=[],
      indx, jsonInst;
  if (!instances) { throw new Error('cannot determine set of DB instances'); } //Something is wrong.. So dont process further..

  this.id = 'InstanceSelector';
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-instance';
  for (indx = 0; indx < instances.length; indx++) {
    jsonInst = instances[indx];
    _instances[jsonInst.instance] = jsonInst;
    menu_items.push({ 'text': jsonInst.name, 'value': jsonInst.instance });
   }

  this.menu = new YAHOO.widget.Button({ type: "menu",
    label: '(instance)',
    menu: menu_items,
    container: this.el
  });

  var onSelectedMenuItemChange = function(event) {
    if ( event.prevValue && event.newValue.value == event.prevValue.value ) { return; }
    var instanceVal = event.newValue.value;
    _sbx.notify(obj.id,'Instance',instanceVal);
  };

  this.getState = function() {
    return PHEDEX.Datasvc.Instance().name;
  }
  this.menu.on('selectedMenuItemChange', onSelectedMenuItemChange);
/* Permit interaction with the navigator
 * @method partnerHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event
 * @private
 */
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'NavReset': {
          var i = PHEDEX.Datasvc.Instance();
          o.menu.set("label", i.name);
          break;
        }
        case 'Instance': {
          var i = PHEDEX.Datasvc.Instance(value);
          o.menu.set("label", i.name);
          _sbx.notify('module','*','getData');
          break;
        }
        case 'StateChanged': {
          var i = PHEDEX.Datasvc.Instance();
          if ( i.name != value.instance ) {
            _sbx.notify(obj.id,'Instance',value.name);
          }
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'instance',state:this.getState});
  return this;
};

// /**
// * @method InitializeNavigator
// * @description This initializes the browser history management library.
// * @param {HTML element} el element specifies element the navigator should be built in
// * @param {Object} cfg Object specifies options for the navigator, takes the following:
// * 'typeconfig'   : an array of objects for organizing the type menu.
// * 'widgetconfig' : an array of objects for organizing the widget menu.
// */
//
// /**
// * @method CreateNavigator
// * @description This initializes the creation of navigator by passing the required parameters.
// */
