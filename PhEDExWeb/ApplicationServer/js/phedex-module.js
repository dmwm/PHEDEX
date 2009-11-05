PHEDEX.Module = function(sandbox, string) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  this.id = string+'_'+PxU.Sequence();
  log('creating "'+string+'"','info','Module');
  var _sbx = sandbox;

  var _construct = function() {
    return {
      me: string,
      _init: function(opts) {
        /** Options which alter the window behavior of this widget.  The
        * options are taken in priority order from:
        *  1. the constructor 'opts' argument 2. The PHEDEX.Util.Config
        * 'opts' for this element 3. The defaults.
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

          /** Minimum width of this widget.
          * @property options.minwidth
          * @type int
          * @private
          */
          minheight:10,

          /** Whether a floating window should be draggable.
          * @property options.minwidth
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
        // this Id will serve both for the HTML element id and the ModuleID for the core, should it need it
        _sbx.listen('CoreCreated',function() { _sbx.notify('ModuleExists',this.id,this); });
        _sbx.notify('ModuleExists',this);
      },

      adjustHeader: function() {},

      initModule: function() {
        log(this.id+': initialising','info','Module');

//      handle messages from the core. Not actually used anywhere yet!
        var coreHandler = function(obj) {
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
        _sbx.listen('module',coreHandler);

//      handle messages directly to me...
        var selfHandler = function(obj) {
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
        _sbx.listen(this.id,selfHandler);

        /** The module used by this widget.  If options.window is true, then
        * it is a Panel, otherwise it is a Module.
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
          YAHOO.lang.augmentObject(this, new PHEDEX.Module.Window(this,module_options),true);
        } else {
          delete module_options['width'];
          delete module_options['height'];
          module_options.draggable = false;
          this.module = new YAHOO.widget.Module(this.el, module_options);
        }
        this.dom.body.style.padding = 0; // lame, but needed if our CSS is loaded before the YUI module CSS...
        if ( this.options.resizeable ) {
          YAHOO.lang.augmentObject(this, new PHEDEX.Module.Resizeable(this),true);
//         } else {
        }

        this.module.render();
//        YUI defines an element-style of 'display:block' on modules or panels. Remove it, we don't want it there...
        this.el.style.display=null;

        log('initModule complete','info','Module');
      },

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

      show: function(args) {
        log(this.id+': showing module "'+this.id+'"','info','Module');
        YAHOO.util.Dom.removeClass(this.el,'phedex-invisible')
      },
      hide: function(args) {
        log(this.id+': hiding module "'+this.id+'"','info','Module');
        YAHOO.util.Dom.addClass(this.el,'phedex-invisible')
      },
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

PHEDEX.Module.Window = function(obj,module_options) {
  if ( PHEDEX[obj.type].Window ) {
    YAHOO.lang.augmentObject(obj,new PHEDEX[obj.type].Window(obj),true);
  }
  YAHOO.util.Dom.addClass(obj.el,'phedex-panel');
  this.module = new YAHOO.widget.Panel(obj.el, module_options);
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

PHEDEX.Module.Resizeable = function(obj) {
  if ( PHEDEX[obj.type].Resizeable ) {
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
//   this.control = [];
//   this.data   = [];
//   this._cfg = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}};
//
//   this.filter.onFilterApplied = new YAHOO.util.CustomEvent("onFilterApplied", this, false, YAHOO.util.CustomEvent.LIST);
//   this.onAcceptFilter         = new YAHOO.util.CustomEvent("onAcceptFilter", this, false, YAHOO.util.CustomEvent.LIST);
//   this.onShowFilter           = new YAHOO.util.CustomEvent("onShowFilter",  this, false, YAHOO.util.CustomEvent.LIST);
//   this.onHideFilter           = new YAHOO.util.CustomEvent("onHideFilter",  this, false, YAHOO.util.CustomEvent.LIST);
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