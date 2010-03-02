PHEDEX.namespace('Global');

PHEDEX.Global.Filter=function(parent) {
  Yla(this, PHEDEX.Base.Object(this));
  this._me = 'globalfilter';
  Yla(this,PHEDEX.Core.Filter(this));
  this.dom.el = PxU.makeChild(parent, 'div', { /*id:'phedex-nav-filter',*/ className:'phedex-nav-component phedex-nav-filter' });
  this.widgets = [];

// replace widget-level events with global-level events for proper two-way communication
  this.filter.onFilterApplied   = PHEDEX.Event.onGlobalFilterApplied;
  this.filter.onFilterCancelled = PHEDEX.Event.onGlobalFilterCancelled;
  this.filter.onFilterValidated = PHEDEX.Event.onGlobalFilterValidated;

  this.fillGlobalFilter = function(el) {
    el.innerHTML = 'this is the filter-panel div';
  }
// This are the user-interaction elements
  this.dom.input = PxU.makeChild(this.dom.el, 'input',
			      { /*id: 'phedex-nav-filter-input',*/ className:'phedex-nav-filter-input',
				type: 'text' });
  this.dom.ctl = PxU.makeChild(this.dom.el, 'div', { className:'phedex-nav-component phedex-nav-link' /*, innerHTML:'Filter'*/ });

// This is the element the global-filter will be displayed in
  this.dom.filterPanel = document.createElement('div');
  this.dom.filterPanel.className = 'phedex-global-filter phedex-visible phedex-widget-selector phedex-box-turquoise';
  document.body.appendChild(this.dom.filterPanel);

  this.onHideFilter   = new YAHOO.util.CustomEvent("onHideFilter",   this, false, YAHOO.util.CustomEvent.LIST);
  this.onAcceptFilter = new YAHOO.util.CustomEvent("onAcceptFilter", this, false, YAHOO.util.CustomEvent.LIST);
  this.onAcceptFilter.subscribe( function(obj) {
    return function() {
      log('onAcceptFilter:'+obj.me(),'info','globalfilter');
      obj.filter.Parse();
    }
  }(this));

  this.ctl.filter = new PHEDEX.Core.Control({text:'Global Filter',
                                            payload:{render:this.dom.ctl,
					      target:this.dom.filterPanel,
                                              fillFn:this.filter.Build,
                                              obj:this,
                                              animate:false,
                                              hover_timeout:200,
                                              onHideControl:this.onHideFilter
//                                              onShowControl:null
                                            }
                                          });

  PHEDEX.Event.onWidgetFilterCancelled.subscribe( function(obj) {
    return function(ev,arr) {
      log('onFilterCancelled:'+obj.me(),'info','datatable');
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      var filter = arr[0];
      if ( typeof(filter) != 'object' ) { return; } // Got some rubbish here?
      for (var i in filter.fields) {
	obj.filter.args[i] = [];
      }
      var str = obj.filter.asString();
      obj.dom.input.value = str;
      obj.ctl.filter.Hide();
    }
  }(this));

  PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
    return function(ev,arr) {
      log('onFilterCancelled:'+obj.me(),'info','globalfilter');
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      obj.dom.input.value = '';
      obj.filter.Reset();
      obj.ctl.filter.Hide();
    }
  }(this));

  PHEDEX.Event.onFilterDefined.subscribe( function(obj) {
    return function(ev,arr) {
      var args = arr[0];
      var widget = arr[1];
      var widgetMe = widget.me();
      var nValues=0;
// TODO ...
// debugger;
      if ( obj.widgets[widgetMe] )
      {
//      This means the object has been seen before, so the global-filter may have fields set for it.
//      These need to be passed back to the widget and acted upon.
// 	widget.filter.args = [];	// hack
	for (var i in args) {
// 	  widget.filter.args[i] = [];	// hack
// 	  widget.filter.args[i].fields = [];	// hack
	  if ( args[i].map ) { widget.filter.args[i].map = args[i].map; }
// 	  widget.filter.args[i].fields = [];	// hack
	  for (var j in args[i].fields) {
// 	    widget.filter.args[i].fields[j] = obj.filter.args[j];	// hack
	    if ( obj.filter.args[j].value ) {
	      args[i].fields[j].value = obj.filter.args[j].value;
	      nValues++;
	    }
	  }
	}
	if ( nValues ) {
// debugger;
	}
	return;
      }
      if ( widget.me() == obj.me() ) { return; } // don't process my own input twice!
      else { obj.filter.init(args); } // copy the initialisation arguments
      log('onFilterDefined:'+widgetMe,'info','globalfilter');
      obj.widgets[widgetMe] = [];
      for (var i in args) {
	for (var j in args[i]) {
	  obj.widgets[widgetMe][j] = i;
	}
      }
      return;
    }
  }(this));

  PHEDEX.Event.onWidgetFilterValidated.subscribe( function(obj) {
    return function(ev,arr) {
      var args = arr[0];
      if ( ! obj.filter.args ) { obj.filter.args = []; }
      for (var i in args) {
	obj.filter.args[i] = args[i];
      }
//    If I only want the global-filter to show elements germaine to the active widget, pass the 'args' to it.
//    If I want to show all set elements of the global filter, don't pass 'args', it will use its internal args.
//       var str = obj.filter.asString(args);
      var str = obj.filter.asString();
      obj.dom.input.value = str;
    }
  }(this));

// TODO This callback is identical to code in phedex-core-widget. If we can sort out the scope, it could be made common-code
  this.filter.onFilterApplied.subscribe( function(obj) {
    return function(ev,arr) {
      var isApplied = arr[0];
      obj.ctl.filter.setApplied(isApplied,true);
      obj.ctl.filter.Hide();
      var str = obj.filter.asString();
      obj.dom.input.value = str;
    }
  }(this));
  PHEDEX.Event.onWidgetFilterApplied.subscribe( function(obj) {
    return function(ev,arr) {
      var isApplied = arr[0];
      obj.ctl.filter.setApplied(isApplied);
    }
  }(this));

  this.onHideFilter.subscribe(function() {
      this.filter.destroy();
    });

  return this;
};

PHEDEX.Event.CreateGlobalFilter.subscribe(function(ev,arr) { new PHEDEX.Global.Filter(arr[0]); });
log('loaded...','info','globalfilter');
