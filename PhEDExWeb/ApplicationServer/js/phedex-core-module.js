PHEDEX.namespace('Core');
PHEDEX.Core.Module = function(sandbox, string) {
  var _sbx = sandbox;
  var _name = string;
  log('Module: creating "'+_name+'"');

  onRegistryCreate = function() {
    return function() {
      _sbx.notify('moduleCreate',_name,this);
    }
  }();

  return {
    connect: function() {
      _sbx.listen('registryCreate',onRegistryCreate);
      _sbx.notify('moduleCreate',_name,this);
    },

    initObj: function(parent) {
      YAHOO.lang.augmentObject(this, PHEDEX.Base.Object(this));
      log(_name+': initialising');
      if ( typeof(parent) == 'string' ) {
	this.el = document.getElementById(parent);
      } else {
	this.el = parent;
      }
      if ( !this.el ) { throw new Error('no or invalid parent for module "'+_name+'" ('+parent+')'); }

      var coreHandler = function(obj) {
	return function(ev,arr) {
	  var action = arr[0];
	  var who = arr[1];
	  if ( who && who != '*' && who != _name ) { return; }
	  if ( typeof(obj[action]) != 'function' ) {
	    throw new Error('Do not now how to execute "'+action+'" for module "'+_name+'"');
	  }
	  obj[action](arr[2]);
	}
      }(this);
      _sbx.listen('module',coreHandler);
    },

    initDom: function() {
      this.dom.header = PxU.makeChild(this.el, 'div', {className:'hd'});
      this.dom.param = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-param'});
      this.dom.title = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-title'});
      this.dom.control = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-control'});
      this.dom.extra = PxU.makeChild(this.dom.header, 'div', {className:'phedex-core-extra phedex-invisible'});
      this.dom.body = PxU.makeChild(this.el, 'div', {className:'bd', id:this.id+'_body'});
      this.dom.content = PxU.makeChild(this.dom.body, 'div', {className:'phedex-core-content',id:this.id+'_content'});
      this.dom.footer = PxU.makeChild(this.el, 'div', {className:'ft'});
    },
    draw: function(args) {
      this.dom.header.innerHTML = _name+': starting...';
      log(_name+': showing');
    },
    show: function(args) {
      log(_name+': showing module "'+_name+'"');
      YAHOO.util.Dom.removeClass(this.el,'phedex-invisible')
    },
    hide: function(args) {
      log(_name+': hiding module "'+_name+'"');
      YAHOO.util.Dom.addClass(this.el,'phedex-invisible')
    },
    destroy: function(args) {
      log(_name+': destroying');
    },
  };
};

// PHEDEX.namespace('Core.Widget');
// PHEDEX.Core.Widget = function(divid,opts) {
//   YAHOO.lang.augmentObject(this, PHEDEX.Base.Object(this));
// //   YAHOO.lang.augmentObject(this, PHEDEX.Core.Filter(this));
//   if ( !divid ) { throw new Error("must provide div name to contain widget"); }
//   this.options = {window:true,
// 		  width:700,
// 		  height:150,
// 		  minwidth:10,
// 		  minheight:10,
// 		  draggable:true,
// 		  resizable:true,
// 		  constraintoviewport:false,
// 		  handles:['b','br','r'],
// 		  };
//   YAHOO.lang.augmentObject(this.options, opts, true);
//   var config = PxU.getConfig(divid);
//   YAHOO.lang.augmentObject(this.options, config.opts, true);
// 
//   if ( typeof(divid) != 'object' ) {
//     this.parent = document.getElementById(divid);
//     if ( !this.parent ) {
//       this.parent = PxU.findOrCreateWidgetDiv(divid);
//       this.parent.created = true;
//     }
//   } else {
//     this.parent = divid;
//   }
// 
//   this.id = PxU.generateDivName(this.parent.id);
//   this.div = PxU.findOrCreateWidgetDiv(this.id, this.parent.id);
// 
//   this.textNodeMap = [];
//   this.hideByDefault = [];
//   this.control = [];
//   this.data   = [];
//   this._cfg = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}};
// 
//   while (this.div.hasChildNodes()) { this.div.removeChild(this.div.firstChild); }
// 
//   YAHOO.util.Dom.addClass(this.div,'phedex-core-widget');
//   if (this.options.window) {
//     YAHOO.util.Dom.addClass(this.div,'phedex-panel');
//   }
// 
//   this.dom.header = PxU.makeChild(this.div, 'div', {className:'hd'});
//   this.dom.param = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-param'});
//   this.dom.title = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-title'});
//   this.dom.control = PxU.makeChild(this.dom.header, 'span', {className:'phedex-core-control'});
//   this.dom.extra = PxU.makeChild(this.dom.header, 'div', {className:'phedex-core-extra phedex-invisible'});
//   this.dom.body = PxU.makeChild(this.div, 'div', {className:'bd', id:this.id+'_body'});
//   this.dom.content = PxU.makeChild(this.dom.body, 'div', {className:'phedex-core-content',id:this.id+'_content'});
//   this.dom.footer = PxU.makeChild(this.div, 'div', {className:'ft'});
// 
// // Create the module
//   var module_options = {
//     close:false,  //this.options.close,
//     visible:true,
//     draggable:this.options.draggable,
//     //       effect:{effect:YAHOO.widget.ContainerEffect.FADE, duration: 0.3},
//     width: this.options.width+"px",
//     height: this.options.height+"px",
//     constraintoviewport:this.options.constraintoviewport,
//     context: ["showbtn", "tl", "bl"],
//     underlay: "matte"
//   };
//   if ( !this.options.window ) {
//     delete module_options['width'];
//     delete module_options['height'];
//     module_options.draggable = false;
//     this.module = new YAHOO.widget.Module(this.id, module_options);
//   } else {
//     this.module = new YAHOO.widget.Panel(this.id, module_options);
//   }
// 
//   this.module.render();
// 
// // (Optionally) Make resizable
//   if ( this.options.window && this.options.resizable ) {
//     YAHOO.util.Dom.addClass(this.div,'phedex-resizeable-panel');
// 
//     this.resize = new YAHOO.util.Resize(this.id, {
//       handles: this.options.handles,
//       autoRatio: false,
//       minWidth:  this.options.minwidth,
//       minHeight: this.options.minheight,
//       status: false
//     });
//     this.resize.on('resize', function(args) {
//       var panelHeight = args.height;
//       if ( panelHeight > 0 )
//       {
// 	this.cfg.setProperty("height", panelHeight + "px");
//       }
//     }, this.module, true);
//     // Setup startResize handler, to constrain the resize width/height
//     // if the constraintoviewport configuration property is enabled.
//     this.resize.on('startResize', function(args) {
//       if (this.cfg.getProperty("constraintoviewport")) {
//         var clientRegion = YAHOO.util.Dom.getClientRegion();
//         var elRegion = YAHOO.util.Dom.getRegion(this.element);
//         var w = clientRegion.right - elRegion.left - YAHOO.widget.Overlay.VIEWPORT_OFFSET;
//         var h = clientRegion.bottom - elRegion.top - YAHOO.widget.Overlay.VIEWPORT_OFFSET;
// 
//         this.resize.set("maxWidth", w);
//         this.resize.set("maxHeight", h);
//       } else {
//         this.resize.set("maxWidth", null);
//         this.resize.set("maxHeight", null);
//       }
//     }, this.module, true);
//   }
// 
//   this.build=function() {
//     this.buildHeader(this.dom.header);
//     this.buildBody(this.dom.content);
//     this.buildFooter(this.dom.footer);
//     this.onBuildComplete.fire(this);
//   }
// 
//   this.populate=function() {
//     this.onUpdateComplete.fire(this);
//     this.fillHeader(this.dom.header);
//     this.fillBody(this.dom.content);
//     this.fillFooter(this.dom.footer);
//     this.finishLoading();
//     this.onPopulateComplete.fire(this);
//   }
// 
//   this.destroy=function() {
//     YAHOO.log('Destroying '+this.div.id+' in '+this.parent.id,'info','Core.Widget');
//     this.cleanup();
//     this.filter.destroy();
//     this.module.destroy();
//     if (this.parent.created && ! this.parent.hasChildNodes() ) {
//       YAHOO.log('Destroying '+this.parent.id,'info','Core.Widget');
//       this.parent.parentNode.removeChild(this.parent);
//     }
//     this.onDestroy.fire(this);
//   }
// 
//   // Implementations should provide their own versions of these functions. The build* functions should be used to create a layout and store references to each element , which the fill* functions should populate with data when it arrives (but not usually alter the HTML) - this is to prevent issues like rebuilding select lists and losing your place.
//   this.buildHeader=function(div) {}
//   this.fillHeader=function(div) {}
// 
//   this.buildBody=function(div) {}
//   this.fillBody=function(div) {}
// 
//   this.buildFooter=function(div) {}
//   this.fillFooter=function(div) {}
// 
// // For filling extra information, if needed...
//   this.buildExtra=function(div) { div.innerHTML='No extra information defined...';}
//   this.fillExtra=function(div) { this.onFillExtra.fire(div); }
// 
//   this.showBusy=function()
//   {
//     if ( this.control.progress ) { this.control.progress.style.display=null; }
//     if ( this.control.close )    { this.control.close.style.display='none'; }
//   }
//   this.showNotBusy=function()
//   {
//     if ( this.control.progress ) { this.control.progress.style.display='none'; }
//     if ( this.control.close )    { this.control.close.style.display=null; }
//   }
// // Start/FinishLoading, surprisingly, show and hide the progress icon.
//   this.startLoading=function()
//   {
//     this.showBusy();
//     this.onLoadingBegin.fire();
//   }
//   this.finishLoading=function()
//   {
//     this.showNotBusy();
//     this.onLoadingComplete.fire();
//   }
//   this.failedLoading=function()
//   {
//     this.showNotBusy();
//     this.onLoadingFailed.fire();
//   }
// 
// // Update is the core method that is called both after the object is first created and when the data expires. Depending on whether the implementation node is a level that fetches data itself or that has data injected by a parent, update() should either make a data request (and then parse it when it arrives) or do any data processing necessary and finally call populate() to fill in the header, body and footer. Start/FinishLoading should be used if data is being fetched.
//   this.update=function() { alert("Unimplemented update()");}
// 
//   this.module.render();
// 
//   this.cleanup=function() {}; // for cleanup work; called in destroy()
// 
// // A bunch of custom events that can be used by whatever needs them. The core widget fires some of these, but not necessarily all. Derived widgets are free to use them or add their own events
// //
// // To fire one of these methods:
// // this.onBuildComplete.fire( arg0, arg1, ... );
// //
// // to subscribe to one of these events:
// // this.onBuildComplete.subscribe(handler,object);
// // where handler is a function and object is an arbitrary object
// //
// // the handler looks like this:
// // var handler = function(event_name, args, object)
// // where event_name would be 'onBuildComplete' in this example,
// // args is an array of the arguments passed to the fire() method: args[0] is arg0, args[1] is arg1, etc
// // object is the thing passed to the subscribe method.
// //
// // See http://developer.yahoo.com/yui/event/#customevent for more complete information.
//   this.onBuildComplete    = new YAHOO.util.CustomEvent("onBuildComplete",    this, false, YAHOO.util.CustomEvent.LIST);
//   this.onPopulateBegin    = new YAHOO.util.CustomEvent("onPopulateBegin",    this, false, YAHOO.util.CustomEvent.LIST);
//   this.onPopulateComplete = new YAHOO.util.CustomEvent("onPopulateComplete", this, false, YAHOO.util.CustomEvent.LIST);
//   this.onUpdateBegin      = new YAHOO.util.CustomEvent("onUpdateBegin",      this, false, YAHOO.util.CustomEvent.LIST);
//   this.onUpdateComplete   = new YAHOO.util.CustomEvent("onUpdateComplete",   this, false, YAHOO.util.CustomEvent.LIST);
//   this.onLoadingBegin     = new YAHOO.util.CustomEvent("onLoadingBegin",     this, false, YAHOO.util.CustomEvent.LIST);
//   this.onLoadingComplete  = new YAHOO.util.CustomEvent("onLoadingComplete",  this, false, YAHOO.util.CustomEvent.LIST);
//   this.onLoadingFailed    = new YAHOO.util.CustomEvent("onLoadingFailed",    this, false, YAHOO.util.CustomEvent.LIST);
//   this.onResizeComplete   = new YAHOO.util.CustomEvent("onResizeComplete",   this, false, YAHOO.util.CustomEvent.LIST);
// // the DataReady and DataFailed events are for (re-)loading data, for use by the data-service. The *Loading* events above are for DOM-related activities within the widget
//   this.onDataReady        = new YAHOO.util.CustomEvent("onDataReady",        this, false, YAHOO.util.CustomEvent.LIST);
//   this.onDataFailed       = new YAHOO.util.CustomEvent("onDataFailed",       this, false, YAHOO.util.CustomEvent.LIST);
//   this.onDestroy          = new YAHOO.util.CustomEvent("onDestroy",          this, false, YAHOO.util.CustomEvent.LIST);
// 
// // for showing/hiding extra control-divs, like the classic extra-div
//   this.onShowExtra      = new YAHOO.util.CustomEvent("onShowExtra", this, false, YAHOO.util.CustomEvent.LIST);
//   this.onHideExtra      = new YAHOO.util.CustomEvent("onHideExtra", this, false, YAHOO.util.CustomEvent.LIST);
// // adjustHeader is not needed with window = false, because the module-height is not defined if it is not
// // confined in a resizeable component. If the module-height is not defined then there is no need to adjust it.
//   if (this.options.window) {
//     this.onShowExtra.subscribe(function(ev,arg) { this.adjustHeader( arg[0]); });
//     this.onHideExtra.subscribe(function(ev,arg) { this.adjustHeader(-arg[0]); });
//   }
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
// /* adjust the header up or down in size by the requisite number of
//    pixels. Used for making/reclaiming space for extra-divs etc */
//   this.adjustHeader=function(arg) {
//     var oheight = parseInt(this.module.cfg.getProperty("height"));
//     if ( isNaN(oheight) ) { return; } // nothing to do, no need to adjust if the height is not specified
//     var hheight = parseInt(this.module.header.offsetHeight);
//     this.module.header.style.height=(hheight+arg)+'px';
//     this.module.cfg.setProperty("height",(oheight+arg)+'px');
//   }
// 
// // TODO This callback is identical to code in phedex-global. If we can sort out the scope, it could be made common-code
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
//     // extra
//     this.ctl.extra = new PHEDEX.Core.Control({text:'Extra',
// 					      payload:{target:this.dom.extra,
// 						       fillFn:this.fillExtra,
// 						       obj:this,
// 						       animate:false,
// 						       hover_timeout:200,
// 						       onHideControl:this.onHideExtra,
// 						       onShowControl:this.onShowExtra
// 						      }
// 					     });
//     YAHOO.util.Dom.insertBefore(this.ctl.extra.el,this.dom.control.firstChild);
// 
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
// 
//   this.startLoading();
//   return this;
// }
// 
// YAHOO.log('loaded...','info','Core.Widget');
