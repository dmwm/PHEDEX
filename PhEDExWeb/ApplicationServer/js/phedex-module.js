/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX
 * @class Module
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.Module = function(sandbox, string) {
  Yla(this, new PHEDEX.Base.Object());
// this Id will serve both for the HTML element id and the ModuleID for the core, should it need it
  this.id = string+'_'+PxU.Sequence();
  log('creating "'+string+'"','info','module');
  var _sbx = sandbox;

  /**
   * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
   * @method _construct
   * @private
   */
  _construct = function() {
    return {
      me: string,
      meta: {},
      /**
       * Initialise the object by setting its properties. This simply sets the objects attributes, according to whatever algorithm is appropriate. It does not create DOM elements or PhEDEx data-structures, they are the province of <strong>initDom</strong> and <strong>initDerived</strong> respectively. Granular initialisation like this allows external components to intercede at specific points, should they wish to do so.
       * @method init
       * @private
       * @param opts {object} object containing initialisation parameters.
       */
      init: function(opts) {
        /** Options which alter the window behavior of this widget.  The
        * options are taken in priority order from:
        *  1. the constructor 'opts' argument 2. The PHEDEX.Util.Config
        * 'opts' for this element (<strong>is this still true?</strong>) 3. The defaults. These options are passed to the <strong>init</strong> method, not the constructor
        * @property options
        * @type object
        * @protected
        */
        var default_options = {
          /** Whether to make the widget behave like an OS window.
          * @property options.window
          * @type boolean
          * @private
          */
          window:true,

          /** Width of this widget.
          * @property options.width
          * @type int
          * @private
          */
          width:700,

          /** Height of this widget.
          * @property options.height
          * @type int
          * @private
          */
          height:150,

          /** Minimum width of this widget.
          * @property options.minwidth
          * @type int
          * @private
          */
          minwidth:10,

          /** Minimum height of this widget.
          * @property options.minheight
          * @type int
          * @private
          */
          minheight:10,

          /** Whether a floating window should be draggable.
          * @property options.draggable
          * @type boolean
          * @private
          */
          draggable:true,

          /** Wheather the window should be resizeable.
          * @property options.resizeable
          * @type boolean
          * @private
          */
          resizeable:true,

          /** Whether a draggable window should be able to go outside the browser window.
          * @property options.constraintoviewport
          * @type boolean
          * @private
          */
          constraintoviewport:false,

          /** Where a resizeable window should be have resize handles.  Use
          *  abbreviations t,r,b,l or a combination, e.g. 'tr'.
          * @property options.handles
          * @type array
          * @private
          */
          handles:['b','br','r'],

          /** Some forms of the web-application may only allow a single module to be displayed at any time,
          * others will allow many modules to be displayed simultaneously. This flag tells the current module
          * to destroy itself if another module is created
          * @property autoDestruct
          * @type boolean
          * @private
          */
          autoDestruct: true
        };
//      These defaults do not override those of the module (if any)
        Yla(this.options, default_options);
//      Options from the constructor do override defaults
        if ( opts ) { Yla(this.options, opts, true); }

        var ILive = function(obj) {
          return function() {
            _sbx.notify('ModuleExists',obj); }
          }(this);
        _sbx.listen('CoreCreated', ILive );
        _sbx.notify('ModuleExists',this);

        this.decorators.push( { name: 'MouseOver' } );
        for (var i in this.decorators) {
          var p = this.decorators[i].payload;
          if ( p && p.map ) {
            for (var j in p.map ) {
              this.allowNotify[p.map[j]] = 1;
            }
          }
        }

        this.meta._filter = this.createFilterMeta();
        _sbx.notify(this.id,'init');
      },

/** Array of names of methods that are allowed to be invoked by the default <strong>selfHandler</strong>, the method that listens for notifications directly to this module. Not all methods can or should be allowed to be triggered by notification, some methods send such notifications themselves to show that they have done their work (so the Core can pick up on it). If they were to allow notifications to trigger calls, you would have an infinite loop.
 * @property allowNotify {object}
 */
      allowNotify: {
                     doSort:1,
                     doFilter:1,
                     resizePanel:1,
                     hideFields:1,
                     menuSelectItem:1,
                     setArgs:1,
                     getData:1,
                     gotData:1,
                     datasvcFailure:1,
                     destroy:1,
                     getStatePlugin:1,
                     setState:1,
                     decoratorsConstructed:1,
                     lookingForA:1
                   },
/** Called by modules that need a partner. They indicate the class of the module they wish to hook up with, and the module replies with its Id.
 * @param arg { object} oject containing the <strong>callerId</strong> and the <strong>moduleClass</strong> it is looking for. If this objects <strong>me</strong> matches the moduleClass, it replies to the caller directly, using <strong>arg.callback</strong> to notify it where it wants.
 */
      lookingForA: function(arg) {
        if ( arg.moduleClass == '*' || arg.moduleClass == this.me ) {
          _sbx.notify(arg.callerId,arg.callback,{moduleClass:this.me, moduleId:this.id});
        }
      },

// These functions must be overridden by modules that need them. Providing them here avoids the need to test for their existence before calling them
      adjustHeader: function() {},
/** set the arguments for the module. Specifically, set the arguments that drive the PhEDEx data-service call, to get new or different data. Use for triggering a change of node, or change of link-direction etc.
 * @method setArgs
 */
      setArgs:      function() {},

/**
 * Set configuration options from an external source. Called after init(), but before anything else, so the module should be complete but not yet have any DOM elements or behavioural constraints.
 * @method setConfig
 * @param config {object} hash of configuration options
 * @public
 */
      setConfig: function(config) {
        var i;
        for ( i in config ) {
          this.options[i] = config[i];
        }
//      Special case for metadata
        for ( i in config.meta ) {
          this.meta[i] = config.meta[i];
        }
      },

/** initialisation specific to derived-types (i.e. PHEDEX.DataTable or PHEDEX.TreeView). May or may not be needed, depending on the specific module. Invoked automatically and internally by the core
 * @method initDerived
 * @private
 */
      initDerived:  function() {},
/** initialisation specific to this module. This is the last initialisation function called, by this point everything is live except for the data and the decorators. Implement this only in modules that need it.
 * @method initMe
 */
      initMe:       function() {},

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed.
 * @method initData
 */
      initData: function() {
log('Should not be here','warn','module');
      },

      /**
       * Called after initDom, this finishes the internal module-structure. Now that the object is complete, it can be made live, i.e. connected to the core by installing a listener for 'module'. It also installs a self-handler, listening for its own id. This is used for interacting with its decorations
       * @method initModule
       */
      initModule: function() {
        log(this.id+': initialising','info','module');

/** Automatically destroy this module if another is created, and my <strong>options.autoDestruct</strong> property is set. Achieve this by listening for <strong>ModuleExists</strong> events from newly created modules, and, if it is not from myself, shoot myself.
 * @method autoDestructHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event. The first argument is the module that has just been created. Compare its <strong>id</strong> to my own to prevent self-termination during my own creation.
 * @private
 */
        this.autoDestructHandler = function(obj) {
          return function(ev,arr) {
            if ( ! obj.options ) { return; }
            if ( ! obj.options.autoDestruct ) { return; }
            if ( arr[0].id == obj.id ) { return; }
            obj.destroy();
          }
        }(this);
        _sbx.listen('ModuleExists',this.autoDestructHandler);

/** Handle messages sent with the <strong>module</strong> event. This allows other components of the application to broadcast a message that will be caught by all modules. There is in principle some overlap between this function and the <strong>selfHandler</strong>, but they have different responses, so are not in fact equivalent. The <strong>genericHandler</strong> is not actually used anywhere yet!
 * @method genericHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event. The first argument is either null, or '*', or the name of a module. If it is null or '*', the event will be accepted. If it is anything else, it will only be accepted if it matches the name of this particular module. The second argument is the name of a member-function of this module, which is then invoked directly. The function will be invoked with a single argument, the third element of the array.
 * @private
 */
        this.genericHandler = function(obj) {
          return function(ev,arr) {
           var who = arr[0],
                action = arr[1];
            if ( who && who != '*' && who != obj.me ) { return; }
//          Special case for mapping 'doX*' to 'x*'
            if ( !obj.allowNotify[action] ) {
              if ( action.match('^do') ) {
                action = action.substring(2,3).toLowerCase() + action.substring(3,action.length);
                if ( !obj.allowNotify[action] ) { return; }
              }
            }
            if ( typeof(obj[action]) == 'null' ) { return; }
            if ( typeof(obj[action]) != 'function' ) {
//            is this really an error? Should I always be able to respond to a message from the core?
              throw new Error('Do not now how to execute "'+action+'" for module "'+obj.id+'"');
            }
            log('genericHandler action for event: '+action+' '+Ylang.dump(arr),'warn',obj.me);
            var arr1 = arr.slice();
            arr1.shift();
            arr1.shift();
            obj[action].apply(obj,arr1);
          }
        }(this);
        _sbx.listen('module',this.genericHandler);


/**
 * Handle messages sent directly to this module. This function is subscribed to listen for its own <strong>id</strong> as an event, and will take action accordingly. This is primarily for interaction with decorators, so actions are specific to the types of decorator. Some are toggles, e.g. <strong>show target</strong> and <strong>hide target</strong>. Others are hidden method-invocations (e.g. <strong>hideFields</strong>), where the action is used to invoke a function with the same name. Still others are more generic, such as <strong>expand</strong>, which require that the module that created the decoration specify a handler to be named when this function is invoked. <strong>expand</strong> specifically applies to <strong>PHEDEX.Component.Control</strong>, when used for the <strong>Extra</strong> field. The handler passed to the control constructor tells it which function will fill in the information in the expanded field.
 * @method selfHandler
 * @param ev {string} name of the event that was sent to this module
 * @param arr {array} array of arguments for the given event
 * @private
 */
        this.selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value = arr[1];
            switch (action) {
              case 'getData': {
                obj.needProcess = true;
                break;
              }
              case 'datasvcFailure': {
                obj.dom.title.innerHTML = 'Error fetching data';
                break;
              }
              case 'show target': { obj.adjustHeader( value); break; }
              case 'hide target': { obj.adjustHeader(-value); break; }
              case 'activate': {
                obj[value]();
                _sbx.notify(arr[2],action,'done');
                break;
              }
              case 'setConfig': {
                this.setConfig(value);
                break;
              }
              default: {
//              Special case for mapping 'doX*' to 'x*'
                if ( !obj.allowNotify[action] ) {
                  if ( action.match('^do') ) {
                    action = action.substring(2,3).toLowerCase() + action.substring(3,action.length);
                  }
                }
                if ( obj[action] && obj.allowNotify[action]) {
                    log('selfHandler: default action for event: '+action+' '+Ylang.dump(arr),'warn',obj.me);
                    var arr1 = arr.slice();
                    arr1.shift();
                    obj[action].apply(obj,arr1);
                }
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);

        /** The YAHOO container module used by this PhEDEx module.  If options.window is true, then
        * it is a YAHOO Panel, otherwise it is a YAHOO Module. The PhEDEx module is augmented with an appropriate subclass, depending on the value of options.window
        * @property module
        * @type Yw.Module|Yw.Panel
        * @private
        */
        var module_options = {
          close:false, // this.options.close,
          visible:true,
          draggable:this.options.draggable,
          // effect:{effect:Yw.ContainerEffect.FADE, duration: 0.3},
          width: this.options.width+"px",
          height: this.options.height+"px",
          constraintoviewport:this.options.constraintoviewport,
          context: ["showbtn", "tl", "bl"],
          underlay: "matte"
        };
        if ( this.options.window ) {
          Yla(this, new PHEDEX.AppStyle.Window(this,module_options),true);
        } else {
          delete module_options['width'];
          delete module_options['height'];
          module_options.draggable = false;
          this.module = new Yw.Module(this.el, module_options);
        }
        this.dom.body.style.padding = 0; // lame, but needed if our CSS is loaded before the YUI module CSS...
        if ( this.options.resizeable ) {
          Yla(this, new PHEDEX.AppStyle.Resizeable(this),true);
        }

        this.module.render();
//        YUI defines an element-style of 'display:block' on modules or panels. Remove it, we don't want it there...
        this.el.style.display=null;

        log('initModule complete','info','module');
      },

      /**
       * initialise the DOM elements for this module. Until this is called, the module has not interacted with the DOM. This function creates a container-element first, then creates all the necessary DOM substructure inside that element. It does not attach itself to the document body, it leaves that to the caller. Delaying the attachment can minimise re-flow in the browser, which would otherwise degrade performance
       * DOM substructure is created in the this.dom sub-object
       * @method initDom
       * @returns el (HTML element} the top-level container-element for this module
       */
      initDom: function() {
        /** The HTML element containing this widget.
        * @property el
        * @type HTML element
        * @private
        */
        var d  = this.dom,
            el = document.createElement('div');
        this.el = el;
        YuD.addClass(el,'phedex-core-widget');

        if ( this.options.noHeader ) {
          d.header = d.buttons = d.param = d.title = d.control = d.extra ={};
        } else {
          d.header  = PxU.makeChild(el, 'div', {className:'hd'});
          d.buttons = PxU.makeChild(d.header, 'span' );
          d.param   = PxU.makeChild(d.header, 'span', {className:'phedex-core-param'});
          d.title   = PxU.makeChild(d.header, 'span', {className:'phedex-core-title'});
          d.title.innerHTML = this.me+': initialising...';
          d.control = PxU.makeChild(d.header, 'span', {className:'phedex-core-control'});
          d.extra   = PxU.makeChild(d.header, 'div',  {className:'phedex-core-extra phedex-invisible'});
        }
        d.body    = PxU.makeChild(el, 'div', {className:'bd'});
        d.content = PxU.makeChild(d.body, 'div', {className:'phedex-core-content'});
        d.footer  = PxU.makeChild(el, 'div', {className:'ft'});

        log(this.id+' initDom complete','info','module');
        return el;
      },

      /**
       * allow the module to be visible on-screen by removing the <strong>phedex-invisible</strong> class from the container element
       * @method show
       */
      show: function() {
        log(this.id+': showing module "'+this.id+'"','info','module');
        YuD.removeClass(this.el,'phedex-invisible')
      },
      /**
       * make the module invisible on-screen by adding the <strong>phedex-invisible</strong> class to the container element
       * @method hide
       */
      hide: function() {
        log(this.id+': hiding module "'+this.id+'"','info','module');
        YuD.addClass(this.el,'phedex-invisible')
      },
      /**
       * destroy the object. Attempts to do this thoroughly by first destroying all the DOM elements, then attempting to find and destroy all sub-objects. It does this by calling this.subobject.destroy() for all subobjects that have a destroy method. It then deletes the sub-object from the module, so the garbage collecter can get its teeth into it.
       * Also signal the sandbox with (this.id,'destroy'), so that decorations can be notified that they should shoot themselves too.
       * @method destroy
       */
      destroy: function() {
        this.destroyDom();
        _sbx.notify(this.id,'destroy');
        for (var i in {ctl:0,dom:0}) {
          for (var j in this[i]) {
            if ( typeof(this[i][j]) == 'object' && typeof(this[i][j].destroy) == 'function' ) {
              try { this[i][j].destroy(); } catch(ex) {} // blindly destroy everything we can!
            }
            delete this[i][j];
          }
        }
        for (var i in this) {
          if ( this[i] && typeof(this[i]) == 'object' && typeof(this[i].destroy) == 'function' ) {
            try { this[i].destroy(); } catch(ex) {} // blindly destroy everything we can!
          }
          delete this[i];
        }
      },

      /**
       * destroy all DOM elements. Used by destroy()
       * @method destroyDom
       * @private
       */
      destroyDom: function(args) {
        log(this.id+': destroying DOM elements','info','module');
        while (this.el.hasChildNodes()) { this.el.removeChild(this.el.firstChild); }
        this.dom = [];
      },

      revealAllElements: function(className) {
        var elList = YuD.getElementsByClassName(className,null,this.dom.content);
        for (var i in elList) {
          if ( YuD.hasClass(elList[i],'phedex-invisible') ) {
            YuD.removeClass(elList[i],'phedex-invisible');
          }
          if ( YuD.hasClass(elList[i],'phedex-core-control-widget-applied') ) {
            YuD.removeClass(elList[i],'phedex-core-control-widget-applied');
          }
        }
      },

/** return an object defining the statePlugin, with <strong>key</strong>, <strong>state</strong>, and <strong>isValid</strong>fields
 * @method getStatePlugin
 * @return state-plugin {object} with two keys, <strong>state</strong> (a function that will return a string representing the state) and <strong>isStateValid</strong> (function that returns a boolean telling if the state is valid for bookmarking)
 */
      getStatePlugin: function(who) {
        _sbx.notify(who,'statePlugin', {key:'module', state:this['getState'], isValid:this['isStateValid'], obj:this});
      },

/** create the necessary metadata to facilitate filter-functionality. This is just a reformatting of the filter-definition into a bunch of look-up hashes.
 * @method createFilterMeta
 * @return object containing the metadata
 */
      createFilterMeta: function() {
        if ( this.meta._filter ) { return this.meta._filter; }
        var meta = { structure: { f:{}, r:{} }, rFriendly:{}, fields:{} },  // mapping of field-to-group, and reverse-mapping of same
            f = this.meta.filter,
            re, str, i, j, k, l, key, fn;

        for (i in f) {
          l = {};
          for (j in f[i].fields) {
            k = j.replace(/ /g,'');
            l[k] = f[i].fields[j];
            l[k].original = j;
          }
          f[i].fields = l;

          if ( f[i].map ) {
            fn = function( m ) {
              return function(k) {
                var re, str = k;
                if ( m.from ) {
                  re = new RegExp(m.from,'g');
                  str = str.replace(re,'');
                }
                str = m.to + '.' + str;
                return str;
              };
            }(f[i].map);
          } else {
            fn = function( m ) { return m; }
          }

          meta.structure['f'][i] = [];
          for (j in f[i].fields) {
            meta.structure['f'][i][j]=0;
            meta.structure['r'][j] = i;
            var fName = fn(j);
            meta.fields[j] = f[i].fields[j];
            meta.fields[j].friendlyName = fName;
            meta.rFriendly[fName.toLowerCase()] = j;
          }
        }
        return meta;
      },

/** Map an internal representation of a module-field into a more human-friendly version. This is used for treeviews primarily, to map the className for the element onto a string that is easier for people to remember
 * @method friendlyName
 * @param key {string} the unfriendly name of the field
 * @return {string} the friendly name
 */
      friendlyName: function(key) {
        key = key.replace(/ /g,'');
        if ( this.meta._filter.fields[key] ) {
          return this.meta._filter.fields[key].friendlyName;
        }
      },

/** Map a friendly-name back to the internal representation used in the derived module. Used primarily for treeviews.
 * @method unFriendlyName
 * @param key {string} the friendly name of the field
 * @return the unfriendly name
 */
      unFriendlyName: function(key) {
        return this.meta._filter.rFriendly[key.toLowerCase()];
      },

/** return a string with the state of the object. The object must be capable of receiving this string and setting it's state from it
 * @method getState
 * @return {string} the state of the object, in any reasonable format that conforms to the navigator's parser
 */
      getState: function() {
        var state = '',
            m = this.meta, i, key, seg, s;
        if ( !m ) { return state; }
        if ( m.sort && m.sort.field ) {
          state = 'sort{'+this.friendlyName(m.sort.field)+' '+this.dirMap(m.sort.dir);
          if ( m.sort.type ) { state += ' '+m.sort.type; }
          state += '}';
        }
        if ( m.hide ) {
          seg = '';
          i = 0;
          for (key in m.hide) {
            if ( key == '__NESTED__' ) { continue; }
            if ( i++ ) { seg += ' '; }
            seg += this.friendlyName(key);
          }
          if ( seg ) { state += 'hide{'+seg+'}'; }
        }
        if ( this.ctl.Filter ) { // TODO this ought really to be a state-plugin for the filter, rather than calling it directly?
          seg = this.ctl.Filter.asString();
          if ( seg ) { state += 'filter{'+seg+'}'; }
        }
        if ( typeof(this.specificState) == 'function' )
        {
          seg = '';
          i = 0;
          s = this.specificState();
          for (key in s) {
            if ( i++ ) { seg += ' '; }
            seg += key+'='+s[key];
          }
          if ( seg ) { state += 'specific{'+seg+'}'; }
        }
        return state;
      },

      setState: function(s) {
        var arr, i, x, m = this.meta, f = m._filter.fields,
            component, negate, name, name2, fName, value, min, max,
            op, opMap = { '=':'value', '<':'max', '>':'min' };
        if ( s.specific ) {
          this.specificState(s.specific);
        }
        if ( s.hide != null ) {
          arr = s.hide.split(' ');
          m.hide = {};
          for (i in arr) {
            m.hide[m._filter.fields[this.unFriendlyName(arr[i])].original] = 1;
          }
        }
        if ( s.sort != null ) {
          arr = s.sort.split(' ');
          m.sort = { field:this.unFriendlyName(arr[0]), dir:this.dirMap(arr[1]) };
          if ( arr[2] ) { m.sort.type = arr[2]; }
        }
        if ( s.filter != null ) {
// TODO go through the fields destroying the default values. Is this done correctly?
          for (fName in f) {
            if ( f[fName].value ) { delete f[fName].value; }
            if ( f[fName].min   ) { delete f[fName].min; }
            if ( f[fName].max   ) { delete f[fName].max; }
          }
          s.filter = s.filter.replace(/(\([^( ]+) ([^) ]+\))/,"$1&$2"); // deal with spaces between parentheses before splitting on spaces
          arr = s.filter.split(' ');
          for (i in arr) {
            component = arr[i];
            if ( component.match(/^(!)?\(([^<>]+)[<>]([^&]+)&([^<>]+)[<>]([^)]+)\)$/) ) {
              negate = RegExp.$1 ? true : false;
              name   = RegExp.$2;
              min    = RegExp.$3;
              name2  = RegExp.$4;
              max    = RegExp.$5;
              if ( name != name2 ) {
                throw new Error('inconsistant filter syntax, grouping of different elements ("'+name+'" and "'+name2+'")');
              }
              fName = this.unFriendlyName(name);
              if ( f[fName] ) { // a bookmarked global-filter may contain fields that are not in this module!
                f[fName].min = min;
                f[fName].max = max;
                f[fName].negate = negate;
              }
              continue;
            }
            if ( component.match('^(!)?([^=<>(]+)([=<>])(.*)$') ) {
              negate = RegExp.$1 ? true : false;
              name   = RegExp.$2;
              op     = RegExp.$3;
              value  = RegExp.$4;
              fName = this.unFriendlyName(name);
              if ( f[fName] ) { // a bookmarked global-filter may contain fields that are not in this module!
                f[fName][opMap[op]]  = value;
                f[fName].negate = negate;
              }
            }
          }
        }
      }

    };
  };
  Yla(this, _construct());
  return this;
};

/**
 * For 'window-like' behaviour (multiple modules on-screen, draggable, closeable), this object provides the necessary extra initialisation. Never called or created in isolation, it is used only by the PHEDEX.Module class internally, in the constructor.
 * @namespace PHEDEX.AppStyle
 * @class Window
 * @param obj {object} the PHEDEX.Module that should be augmented with a PHEDEX.AppStyle.Window
 * @param module_options {object} options used to set the module properties
 */
PHEDEX.namespace('AppStyle');
PHEDEX.AppStyle.Window = function(obj,module_options) {
  var pType = PHEDEX[obj.type];
  if ( !pType ) { return; }
  if (pType.Window ) {
    Yla(obj,new pType.Window(obj),true);
  }
  YuD.addClass(obj.el,'phedex-panel');
  this.module = new Yw.Panel(obj.el, module_options);
  /**
   * adjust the height of the panel header element to accomodate new stuff inside it. Used for showing 'extra' information, etc. Useful for 'window'-mode panels, where the size of the container on display is fixed. When 'extra' information is shown, the fixed-size needs to be adjusted to make room for it.
   * @method adjustHeader
   * @private
   * @param arg {int} number of pixels (positive or negative) by which the height of the header should be adjusted
   */
  this.adjustHeader = function(arg) { // 'window' panels need to respond to header-resizing
    var oheight = parseInt(this.module.cfg.getProperty("height"));
    if ( isNaN(oheight) ) { return; } // nothing to do if the height is not specified
    var hheight = parseInt(this.module.header.offsetHeight);
    this.module.header.style.height=(hheight+arg)+'px';
    this.module.cfg.setProperty("height",(oheight+arg)+'px');
  };
  var ctor = function(sandbox,args) {
    var el = document.createElement('img');
    el.src = '/images/widget-close.gif';
    el.style.cssFloat = 'right';
    el.style.padding = '2px 0 0';
    el.title = 'click here to close this module';
    YuE.addListener(el, "click", function() { this.destroy(); }, null, args.payload.obj);
    return { el:el };
  };
  var close = { name:'close', parent:'control', ctor:ctor};
  obj.decorators.push(close);
}

/**
 * For resizeable modules ('window-like'), this object provides the necessary extra initialisation. Never called or created in isolation, it is used only by the PHEDEX.Module class internally, in the constructor.
 * @namespace PHEDEX.AppStyle
 * @class Resizeable
 * @param obj {object} the PHEDEX.Module whose on-screen representation should be resizeable
 */
PHEDEX.AppStyle.Resizeable = function(obj) {
  var pType = PHEDEX[obj.type];
  if ( !pType ) { return; }
  if ( pType.hasOwnProperty('Resizeable') ) {
    Yla(obj,new pType.Resizeable(obj),true);
  }
  YuD.addClass(obj.el,'phedex-resizeable-panel');

  /** Handles the resizing of this widget.
  * @property resize
  * @type YAHOO.util.Resize
  * @private
  */
  this.resize = new Yu.Resize(obj.el, {
    handles: obj.options.handles,
    autoRatio: false,
    minWidth:  obj.options.minwidth,
    minHeight: obj.options.minheight,
    status: false
  });
  this.resize.on('resize', function(args) {
    var panelHeight = args.height;
    if ( panelHeight > 0 ) {
      this.cfg.setProperty("height", panelHeight + "px");
    }
  }, obj.module, true);
// Setup startResize handler, to constrain the resize width/height
// if the constraintoviewport configuration property is enabled.
  this.resize.on('startResize', function(args) {
    if (this.module.cfg.getProperty("constraintoviewport")) {
      var clientRegion = YuD.getClientRegion(),
          elRegion = YuD.getRegion(this.module.element),
          w = clientRegion.right - elRegion.left - Yw.Overlay.VIEWPORT_OFFSET,
          h = clientRegion.bottom - elRegion.top - Yw.Overlay.VIEWPORT_OFFSET;

      this.resize.set("maxWidth", w);
      this.resize.set("maxHeight", h);
    } else {
      this.resize.set("maxWidth", null);
      this.resize.set("maxHeight", null);
    }
  }, obj, true);
}

log('loaded...','info','module');
