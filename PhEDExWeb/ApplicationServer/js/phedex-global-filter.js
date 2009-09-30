PHEDEX.namespace('Global');

PHEDEX.Global.Filter=function(el) {
  YAHOO.lang.augmentObject(this, PHEDEX.Base.Object(this));
  this._me = 'PHEDEX.Global.Filter';
  if ( typeof(el) == 'object' ) {
    this.dom.el = el;
  } else {
    this.dom.el = document.getElementById(el);
  }
  YAHOO.lang.augmentObject(this,PHEDEX.Core.Filter(this));
  this.widgets = [];

// replace widget-level events with global-level events for proper two-way communication
  this.filter.onFilterApplied   = PHEDEX.Event.onGlobalFilterApplied;
  this.filter.onFilterCancelled = PHEDEX.Event.onGlobalFilterCancelled;
  this.filter.onFilterValidated = PHEDEX.Event.onGlobalFilterValidated;

  this.fillGlobalFilter = function(el) {
    el.innerHTML = 'this is the filter-panel div';
  }
//   var _initGlobalFilter = function(el) {
//     var filterdiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter', className:'phedex-nav-component phedex-nav-filter' });
//     var input = PxU.makeChild(filterdiv, 'input',
// 			      { id: 'phedex-nav-filter-input', className:'phedex-nav-filter-input',
// 				type: 'text' });
//     var filterpaneldiv = PxU.makeChild(el, 'div', { id:'phedex-nav-filter-panel', className:'phedex-nav-component phedex-nav-link' /*, innerHTML:'Filter'*/ });
  this.dom.el = PxU.makeChild(el, 'div', { className:'phedex-nav-component phedex-nav-link' /*, innerHTML:'Filter'*/ });
  this.dom.filterPanel = document.createElement('div');
  this.dom.filterPanel.className = 'phedex-global-filter phedex-visible phedex-widget-selector phedex-box-turquoise';
  document.body.appendChild(this.dom.filterPanel);

// FIXME This should come from somewhere else!
  this.dom.input = document.getElementById('phedex-nav-filter-input');

  this.onHideFilter   = new YAHOO.util.CustomEvent("onHideFilter",   this, false, YAHOO.util.CustomEvent.LIST);
  this.onAcceptFilter = new YAHOO.util.CustomEvent("onAcceptFilter", this, false, YAHOO.util.CustomEvent.LIST);
  this.onAcceptFilter.subscribe( function(obj) {
    return function() {
      YAHOO.log('onAcceptFilter:'+obj.me(),'info','GlobalFilter');
      obj.filter.Parse();
    }
  }(this));

  this.ctl.filter = new PHEDEX.Core.Control({text:'Global Filter',
                                            payload:{render:this.dom.el, //filterpaneldiv,
					      target:this.dom.filterPanel,
                                              fillFn:this.filter.Build, //fillGlobalFilter,
                                              obj:this,
                                              animate:false,
                                              hover_timeout:200,
                                              onHideControl:this.onHideFilter
//                                              onShowControl:null
                                            }
                                          });

  PHEDEX.Event.onWidgetFilterCancelled.subscribe( function(obj) {
    return function(ev,arr) {
      YAHOO.log('onFilterCancelled:'+obj.me(),'info','Core.DataTable');
      YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
      var filter = arr[0];
      if ( typeof(filter) != 'object' ) { return; } // Got some rubbish here?
      for (var i in filter.fields) {
	obj.filter.args[i] = []; // v;
      }
      var str = obj.filter.asString();
      obj.dom.input.value = str;
      obj.ctl.filter.Hide();
    }
  }(this));

  PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
    return function(ev,arr) {
      YAHOO.log('onFilterCancelled:'+obj.me(),'info','GlobalFilter');
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
      if ( obj.widgets[widget] ) { return; } // already seen this one...
      if ( widget == obj.me() ) { return; } // don't process my own input twice!
      else { obj.filter.init(args); } // copy the initialisation arguments
      YAHOO.log('onFilterDefined:'+widget,'info','GlobalFilter');
      obj.widgets[widget] = [];
      for (var i in args) {
	for (var j in args[i]) {
	  obj.widgets[widget][j] = i;
	}
      }
    }
  }(this));

  PHEDEX.Event.onWidgetFilterValidated.subscribe( function(obj) {
    return function(ev,arr) {
      var args = arr[0];
      var str = obj.filter.asString(args);
      obj.dom.input.value = str;
      if ( ! obj.filter.args ) { obj.filter.args = []; }
      for (var i in args) {
	obj.filter.args[i] = args[i];
      }
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
