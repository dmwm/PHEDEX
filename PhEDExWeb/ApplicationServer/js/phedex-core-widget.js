//This 'class' represents the basic header,body,footer node for a dynamic PhEDEx page.
//Required arguments either a div object or a id name for a div for the item to be built in (divid), and a options-object.
//Individual nodes should subclass this, calling the superconstructor with either a ready div or an ID of an existing div, and then
//implement their own methods to generate the content, and handle updates.

// instantiate the PHEDEX.Core.Widget namespace
PHEDEX.namespace('Core.Widget');

//This should be subclassed for each class and then specific child node.
//TODO: Prototype instead of instance based subclassing.

PHEDEX.Core.Widget = function(divid,opts) {
// Set defaults, then copy the options over the defaults.
  this.options = {width:700,
		  height:150,
		  minwidth:10,
		  minheight:10,
		  close:false,
		  draggable:true,
		  constraintoviewport:false,
		  handles:['b','br','r']
		  };
  if (opts) {
    for (o in opts) {
      this.options[o]=opts[o];
    }
  }
// Test whether we were passed an object (assumed div) or something else (assumed element.id)
// Set the div and id appropriately.
  if (typeof(divid)=='object') {
    this.id = divid.id;
    this.div = divid;
  } else {
    if ( !divid ) { divid = PHEDEX.Util.generateDivName(); }
    this.id = divid;
    this.div = PHEDEX.Util.findOrCreateWidgetDiv(this.id);
  }
  this.me=function() { YAHOO.log('unimplemented "me"','error','Core.Widget'); return 'PHEDEX.Core.Widget'; }
  this.textNodeMap = [];
  this.hideByDefault = [];
  this.control = [];
  this.dom    = [];
  this.ctl    = [];
//   this.structure = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}, filter:{}};
  this._cfg = {headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{}};

// This may be heavy-handed, wipe out all children and rebuild from scratch. For now, it works well enough...
  while (this.div.hasChildNodes()) { this.div.removeChild(this.div.firstChild); }

  YAHOO.util.Dom.addClass(this.div,'phedex-core-widget');
// Everything is a resizeable panel now
  YAHOO.util.Dom.addClass(this.div,'phedex-resizeable-panel');
// Create the structure for the embedded panel
  this.dom.header = document.createElement('div');
  this.dom.header.className = 'hd';
//   this.dom.header.id = this.id+'_head';
  this.div.appendChild(this.dom.header);

  this.dom.param = document.createElement('span');
  this.dom.param.className = 'phedex-core-param';
//   this.dom.param.id = this.id+'_param';
  this.dom.header.appendChild(this.dom.param);

  this.dom.title = document.createElement('span');
  this.dom.title.className = 'phedex-core-title';
//   this.dom.title.id = this.id+'_title';
  this.dom.header.appendChild(this.dom.title);

  this.dom.control = document.createElement('span');
  this.dom.control.className = 'phedex-core-control';
//   this.dom.control.id = this.id+'_control';
  this.dom.header.appendChild(this.dom.control);

  this.dom.extra = document.createElement('div');
  this.dom.extra.className = 'phedex-core-extra phedex-invisible';
//   this.dom.extra.id = this.id+'_extra';
  this.dom.header.appendChild(this.dom.extra);

  this.dom.body = document.createElement('div');
  this.dom.body.className = 'bd';
  this.dom.body.id = this.id+'_body';
  this.div.appendChild(this.dom.body);

  this.dom.content = document.createElement('div');
  this.dom.content.className = 'phedex-core-content';
  this.dom.content.id = this.id+'_content';
  this.dom.body.appendChild(this.dom.content);

  this.dom.footer = document.createElement('div');
  this.dom.footer.className = 'ft';
//   this.dom.footer.id = this.id+'_foot';
  this.div.appendChild(this.dom.footer);

  this.dom.filter = document.createElement('div');
  this.dom.filter.id = this.id+'_filter';

// Create the panel
  this.panel = new YAHOO.widget.Panel(this.id,
    {
      close:false,  //this.options.close,
      visible:true,
      draggable:true,
//       effect:{effect:YAHOO.widget.ContainerEffect.FADE, duration: 0.3},
      width: this.options.width+"px",
      height: this.options.height+"px",
      constraintoviewport: this.options.constraintoviewport,
      context: ["showbtn", "tl", "bl"],
      underlay: "matte"
    }
  ); this.panel.render();
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
  }, this.panel, true);
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
    }, this.panel, true);
//     this.resize = resize;

  this.build=function() {
    this.buildHeader(this.dom.header);
    this.buildBody(this.dom.content);
    this.buildFooter(this.dom.footer);
    this.onBuildComplete.fire();
  }

  this.populate=function() {
    this.onUpdateComplete.fire();
    this.fillHeader(this.dom.header);
    this.fillBody(this.dom.content);
    this.fillFooter(this.dom.footer);
    this.finishLoading();
    this.onPopulateComplete.fire();
  }

  // Implementations should provide their own versions of these functions. The build* functions should be used to create a layout and store references to each element , which the fill* functions should populate with data when it arrives (but not usually alter the HTML) - this is to prevent issues like rebuilding select lists and losing your place.
  this.buildHeader=function(div) {}
  this.fillHeader=function(div) {}
  
  this.buildBody=function(div) {}
  this.fillBody=function(div) {}

  this.buildFooter=function(div) {}
  this.fillFooter=function(div) {}

// For filling extra information, if needed...
  this.buildExtra=function(div) { div.innerHTML='No extra information defined...';}
  this.fillExtra=function(div) { }

  // Start/FinishLoading, surprisingly, show and hide the progress icon.
  this.showBusy=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display=null; }
    if ( this.control.close )    { this.control.close.style.display='none'; }
  }
  this.showNotBusy=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display='none'; }
    if ( this.control.close )    { this.control.close.style.display=null; }
  }
  this.startLoading=function()
  {
    this.showBusy();
    this.onLoadingBegin.fire();
  }
  this.finishLoading=function()
  {
    this.showNotBusy();
    this.onLoadingComplete.fire();
  }
  this.failedLoading=function()
  {
    this.showNotBusy();
    this.onLoadingFailed.fire();
  }

// Update is the core method that is called both after the object is first created and when the data expires. Depending on whether the implementation node is a level that fetches data itself or that has data injected by a parent, update() should either make a data request (and then parse it when it arrives) or do any data processing necessary and finally call populate() to fill in the header, body and footer. Start/FinishLoading should be used if data is being fetched.
  this.update=function() { alert("Unimplemented update()");}

  this.panel.render();

// A bunch of custom events that can be used by whatever needs them. The core widget fires some of these, but not necessarily all. Derived widgets are free to use them or add their own events
//
// To fire one of these methods:
// this.onBuildComplete.fire( arg0, arg1, ... );
//
// to subscribe to one of these events:
// this.onBuildComplete.subscribe(handler,object);
// where handler is a function and object is an arbitrary object
//
// the handler looks like this:
// var handler = function(event_name, args, object)
// where event_name would be 'onBuildComplete' in this example,
// args is an array of the arguments passed to the fire() method: args[0] is arg0, args[1] is arg1, etc
// object is the thing passed to the subscribe method.
//
// See http://developer.yahoo.com/yui/event/#customevent for more complete information.
  this.onBuildComplete    = new YAHOO.util.CustomEvent("onBuildComplete",    this, false, YAHOO.util.CustomEvent.LIST);
  this.onPopulateBegin    = new YAHOO.util.CustomEvent("onPopulateBegin",    this, false, YAHOO.util.CustomEvent.LIST);
  this.onPopulateComplete = new YAHOO.util.CustomEvent("onPopulateComplete", this, false, YAHOO.util.CustomEvent.LIST);
  this.onUpdateBegin      = new YAHOO.util.CustomEvent("onUpdateBegin",      this, false, YAHOO.util.CustomEvent.LIST);
  this.onUpdateComplete   = new YAHOO.util.CustomEvent("onUpdateComplete",   this, false, YAHOO.util.CustomEvent.LIST);
  this.onLoadingBegin     = new YAHOO.util.CustomEvent("onLoadingBegin",     this, false, YAHOO.util.CustomEvent.LIST);
  this.onLoadingComplete  = new YAHOO.util.CustomEvent("onLoadingComplete",  this, false, YAHOO.util.CustomEvent.LIST);
  this.onLoadingFailed    = new YAHOO.util.CustomEvent("onLoadingFailed",    this, false, YAHOO.util.CustomEvent.LIST);
  this.onResizeComplete   = new YAHOO.util.CustomEvent("onResizeComplete",   this, false, YAHOO.util.CustomEvent.LIST);
// the DataReady and DataFailed events are for (re-)loading data, for use by the data-service. The *Loading* events above are for DOM-related activities within the widget
  this.onDataReady        = new YAHOO.util.CustomEvent("onDataReady",        this, false, YAHOO.util.CustomEvent.LIST);
  this.onDataFailed       = new YAHOO.util.CustomEvent("onDataFailed",       this, false, YAHOO.util.CustomEvent.LIST);

  this.onDestroy  = new YAHOO.util.CustomEvent("onDestroy",  this, false, YAHOO.util.CustomEvent.LIST);
  this.onDestroy.subscribe( function() {
    while (this.div.hasChildNodes()) {
      this.div.removeChild(this.div.firstChild);
    }
    this.filter.destroy();
    PHEDEX.Event.onWidgetDestroy.fire(this);
  });

// for showing/hiding extra control-divs, like the classic extra-div
  this.onShowExtra      = new YAHOO.util.CustomEvent("onShowExtra", this, false, YAHOO.util.CustomEvent.LIST);
  this.onHideExtra      = new YAHOO.util.CustomEvent("onHideExtra", this, false, YAHOO.util.CustomEvent.LIST);
  this.onShowExtra.subscribe(function(ev,arg) { this.adjustHeader( arg[0]); });
  this.onHideExtra.subscribe(function(ev,arg) { this.adjustHeader(-arg[0]); });

  this.onShowFilter     = new YAHOO.util.CustomEvent("onShowFilter", this, false, YAHOO.util.CustomEvent.LIST);
  this.onHideFilter     = new YAHOO.util.CustomEvent("onHideFilter", this, false, YAHOO.util.CustomEvent.LIST);
  this.onHideFilter.subscribe(function() {
      this.filter.destroy();
      this.ctl.filter.setApplied(this.filter.isApplied());
    });

// adjust the header up or down in size by the requisite number of pixels. Used for making/reclaiming space for extra-divs etc
  this.adjustHeader=function(arg) {
    var oheight = parseInt(this.panel.cfg.getProperty("height"));
    var hheight = parseInt(this.panel.header.offsetHeight);
    this.panel.header.style.height=(hheight+arg)+'px';
    this.panel.cfg.setProperty("height",(oheight+arg)+'px');
  }

// This uses a closure to capture the 'this' we are dealing with and then subscribe it to the onFilterCancel event.
// Note the pattern: Event.subscribe( function(obj) { return function() { obj.whatever(); ...; } }(this) );
  PHEDEX.Event.onFilterCancel.subscribe( function(obj) {
    return function() {
      YAHOO.log('onFilterCancel:'+obj.me(),'info','Core.Widget');
      obj.ctl.filter.Hide();
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      obj.filter.Reset();
    }
  }(this));
  PHEDEX.Event.onFilterAccept.subscribe( function(obj) {
    return function() {
      YAHOO.log('onFilterAccept:'+obj.me(),'info','Core.Widget');
      obj.filter.Parse();
    }
  }(this));
    PHEDEX.Event.onFilterValidated.subscribe( function(obj) {
    return function(ev,arr) {
      YAHOO.log('onFilterValidated:'+obj.me(),'info','Core.Widget');
debugger;
      obj.ctl.filter.Hide();
      var args = arr[0];
    }
  }(this));

  this.onBuildComplete.subscribe(function() {
    YAHOO.log('onBuildComplete: '+this.me(),'info','Core.Widget');
    this.ctl.extra = new PHEDEX.Core.Control( {text:'Extra',
                    payload:{target:this.dom.extra, fillFn:this.fillExtra, obj:this, animate:false, hover_timeout:200, onHideControl:this.onHideExtra, onShowControl:this.onShowExtra} } );
    YAHOO.util.Dom.insertBefore(this.ctl.extra.el,this.dom.control.firstChild);
    this.ctl.filter = new PHEDEX.Core.Control( {text:'Filter',
                    payload:{target:this.dom.filter, fillFn:this.filter.Build, obj:this, animate:false, hover_timeout:200, onHideControl:this.onHideFilter, onShowControl:this.onShowFilter} } );
    YAHOO.util.Dom.insertBefore(this.ctl.filter.el,this.dom.control.firstChild);
    if ( !this.filter.isDefined() ) { this.ctl.filter.Disable(); }
  });

// Create a (usually hidden) progress indicator.
  this.control.progress = document.createElement('img');
  this.control.progress.src = '/images/progress.gif';
  this.dom.control.appendChild(this.control.progress);

  this.control.close = document.createElement('img');
  this.control.close.src = '/images/widget-close.gif';
  this.dom.control.appendChild(this.control.close);
  YAHOO.util.Event.addListener(this.control.close, "click", function(obj) { return function() { obj.onDestroy.fire(); } } (this), this);

  this.startLoading();
//   YAHOO.lang.augmentObject(PHEDEX.Core.Widget,PHEDEX.Core.Filter);
  YAHOO.lang.augmentObject(this,PHEDEX.Core.Filter(this));
  return this;
}


YAHOO.log('loaded...','info','Core.Widget');