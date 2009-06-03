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

// This may be heavy-handed, wipe out all children and rebuild from scratch. For now, it works well enough...
  while (this.div.hasChildNodes()) { this.div.removeChild(this.div.firstChild); }

// Everything is a resizeable panel now
  this.div.className = 'resizablepanel';
// Create divs for the embedded panel
  this.div_header = document.createElement('div');
  this.div_header.className = 'hd';
  this.div_header.id = this.id+'_hd';
  this.div.appendChild(this.div_header);

  this.div_body = document.createElement('div');
  this.div_body.className = 'bd';
  this.div_body.id = this.id+'_bd';
  this.div.appendChild(this.div_body);

  this.div_footer = document.createElement('div');
  this.div_footer.className = 'ft';
  this.div_footer.id = this.id+'_ft';
  this.div.appendChild(this.div_footer);
// Within the body_div, create a content div. This gives a separate handle for styling and control,
// rather than having too many things all trying to control the body_div element
  this.div_content = document.createElement('div');
  this.div_content.className = 'content';
  this.div_content.id = this.id+'_content';
  this.div_body.appendChild(this.div_content);

// Create the panel
  this.panel = new YAHOO.widget.Panel(this.id,
    {
      close:this.options.close,
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
  YAHOO.util.Event.addListener(this.panel.close, "click", this.destroyContent, this);

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
  
  // Start/FinishLoading, surprisingly, show and hide the progress icon.
  this.startLoading=function()
  {
    this.progress_img.style.display='block';
    this.panel.close.style.display='none';
    this.onLoadingBegin.fire();
  }
  this.finishLoading=function()
  {
    this.progress_img.style.display='none';
    this.panel.close.style.display='block';
    this.onLoadingComplete.fire();
  }
  this.failedLoading=function()
  {
    this.progress_img.style.display='none';
    this.panel.close.style.display='block';
    this.onLoadingFailed.fire();
  }

// Update is the core method that is called both after the object is first created and when the data expires. Depending on whether the implementation node is a level that fetches data itself or that has data injected by a parent, update() should either make a data request (and then parse it when it arrives) or do any data processing necessary and finally call populate() to fill in the header, body and footer. Start/FinishLoading should be used if data is being fetched.
  this.update=function() { alert("Unimplemented update()");}

// A bunch of custom events that can be used by whatever needs them. The core widget fires some of these, but not necessarily all. Derived widgets are free to use them or add their own events
  this.onBuildComplete    = new YAHOO.util.CustomEvent("onBuildComplete");
  this.onPopulateBegin    = new YAHOO.util.CustomEvent("onPopulateBegin");
  this.onPopulateComplete = new YAHOO.util.CustomEvent("onPopulateComplete");
  this.onUpdateBegin      = new YAHOO.util.CustomEvent("onUpdateBegin");
  this.onUpdateComplete   = new YAHOO.util.CustomEvent("onUpdateComplete");
  this.onLoadingBegin     = new YAHOO.util.CustomEvent("onLoadingBegin");
  this.onLoadingComplete  = new YAHOO.util.CustomEvent("onLoadingComplete");
  this.onLoadingFailed    = new YAHOO.util.CustomEvent("onLoadingFailed");
  this.onResizeComplete   = new YAHOO.util.CustomEvent("onResizeComplete");

  this.panel.render();

// Create a (usually hidden) progress indicator.
  this.progress_img = document.createElement('img');
  this.progress_img.src = '/images/progress.gif';
  this.progress_img.className = 'node-progress';
  this.div_header.appendChild(this.progress_img);

  this.startLoading();
  return this;
}
