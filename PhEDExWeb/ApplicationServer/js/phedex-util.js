// Utility functions, not PhEDEx-specific, such as adding listeners for on-load etc.
PHEDEX.namespace('Util');

PHEDEX.Util.findOrCreateWidgetDiv = function(name,container)
{
// Find a div named 'name' and return it. If that div doesn't exist, create it, append it to a div called
// 'phedex-main', and then return it. This lets me create widgets in the top-level phedex-main div, on demand.
  if ( !container ) { container = 'phedex-main'; }
  var div = document.getElementById(name);
  if ( !div )
  {
    div = document.createElement('div');
    div.id = name;
    var parent = document.getElementById(container);
    if (!parent) {
      throw new Error('could not find parent container '+container);
    }
    parent.appendChild(div);
  }
  return div;
}

// generate a new and page-unique name to use for a div for instantiating on-the-fly widgets
PHEDEX.Util.generateDivName=function(prefix) {
  var j = ++PHEDEX.Page.Config.Count;
  if ( ! prefix ) { prefix = 'phedex-auto-widget'; }
  return prefix+'-'+j;
}

// not used. Creates a UL from an array of strings
PHEDEX.Util.makeUList = function(args) {
  var list = document.createElement('ul');
  for ( var i in args )
  {
    var li = document.createElement('li');
    li.innerHTML = args[i];
    list.appendChild(li);
  }
  return list;
}

// Make a child node of some kind
PHEDEX.Util.makeChild = function(parent, kind, args) {
  // Optionally get the parent by id
  if (typeof(parent) != 'object') {
    parent = document.getElementById(parent); 
  }
  if (!parent) { throw new Error("cannot makeChild:  parent is not set"); }
  if (!kind)   { throw new Error("cannot makeChild:  kind is not set"); }

  var child = document.createElement(kind);
  if (!child)   { throw new Error("cannot makeChild:  bad child type?"); }
  for (var a in args) {
    child[a] = args[a];
  }
  parent.appendChild(child);
  return child;
}

// build a tree-node. Takes a Specification-object and a Value-object. Specification and Value are
// nominally identical, except values in the Value object can override the Specification object.
// This lets us create a template Specification and use it in several places (header, body) with
// different Values.
PHEDEX.Util.makeNode = function(spec,val) {
  if ( !val ) { val = {}; }
  var wtot = spec.width || 0;
  var list = document.createElement('ul');
  var div = document.createElement('div');
  list.className = 'inline_list';
  if ( wtot )
  {
    div.style.width = wtot+'px';
    var n = spec.format.length;
    for ( var i in spec.format )
    {
      if ( typeof(spec.format[i]) == 'object' )
      {
	var w_el = parseInt(spec.format[i].width);
	if ( w_el ) { wtot -= w_el; n--; }
      }
    }
  }
  var w = Math.round(wtot/n);
  if ( w < 0 ) { w=0; }
  for ( var i in spec.format )
  {
    var d1 = document.createElement('div');
    if ( val.length > 0 )
    {
      var v = val[i];
      if ( spec.format[i].format ) { v = spec.format[i].format(val[i]); }
      d1.innerHTML = v;
    } else {
      d1.innerHTML = spec.format[i].text;
    }
    var w_el = parseInt(spec.format[i].width);
    if ( w_el ) {
      d1.style.width = w_el+'px';
    } else {
      if ( w ) { d1.style.width = w+'px'; }
    }
    if ( spec.className ) { d1.className = spec.className; }
    if ( spec.format[i].className ) {
      YAHOO.util.Dom.addClass(d1,spec.format[i].className);
    }
    if ( spec.format[i].otherClasses ) {
      var oc = spec.format[i].otherClasses.split(' ');
      for (var c in oc) { YAHOO.util.Dom.addClass(d1,oc[c]); }
    }
    var li = document.createElement('li');
    li.appendChild(d1);
    list.appendChild(li);
  }
  div.appendChild(list);
  return div;
}

// removed from PHEDEX.Core.Widget and placed here, for convenience
PHEDEX.Util.format={
    bytes:function(raw) {
      var f = parseFloat(raw);
      if (f>=1099511627776) return (f/1099511627776).toFixed(1)+' TB';
      if (f>=1073741824) return (f/1073741824).toFixed(1)+' GB';
      if (f>=1048576) return (f/1048576).toFixed(1)+' MB';
      if (f>=1024) return (f/1024).toFixed(1)+' KB';
      return f.toFixed(1)+' B';
    },
    '%':function(raw) {
      return (100*parseFloat(raw)).toFixed(2)+'%';
    },
    longString:function(raw) {
      return "<acronym title='"+raw+"'>"+raw+"</acronym>";
    },
    block:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    },
    file:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    },
    date:function(raw) {
      var d =new Date(parseFloat(raw)*1000);
      return d.toGMTString();
    },
    dataset:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    },
    filesBytes:function(f,b) {
//    allow a single object to be passed in instead of two literals
      if ( typeof(f) == 'object' ) { b = f.bytes; f=f.files; }
      var str = f+' files';
      if ( f > 0  ) { str += " / "+PHEDEX.Util.format.bytes(b); }
      return str;
    },
    spanWrap:function(raw) {
//    wrap the raw data in a span, to allow it to be tagged/found in the DOM. Can use this for detecting long
//    strings that are partially hidden because the div is too short, and show a tooltip or something...
      return "<span class='spanWrap'>"+raw+"</span>";
    }
}

PHEDEX.Util.Sort={
  alpha: {
    asc: function (a,b) {
      if ( a > b ) { return  1; }
      if ( a < b ) { return -1; }
      return 0;
    },
    desc: function (a,b) {
      if ( a > b ) { return -1; }
      if ( a < b ) { return  1; }
      return 0;
    }
  },
  numeric: {
    asc:  function(a,b) { return a-b; },
    desc: function(a,b) { return b-a; }
  },
  files: {
    asc:  function(a,b) { return a.files-b.files; },
    desc: function(a,b) { return b.files-a.files; }
  },
  bytes: {
    asc:  function(a,b) { return a.bytes-b.bytes; },
    desc: function(a,b) { return b.bytes-a.bytes; }
  }
};

// for a given element, return the global configuration object defined for it. This allows to find configurations
// for elements created on the fly. If no configuration found, return a correct empty object, to avoid the need
// for messy nested existence checks in the client code
PHEDEX.Util.getConfig=function(element) {
  var config = PHEDEX.Page.Config.Elements[element];
  if ( config ) { return config; }
  config={};
  config.opts = {};
  return config;
}

// generate a new and page-unique name to use for a div for instantiating on-the-fly widgets
PHEDEX.Util.Sequence=function() {
  var _seqArr = {},
      _seq = 0;
  return function(name) {
    if ( !name ) { return _seq++; }
    if (!_seqArr[name] ) { _seqArr[name] = 0; }
    return _seqArr[name]++;
  }
}();

// Sum an array-field, with an optional parser to handle the field-format
PHEDEX.Util.sumArrayField=function(q,f,p) {
  var sum=0;
  if ( !p ) { p = parseInt; }
  for (var i in q) {
    sum+= p(q[i][f]);
  }
  return sum;
}

PHEDEX.Util.toggleVisible = function(thisClass,el)
{
// find all elements with class=thisClass below el in the DOM. For those that have phedex-(in)visible set, toggle the value
  if (typeof(el) != 'object') {
    el = document.getElementById(el);
  }
  var elList = YAHOO.util.Dom.getElementsByClassName(thisClass,null,el)
  for (var i in elList) {
    if ( YAHOO.util.Dom.hasClass(elList[i],'phedex-visible') ) {
      YAHOO.util.Dom.removeClass(elList[i],'phedex-visible');
      YAHOO.util.Dom.addClass(elList[i],'phedex-invisible');
    } else if ( YAHOO.util.Dom.hasClass(elList[i],'phedex-invisible') ) {
      YAHOO.util.Dom.removeClass(elList[i],'phedex-invisible');
      YAHOO.util.Dom.addClass(elList[i],'phedex-visible');
    }
  }
}

PHEDEX.Util.initialCaps = function(str) {
  return str.substring(0,1).toUpperCase() + str.substring(1,str.length);
}

PHEDEX.Util.getConstructor = function( string ) {
  var x = string.split('-'),
      ctor = PHEDEX,
      c;
  for (var j in x ) {
    if ( j == 0 && x[j] == 'phedex' ) { continue; }
    var field = PxU.initialCaps(x[j]);
    if ( ctor[field] ) { c = ctor[field] }
    else {
      for (var k in ctor) {
        field = k.toLowerCase();
        if ( field == x[j] ) {
          c = ctor[k];
          break;
        }
      }
    }
    if ( !c ) { return null; }
    ctor = c;
  }
  return ctor;
}
var PxU = PHEDEX.Util;
log('loaded...','info','util');