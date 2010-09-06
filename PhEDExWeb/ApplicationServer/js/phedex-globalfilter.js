PHEDEX.GlobalFilter = function(sandbox,args) {
  var _me = 'globalfilter',
      _sbx = sandbox,
      _filter = 'this is the global-filter',
      ctlArgs = {
                  name:  'Global Filter',
                  source:'component-filter',
                  payload:{
                    obj:  this,
                    control: {
                      parent: 'el',
                      payload:{
                        text:    'Global Filter',
                        title:   "Show/hide the global-filter GUI panel, which lets you create a global filter for all the modules loaded so far this session. The global-filter is currently disabled, because it doesn't work yet",
                        disabled: true,
                        hidden:   true,
                        context: 'input',
                        align:   'bl'
                      },
                      el: 'content'
                    }
                  },
                  target:  'filterPanel'
                };
  Yla(this, new PHEDEX.Base.Object());

  this.filterHandler = function(obj) {
    return function(ev,arr) {
      var module = arr[0],
          filter = arr[1];
      obj.dom.input.value = arr[2];
      _sbx.notify(obj.ctl.filter.id,'setApplied',arr[2]);
    }
  }(this);
  _sbx.listen('Filter',this.filterHandler);

  _construct = function() {
    return {
      me: 'Global Filter',

      _init: function(args) {
        var d = this.dom;
        this.el = document.getElementById('phedex-globalfilter');
        d.el = PxU.makeChild(this.el, 'div', { className:'phedex-nav-component phedex-nav-filter' });
        d.control = document.createElement('div');

//      This is the element the global-filter will be displayed in
//         d.filterPanel = document.createElement('div');
//         d.filterPanel.className = 'phedex-global-filter phedex-visible phedex-widget-selector phedex-box-turquoise';
//         document.body.appendChild(d.filterPanel);

//      This are the user-interaction elements
        this.dom.input = PxU.makeChild(this.dom.el, 'input', { className:'phedex-nav-filter-input', type: 'text' });
        this.dom.input.title = 'This is the global-filter input-box. Type or paste a filter definition here, or edit the one you see';
        this.dom.input.disabled = true;
        this.dom.ctl = PxU.makeChild(this.dom.el, 'div', { className:'phedex-nav-component phedex-nav-link' });

        this.type = 'GlobalFilter'; // needed to get the right 'applyFilter' function
        this.ctl.filter = new PHEDEX.Component.Filter(sandbox,ctlArgs);

//         this.fillGlobalFilter = function(el) {
//           el.innerHTML = 'this is the filter-panel div';
//         }
      },

      init: function() {
      }
    };
  };
  Yla(this, _construct(this),true);
  this._init(args);

//   this.widgets = [];

// replace widget-level events with global-level events for proper two-way communication
//   this.filter.onFilterApplied   = PHEDEX.Event.onGlobalFilterApplied;
//   this.filter.onFilterCancelled = PHEDEX.Event.onGlobalFilterCancelled;
//   this.filter.onFilterValidated = PHEDEX.Event.onGlobalFilterValidated;

//   this.onHideFilter   = new YuCE("onHideFilter",   this, false, YuCE.LIST);
//   this.onAcceptFilter = new YuCE("onAcceptFilter", this, false, YuCE.LIST);
//   this.onAcceptFilter.subscribe( function(obj) {
//     return function() {
//       log('onAcceptFilter:'+obj.me(),'info','globalfilter');
//       obj.filter.Parse();
//     }
//   }(this));

//   PHEDEX.Event.onWidgetFilterCancelled.subscribe( function(obj) {
//     return function(ev,arr) {
//       log('onFilterCancelled:'+obj.me(),'info','datatable');
//       YuD.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       var filter = arr[0];
//       if ( typeof(filter) != 'object' ) { return; } // Got some rubbish here?
//       for (var i in filter.fields) {
// 	obj.filter.args[i] = [];
//       }
//       var str = obj.filter.asString();
//       obj.dom.input.value = str;
//       obj.ctl.filter.Hide();
//     }
//   }(this));

//   PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
//     return function(ev,arr) {
//       log('onFilterCancelled:'+obj.me(),'info','globalfilter');
//       YuD.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.dom.input.value = '';
//       obj.filter.Reset();
//       obj.ctl.filter.Hide();
//     }
//   }(this));

//   PHEDEX.Event.onFilterDefined.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       var widget = arr[1];
//       var widgetMe = widget.me();
//       var nValues=0;
// // TODO ...
// // debugger;
//       if ( obj.widgets[widgetMe] )
//       {
// //      This means the object has been seen before, so the global-filter may have fields set for it.
// //      These need to be passed back to the widget and acted upon.
// // 	widget.filter.args = [];	// hack
// 	for (var i in args) {
// // 	  widget.filter.args[i] = [];	// hack
// // 	  widget.filter.args[i].fields = [];	// hack
// 	  if ( args[i].map ) { widget.filter.args[i].map = args[i].map; }
// // 	  widget.filter.args[i].fields = [];	// hack
// 	  for (var j in args[i].fields) {
// // 	    widget.filter.args[i].fields[j] = obj.filter.args[j];	// hack
// 	    if ( obj.filter.args[j].value ) {
// 	      args[i].fields[j].value = obj.filter.args[j].value;
// 	      nValues++;
// 	    }
// 	  }
// 	}
// 	if ( nValues ) {
// // debugger;
// 	}
// 	return;
//       }
//       if ( widget.me() == obj.me() ) { return; } // don't process my own input twice!
//       else { obj.filter.init(args); } // copy the initialisation arguments
//       log('onFilterDefined:'+widgetMe,'info','globalfilter');
//       obj.widgets[widgetMe] = [];
//       for (var i in args) {
// 	for (var j in args[i]) {
// 	  obj.widgets[widgetMe][j] = i;
// 	}
//       }
//       return;
//     }
//   }(this));

//   PHEDEX.Event.onWidgetFilterValidated.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       if ( ! obj.filter.args ) { obj.filter.args = []; }
//       for (var i in args) {
// 	obj.filter.args[i] = args[i];
//       }
// //    If I only want the global-filter to show elements germaine to the active widget, pass the 'args' to it.
// //    If I want to show all set elements of the global filter, don't pass 'args', it will use its internal args.
// //       var str = obj.filter.asString(args);
//       var str = obj.filter.asString();
//       obj.dom.input.value = str;
//     }
//   }(this));

// TODO This callback is identical to code in phedex-core-widget. If we can sort out the scope, it could be made common-code
//   this.filter.onFilterApplied.subscribe( function(obj) {
//     return function(ev,arr) {
//       var isApplied = arr[0];
//       obj.ctl.filter.setApplied(isApplied,true);
//       obj.ctl.filter.Hide();
//       var str = obj.filter.asString();
//       obj.dom.input.value = str;
//     }
//   }(this));

//   PHEDEX.Event.onWidgetFilterApplied.subscribe( function(obj) {
//     return function(ev,arr) {
//       var isApplied = arr[0];
//       obj.ctl.filter.setApplied(isApplied);
//     }
//   }(this));

//   this.onHideFilter.subscribe(function() {
//       this.filter.destroy();
//     });

  return this;
};

PHEDEX.GlobalFilter.Filter = function(sandbox,obj) {
  return {
    applyFilter: function(args) {
//   this is much easier for tables than for branches. Just go through the data-table and build a new one,
//   then feed that to the DataSource!
//       var table=[], keep, fValue, kValue, status, a;
//       if ( ! args ) { args = this.args; }
//       for (var i in obj.data) {
//         keep=true;
//         for (var j in args) {
//           a = args[j];
//           if ( typeof(a.values) == 'undefined' ) { continue; }
//           fValue = a.values;
//           kValue = obj.data[i][j];
//           if ( a.preprocess ) { kValue = a.preprocess(kValue); }
//           status = this.Apply[this.fields[j].type](fValue,kValue);
//           if ( a.negate ) { status = !status; }
//           if ( !status ) { // Keep the element if the match succeeded!
//             this.count++;
//             keep=false;
//           }
//         }
//         if ( keep ) { table.push(obj.data[i]); }
//       }
//       obj.sortNeeded = true;
//       obj.fillDataSource(table);
//       return this.count;
    }
  };
};

PHEDEX.Core.onLoaded('globalfilter');
// PHEDEX.Event.CreateGlobalFilter.subscribe(function(ev,arr) { new PHEDEX.Global.Filter(arr[0]); });
log('loaded...','info','globalfilter');
