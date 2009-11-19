/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX
 * @class Module
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.Module = function(sandbox, string) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
// this Id will serve both for the HTML element id and the ModuleID for the core, should it need it
  this.id = string+'_'+PxU.Sequence();
  log('creating "'+string+'"','info','Module');
  var _sbx = sandbox;

  /**
   * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
   * @method _construct
   * @private
   */
  var _construct = function() {
    return {
      me: string,
      /**
       * initialise the object by setting its properties
       * @method _init
       * @private
       * @param opts {object} object containing initialisation parameters.
       */
      _init: function(opts) {
        /** Options which alter the window behavior of this widget.  The
        * options are taken in priority order from:
        *  1. the constructor 'opts' argument 2. The PHEDEX.Util.Config
        * 'opts' for this element 3. The defaults. These options are passed to the <strong>_init</strong> method, not the constructor
        * @property options
        * @type object
        * @protected
        */
        this.options = {
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
        };
        // Options from the constructor override defaults
        YAHOO.lang.augmentObject(this.options, opts, true);
        _sbx.listen('CoreCreated',function() { _sbx.notify('ModuleExists',this.id,this); });
        _sbx.notify('ModuleExists',this);

        this.decorators.push(
          {
            name:'Filter',
            source: 'component-control',
            parent: 'control',
            payload:{
              disabled: true,
              hidden:   true,
              target:  'filter',
              fillFn:  'filter.Build',
              fillArgs:'fillArgs',
              animate:  false,
//              onHideControl:this.onHideFilter,
//              onShowControl:this.onShowFilter
            }
          }
        );
      },

      adjustHeader: function() {},

      /**
       * now that the object is complete, it can be made live, i.e. connected to the core by installing a listener for 'module'. It also installs a self-handler, listening for its own id. This is used for interacting with its decorations
       * @method initModule
       */
      initModule: function() {
        log(this.id+': initialising','info','Module');

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
            if ( who && who != '*' && who != obj.id ) { return; }
            if ( typeof(obj[action]) == 'null' ) { return; }
            if ( typeof(obj[action]) != 'function' ) {
//            is this really an error? Should I always be able to respond to a message from the core?
              throw new Error('Do not now how to execute "'+action+'" for module "'+obj.id+'"');
            }
            obj[action](arr[2]);
          }
        }(this);
        _sbx.listen('module',this.genericHandler);

/**
 * Handle messages sent directly to this module. This function is subscribed to listen for its own <strong>id</strong> as an event, and will take action accordingly. This is primarily for interaction with decorators, so actions are specific to the types of decorator. Some are toggles, e.g. <strong>show target</strong> and <strong>hide target</strong>. Others are hidden method-invocations (e.g. <strong>hideByDefault</strong>), where the action is used to invoke a function with the same name. Still others are more generic, such as <strong>expand</strong>, which require that the module that created the decoration specify a handler to be named when this function is invoked. <strong>expand</strong> specifically applies to <strong>PHEDEX.Component.Control</strong>, when used for the <strong>Extra</strong> field. The handler passed to the control constructor tells it which function will fill in the information in the expanded field.
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
              case 'show target': { obj.adjustHeader( value); break; }
              case 'hide target': { obj.adjustHeader(-value); break; }
              case 'expand': {
                obj[value]();
                _sbx.notify(arr[2],action,'done');
                break;
              }
              case 'resizePanel':
              case 'hideByDefault':
              case 'menuSelectItem': {
                if ( obj[action] ) {
                  arr.shift();
                  obj[action](arr);
                }
                break;
              }
//               default: { log('unhandled event: '+action,'warn',obj.me); break; }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);

        /** The YAHOO container module used by this PhEDEx module.  If options.window is true, then
        * it is a YAHOO Panel, otherwise it is a YAHOO Module. The PhEDEx module is augmented with an appropriate subclass, depending on the value of options.window
        * @property module
        * @type YAHOO.widget.Module|YAHOO.widget.Panel
        * @private
        */
        var module_options = {
          close:false, // this.options.close,
          visible:true,
          draggable:this.options.draggable,
          // effect:{effect:YAHOO.widget.ContainerEffect.FADE, duration: 0.3},
          width: this.options.width+"px",
          height: this.options.height+"px",
          constraintoviewport:this.options.constraintoviewport,
          context: ["showbtn", "tl", "bl"],
          underlay: "matte"
        };
        if ( this.options.window ) {
          YAHOO.lang.augmentObject(this, new PHEDEX.AppStyle.Window(this,module_options),true);
        } else {
          delete module_options['width'];
          delete module_options['height'];
          module_options.draggable = false;
          this.module = new YAHOO.widget.Module(this.el, module_options);
        }
        this.dom.body.style.padding = 0; // lame, but needed if our CSS is loaded before the YUI module CSS...
        if ( this.options.resizeable ) {
          YAHOO.lang.augmentObject(this, new PHEDEX.AppStyle.Resizeable(this),true);
//         } else {
        }

        this.module.render();
//        YUI defines an element-style of 'display:block' on modules or panels. Remove it, we don't want it there...
        this.el.style.display=null;

        log('initModule complete','info','Module');
      },

      /**
       * initialise the DOM elements for this module. Until this is called, the module has not interacted with the DOM. This function creates a container-element first, then creates all the necessary DOM substructure inside that element. It does not attach itself to the document body, it leaves that to the caller.
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
        this.el = document.createElement('div');
        YAHOO.util.Dom.addClass(this.el,'phedex-core-widget');

        this.dom.header  = PxU.makeChild(this.el, 'div', {className:'hd'});
        this.dom.param   = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-param'});
        this.dom.title   = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-title'});
        this.dom.title.innerHTML = this.me+': initialising...';
        this.dom.control = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-control float-right'});
        this.dom.extra   = PxU.makeChild(this.dom.header, 'div', {className:'phedex-core-extra phedex-invisible'});
        this.dom.body    = PxU.makeChild(this.el, 'div', {className:'bd'});
        this.dom.content = PxU.makeChild(this.dom.body, 'div', {className:'phedex-core-content'});
        this.dom.footer  = PxU.makeChild(this.el, 'div', {className:'ft'});
        log(this.id+' initDom complete','info','Module');
        return this.el;
      },

      /**
       * allow the module to be visible on-screen by removing the <strong>phedex-invisible</strong> class from the container element
       * @method show
       */
      show: function() {
        log(this.id+': showing module "'+this.id+'"','info','Module');
        YAHOO.util.Dom.removeClass(this.el,'phedex-invisible')
      },
      /**
       * make the module invisible on-screen by adding the <strong>phedex-invisible</strong> class to the container element
       * @method hide
       */
      hide: function() {
        log(this.id+': hiding module "'+this.id+'"','info','Module');
        YAHOO.util.Dom.addClass(this.el,'phedex-invisible')
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
          if ( typeof(this[i]) == 'object' && typeof(this[i].destroy) == 'function' ) {
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
        log(this.id+': destroying DOM elements','info','Module');
        while (this.el.hasChildNodes()) { this.el.removeChild(this.el.firstChild); }
        this.dom = [];
      },
    };
  };
  YAHOO.lang.augmentObject(this, _construct());
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
  if ( PHEDEX[obj.type].Window ) {
    YAHOO.lang.augmentObject(obj,new PHEDEX[obj.type].Window(obj),true);
  }
  YAHOO.util.Dom.addClass(obj.el,'phedex-panel');
  this.module = new YAHOO.widget.Panel(obj.el, module_options);
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
    YAHOO.util.Event.addListener(el, "click", function() { this.destroy(); }, null, args.payload.obj);
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
  if ( PHEDEX[obj.type].hasOwnProperty('Resizeable') ) {
    YAHOO.lang.augmentObject(obj,new PHEDEX[obj.type].Resizeable(obj),true);
  }
  YAHOO.util.Dom.addClass(obj.el,'phedex-resizeable-panel');

  /** Handles the resizing of this widget.
  * @property resize
  * @type YAHOO.util.Resize
  * @private
  */
  this.resize = new YAHOO.util.Resize(obj.el, {
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
      var clientRegion = YAHOO.util.Dom.getClientRegion(),
          elRegion = YAHOO.util.Dom.getRegion(this.module.element),
          w = clientRegion.right - elRegion.left - YAHOO.widget.Overlay.VIEWPORT_OFFSET,
          h = clientRegion.bottom - elRegion.top - YAHOO.widget.Overlay.VIEWPORT_OFFSET;

      this.resize.set("maxWidth", w);
      this.resize.set("maxHeight", h);
    } else {
      this.resize.set("maxWidth", null);
      this.resize.set("maxHeight", null);
    }
  }, obj, true);
}

//
//   this.textNodeMap = [];
//   this.hideByDefault = [];
//   this._cfg = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}};
//
//   this.onHideFilter.subscribe(function() {
//       this.filter.destroy();
//       var isApplied = this.filter.isApplied();
//       this.ctl.filter.setApplied(isApplied);
//       PHEDEX.Event.onWidgetFilterApplied.fire(isApplied);
//     });
//
//   this.onAcceptFilter.subscribe( function(obj) {
//     return function() {
//       YAHOO.log('onAcceptFilter:'+obj.me(),'info','Core.Widget');
//       obj.filter.Parse();
//     }
//   }(this));
// 
//   PHEDEX.Event.onGlobalFilterApplied.subscribe( function(obj) {
//     return function(ev,arr) {
//       var isApplied = arr[0];
//       obj.ctl.filter.setApplied(isApplied);
//     }
//   }(this));
// 
//   PHEDEX.Event.onFilterDefined.subscribe( function() {
//     return function(ev,arr) {
//       var args = arr[0];
//       var widget = arr[1];
//       widget.filter.init(args);
//     }
//   }());
// 
//   this.onBuildComplete.subscribe(function() {
//     YAHOO.log('onBuildComplete: '+this.me(),'info','Core.Widget');
//     // filter
//     var fillArgs = { context:[this.dom.body,"tl","tl", ["beforeShow", "windowResize"]],
// 		     visible:false,
// 		     autofillheight:'body',
// 		     width:this.dom.body.offsetWidth+'px'
// 		   };
//     this.ctl.filter = new PHEDEX.Core.Control({text:'Filter',
// 					       payload:{target:this.dom.filter,
// 							fillFn:this.filter.Build,
// 							fillArgs:fillArgs,
// 							obj:this,
// 							animate:false,
// 							hover_timeout:200,
// 							onHideControl:this.onHideFilter,
// 							onShowControl:this.onShowFilter
// 						       }
// 					      });
//     YAHOO.util.Dom.insertBefore(this.ctl.filter.el,this.dom.control.firstChild);
//     if ( !this.filter.isDefined() ) { this.ctl.filter.Disable(); }
//   });
// 
//   // Create a (usually hidden) progress indicator.
//   this.control.progress = PxU.makeChild(this.dom.control, 'img', {src:'/images/progress.gif'});
// 
//   if (this.options.window) {
//     this.control.close = PxU.makeChild(this.dom.control, 'img', {src:'/images/widget-close.gif'});
//     YAHOO.util.Event.addListener(this.control.close, "click", this.destroy, null, this);
//   }
