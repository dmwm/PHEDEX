/** The Widget class serves as the base class for all graphical elements
 * in Appserv.  It holds a YAHOO.widget.Module (or Panel), and
 * provides convenience functions for populating the header, body, and
 * footer of that module.  Functional widgets should subclass this,
 * calling the superconstructor with either a ready div or an ID of an
 * existing div, and then implement their own methods to generate the
 * content, and handle updates.
 * 
 * @namespace PHEDEX.Core
 * @class Widget
 * @extends PHEDEX.Base.Object
 * @uses PHEDEX.Core.Filter
 * @param {string|HTML Element} divid   The dom element or element id which shall become the parent of the widget.
 * @param {object}              opts    The options for widget creation.
 * @constructor
 */
PHEDEX.namespace('Core.Widget');
PHEDEX.Core.Widget = function(divid,opts) {
  // Base object definitions, shared between all PhEDEx objects
  YAHOO.lang.augmentObject(this, PHEDEX.Base.Object(this));
  YAHOO.lang.augmentObject(this, PHEDEX.Core.Filter(this));

  // Require divid of some kind
  if ( !divid ) { throw new Error("must provide div name to contain widget"); }

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

    /** Wheather the window should be resizable.
     * @property options.resizeable
     * @type boolean
     * @private 
     */
    resizable:true,

    /** Whether a draggable window should be able to go outside the browser window.
     * @property options.constraintoviewport
     * @type boolean
     * @private
     */
    constraintoviewport:false,

    /** Where a resizable window should be have resize handles.  Use
     *  abbreviations t,r,b,l or a combination, e.g. 'tr'.
     * @property options.handles
     * @type array
     * @private
     */
    handles:['b','br','r'],
  };

  // Options from the constructor override defaults
  YAHOO.lang.augmentObject(this.options, opts, true);

  // Options from a configuration overide constructor
  var config = PxU.getConfig(divid);
  YAHOO.lang.augmentObject(this.options, config.opts, true);


  /** The parent element this widget will be created in.  It is looked
   * up from the DOM or created using the 'divid' constructor param.
   * If we created the div, we append the 'created' property to
   * 'parent' in order to mark it for later cleanup.
   * @property parent
   * @type DOM-node
   * @private
   */
  if ( typeof(divid) != 'object' ) {
    this.parent = document.getElementById(divid);
    if ( !this.parent ) {
      this.parent = PxU.findOrCreateWidgetDiv(divid);
      this.parent.created = true;
    }
  } else {
    this.parent = divid;
  }

  /** The id of the element containing this widget.
   * @property id
   * @type string
   * @private
   */
  this.id = PxU.generateDivName(this.parent.id);

  /** The HTML Element containing this widget.
   * @property div
   * @type HTML Element
   * @private
   */
  this.div = PxU.findOrCreateWidgetDiv(this.id, this.parent.id);

  /** FIXME:  Should this be defined here?
   * @property textNodeMap
   * @type array
   * @protected
   */
  this.textNodeMap = [];

  /** FIXME:  Should this be defined here?
   * @property hideByDefault
   * @type array
   * @protected
   */
  this.hideByDefault = [];

  /** FIXME:  Should this be defined here?
   * A collection of controls to put into the header.
   * @property control
   * @type object
   * @protected
   */
  this.control = {};

  /** FIXME:  Should this be defined here?
   * @property data
   * @type array
   * @protected
   */
  this.data   = [];

  /** FIXME:  Should this be defined here?
   * @property _cfg
   * @type array
   * @protected
   */
  this._cfg = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}};

  // This may be heavy-handed, wipe out all children and rebuild from scratch. For now, it works well enough...
  while (this.div.hasChildNodes()) { this.div.removeChild(this.div.firstChild); }

  YAHOO.util.Dom.addClass(this.div,'phedex-core-widget');
  if (this.options.window) {
    YAHOO.util.Dom.addClass(this.div,'phedex-panel');
  }

  // Create the structure for the embedded module
  this.dom.header = PxU.makeChild(this.div, 'div', {className:'hd'});
  this.dom.param = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-param'});
  this.dom.title = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-title'});
  this.dom.control = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-control'});
  this.dom.extra = PxU.makeChild(this.dom.header, 'div', {className:'phedex-core-extra phedex-invisible'});
  this.dom.body = PxU.makeChild(this.div, 'div', {className:'bd', id:this.id+'_body'});
  this.dom.content = PxU.makeChild(this.dom.body, 'div', {className:'phedex-core-content',id:this.id+'_content'});
  this.dom.footer = PxU.makeChild(this.div, 'div', {className:'ft'});

  /** The module used by this widget.  If options.window is true, then
   * it is a Panel, otherwise it is a Module.
   * @property module
   * @type YAHOO.widget.Module|YAHOO.widget.Panel
   * @private
   */
  var module_options = {
    close:false,  //this.options.close,
    visible:true,
    draggable:this.options.draggable,
    //       effect:{effect:YAHOO.widget.ContainerEffect.FADE, duration: 0.3},
    width: this.options.width+"px",
    height: this.options.height+"px",
    constraintoviewport:this.options.constraintoviewport,
    context: ["showbtn", "tl", "bl"],
    underlay: "matte"
  };
  if ( !this.options.window ) {
    delete module_options['width'];
    delete module_options['height'];
    module_options.draggable = false;
    this.module = new YAHOO.widget.Module(this.id, module_options);
  } else {
    this.module = new YAHOO.widget.Panel(this.id, module_options);
  }

  this.module.render();

  // (Optionally) Make resizable
  if ( this.options.window && this.options.resizable ) {
    YAHOO.util.Dom.addClass(this.div,'phedex-resizeable-panel');

    /** Handles the resizing of this widget.
     * @property resize
     * @type YAHOO.util.Resize
     * @private
     */
    this.resize = new YAHOO.util.Resize(this.id, {
      handles: this.options.handles,
      autoRatio: false,
      minWidth:  this.options.minwidth,
      minHeight: this.options.minheight,
      status: false
    });
    this.resize.on('resize', function(args) {
      var panelHeight = args.height;
      if ( panelHeight > 0 )
      {
	this.cfg.setProperty("height", panelHeight + "px");
      }
    }, this.module, true);
    // Setup startResize handler, to constrain the resize width/height
    // if the constraintoviewport configuration property is enabled.
    this.resize.on('startResize', function(args) {
      if (this.cfg.getProperty("constraintoviewport")) {
        var clientRegion = YAHOO.util.Dom.getClientRegion();
        var elRegion = YAHOO.util.Dom.getRegion(this.element);
        var w = clientRegion.right - elRegion.left - YAHOO.widget.Overlay.VIEWPORT_OFFSET;
        var h = clientRegion.bottom - elRegion.top - YAHOO.widget.Overlay.VIEWPORT_OFFSET;

        this.resize.set("maxWidth", w);
        this.resize.set("maxHeight", h);
      } else {
        this.resize.set("maxWidth", null);
        this.resize.set("maxHeight", null);
      }
    }, this.module, true);
  }
   
  /** Calls methods to build the widget header, body, and footer
   * @method build
   * @protected
   */
  this.build=function() {
    this.buildHeader(this.dom.header);
    this.buildBody(this.dom.content);
    this.buildFooter(this.dom.footer);
    this.onBuildComplete.fire(this);
  }

  /** Calls methods to populate the GUI elements with data
   * @method populate
   * @protected
   */
  this.populate=function() {
    this.onUpdateComplete.fire(this);
    this.fillHeader(this.dom.header);
    this.fillBody(this.dom.content);
    this.fillFooter(this.dom.footer);
    this.finishLoading();
    this.onPopulateComplete.fire(this);
  }

  /** Calls methods to build the widget header, body, and footer
   * @method build
   * @protected
   */
  this.destroy=function() {
    YAHOO.log('Destroying '+this.div.id+' in '+this.parent.id,'info','Core.Widget');
    this.cleanup();
    this.filter.destroy(); // FIXME: not defined above... should it be here?
    this.module.destroy();
    if (this.parent.created && ! this.parent.hasChildNodes() ) {
      YAHOO.log('Destroying '+this.parent.id,'info','Core.Widget');
      this.parent.parentNode.removeChild(this.parent);
    }
    this.onDestroy.fire(this);
  }

  /** Hook to build the header.  Should be used to create a layout and
   *  store references to each element, which the fillHeader functions
   *  will populate with data when it arrives.
   * @method buildHeader
   * @param {string|HTML Element} div The div which to use for the header. FIXME: needed?
   * @protected
   * @returns void
   */
  this.buildHeader=function(div) {}

  /** Hook to fill the header elements with data.  Should not
   *  create/remove the DOM elements, only set their value.
   * @method fillHeader
   * @param {string|HTML Element} div The div which to use for the header. FIXME: needed?
   * @protected
   * @returns void
   */
  this.fillHeader=function(div) {}

  /** Hook to build the body.  Should be used to create a layout and
   *  store references to each element, which the fillBody function
   *  will populate with data when it arrives.
   * @method buildBody
   * @param {string|HTML Element} div The div which to use for the body. FIXME: needed?
   * @protected
   * @returns void
   */  
  this.buildBody=function(div) {}

  /** Hook to fill the body elements with data.  Should not
   *  create/remove the DOM elements, only set their value.
   * @method fillBody
   * @param {string|HTML Element} div The div which to use for the body. FIXME: needed?
   * @protected
   * @returns void
   */
  this.fillBody=function(div) {}

  /** Hook to build the footer.  Should be used to create a layout and
   *  store references to each element, which the fillFooter functions
   *  will populate with data when it arrives.
   * @method buildFooter
   * @param {string|HTML Element} div The div which to use for the footer. FIXME: needed?
   * @protected
   * @returns void
   */
  this.buildFooter=function(div) {}

  /** Hook to fill the footer elements with data.  Should not
   *  create/remove the DOM elements, only set their value.
   * @method fillFooter
   * @param {string|HTML Element} div The div which to use for the footer. FIXME: needed?
   * @protected
   * @returns void
   */
  this.fillFooter=function(div) {}

  /** Hook to build the "extra div". Should be used to create a layout and
   *  store references to each element, which the fillExtra function
   *  will populate with data when it arrives.
   * @method buildExtra
   * @param {string|HTML Element} div The div which to use for the "extra div". FIXME: needed?
   * @protected
   * @returns void
   */
  this.buildExtra=function(div) { div.innerHTML='No extra information defined...';}

  /** Hook to fill the "extra div" elements with data.  Should not
   *  create/remove the DOM elements, only set their value.
   * @method fillExtra
   * @param {string|HTML Element} div The div which to use for the "extra div". FIXME: needed?
   * @protected
   * @returns void
   */
  this.fillExtra=function(div) { this.onFillExtra.fire(div); }

  /** Displays the "busy" twirl in the header.
   * @method showBusy
   * @protected
   * @returns void
   */
  this.showBusy=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display=null; }
    if ( this.control.close )    { this.control.close.style.display='none'; }
  }

  /** Hides the "busy" twirl in the header.
   * @method showNotBusy
   * @protected
   * @returns void
   */
  this.showNotBusy=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display='none'; }
    if ( this.control.close )    { this.control.close.style.display=null; }
  }

  /** Called when initialization is finished and data loading begins.
   *  The widget is shown as "busy" and onLoadingBegin is fired.
   * @method startLoading
   * @private
   * @returns void
   */
  this.startLoading=function()
  {
    this.showBusy();
    this.onLoadingBegin.fire();
  }

  /** To be called when data loading ends.  The widget is shown as
   *  "not busy" and onLoadingCompleteis fired.
   * @method finishLoading
   * @protected
   * @returns void
   */
  this.finishLoading=function()
  {
    this.showNotBusy();
    this.onLoadingComplete.fire();
  }

  /** To be called when data loading fails.  The widget is shown as
   *  "not busy" and onLoadingFailed is fired.
   * @method finishLoading
   * @protected
   * @returns void
   */
  this.failedLoading=function()
  {
    this.showNotBusy();
    this.onLoadingFailed.fire();
  }

  /** This is the core method that is called both after the object is
   *  first created and when the data expires. Depending on whether the
   *  implementation node is a level that fetches data itself or that has
   *  data injected by a parent, update() should either make a data request
   *  (and then parse it when it arrives) or do any data processing
   *  necessary and finally call populate() to fill in the header, body and
   *  footer. startLoading/finishLoading should be used if data is
   *  being fetched.
   * @method update
   * @protected
   * @returns void
   */
  this.update=function() { alert("Unimplemented update()");}

  this.module.render(); // FIXME:  needed?
  
  /** This is a subclass hook that can be used to do any necessary
   *  cleanup jobs when the widget is to be destroyed.
   * @method cleanup
   * @protected
   * @returns void
   */
  this.cleanup=function() {};

  /* A bunch of custom events that can be used by whatever needs
   | them. The core widget fires some of these, but not necessarily
   | all. Derived widgets are free to use them or add their own events
   |
   | To fire one of these methods:
   | this.onBuildComplete.fire( arg0, arg1, ... );
   |
   | To subscribe to one of these events:
   | this.onBuildComplete.subscribe(handler,object);
   | where handler is a function and object is an arbitrary object
   |
   | The handler looks like this:
   | var handler = function(event_name, args, object)
   | where event_name would be 'onBuildComplete' in this example,
   | args is an array of the arguments passed to the fire() method: args[0] is arg0, args[1] is arg1, etc
   | object is the thing passed to the subscribe method.
   |
   | See http://developer.yahoo.com/yui/event/#customevent for more complete information.
   */

  // FIXME: Below are some events that we don't fire
  // ourselves.  If we aren't going to fire them, why should we define
  // them?  Don't make promises you can't keep?

  /** CustomEvent fired when build has completed.
   * @event onBuildComplete 
   * @param {Widget} widget Reference to the widget that was  built.
   */
  this.onBuildComplete    = new YAHOO.util.CustomEvent("onBuildComplete",    this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent to be fired by a subclass when populate begins.
   * @event onPopulateBegin
   * @param {Widget} widget Reference to the widget being populated.
   */
  this.onPopulateBegin    = new YAHOO.util.CustomEvent("onPopulateBegin",    this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when populate has completed..
   * @event onPopulateComplete
   * @param {Widget} widget Reference to the widget that was populated.
   */
  this.onPopulateComplete = new YAHOO.util.CustomEvent("onPopulateComplete", this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent to be fired by a subclass when update begins.
   * @event onUpdateBegin
   * @param {Widget} widget Reference to the widget being populated.
   */
  this.onUpdateBegin      = new YAHOO.util.CustomEvent("onUpdateBegin",      this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when update has completed.
   * @event onUpdateComplete
   * @param {Widget} widget Reference to the widget being updated.
   */
  this.onUpdateComplete   = new YAHOO.util.CustomEvent("onUpdateComplete",   this, false, YAHOO.util.CustomEvent.LIST);

  // FIXME: Fired before returning 'this'.  How is the caller supposed
  //        to listen to the event?
  /** CustomEvent fired when a loading operation begins.  FIXME:  Cannot be subscribed in time!
   * @event onLoadingBegin
   */
  this.onLoadingBegin     = new YAHOO.util.CustomEvent("onLoadingBegin",     this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when a loading operation has completed.
   * @event onLoadingComplete
   */
  this.onLoadingComplete  = new YAHOO.util.CustomEvent("onLoadingComplete",  this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when a loading operation has failed.
   * @event onLoadingFailed
   */
  this.onLoadingFailed    = new YAHOO.util.CustomEvent("onLoadingFailed",    this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when the widget has finsihed resizing.  FIXME:  Never fired!
   * @event onResizeComplete
   */
  this.onResizeComplete   = new YAHOO.util.CustomEvent("onResizeComplete",   this, false, YAHOO.util.CustomEvent.LIST);

  /* The DataReady and DataFailed events are for (re-)loading data, for
   | use by the data-service. The *Loading* events above are for
   | DOM-related activities within the widget 
   */

  /** CustomEvent to be fired by a subclass when data is ready.
   * @event onDataReady
   * @param {object} data The data which is ready for use.
   * @param {object} context Used for describing context for fetching the data.
   */
  this.onDataReady        = new YAHOO.util.CustomEvent("onDataReady",        this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent to be fired by a subclass when fetching data failed.
   * @event onDataFailed
   * @param {Error} error Describes what happened.
   */
  this.onDataFailed       = new YAHOO.util.CustomEvent("onDataFailed",       this, false, YAHOO.util.CustomEvent.LIST);

  /** Custom event fired when the widget is about to be destroyed.
   * @event onDestroy
   * @param {Widget} widget The widget which is being destroyed.
   */ 
  this.onDestroy          = new YAHOO.util.CustomEvent("onDestroy",          this, false, YAHOO.util.CustomEvent.LIST);

  /** Custom event fired when the extra div is shown.
   * @event onShowExtra
   */
  this.onShowExtra      = new YAHOO.util.CustomEvent("onShowExtra", this, false, YAHOO.util.CustomEvent.LIST);

  /** Custom event fired when the extra div is hidden.
   * @event onHideExtra
   */
  this.onHideExtra      = new YAHOO.util.CustomEvent("onHideExtra", this, false, YAHOO.util.CustomEvent.LIST);

  // adjustHeader is not needed with window = false, because the module-height is not defined if it is not
  // confined in a resizeable component. If the module-height is not defined then there is no need to adjust it.
  if (this.options.window) {
    this.onShowExtra.subscribe(function(ev,arg) { this.adjustHeader( arg[0]); });
    this.onHideExtra.subscribe(function(ev,arg) { this.adjustHeader(-arg[0]); });
  }

  // FIXME:  Belongs to the filter, should this be defined here?
  /** CustomEvent fired when the filter is activated.
   * @event filter.onFilterApplied
   */
  this.filter.onFilterApplied = new YAHOO.util.CustomEvent("onFilterApplied", this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when the filter is accepted.
   * @event onAcceptFilter
   */
  this.onAcceptFilter         = new YAHOO.util.CustomEvent("onAcceptFilter", this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when the filter is shown.
   * @event onShowFilter
   */
  this.onShowFilter           = new YAHOO.util.CustomEvent("onShowFilter",  this, false, YAHOO.util.CustomEvent.LIST);

  /** CustomEvent fired when the filter is shown.
   * @event onHideFilter
   */
  this.onHideFilter           = new YAHOO.util.CustomEvent("onHideFilter",  this, false, YAHOO.util.CustomEvent.LIST);

  this.onHideFilter.subscribe(function() {
      this.filter.destroy();
      var isApplied = this.filter.isApplied();
      this.ctl.filter.setApplied(isApplied);
      PHEDEX.Event.onWidgetFilterApplied.fire(isApplied);
    });

  // Adjust the header up or down in size by the requisite number of
  // pixels. Used for making/reclaiming space for extra-divs etc.
  this.adjustHeader=function(arg) {
    var oheight = parseInt(this.module.cfg.getProperty("height"));
    if ( isNaN(oheight) ) { return; } // nothing to do, no need to adjust if the height is not specified
    var hheight = parseInt(this.module.header.offsetHeight);
    this.module.header.style.height=(hheight+arg)+'px';
    this.module.cfg.setProperty("height",(oheight+arg)+'px');
  }

  // FIXME: This callback is identical to code in phedex-global. If we
  // can sort out the scope, it could be made common-code
  this.onAcceptFilter.subscribe( function(obj) {
    return function() {
      YAHOO.log('onAcceptFilter:'+obj.me(),'info','Core.Widget');
      obj.filter.Parse();
    }
  }(this));

  PHEDEX.Event.onGlobalFilterApplied.subscribe( function(obj) {
    return function(ev,arr) {
      var isApplied = arr[0];
      obj.ctl.filter.setApplied(isApplied);
    }
  }(this));

  PHEDEX.Event.onFilterDefined.subscribe( function() {
    return function(ev,arr) {
      var args = arr[0];
      var widget = arr[1];
      widget.filter.init(args);
    }
  }());

  this.onBuildComplete.subscribe(function() {
    YAHOO.log('onBuildComplete: '+this.me(),'info','Core.Widget');
    // extra
    this.ctl.extra = new PHEDEX.Core.Control({text:'Extra',
					      payload:{target:this.dom.extra,
						       fillFn:this.fillExtra,
						       obj:this,
						       animate:false,
						       hover_timeout:200,
						       onHideControl:this.onHideExtra,
						       onShowControl:this.onShowExtra
						      } 
					     });
    YAHOO.util.Dom.insertBefore(this.ctl.extra.el,this.dom.control.firstChild);
    
    // filter
    var fillArgs = { context:[this.dom.body,"tl","tl", ["beforeShow", "windowResize"]],
		     visible:false,
		     autofillheight:'body',
		     width:this.dom.body.offsetWidth+'px'
		   };
    this.ctl.filter = new PHEDEX.Core.Control({text:'Filter',
					       payload:{target:this.dom.filter,
							fillFn:this.filter.Build,
							fillArgs:fillArgs,
							obj:this,
							animate:false,
							hover_timeout:200,
							onHideControl:this.onHideFilter,
							onShowControl:this.onShowFilter
						       } 
					      });
    YAHOO.util.Dom.insertBefore(this.ctl.filter.el,this.dom.control.firstChild);
    if ( !this.filter.isDefined() ) { this.ctl.filter.Disable(); }
  });
  
  /** The "please wait" twirl image, usually hidden.
   * @property control.progress
   * @type HTML img
   * @private
   */
  this.control.progress = PxU.makeChild(this.dom.control, 'img', {src:'/images/progress.gif'});

  /** Window closing control.  Only exists if options.window is true.
   * @property control.close
   * @type HTML img
   * @private
   */
  if (this.options.window) {
    this.control.close = PxU.makeChild(this.dom.control, 'img', {src:'/images/widget-close.gif'});
    YAHOO.util.Event.addListener(this.control.close, "click", this.destroy, null, this);
  }

  this.startLoading();
  return this;
}

YAHOO.log('loaded...','info','Core.Widget');
