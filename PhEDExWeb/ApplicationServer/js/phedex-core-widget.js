//This 'class' represents the basic header,body,footer node for a dynamic PhEDEx page.
//Required arguments either a div object or a id name for a div for the item to be built in (divid), a parent node (if one exists).
//Individual nodes should subclass this, calling the superconstructor with either a ready div or an ID of an existing div, and then
//implement their own methods to generate the content, and handle updates.

// instantiate the PHEDEX.Core.Widget namespace
PHEDEX.namespace('Core.Widget');

//This should be subclassed for each class and then specific child node.
//TODO: Prototype instead of instance based subclassing.

PHEDEX.Core.Widget = function(divid,parent,opts) {
  // Copy the options over the defaults.
  this.options = {width:700,
		  height:150,
		  minwidth:10,
		  minheight:10,
		  close:true,
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

// This may be heavy-handed, wipe out all children and rebuild from scratch. For now, it works well enough...
  while (this.div.hasChildNodes()) { this.div.removeChild(this.div.firstChild); }

  YAHOO.util.Dom.addClass(this.div,'phedex-core-widget');
// Everything is a resizeable panel now
  YAHOO.util.Dom.addClass(this.div,'phedex-resizeable-panel');
// Create the structure for the embedded panel
  this.div_header = document.createElement('div');
  this.div_header.className = 'hd';
  this.div_header.id = this.id+'_head';
  this.div.appendChild(this.div_header);

  this.span_param = document.createElement('span');
  this.span_param.className = 'phedex-core-param';
  this.span_param.id = this.id+'_param';
  this.div_header.appendChild(this.span_param);

  this.span_title = document.createElement('span');
  this.span_title.className = 'phedex-core-title';
  this.span_title.id = this.id+'_title';
  this.div_header.appendChild(this.span_title);

  this.span_control = document.createElement('span');
  this.span_control.className = 'phedex-core-control';
  this.span_control.id = this.id+'_control';
  this.div_header.appendChild(this.span_control);

  this.div_extra = document.createElement('div');
  this.div_extra.className = 'phedex-core-extra phedex-invisible';
  this.div_extra.id = this.id+'_extra';
  this.div_header.appendChild(this.div_extra);

  this.div_body = document.createElement('div');
  this.div_body.className = 'bd';
  this.div_body.id = this.id+'_body';
  this.div.appendChild(this.div_body);

  this.div_content = document.createElement('div');
  this.div_content.className = 'phedex-core-content';
  this.div_content.id = this.id+'_content';
  this.div_body.appendChild(this.div_content);

  this.div_footer = document.createElement('div');
  this.div_footer.className = 'ft';
  this.div_footer.id = this.id+'_foot';
  this.div.appendChild(this.div_footer);

  this.div_filter = document.createElement('div');
  this.div_filter.id = this.id+'_filter';

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
  var resize = new YAHOO.util.Resize(this.id, {
//       handles: ['br','b','r'],
      handles: this.options.handles, // ['br','b','r'],
      autoRatio: false,
      minWidth:  this.options.minwidth,
      minHeight: this.options.minheight,
      status: false
   });
  resize.on('resize', function(args) {
      var panelHeight = args.height;
      if ( panelHeight > 0 )
      {
	this.cfg.setProperty("height", panelHeight + "px");
      }
  }, this.panel, true);
// Setup startResize handler, to constrain the resize width/height
// if the constraintoviewport configuration property is enabled.
  resize.on('startResize', function(args) {
    if (this.cfg.getProperty("constraintoviewport")) {
        var clientRegion = YAHOO.util.Dom.getClientRegion();
        var elRegion = YAHOO.util.Dom.getRegion(this.element);
        var w = clientRegion.right - elRegion.left - YAHOO.widget.Overlay.VIEWPORT_OFFSET;
        var h = clientRegion.bottom - elRegion.top - YAHOO.widget.Overlay.VIEWPORT_OFFSET;

        resize.set("maxWidth", w);
        resize.set("maxHeight", h);
      } else {
        resize.set("maxWidth", null);
        resize.set("maxHeight", null);
      }
    }, this.panel, true);
    this.resize = resize;

// Assign an event-handler to delete the content when the container is closed. Do this now rather than
// in the constructor to avoid it hanging around when it is no longer needed.
  this.destroyContent = function(e,that) {
    while (that.div.hasChildNodes()) {
      that.div.removeChild(that.div.firstChild);
    }
  }
  if ( this.panel.close ) {
    YAHOO.util.Event.addListener(this.panel.close, "click", this.destroyContent, this);
  }
  this.build=function() {
    this.buildHeader(this.div_header);
    this.buildBody(this.div_content);
    this.buildFooter(this.div_footer);
    this.onBuildComplete.fire();
  }

  this.populate=function() {
    this.onUpdateComplete.fire();
    this.fillHeader(this.div_header);
    this.fillBody(this.div_content);
    this.fillFooter(this.div_footer);
    this.finishLoading();
    this.onPopulateComplete.fire();
  }

  // Implementations should provide their own versions of these functions. The build* functions should be used to create a layout and store references to each element , which the fill* functions should populate with data when it arrives (but not usually alter the HTML) - this is to prevent issues like rebuilding select lists and losing your place.
  this.buildHeader=function(div) {}
  this.fillHeader=function(div) {}
  
  this.buildBody=function(div) {}
  this.fillBody=function(div) {}
  this.deleteBodyContent=function(div) {}

  this.buildFooter=function(div) {}
  this.fillFooter=function(div) {}

// For filling extra information, if needed...
  this.buildExtra=function(div) { div.innerHTML='No extra information defined...';}
  this.fillExtra=function(div) {}
  
  // Start/FinishLoading, surprisingly, show and hide the progress icon.
  this.startLoading=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display=null; }
    if ( this.control.close )    { this.control.close.style.display='none'; }
    this.onLoadingBegin.fire();
  }
  this.finishLoading=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display='none'; }
    if ( this.control.close )    { this.control.close.style.display=null; }
    this.onLoadingComplete.fire();
  }
  this.failedLoading=function()
  {
    if ( this.control.progress ) { this.control.progress.style.display='none'; }
    if ( this.control.close )    { this.control.close.style.display=null; }
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

// for showing/hiding extra control-divs, like the classic extra-div
  this.onShowExtra      = new YAHOO.util.CustomEvent("onShowExtra", this, false, YAHOO.util.CustomEvent.LIST);
  this.onHideExtra      = new YAHOO.util.CustomEvent("onHideExtra", this, false, YAHOO.util.CustomEvent.LIST);
  this.onShowExtra.subscribe(function(ev,arg) { this.adjustHeader( arg[0]); });
  this.onHideExtra.subscribe(function(ev,arg) { this.adjustHeader(-arg[0]); });

  this.onShowFilter     = new YAHOO.util.CustomEvent("onShowFilter", this, false, YAHOO.util.CustomEvent.LIST);
  this.onHideFilter     = new YAHOO.util.CustomEvent("onHideFilter", this, false, YAHOO.util.CustomEvent.LIST);

// adjust the header up or down in size by the requisite number of pixels. Used for making/reclaiming space for extra-divs etc
  this.adjustHeader=function(arg) {
    var oheight = parseInt(this.panel.cfg.getProperty("height"));
    var hheight = parseInt(this.panel.header.offsetHeight);
    this.panel.header.style.height=(hheight+arg)+'px';
    this.panel.cfg.setProperty("height",(oheight+arg)+'px');
  }

// These need to be overridden in the derived widgets...
  this.applyFilter=function() {}     // Apply the filter to the data
//   this.fillFilter = function(div) {} // Create the filter-form in the div allocated

// These filter-functions are generic
  this.acceptFilter=function() {
    YAHOO.log('acceptFilter:'+this.me(),'info','Core.Widget');
    var elList = YAHOO.util.Dom.getElementsByClassName('phedex-filter-elem');
    for (var i in elList) {
      var el = elList[i];
      this.filter.args[el.name] = el.value;
    }
    this.applyFilter();
    this.hideFilter();
  }
  this.resetFilter=function() { this.filter = {args:{}, count:0}; }
  this.cancelFilter=function() {
    this.filter = {count:0, args:{}};
    this.hideFilter();
    YAHOO.log('cancelFilter:'+this.me(),'info','Core.Widget');
  }
// Build the filter-div, allow the widget to define its contents...
  this.buildFilter=function(div) {
    var obj = this.obj;
    obj.filter_overlay = new YAHOO.widget.Overlay(obj.div_filter.id, { context:[obj.div_body.id,"tl","tl", ["beforeShow", "windowResize"]],
            visible:false,
	    autofillheight:'body'} );
    obj.filter_overlay.setHeader('Filter data selection');
    obj.filter_overlay.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
    obj.filter_overlay.setFooter('&nbsp;');
    YAHOO.util.Dom.addClass(obj.filter_overlay.element,'phedex-core-overlay')

    var body = obj.filter_overlay.body;
    body.innerHTML=null;
    var fieldset = document.createElement('fieldset');
    fieldset.id = 'fieldset_'+PHEDEX.Util.Sequence();
    var legend = document.createElement('legend');
    legend.appendChild(document.createTextNode('filter parameters'));
    fieldset.appendChild(legend);
    var filterDiv = document.createElement('div');
    filterDiv.id = 'filterDiv_'+PHEDEX.Util.Sequence();
    fieldset.appendChild(filterDiv);
    var buttonDiv = document.createElement('div');
    buttonDiv.id = 'buttonDiv_'+PHEDEX.Util.Sequence();
    fieldset.appendChild(buttonDiv);
    body.appendChild(fieldset);

    obj.filter_overlay.render(document.body);
    obj.filter_overlay.cfg.setProperty('width',obj.div_body.offsetWidth+'px');
    obj.filter_overlay.show();
    obj.filter_overlay.cfg.setProperty('zindex',10);
    obj.fillFilter(filterDiv);

    var buttonAcceptFilter = new YAHOO.widget.Button({ label: 'Accept Filter', container: buttonDiv });
    buttonAcceptFilter.on('click', function(){ this.acceptFilter(filterDiv); }, obj, obj );
    var buttonCancelFilter = new YAHOO.widget.Button({ label: 'Cancel Filter', container: buttonDiv });
    buttonCancelFilter.on('click', function(){ this.cancelFilter(); }, obj, obj );
  }
  this.hideFilter = function() {
// Hide the filter-div, destroying the contents of the filter-overlay and applying the filter to the tree.
    if ( this.filter.count ) { YAHOO.util.Dom.addClass   (this.ctl_filter.el,'phedex-core-control-widget-applied'); }
    else                     { YAHOO.util.Dom.removeClass(this.ctl_filter.el,'phedex-core-control-widget-applied'); }
    this.filter_overlay.destroy();
    this.ctl_filter.Hide();
  }
  this.resetFilter();

// Create a (usually hidden) progress indicator.
  this.control.progress = document.createElement('img');
  this.control.progress.src = '/images/progress.gif';
  this.span_control.appendChild(this.control.progress);

  this.control.close = document.createElement('img');
  this.control.close.src = '/images/widget-close.gif';
  this.span_control.appendChild(this.control.close);
  YAHOO.util.Event.addListener(this.control.close, "click", this.destroyContent, this);

  this.startLoading();
  return this;
}
YAHOO.log('loaded...','info','Core.Widget');