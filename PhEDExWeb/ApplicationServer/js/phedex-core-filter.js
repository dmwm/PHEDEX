PHEDEX.namespace('Core.Filter');

// borrowed the coding style from the YUI EventProvider class. This apparently makes it suitable for passing to YAHOO.lang.augmentProto,
// which means the core-widget can 'inherit' this code without having to have it cluttering up the core-widget directly. Makes it more
// maintainable.
//
// As an extra effort towards clean code, I put everything in a sub-object, 'filter'. So instead of inheriting methods which become
// PHEDEX.Core.Widget.filterMethod I have PHEDEX.Core.Widget.filter.Method. This helps reduce namespace-collisions while keeping sensible
// names for methods, and makes it easier to inspect the code in firebug, by giving a hierarchy which can save screen-space. It also makes
// it easier to understand the code: anything in this.filter must be related to this file!
PHEDEX.Core.Filter = function() { }
PHEDEX.Core.Filter.prototype = {
  filter: {
    TypeMap: { // map a 'logical element' (such as 'floating-point range') toone or more DOM selection elements
      regex:       {type:'input', size:20},
      int:         {type:'input', size:7 },
      float:       {type:'input', size:7 },
      percent:     {type:'input', size:5 },
      minmax:      {type:'input', size:7, fields:['min','max'], class:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is default...
      minmaxFloat: {type:'input', size:7, fields:['min','max'], class:'minmaxFloat' },
      minmaxPct:   {type:'input', size:5, fields:['min','max'], class:'minmaxPercent' }
    },
    Validate: {
      regex: function(arg) { return {result:true, value:arg}; }, // ...no sensible way to validate a regex except to compile it, assume true...
      int: function(arg) {
	var i = parseInt(arg);
	return {result:true, value:i};
      },
      float: function(arg) {
	var i = parseFloat(arg);
	if ( isNaN(i) ) { return {result:false}; }
	return {result:true, value:i};
      },
      percent: function(arg) {
	var i = parseFloat(arg);
	if ( isNaN(i) ) { return {result:false}; }
	if ( i>100.0 || i<0.0 ) { return {result:false}; }
	return {result:true, value:i};
      },
      minmax: function(arg) {
	var v = { result:false };
	if ( arg.min ) { v.min = parseInt(arg.min); if ( isNaN(v.min) ) { return v; } }
	if ( arg.max ) { v.max = parseInt(arg.max); if ( isNaN(v.max) ) { return v; } }
	if ( v.min && v.max && v.min > v.max ) { return v; }
	v.result = true;
	return v;
      },
      minmaxFloat: function(arg) {
	var v = { result:false };
	if ( arg.min ) { v.min = parseFloat(arg.min); if ( isNaN(v.min) ) { return v; } }
	if ( arg.max ) { v.max = parseFloat(arg.max); if ( isNaN(v.max) ) { return v; } }
	if ( v.min && v.max && v.min > v.max ) { return v; }
	v.result = true;
	return v;
      },
      minmaxPct: function(arg) {
	var v = { result:false };
	if ( arg.min ) { v.min = parseFloat(arg.min); if ( isNaN(v.min) ) { return v; } }
	if ( arg.max ) { v.max = parseFloat(arg.max); if ( isNaN(v.max) ) { return v; } }
	if ( v.min && v.max && v.min > v.max ) { return v; }
	if ( v.min && ( v.min < 0 || v.min > 100 ) ) { return v; }
	if ( v.max && ( v.max < 0 || v.max > 100 ) ) { return v; }
	v.result = true;
	return v;
      }
    },

    Reset: function() {
      this.count=0;
      this.args={};
    },

    Build: function(div) {
      this.filter.overlay = new YAHOO.widget.Overlay(this.dom.filter.id, { context:[this.dom.body.id,"tl","tl", ["beforeShow", "windowResize"]],
            visible:false,
	    autofillheight:'body'} );
      this.filter.overlay.setHeader('Filter data selection');
      this.filter.overlay.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
      this.filter.overlay.setFooter('&nbsp;');
      YAHOO.util.Dom.addClass(this.filter.overlay.element,'phedex-core-overlay')

      var body = this.filter.overlay.body;
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
      buttonDiv.className = 'phedex-filter-buttons';
      fieldset.appendChild(buttonDiv);
      body.appendChild(fieldset);

      this.filter.overlay.render(document.body);
      this.filter.overlay.cfg.setProperty('width',this.dom.body.offsetWidth+'px');
      this.filter.overlay.show();
      this.filter.overlay.cfg.setProperty('zindex',10);
      this.filter.Fill(filterDiv);

//    fire global events when the buttons are clicked. 
      var buttonAcceptFilter = new YAHOO.widget.Button({ label: 'Accept Filter', container: buttonDiv });
      buttonAcceptFilter.on('click', function() { PHEDEX.Event.onFilterAccept.fire(); }, this, this );
      var buttonCancelFilter = new YAHOO.widget.Button({ label: 'Cancel Filter', container: buttonDiv });
      buttonCancelFilter.on('click', function() { PHEDEX.Event.onFilterCancel.fire(); }, this, this );
    },

    Fill: function(div) {
      this.focusMap={};
      for (var key in this.cfg) {
	var focusOn;
	var c = this.cfg[key];
	if ( !c.value ) { c.value = null; }

	var outer = document.createElement('div');
	outer.className = 'phedex-filter-outer';
	var inner = document.createElement('div');
	inner.className = 'phedex-filter-inner';
	inner.id = 'phedex_filter_inner_'+PHEDEX.Util.Sequence();
	var e = this.TypeMap[c.type];
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
	  if ( e.class   ) { YAHOO.util.Dom.addClass(el,'phedex-filter-elem-'+e.class); }
	  var size = e.size || c.size;
	  if ( size ) { el.setAttribute('size',size); }
	  el.setAttribute('type',e.type);
	  el.setAttribute('name',key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
	  el.setAttribute('value',c.value);
	  inner.appendChild(el);
	  if ( ! this.focusMap[inner.id] ) { this.focusMap[inner.id] = el.id; }
	  if ( !focusOn ) { focusOn = el; }
	}
	outer.appendChild(inner);
// 	if ( c.tip ) { outer.setAttribute('tip',c.tip); } // would be nice to set a tooltip
	outer.appendChild(document.createTextNode(c.text));
	div.appendChild(outer);
	focusOn.focus();
      }
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
//	  find the phedex-filter-key-* classname of this element
	  var elClasses = el.className.split(' ');
	  for (var k in elClasses) {
	    if ( elClasses[k].match(keyMatch) ) {
	      key = elClasses[k].split('-')[3];
	      if ( key != '' ) { values[key] = el.value; } // single-valued elements don't have a key!
	      else	       { value       = el.value; }
	      nItems++;
	      if ( el.value ) { nSet++; }
	    }
	  }
	}
	var type = this.cfg[el.name].type;
	var s;
	if ( nSet ) {
	  if ( nItems > 1 ) {
	    s = this.Validate[type](values);
	    if ( s.result ) {
	      this.args[el.name] = values;
	      this.setValid(innerList[i]);
	    }
	  } else {
	    s = this.Validate[type](value);
	    if ( s.result ) {
	      this.args[el.name] = value;
	      this.setValid(innerList[i]);
	    }
	  }
	  if ( !s.result ) {
	    YAHOO.log('Invalid entry for "'+this.cfg[el.name].text+'", aborting accept','error','Core.Widget');
	    this.setInvalid(innerList[i],isValid);
	    isValid = false;
	  }
	}
      }
      if ( isValid ) { PHEDEX.Event.onFilterValidated.fire(this.args); }
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
    }
  }
}