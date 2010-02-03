PHEDEX.namespace('Component');
PHEDEX.Component.Filter = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'component-filter',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner;

//   this.decorators.push(args.payload.control);

/**
 * construct a PHEDEX.Component.Filter object. Used internally only.
 * @method _contruct
 * @private
 */

  var moduleHandler = function(obj) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'Cancel': {
          this.ctl.filter.Hide();
          break;
        }
        case 'Reset': {
          this.ctl.filter.Hide();
          break;
        }
        case 'Accept': {
          this.ctl.filter.Hide();
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.selfHandler);

  _construct = function() {
    return {
      me: _me,

      Build: function(el,args) {
//         if ( args && !obj.options.window ) { args.width = '700px'; } // kludgy way to set filter-overlay-width in 'window:false' mode
        if ( !args ) { args = {}; }
        args.context = [obj.dom.content,'tl','tl'];
        this.overlay = new YAHOO.widget.Overlay(el,args);
        this.overlay.setHeader('Filter data selection ('+obj.me+')');
        this.overlay.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
        this.overlay.setFooter('&nbsp;');
        YAHOO.util.Dom.addClass(this.overlay.element,'phedex-core-overlay')

        var body = this.overlay.body;
        body.innerHTML=null;
        var filterDiv = document.createElement('div');
        var buttonDiv = document.createElement('div');
        buttonDiv.className = 'phedex-filter-buttons';
        body.appendChild(filterDiv);
        body.appendChild(buttonDiv);

        YAHOO.util.Dom.removeClass(el,'phedex-invisible'); // div must be visible before overlay is show()n, or it renders in the wrong place!
        this.overlay.render(document.body);
        this.overlay.cfg.setProperty('zindex',100);
//         this.Fill(filterDiv);

        var buttonAcceptFilter = new YAHOO.widget.Button({ label: 'Accept Changes', container: buttonDiv });
        buttonAcceptFilter.on('click', function() { _sbx.notify(this.id,'Filter','Accept'); } );
        var buttonCancelFilter = new YAHOO.widget.Button({ label: 'Cancel Changes', container: buttonDiv });
        buttonCancelFilter.on('click', function() { _sbx.notify(this.id,'Filter','Cancel'); } );
        var buttonResetFilter = new YAHOO.widget.Button({ label: 'Reset Filter', container: buttonDiv });
        buttonResetFilter.on('click', function() { _sbx.notify(this.id,'Filter','Reset'); } );
//      make sure the filter moves with the widget when it is dragged!
        if (obj.options.window) { // TODO this shouldn't be looking so close into the OBJ...?
          obj.module.dragEvent.subscribe(function(type,args) { this.overlay.align('tl','tl'); }, obj, true);
        }
      },
/**
 * Initialise the component
 * @method _init
 * @param args {object} pointer to object containing configuration parameters
 * @private
 */
      _init: function(args) {
        var apc = payload.control,
            el;
        if ( apc ) {
          this.dom.filter = document.createElement('div');
          this.Build( this.dom.filter, args.overlay );
          apc.payload.obj = this;
          apc.payload.text = 'Filter';
          apc.payload.target = 'filter';
          apc.payload.hidden = 'true';
          apc.name = 'filterControl';
//           obj.dom.filter = el;
          this.ctl[apc.name] = new PHEDEX.Component.Control( _sbx, apc );
          if ( apc.parent ) { obj.dom[apc.parent].appendChild(this.ctl[apc.name].el); }
        }
      },


      typeMap: { // map a 'logical element' (such as 'floating-point range') to one or more DOM selection elements
        regex:       {type:'input', size:20},
        int:         {type:'input', size:7 },
        float:       {type:'input', size:7 },
        percent:     {type:'input', size:5 },
        minmax:      {type:'input', size:7, fields:['min','max'], className:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is default...
        minmaxFloat: {type:'input', size:7, fields:['min','max'], className:'minmaxFloat' },
        minmaxPct:   {type:'input', size:7, fields:['min','max'], className:'minmaxPct' }
      },
      Validate: {
        regex: function(arg) { return {result:true, parsed:arg}; }, // ...no sensible way to validate a regex except to compile it, assume true...
        int: function(arg) {
          var i = parseInt(arg);
          return {result:true, parsed:i};
        },
        float: function(arg) {
          var i = parseFloat(arg);
          if ( isNaN(i) ) { return {result:false}; }
          return {result:true, parsed:i};
        },
        percent: function(arg) {
          var i = parseFloat(arg);
          if ( isNaN(i) ) { return {result:false}; }
          if ( i>100.0 || i<0.0 ) { return {result:false}; }
          return {result:true, parsed:i};
        },
        minmax: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min != '' ) { v.parsed.min = parseInt(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max != '' ) { v.parsed.max = parseInt(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          v.result = true;
          return v;
        },
        minmaxFloat: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min ) { v.parsed.min = parseFloat(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max ) { v.parsed.max = parseFloat(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          v.result = true;
          return v;
        },
        minmaxPct: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min ) { v.parsed.min = parseFloat(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max ) { v.parsed.max = parseFloat(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          if ( v.parsed.min && ( v.parsed.min < 0 || v.parsed.min > 100 ) ) { return v; }
          if ( v.parsed.max && ( v.parsed.max < 0 || v.parsed.max > 100 ) ) { return v; }
          v.result = true;
          return v;
        }
      },

      Apply: {
        regex:   function(arg,val) {
          var re = new RegExp(arg);
          if ( val.match(re) ) { return true; }
          return false;
        },
        int:     function(arg,val) { return val > arg; },
        float:   function(arg,val) { return val > arg; },
        percent: function(arg,val) { return val > arg; },
        minmax: function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        },
        minmaxFloat: function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        },
        minmaxPct: function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        }
      },

      Preprocess: {
        toTimeAgo: function(x)
        {
          var d = new Date();
          var now = d.getTime()/1000;
          return now-x;
        },
        toPercent: function(x) { return 100*x; },
      },

//    the global-filter will override these. Global-filter and core-widget communicate by event-pairs. Each
//    object subscribes to one event of a pair and emits the other. This keeps some symmetry in the code
//    without having to mess around with inspecting which event actually fired. Essentially the components
//    communicate via DAGs of events, never loops.
//    The core-filter code simply fires the event assigned to it, the derived components subscribe explicitly
//    to the event they are interested in.
//       onFilterApplied:   PHEDEX.Event.onWidgetFilterApplied,   // event to fire once the filter is applied
//       onFilterValidated: PHEDEX.Event.onWidgetFilterValidated, // event to fire once the filter is validated
//       onFilterCancelled: new YAHOO.util.CustomEvent('onWidgetFilterCancelled', this, false, YAHOO.util.CustomEvent.LIST), // event to fire once the filter is cancelled

      fields: [],
      structure:{ f:[], r:[] },  // mapping of field-to-group, and reverse-mapping of same
      map: [],
      init: function(args) {
        for (var i in args) {
          if ( args[i].map ) {
            this.map[i] = {to:args[i].map.to};
            if ( args[i].map.from ) {
              this.map[i].from = args[i].map.from;
              this.map[i].func = function(f,t) {
                return function(str) {
                  var re = new RegExp(f,'g');
                  str = str.replace(re, t+'.');
                  return str;
                }
              }(args[i].map.from,args[i].map.to);
            };
          }
          this.structure['f'][i] = [];
          for (var j in args[i].fields) {
            this.structure['f'][i][j]=0;
            this.structure['r'][j] = i;
            this.fields[j] = args[i].fields[j];
          }
        }
      },
      isDefined: function() {
        for (var j in this.fields) { return 1; }
        return 0;
      },

      revealAllElements: function(className) {
        var elList = YAHOO.util.Dom.getElementsByClassName(className,null,obj.dom.content);
        for (var i in elList) {
          if ( YAHOO.util.Dom.hasClass(elList[i],'phedex-invisible') ) {
            YAHOO.util.Dom.removeClass(elList[i],'phedex-invisible');
          }
          if ( YAHOO.util.Dom.hasClass(elList[i],'phedex-core-control-widget-applied') ) {
            YAHOO.util.Dom.removeClass(elList[i],'phedex-core-control-widget-applied');
          }
        }
      },

      Reset: function() {
        this.count=0;
        this.args={};
      },

      Fill: function(container) {
//  var container = div;
        if ( !this.args ) { this.args = []; }
        if ( !this.ctl ) { this.ctl = []; }
        this.focusMap={};
        for (var label in this.structure['f']) {
          var fieldset = document.createElement('fieldset');
          var helpClass = 'phedex-filter-help-class-'+PHEDEX.Util.Sequence();
//    fieldset.class = helpClass;
          var legend = document.createElement('legend');
          legend.appendChild(document.createTextNode(label));
          fieldset.appendChild(legend);

          var helpCtl = document.createElement('span');
          helpCtl.appendChild(document.createTextNode('[?]'));
          YAHOO.util.Event.addListener(helpCtl, 'click', function(aClass,anElement) {
            return function() { PxU.toggleVisible(aClass,anElement) };
          }(helpClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(helpCtl);

          var hideClass = 'phedex-filter-hide-class-'+PHEDEX.Util.Sequence();
          var hideCtl = document.createElement('span');
          hideCtl.appendChild(document.createTextNode('[x]'));
          YAHOO.util.Event.addListener(hideCtl, 'click', function(aClass,anElement) {
              return function() { PxU.toggleVisible(aClass,anElement) };
          }(hideClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(hideCtl);

          container.appendChild(fieldset);
          for (var key in this.structure['f'][label]) {
            if ( !this.args[key] ) { this.args[key] = []; }
            var focusOn;
            var c = this.fields[key];
            if ( !c.value ) { c.value = null; }

            var outer = document.createElement('div');
            outer.className = 'phedex-filter-outer phedex-visible '+hideClass;
            var inner = document.createElement('div');
            inner.className = 'phedex-filter-inner';
            inner.id = 'phedex_filter_inner_'+PHEDEX.Util.Sequence();
            var e = this.typeMap[c.type];
            if ( !e ) {
              YAHOO.log('unknown filter-type"'+c.type+'", aborting','error','Core.TreeView');
              return;
            }
            var fields = e.fields;
            if ( !fields ) { fields = [ '' ]; }
            for (var i in fields) {
              if ( i > 0 ) { inner.appendChild(document.createTextNode('  ')); }
              if ( fields[i] != '' ) {
                inner.appendChild(document.createTextNode(fields[i]+' '));
              }
              var el = document.createElement(e.type);
              el.id = 'phedex_filter_elem_'+PHEDEX.Util.Sequence();
              el.className = 'phedex-filter-elem';
              YAHOO.util.Dom.addClass(el,'phedex-filter-key-'+fields[i]);
              if ( e.className ) { YAHOO.util.Dom.addClass(el,'phedex-filter-elem-'+e.className); }
              var size = e.size || c.size;
              if ( size ) { el.setAttribute('size',size); }
              el.setAttribute('type',e.type);
              el.setAttribute('name',key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
              el.setAttribute('value',c.value);
              var def = this.args[key].value || [];
              if ( def.value ) { def = def.value; }
              if ( fields[i] ) {
                if ( def[fields[i]] ) {
                  def = def[fields[i]];
                } else {
                  def = null;
                }
              }
              el.setAttribute('value',def);
              inner.appendChild(el);
              if ( ! this.focusMap[inner.id] ) { this.focusMap[inner.id] = el.id; }
              if ( !focusOn ) { focusOn = el; }
            }
            var cBox = document.createElement('input');
            cBox.type = 'checkbox';
            cBox.className = 'phedex-filter-checkbox';
            cBox.checked = this.args[key].negate;
            inner.appendChild(cBox);
            outer.appendChild(inner);
            var fieldLabel = document.createElement('div');
            fieldLabel.className = 'float-left';
            fieldLabel.appendChild(document.createTextNode(c.text));
            outer.appendChild(fieldLabel);

            if ( c.tip ) {
              var help = document.createElement('div');
              help.className = 'phedex-filter-help phedex-invisible float-right '+helpClass;
              help.appendChild(document.createTextNode(c.tip));
              outer.appendChild(help);
            }
            fieldset.appendChild(outer);
          }
          focusOn.focus();
        }
        var kl = new YAHOO.util.KeyListener(container, { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
                                                { fn:function() { obj.onAcceptFilter.fire(); }, scope:this, correctScope:true } );
        kl.enable();
      },

      Parse: function() {
        this.Reset();
        var isValid = true;
        var keyMatch = /^phedex-filter-key-/;
        var innerList = YAHOO.util.Dom.getElementsByClassName('phedex-filter-inner');
        for (var i in innerList) {
          var nItems = 0, nSet = 0;
          var values = {};
          var value = null;
          var elList = YAHOO.util.Dom.getElementsByClassName('phedex-filter-elem',null,innerList[i]);
          for (var j in elList) {
            var el = elList[j];
            var key;
//      find the phedex-filter-key-* classname of this element
            var elClasses = el.className.split(' ');
            for (var k in elClasses) {
              if ( elClasses[k].match(keyMatch) ) {
                key = elClasses[k].split('-')[3];
                if ( key != '' ) { values[key] = el.value; } // single-valued elements don't have a key!
                else           { value       = el.value; }
                nItems++;
                if ( el.value ) { nSet++; }
              }
            }
          }
          var type = this.fields[el.name].type;
          this.args[el.name] = [];
          var s, v;
          if ( nSet ) {
            if ( nItems > 1 ) { v = values; }
            else              { v = value; }
            s = this.Validate[type](v);
            if ( s.result ) {
              this.args[el.name].value = s.parsed;
              this.setValid(innerList[i]);
              var x = this.fields[el.name];
              if ( x.format ) { this.args[el.name].format = x.format; }
              if ( x.preprocess ) {
                if ( typeof(x.preprocess) == 'string' ) {
                  this.args[el.name].preprocess = this.Preprocess[x.preprocess];
                } else {
                  this.args[el.name].preprocess = x.preprocess;
                }
              }
            }
            this.args[el.name].negate = YAHOO.util.Dom.getElementsByClassName('phedex-filter-checkbox',null,innerList[i])[0].checked;
            if ( !s.result ) {
              YAHOO.log('Invalid entry for "'+this.fields[el.name].text+'", aborting accept','error','Core.Widget');
              this.setInvalid(innerList[i],isValid);
              isValid = false;
            }
          }
        }
        if ( isValid ) {
          this.onFilterValidated.fire(this.args);
          this.onFilterApplied.fire(this.args);
        }
        return isValid; // in case it's useful...
      },

      setValid:   function(el) {
        YAHOO.util.Dom.removeClass(el,'phedex-filter-elem-invalid');
        this.count++;
      },
      setInvalid: function(el,setFocus) {
        YAHOO.util.Dom.addClass(el,'phedex-filter-elem-invalid');
        if ( setFocus ) {
          var focusOn = document.getElementById(this.focusMap[el.id]);
          focusOn.focus();
        }
      },

      isApplied: function() { return this.count; },
      destroy: function() {
        if ( this.overlay && this.overlay.element ) { this.overlay.destroy(); }
        this.dom.filter.destroy();
      },

      asString: function(args) {
        var str = '';
        if ( !args ) { args = this.args; }
        for (var key in args) {
          var mKey = key;
          if ( typeof(args[key].value) == 'undefined' ) { continue; }
          var rKey = this.structure['r'][key];
          if ( this.map[rKey].func ) {
            mKey = this.map[rKey].func(key);
          } else {
            mKey = this.map[rKey].to + '.' + key;
          }
          var fValue = args[key].value;
          if ( args[key].format ) { fValue = args[key].format(fValue); }
          var negate = args[key].negate;
          var seg = '';
          if ( negate ) { seg = '!'; }
            if ( typeof(fValue) == 'object' ) {
              var c = 0, seg1 = null, seg2 = null;
              if ( fValue.min != null ) { c++; seg1 = mKey+'>'+fValue.min; }
              if ( fValue.max != null ) { c++; seg2 = mKey+'<'+fValue.max; }
              if ( c == 0 ) { /* This shouldn't happen if validation worked! */ continue; }
              if ( c == 1 ) { seg += ( seg1 || seg2 ); } // one or the other is set
              if ( c == 2 ) { seg += seg1 +'&'+ seg2; }  // both are set
            } else {
              seg += mKey+'='+fValue;
            }
            if ( str ) { str += ','; }
            str += seg;
          }
        return str;
      }
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-filter');
//   this.onFilterCancelled.subscribe( function(obj) {
//     return function() {
//       log('onWidgetFilterCancelled:'+obj.me(),'info','Core.DataTable');
//       YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.fillDataSource(obj.data);
//       obj.filter.Reset();
//       obj.ctl.filter.Hide();
//       PHEDEX.Event.onWidgetFilterCancelled.fire(obj.filter);
//     }
//   }(this));
//   PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
//     return function() {
//       log('onGlobalFilterCancelled:'+obj.me(),'info','Core.DataTable');
//       YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.fillDataSource(obj.data);
//       obj.filter.Reset();
//     }
//   }(this));
//
//   PHEDEX.Event.onGlobalFilterValidated.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       if ( ! obj.filter.args ) { obj.filter.args = []; }
//       for (var i in args) {
//      obj.filter.args[i] = args[i];
//       }
//       obj.applyFilter(arr[0]);
//     }
//   }(this));
//   this.onFilterApplied.subscribe(function(obj) {
//     return function(ev,arr) {
//       obj.applyFilter(arr[0]);
//       obj.ctl.filter.Hide();
//     }
//   }(this));
//
//   this.applyFilter=function(args) {
// // this is much easier for tables than for branches. Just go through the data-table and build a new one,
// // then feed that to the DataSource!
//     var table=[];
//     if ( ! args ) { args = this.args; }
//     for (var i in this.data) {
//       var keep=true;
//       for (var key in args) {
//      if ( typeof(args[key].value) == 'undefined' ) { continue; }
//      var fValue = args[key].value;
//      var kValue = this.data[i][key];
//      if ( args[key].preprocess ) { kValue = args[key].preprocess(kValue); }
//      var negate = args[key].negate;
//      var status = this.Apply[this.fields[key].type](fValue,kValue);
//      if ( args[key].negate ) { status = !status; }
//      if ( !status ) { // Keep the element if the match succeeded!
//        this.count++;
//        keep=false;
//      }
//       }
//       if ( keep ) { table.push(this.data[i]); }
//     }
//     this.fillDataSource(table);
//     return this.count;
//   }
