/* PHEDEX.Navigator
 * Navigation widget for the application.  Allows user to input PhEDEx
 * entities ("Targets") and view widgets ("Pages") associated with them.
 * Uses PHEDEX.Core.Widget.Registry to build menus and construct
 * widgets.  Also defines the "Global Filter", which allows the user to
 * type in name:value pairs which are passed to the active widget to
 * apply filters.
*/
PHEDEX.namespace('Navigator');
PHEDEX.Navigator = function(sandbox) {
  this.id = 'Navigator_' + PxU.Sequence();
  var _sbx = sandbox,
      PxD  = PHEDEX.Datasvc,

    //========================= Private Properties ======================
      _hist_sym_sep = "+",    //This character separates the states in the history URL
      _hist_sym_equal = "~",  //This character indicates the state value
      _initialPageState,
      me = 'navigator',
      _newModule, _newModuleArgs, _needNewModule;


  Yla(this, new PHEDEX.Base.Object());
  this.state = {}; // plugins from decorators to access state-information easily (cheating a little)

    /**
    * @method _setState
    * @description This sets the state of the navigator. If the state has changed, fire _fireNavChange event.  
    * The changes to navigator state must pass through this function! It is also called by history navigate functionality 
    * to set the status in web page.
    * @param {String} pgstate String specifying the state of the page to be set.
    */
    _setState = function(obj) {
      return function(pgstate) {
        var state = null,
            changed = 0, mChange = 0,
            value, args;
        if (!pgstate) {
            pgstate = _initialPageState; //Set the state to its initial state
        }
        if (pgstate) {
            state = _parseQueryString(pgstate); //Parse the current history state and get the key and its values
        }
        if (!state) { return; } //Do Nothing and return
        for (var key in obj.state)
        {
          if ( !obj.state[key].isValid() ) { changed++; continue; }
          value = obj.state[key].state();
          if ( value != state[key] ) {
            log('setState: '+key+' ('+state[key]+' => '+Ylang.JSON.stringify(value)+')','info',obj.me);
            if ( key == 'module' ) { mChange = 1; }
            else { changed++; }
          }
        }
        log('setState: '+changed+' changes w.r.t. currently known state ('+pgstate+')','info',obj.me);
        _sbx.notify('currentState',pgstate);
//         if ( state.module && !obj.state['module'] ) { mChange = 1; }
        if ( !changed && !mChange ) { return; }
        if ( mChange ) { 
          if ( state.module ) {
            try {
              _sbx.notify(obj.state.module.obj.id,'setState',state.module);
            } catch(ex) { }
          }
        }
        _sbx.notify(obj.id,'StateChanged',state);
        if ( !changed ) { return; }
        if ( state.module ) { args = {state:state.module}; }
        _sbx.notify('_navCreateModule',state.widget,args);
      };
    }(this);

    /**
    * @method _parseQueryString
    * @description This parses the page query and return the key and its values.  
    * @param {String} strQuery specifies the state of the page to be set.
    */
    var _parseQueryString = function(strQuery) {
        var strTemp = "", indx = 0,
            arrResult = {},
            arrQueries = strQuery.split(_hist_sym_sep),
            subQueries, subStr, subState, i;
        for (indx = 0; indx < arrQueries.length; indx++) {
            strTemp = arrQueries[indx].split(_hist_sym_equal);
            if (strTemp[1].length > 0) {
                subState = {};
                subQueries = strTemp[1].split('}');
                if (subQueries.length > 1) {
                  for (i=0; i<subQueries.length; i++) {
                    subStr = subQueries[i].split('{');
                    if ( subStr.length == 2 ) { subState[subStr[0]] = subStr[1]; }
                  }
                  arrResult[strTemp[0]] = subState;
                } else {
                  arrResult[strTemp[0]] = strTemp[1];
                }
            }
        }
        return arrResult;
    };
    _initialPageState = Yu.History.getBookmarkedState("page") ||
                        Yu.History.getQueryStringParameter("page") ||
                        'instance~Production+type~none+widget~nodes';
    log('InitialPageState: '+_initialPageState,'info',this.me);
    Yu.History.register("page", _initialPageState, _setState);

    /**
    * @method _getCurrentState
    * @description This gets the current state of the web page for history maintenance.  
    */
    this._getCurrentState = function() {
      var newState = '';
      for (var key in this.state)
      {
        var valid = false, value, o = this.state[key];
        try { valid = o.isValid() } catch(ex) { log(ex,'error',this.me); }
        if ( !valid ) { return null; }
        if ( o.obj ) { value = o.state.apply(o.obj); }
        else         { value = o.state(); }
        if ( !value ) { log('State: key='+key+' got '+value,'warn',this.me); continue; }
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
            if ( !newState ) { return; }
            currentState = Yu.History.getCurrentState("page");
            if (newState !== currentState) //Check if previous and current state are different to avoid looping
            {
                _sbx.notify(this.id,'UpdatePermalink',newState);
                log('addToHistory: '+newState,'info',this.me);
                Yu.History.navigate("page", newState); //Add current state to history and set values
            } else {
                log('addToHistory: state unchanged','info',this.me);
            }
        }
        catch (ex) {
          banner('Error determining page state','error');
          log(ex,'error',this.me);
          _setState(newState); //In case YUI History doesnt work
        }
    };

  this.needNewModule = function() {
    log('NeedNewModule: _needNewModule='+_needNewModule+', _newModule='+_newModule+', _newModuleArgs='+Ylangd(_newModuleArgs,1),'info',me);
    if ( _needNewModule && _newModule ) {
      _sbx.notify('module','*','destroy');
      _sbx.notify('_navCreateModule',_newModule,_newModuleArgs);
      _newModule = _newModuleArgs = null;
      _needNewModule = false;
    } else {
      _needNewModule = true;
    }
  };
  this.selfHandler = function(obj) {
    var nDec = 0;
    return function(who, arr) {
      var action = arr[0],
          args   = arr[1];
      log('selfHandler: ev='+who+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'decoratorsReady': {
          if ( _initialPageState ) {
            _setState(_initialPageState);
            _sbx.notify(obj.id,'UpdatePermalink',_initialPageState);
            _initialPageState = null;
          } else {
            _sbx.notify(who,'NavReset');
          }
          break;
        }
        case 'decoratorReady': {
          nDec++;
          log('decoratorReady received: '+nDec+' decorators out of '+obj.decorators.length,'info',me);
          if ( nDec == obj.decorators.length ) {
            _sbx.notify(obj.id,'decoratorsReady');
          }
          break;
        }
        case 'statePlugin': {
          obj.state[args.key] = args;
          break;
        }
        case 'TargetSelected': {
          _sbx.notify('module','*','doSetArgs',arr[2]);
          break;
        }
        case 'TargetType': {
          _newModule = null;
          _needNewModule = true;
          obj.needNewModule();
          break;
        }
        case 'WidgetSelected': {
          _newModule = args;
          _needNewModule = true;
          obj.needNewModule();
          break;
        }
        case 'NewModule': {
          _newModule = args;
          obj.needNewModule();
          break;
        }
        case 'NewModuleArgs': {
          _newModuleArgs = args;
          break;
        }
        case 'NeedNewModule': {
          obj.needNewModule();
          break;
        }

// This is to respond to changes in the decorations that are worthy of a bookmark. This is also triggered in response
// to a 'gotData' from a module. This means that only states with valid modules and/or with changes of instance are
// recorded as historic/bookmarkable states. This is reasonable, other states are incomplete.
//         case 'WidgetSelected':
        case 'InstanceSelected': {
          obj._addToHistory();
          break;
        }
      };
    };
  }(this);

  this.coreHandler = function(obj) {
    return function(ev, arr) {
      log('coreHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      _sbx.notify('Registry','getTypeOfModule',arr[0], obj.id);
      if ( arr[1] ) { // I have arguments for this module, when it is created. Stash them globally for later use
        _sbx.notify(obj.id,'NewModule',arr[0]);
        _sbx.notify(obj.id,'NewModuleArgs',arr[1]);
      }
      _sbx.notify(obj.id,'NeedNewModule');
    };
  }(this);

  this.moduleHandler = function(o) {
    return function(ev,arr) {
      switch ( ev ) {
        case 'ModuleExists': {
          if ( arr[0].id == o.id ) { return; } // ignore myself
          _sbx.listen(arr[0].id, o.moduleHandler);
          if ( o.moduleState ) {
            _sbx.notify(arr[0].id,'setState',o.moduleState);
            delete o.moduleState;
          }
          log('ModuleExists: _needNewModule='+_needNewModule+', _newModule='+_newModule+', _newModuleArgs='+Ylangd(_newModuleArgs,1),'info',me);
          break;
        }
        default: {
          var who = ev,
              action = arr[0];
          switch ( action ) {
            case 'initModule': {
              _sbx.notify(who,'getStatePlugin',o.id);
              break;
            }
            case 'gotData':
            case 'updateHistory':
            case 'hideColumn': {
              o._addToHistory();
              break;
            }
            case 'destroy': {
              if ( o.state.module ) { delete o.state.module; }
              break;
            }
          }
        }
      }
    };
  }(this);

    _construct=function() {
      return {
        me:   'navigator',
        type: 'Navigator',

        decorators: [
          {
            name:   'InstanceSelector',
            parent: 'navigator',
            payload:{
              type: 'menu'
            }
          },
          {
            name:   'TypeSelector',
            parent: 'navigator',
            payload:{
              type: 'menu'
            }
          },
          {
            name:   'TargetTypeSelector',
            parent: 'navigator'
          },
          {
            name:   'WidgetSelector',
            parent: 'navigator'
          },
          {
            name:   'Permalink',
            parent: 'navigator'
          }
        ],

        //========================= Public Methods ==========================
        //
        // init(el, opts)
        //   called when this object is created
        //   div: element the navigator should be built in
        //   opts:  options for the navigator, takes the following:
        //     'typeconfig'   : an array of objects for organizing the type menu.
        //     'widgetconfig' : an array of objects for organizing the widget menu.
        init: function(args) {
          Yu.History.onReady( (function(obj) {
            return function() {
              setTimeout(function() { obj.create(args); },0); //Initializes the form
            };
          })(this) );
          try {
            Yu.History.initialize("yui-history-field", "yui-history-iframe");
          } catch (ex) {
            log(ex,'error',obj.me)
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

            _sbx.listen(this.id,this.selfHandler);
            _sbx.listen('ModuleExists',this.moduleHandler);
            _sbx.notify('ModuleExists',this); // let the Core drive my decorators etc
            _sbx.notify(this.id,'loadDecorators',this);
            _sbx.replaceEvent('CreateModule','_navCreateModule');
            _sbx.listen('_navCreateModule',this.coreHandler);
        }
      }
    };
    Yla(this, _construct(), true);
};

PHEDEX.Navigator.WidgetSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _menu = { items:[] }, // will hold both the menu button itself, and the structure used to create it
      _widget = {},         // the currently selected widget
      _new_widget_name,     // name of widget being created by external means (e.g. context-menu)
      me = 'widgetselector';

  this.id = 'WidgetSelector_' + PxU.Sequence();
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-widget';
  var _getWidgetMenuItems = function(type) {
    var widgets = _menu.items[type],
        menu_items = [], item, w, feature_prefix;
    for (w in widgets) {
      w = widgets[w];
      feature_prefix = '';
      if ( w.feature_class ) {
        feature_prefix = PxU.feature[w.feature_class];
      }
      item = { text:feature_prefix + w.label, value:w };
      menu_items.push(item);
    }
    return menu_items;
  };

  this.initWidgetSelector = function() {
    _menu.menu = new Yw.Button({ 'type': "menu",
      'label': '(widget)',
      'menu': [],
      'container': this.el
    });

    // update state on menu selections
    var onSelectedMenuItemChange = function(o) {
      return function (event) {
        var widget = event.newValue.value;
        if ( event.prevValue && event.prevValue.value.label == widget.label ) { return; }
        log('onSelectedMenuItemChange: '+widget.short_name+' '+Ylangd(widget,2),'info',me);
        if ( _widget.id == widget.id ) { log('updateWidgetGUI called for same widget','warn',me); return; }
        _widget = widget;
        o._updateWidgetGUI(widget);
        if ( _widget.args ) {
          _sbx.notify(obj.id,'NewModuleArgs',_widget.args);
        }
        _sbx.notify(obj.id,'WidgetSelected',o.getState());
      }
    }(this);
    _menu.menu.on("selectedMenuItemChange", onSelectedMenuItemChange);
  };

  this.isStateValid = function() {
    if ( _widget.short_name ) { return true; }
    return false;
  }
  this.getState = function() {
    return _widget.short_name;
  }
  this._updateWidgetGUI = function(widget) {
    _menu.menu.set("label", widget.label);
  };
  this._updateWidgetMenu = function(type,_name) {
    log('updateWidgetMenu: type='+type+', widget='+_name,'info',me);
    var m, items = _getWidgetMenuItems(type);
    if ( !items.length ) {
      _sbx.notify('Registry','getWidgetsByInputType',type,this.id);
      if ( _name ) { _new_widget_name = _name; }
      return;
    }
    if ( _new_widget_name ) {
      _name = _new_widget_name;
      _new_widget_name = null;
    }
    if ( _name ) {
      for (var i in items) {
        if ( items[i].value.short_name == _name ) {
          _widget = items[i].value;
        }
      }
    } else {
       _widget = items[0].value; // save first value now; passing to addItems alters structure
        if ( _widget.args ) { // set any arguments _before_ triggering the creation of the widget!
          _sbx.notify(obj.id,'NewModuleArgs',_widget.args);
        }
       _sbx.notify(obj.id,'WidgetSelected',this.getState()); // Trigger new module creation since I know the name of the module to create!
    }
    m = _menu.menu.getMenu();
    if (YuD.inDocument(m.element)) {
      m.clearContent();
      m.addItems(items);
      m.render();
//  m._aItemGroups[0][1].CSS_CLASS_NAME += ' phedex-contextmenu-beta';
    } else {
      m.itemData = items;
    }
    this._updateWidgetGUI(_widget);
    return;
  };
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      log('partnerHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'NavReset': {
          break;
        }
        case 'NewModule': {
          _new_widget_name = value;
//           o._updateWidgetMenu();
          break;
        }
        case 'StateChanged': {
          _widget = {};
          o._updateWidgetMenu(value.type,value.widget);
          break;
        }
        case 'TargetType': {
          o._updateWidgetMenu(value);
          break;
        }
        case 'WidgetsByInputType': {
          _menu.items[value] = arr[2];
          o._updateWidgetMenu(value);
          break;
        }
      }
    }
  }(this);
  this.initWidgetSelector();
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'widget', state:this.getState, isValid:this.isStateValid});
  _sbx.notify(obj.id,'decoratorReady',this.id);
  return this;
};

PHEDEX.Navigator.Permalink = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      me = 'permalink';

  this.id = 'Permalink_' + PxU.Sequence();
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-permalink';
  var a = PxU.makeChild(this.el, 'a', { id: 'phedex-nav-filter-link', innerHTML: 'Link', href: '#', title:'Permalink to the current page-state. Right-click to bookmark this view, or to save the link so you can mail it to someone else', className:'phedex-link phedex-link-inline' });
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value  = arr[1];
      log('partnerHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'NavReset': {
          a.href = document.location.href;
          break;
        }
        case 'UpdatePermalink': {
          if (value) {
            a.href = '#page=' + escape(value); //Update the link with permalink URL
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
  _sbx.notify(obj.id,'decoratorReady',this.id);
  return this;
};

PHEDEX.Navigator.TargetTypeSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _type, // The currently selected type
// TODO _typeargs and _state are somewhat redundant, and need sorting out
      _typeArgs = {},   // currently selected arguments for the given types
      _state = {},      // current state for each type
      _moduleArgs = {}, // stored arguments for new module when I don't know what type it is yet
      me = 'targettypeselector';

  this.id = 'TargetTypeSelector_' + PxU.Sequence();
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-targettype';
// create the targetdiv here rather than in the initTargetSelectors to avoid racing for the DOM parent
  var targetdiv = PxU.makeChild(this.el, 'div', { className: 'phedex-nav-component phedex-nav-target' });

  this._initTargetSelectors = function(target_types) {
    if ( this.dom ) { return; }
    this.dom={};
    for (var t in target_types) {
      try {
        if ( _selectors[t] ) {
          this.dom[t] = _selectors[t].init(targetdiv,t);
        }
      } catch (ex) { log(ex,'error',obj.me); banner('Error initialising Navigator for type "'+t+'"!','error'); }
    }
    this._updateTargetSelector();
  };

  _selectors = {
    none: {
      init: function(el) {
        return PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target-none' });
       },
      needValue: false,
      updateGUI: function() { } // not really needed
    },

    'static': {
      init: function(el) {
        return PxU.makeChild(el, 'div');
       },
      needValue: false,
      updateGUI: function() {
        _type = 'static';
      }
    },

    activity: {
      init: function(el) {
        return PxU.makeChild(el, 'div');
       },
      needValue: false,
      updateGUI: function() {
        _type = 'activity';
      }
    },

    text: {
      init: function(el, type) {
        var sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target' }),
           input = PxU.makeChild(sel, 'input', { type: 'text' });
        _selectors[type].needValue = true;
        _selectors[type].updateGUI = function(i) {
          return function() {
            log('updateGUI for _selectors['+type+']','info',me);
            i.value = _state[_type]; // TODO Is this correct? What if Instance has changed?
          }
        }(input);
        return sel;
      }
    },

    block: {
      init: function(el, type) {
        var sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component phedex-nav-target-block' }),
          input = PxU.makeChild(sel, 'input', { type: 'text', title:'Type a block-name here (SQL or shell-style regular expressions allowed)', size:30 });
        _selectors[type].needValue = true;
        _selectors[type].updateGUI = function(i) {
          return function() {
            log('updateGUI for _selectors['+type+']','info',me);
            i.value = _state[_type]; // TODO Is this correct? What if Instance has changed?
            i.title = _state[_type];
          }
        }(input);

        var k1 = new Yu.KeyListener(input,
                                          { keys: Yu.KeyListener.KEY['ENTER'] },
                                          { fn:function(o){
            return function() {
              if ( !_typeArgs[_type] ) { _typeArgs[_type] = {}; }
              _typeArgs[_type].block = input.value;
              _state[_type] = input.value;
              _sbx.notify('module','*','doSetArgs',_typeArgs[_type]);
            } }(this),
                                            scope:this, correctScope:true } );
        k1.enable();

        return sel;
      }
    },

    node: {
      init: function(el,type) {
        var dataKey = 'node',
            api     = 'nodes',
            argKey  = 'node';
        return _makeSelector(el,type,dataKey,api,argKey);
      }
    },

    group: {
      init: function(el,type) {
        var dataKey = 'group',
            api     = 'groups',
            argKey  = 'group';
        return _makeSelector(el,type,dataKey,api,argKey);
      }
    }
  };

  var _makeSelector = function(el,type,dataKey,api,argKey) {
        var sel, input, container, id='phedex-nav-target-'+argKey+'sel';
            sel = document.getElementById(id);
            if ( sel ) {
              input     = document.getElementById(id+'-input');
              container = document.getElementById(id+'-container');
              container.innerHTML = input.innerHTML = '';
            } else {
              sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component '+id }),
              input     = PxU.makeChild(sel, 'input', { type: 'text', title: 'enter a valid "'+dataKey+'" name (wildcards allowed)' }),
              container = PxU.makeChild(sel, 'div');
              sel.id = id;
              input.id = id+'-input';
              container.id = id+'-container';
            };
          makeList = function(data) {
            if ( !data[dataKey] ) {
              banner('Error making '+api+' call, autocomplete will not work','error');
              log('error making '+api+' call: '+err(data),'error',me);
              return;
            }
            data = data[dataKey];
            var list = [], i;
            for (i in data) {
              list.push(data[i].name);
            }
            _autocompleteSelector(input,container,list.sort(),argKey);
          };
        PHEDEX.Datasvc.Call({ api:api, callback:makeList });
        _selectors[type].needValue = true;
        _selectors[type].updateGUI = function(i) {
          return function(value) {
            log('updateGUI for _selectors['+type+'], value='+value,'info',me);
            i.value = value;// || _state[_type]; // Is this correct? What if Instance has changed? What if the target is coming from history?
          }
        }(input);
        _selectors[type].value = function(i) {
          return function() {
            return i.value;
          }
        }(input);

        var k1 = new Yu.KeyListener(input,
                                          { keys: Yu.KeyListener.KEY['ENTER'] },
                                          { fn:function(o){
            return function() {
              if ( !_typeArgs[_type] ) { _typeArgs[_type] = {}; }
              _typeArgs[_type][argKey] = input.value;
              _sbx.notify(obj.id,'TargetSelected',_type,_typeArgs[_type]);
            } }(this),
                                            scope:this, correctScope:true } );
        k1.enable();

        return sel;
      };

  this._updateTargetSelectors = function(obj) {
    return function() {
      var i, t, types = ['node','group'];
      for (i in types) {
        t = types[i];
        try {
          if ( _selectors[t] ) {
            obj.dom[t] = _selectors[t].init(targetdiv,t);
          }
        } catch (ex) { log(ex,'error',obj.me); banner('Error initialising Navigator for type "'+t+'"!','error'); }
    }
      obj._updateTargetSelector();
    }
  }(this);
  _sbx.listen('InstanceChanged', this._updateTargetSelectors );

  var _autocompleteSelector = function(input,container,list,key) {
    var ds  = new Yu.LocalDataSource(list),
        cfg = {
          prehighlightClassName:"yui-ac-prehighlight",
          useShadow: true,
//           forceSelection: true,
          queryMatchCase: false,
          queryMatchContains: true
        },
        auto_comp = new Yw.AutoComplete(input, container, ds, cfg),
    selection_callback = function(_dummy, args) {
      var value = args[2][0];
      _state[_type] = value;
      if ( ! _typeArgs[_type] ) { _typeArgs[_type] = {}; }
      _typeArgs[_type][key] = value;
      _sbx.notify(obj.id,'TargetSelected',_type,_typeArgs[_type]);
    },
    unmatchedSelection_callback = function(_t,_k) {
      return function(_dummy, args) {
      if ( !_t ) { _t = _k; }
      var value = _selectors[_t].value();
      _state[_t] = value;
      if ( ! _typeArgs[_t] ) { _typeArgs[_t] = {}; }
      if ( _typeArgs[_t][_k] == value ) { return; }
      _typeArgs[_t][_k] = value;
      _sbx.notify(obj.id,'TargetSelected',_t,_typeArgs[_t]);
    }
    }(_type,key);
    auto_comp.itemSelectEvent.subscribe(selection_callback);
    auto_comp.unmatchedItemSelectEvent.subscribe(unmatchedSelection_callback);
  };

  this._updateTargetSelector = function(type) {
    if ( type ) { _type = type; }
    for (var t in this.dom) {
      var el = this.dom[t];
      if ( t == _type ) {
        el.style.visibility = 'visible';
        el.style.position = 'relative';
      } else {
        el.style.visibility = 'hidden';
        el.style.position = 'absolute';
      }
    }
    return;
  };
  this.isStateValid = function() {
    if ( !_type ) { return false; }
    if ( !_selectors[_type].needValue ) { return true; }
    if ( !_state[_type] ) { return false; }
    return true;
  }
  this.getState = function() {
    return _state[_type];
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
          value = arr[1], arg;
      log('partnerHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'NavReset': {
          break;
        }
        case 'NewModuleArgs': {
          _moduleArgs = value;
          arg = _moduleArgs[_type];
          if ( arg ) {
            _typeArgs[_type][_type] = arg;
            _state[_type] = arg;
            _selectors[_type].updateGUI(arg);
          }
          break;
        }
        case 'TargetType': {
          o._updateTargetSelector(value);
          if ( _moduleArgs ) {
            arg = _moduleArgs[value];
            _typeArgs[_type] = _moduleArgs;
            if ( arg ) {
              _state[_type] = arg;
              _selectors[_type].updateGUI(arg);
            }
            _moduleArgs = null;
          }
          break;
        }
        case 'TargetTypes': {
          o._initTargetSelectors(value);
          if ( !o._sentDecoratorReady ) {
            _sbx.notify(obj.id,'decoratorReady',o.id);
            o._sentDecoratorReady = true;
          }
          break;
        }
        case 'StateChanged': {
          if ( value.module ) { _moduleArgs = value.module; }
          if ( value.type && value.type != _type ) {
            o._updateTargetSelector(value.type);
          }
          if ( value.target && value.target != _state[_type] ) {
            _typeArgs[_type] = {};
            _typeArgs[_type][_type] = value.target;
            _state[_type] = value.target;
            _selectors[_type].updateGUI(value.target);
          }
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify('Registry','getTargetTypes');
  this.moduleHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      log('moduleHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'needArguments': {
          if ( _moduleArgs ) {
log('why is _moduleArgs still set? '+Ylangd(_moduleArgs),'error',me);
            _sbx.notify(arr[1],'doSetArgs',_moduleArgs);
          }
          if ( _typeArgs[_type] ) {
            _sbx.notify(arr[1],'doSetArgs',_typeArgs[_type]);
          }
          break;
        }
      }
    }
  }(this);
  _sbx.listen('module', this.moduleHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'target', state:this.getState, isValid:this.isStateValid});
  return this;
};

PHEDEX.Navigator.TypeSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      _target_types,
      _target_type,
      me = 'typeselector';

  this.id = 'TypeSelector_' + PxU.Sequence();
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-type';

  this.setInputTypes = function() {
    // get registered target types and store them with optional config params
    var i, o, opts, menu_items=[], menu, type, tc=obj.cfg.typecfg, types=[];
    _target_types = {};
    for (type in tc) {
      opts=tc[type];
      if ( !opts ) { continue; }
      o = { 'name':type, 'label':'Explore by '+PxU.initialCaps(type), 'order': Number.POSITIVE_INFINITY },
      Yla(o, opts, true);
      _target_types[type] = o;
      types.push(type);
    }
    _sbx.notify(obj.id,'TargetTypes',_target_types);

    // sort types by object params
    types.sort(function(a, b) {
      return _target_types[a].order - _target_types[b].order;
    });

    // build menu items in sorted order
    for (i in types) {
      o = _target_types[types[i]];
      menu_items.push({ 'text': o.label, 'value': o.name });
    }
    menu = this.button.getMenu();
    if (Yu.Dom.inDocument(menu.element)) {
      menu.clearContent();
      menu.addItems(menu_items);
      menu.render();
    } else {
      menu.itemData = menu_items;
    }
  }
  this.button = new Yw.Button({ type: "menu",
    label: '(type)',
    menu: [],
    container: this.el
  });
  var onSelectedMenuItemChange = function(event) {
    if ( event.prevValue && event.newValue.value == event.prevValue.value ) { return; }
    var type = event.newValue.value;
    _sbx.notify(obj.id,'NeedNewModule'); // because the target-type has changed, I need to create a new widget for the new type
    _sbx.notify(obj.id,'TargetType',type);
  };
  this.button.on("selectedMenuItemChange", onSelectedMenuItemChange);

  this.isStateValid = function() {
    if ( _target_type ) { return true; }
    return false;
  }
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
      log('partnerHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'NavReset': {
          _sbx.notify(obj.id,'TargetTypes',_target_types);
          break;
        }
        case 'TargetType': {
          _target_type = value;
          o.button.set("label", _target_types[value].label);
          break;
        }
        case 'StateChanged': {
          _target_type = value.type;
          o.button.set("label", _target_types[_target_type].label);
          break;
        }
        case 'NeedTargetTypes': {
          _sbx.notify(obj.id,'TargetTypes',_target_types);
          break;
        }
        case 'InputTypes': {
          o.setInputTypes(value);
          if ( !o._sentDecoratorReady ) {
            _sbx.notify(obj.id,'decoratorReady',o.id);
            o._sentDecoratorReady = true;
          }
          break;
        }

        case 'NewModuleArgs': {
          this._moduleArgs = value;
          break;
        }
      }
    }
  }(this);
  this.registryHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1], key;
      log('registryHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'TypeOfModule': {
          for (i in value) {
            if ( _target_type == value[i] ) { return; }
          }
          for (key in value) {
            if ( this._moduleArgs[key] ) { _target_type = key; }
          }
          delete this._moduleArgs;
          _sbx.notify(obj.id,'TargetType',_target_type);
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id, this.partnerHandler);
  _sbx.listen(obj.id,  this.partnerHandler);
  _sbx.listen(this.id, this.registryHandler);
  _sbx.listen(obj.id,  this.registryHandler);
  _sbx.notify('Registry','getInputTypes',this.id);
  _sbx.notify(obj.id,'statePlugin', {key:'type', state:this.getState, isValid:this.isStateValid});
  return this;
};

PHEDEX.Navigator.InstanceSelector = function(sandbox,args) {
  var p    = args.payload,
      obj  = args.payload.obj,
      _sbx = sandbox,
      instances = PHEDEX.Datasvc.Instances(), // Get current instances
      _instances = {}, menu_items=[],
      _instance,
      indx, jsonInst,
      me = 'instanceselector',
      _stateIsValid = false;

  if (!instances) { throw new Error('cannot determine set of DB instances'); } //Something is wrong.. So dont process further..

  this.id = 'InstanceSelector_' + PxU.Sequence();
  this.el = document.createElement('div');
  this.el.className = 'phedex-nav-component phedex-nav-instance';
  for (indx = 0; indx < instances.length; indx++) {
    jsonInst = instances[indx];
    _instances[jsonInst.instance] = jsonInst;
    menu_items.push({ 'text': jsonInst.name, 'value': jsonInst.name });
   }

  this.menu = new Yw.Button({ type: "menu",
    label: '(instance)',
    menu: menu_items,
    container: this.el
  });

  var changeInstance = function(o) {
    return function(instance) {
      var _currInstance = PHEDEX.Datasvc.Instance();
      if ( !instance ) { return; }
      if ( typeof(instance) != 'object' ) {
        instance = PHEDEX.Datasvc.InstanceByName(instance);
      }

      if ( _currInstance.name != instance.name || !_stateIsValid ) {
        PHEDEX.Datasvc.Instance(instance.instance);
        log('change instance to '+instance.name,'info',obj.me);
        o.menu.set("label", instance.name);
        _stateIsValid = true;
      }
    };
  }(this);

  var onSelectedMenuItemChange = function(event) {
    if ( event.prevValue ) {
      if ( event.newValue.value == event.prevValue.value ) { return; }
    } else {
      if ( event.newValue.value == PHEDEX.Datasvc.Instance().instance ) { return; }
    }
    changeInstance(event.newValue.value);
    _sbx.notify(obj.id,'InstanceSelected',event.newValue.value);
    _sbx.notify('module','*','getData');
  };

  this.isStateValid = function() { return _stateIsValid; }
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
      log('partnerHandler: ev='+ev+' args='+Ylangd(arr,1),'info',me);
      switch (action) {
        case 'NavReset': {
          changeInstance('Production');
          break;
        }
        case 'StateChanged': {
          changeInstance(value.instance); //PHEDEX.Datasvc.InstanceByName(value.instance));
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.partnerHandler);
  _sbx.listen(obj.id, this.partnerHandler);
  _sbx.notify(obj.id,'statePlugin', {key:'instance', state:this.getState, isValid:this.isStateValid});
  _sbx.notify(obj.id,'decoratorReady',this.id);
  return this;
};

log('loaded...','info','navigator');
