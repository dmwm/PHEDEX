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
  var i, li, list = document.createElement('ul');
  for (i in args)
  {
    li = document.createElement('li');
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

  var a, child = document.createElement(kind);
  if (!child)   { throw new Error("cannot makeChild:  bad child type?"); }
  for (a in args) {
    child[a] = args[a];
  }
  parent.appendChild(child);
  return child;
}

PHEDEX.Util.format={
  bytes:function(raw) {
    var f = parseFloat(raw), bounds, bounds_length, i;
    bounds = [ [ Math.pow(1000,6), 'E' ],
               [ Math.pow(1000,5), 'P' ],
               [ Math.pow(1000,4), 'T' ],
               [ Math.pow(1000,3), 'G' ],
               [ Math.pow(1000,2), 'M' ],
               [          1000,    'K' ] ];
    bounds_length = bounds.length;
    for (i=0; i<bounds_length; i++) {
      if ( f>bounds[i][0] ) { return (f/bounds[i][0]).toFixed(1)+' '+bounds[i][1]+'B'; }
    }
    if ( f ) { return f; }
    return '-';
  },
  '%':function(raw) {
    return (100*parseFloat(raw)).toFixed(2)+'%';
  },
  longString:function(raw) {
    return "<acronym title='"+raw+"'>"+raw+"</acronym>";
  },
  block:function(raw) {
    if (raw.length>50) {
      var _short = raw.substring(0,50);
      return "<acronym title='"+raw+"'>"+_short+"...</acronym>";
    } else {
      return raw;
    }
  },
  file:function(raw) {
    if (raw.length>50) {
      var _short = raw.substring(0,50);
      return "<acronym title='"+raw+"'>"+_short+"...</acronym>";
    } else {
      return raw;
    }
  },
  date:function(raw) {
    var d =new Date(parseFloat(raw)*1000);
    return d.toGMTString();
  },
  UnixEpochToGMT: function(epoch) {
    if ( epoch*1 === 0 ) { return 'forever'; }
    if ( !epoch ) { return '-'; }
    return new Date(epoch*1000).toGMTString();
  },
  UnixEpochToUTC: function(epoch) {
    if ( epoch*1 === 0 ) { return 'forever'; }
    if ( !epoch ) { return '-'; }
    return new Date(epoch*1000).toUTCString().replace(/GMT/,'UTC');
  },
  secondsToDHMS:function(seconds) {
    var days, hours, minutes;
    days = Math.floor(seconds / 86400);
    seconds  = Math.floor(seconds - days * 86400);
    hours = Math.floor(seconds / 3600);
    minutes = Math.floor((seconds - (hours * 3600))/60);
    seconds -= ((hours * 3600) + (minutes * 60));
    seconds += ''; minutes += ''; hours += '';
    while (hours.length < 2)   {hours   = '0' + hours;}
    while (minutes.length < 2) {minutes = '0' + minutes;}
    while (seconds.length < 2) {seconds = '0' + seconds;}
    return days+' d '+hours + ':' + minutes + ':' + seconds;
  },
  secondsToYMD:function(seconds) {
    var years, months, days, result=' ';
    years = Math.floor(seconds / (86400*365) );
    seconds  = Math.floor(seconds - years * 86400*365);
    months = Math.floor(seconds / (86400*30));
    days = Math.floor((seconds - (months * 86400*30))/86400);
    if ( years  ) { result += years  + ' year'  + (years  > 1 ? 's ' : ' ' ); }
    if ( months ) { result += months + ' month' + (months > 1 ? 's ' : ' ' ); }
    if ( days   ) { result += days   + ' day'   + (days   > 1 ? 's ' : ' '  ); }
    return result;
  },
  dataset:function(raw) {
    if (raw.length>50) {
      var _short = raw.substring(0,50);
      return "<acronym title='"+raw+"'>"+_short+"...</acronym>";
    } else {
      return raw;
    }
  },
  filesBytes:function(f,b) {
//  allow a single object to be passed in instead of two literals
    if ( typeof(f) == 'object' ) { b = f.bytes; f=f.files; }
    var str = f+' files';
    if ( f > 0  ) { str += " / "+PHEDEX.Util.format.bytes(b); }
    return str;
  },
  spanWrap:function(raw) {
//  wrap the raw data in a span, to allow it to be tagged/found in the DOM. Can use this for detecting long
//  strings that are partially hidden because the div is too short, and show a tooltip or something...
    return "<span class='span-wrap'>"+raw+"</span>";
  },
  toFixed: function(mantissa) {
    return function(raw) {
      return parseFloat(raw).toFixed(mantissa);
    }
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
  var i, sum=0;
  if ( !p ) { p = parseInt; }
  for (i in q) {
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
  var i, e, elList = YuD.getElementsByClassName(thisClass,null,el),
  visible = 'phedex-visible', invisible='phedex-invisible';
  for (i in elList) {
    e = elList[i];
    if ( YuD.hasClass(e,visible) ) {
      YuD.removeClass(e,visible);
      YuD.addClass(e,invisible);
    } else if ( YuD.hasClass(e,invisible) ) {
      YuD.removeClass(e,invisible);
      YuD.addClass(e,visible);
    }
  }
}

PHEDEX.Util.initialCaps = function(str) {
  return str.substring(0,1).toUpperCase() + str.substring(1,str.length);
}

PHEDEX.Util.getConstructor = function( string ) {
  var x = string.split('-'),
      ctor = PHEDEX,
      c, j, field, k;
  for (j in x ) {
    if ( j == 0 && x[j] == 'phedex' ) { continue; }
    field = PxU.initialCaps(x[j]);
    if ( ctor[field] ) { c = ctor[field] }
    else {
      for (k in ctor) {
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

PHEDEX.Util.epochAlign = function(time,interval) {
/*
 * align a time to an interval. The time defaults to 'now', the interval defaults to one minute
 */
  if ( ! time ) {
    time = new Date();
    time = time.getTime() / 1000;
  }
  if ( !interval ) { interval = 60; }
  time = Math.round(time-time%interval);
  return time;
}

PHEDEX.Util.now = function() {
  var today = new Date();
  return {year:today.getFullYear(), month:today.getMonth()+1, day:today.getDate(), hour:today.getHours(), minute:today.getMinutes(), second:today.getSeconds()};
};

PHEDEX.Util.feature = {
  alpha: "<div class='phedex-feature-class phedex-feature-alpha' title='this feature is in alpha-release, expect bugs!'>&alpha;</div>",
  beta:  "<div class='phedex-feature-class phedex-feature-beta'  title='this feature is in beta-release, and may not be production quality'>&beta;</div>"
};
PHEDEX.Util.icon = {
 'green-circle':  "<img alt='0 the number here drives the sort-order' class='phedex-icon-class phedex-icon-green-circle'  src='"+PxW.WebAppURL+"/images/icon-circle-green.png' />",
 'yellow-circle': "<img alt='1 the number here drives the sort-order' class='phedex-icon-class phedex-icon-yellow-circle' src='"+PxW.WebAppURL+"/images/icon-circle-yellow.png' />",
 'red-circle':    "<img alt='2 the number here drives the sort-order' class='phedex-icon-class phedex-icon-red-circle'    src='"+PxW.WebAppURL+"/images/icon-circle-red.png' />",
  Error:          "<img src='"+PxW.WebAppURL+"/images/icon-circle-red.png' style='vertical-align:bottom' />",
  Warn:           "<img src='"+PxW.WebAppURL+"/images/icon-circle-yellow.png' style='vertical-align:bottom' />",
  OK:             "<img src='"+PxW.WebAppURL+"/images/icon-circle-green.png' style='vertical-align:bottom' />"
};

PHEDEX.Util.UserAgent = function() {
  return 'PhEDEx-WebApp/'+PxW.Version+' (CMS) '+navigator.userAgent;
}

PHEDEX.Util.DBSDefaults = {
  prod:'https://cmsweb.cern.ch/dbs/prod/global/DBSReader',
  test:'LoadTest',
  debug:'LoadTest',
  tbedi:'https://cmsweb.cern.ch/dbs/prod/global/DBSReader',
  tbedii:'test',
  tony:'test'
}

/**
* This is the prototype for the string trim function. This is to trim the string 
* i.e to remove starting and trailing whitespace.
* @method trim
*/
String.prototype.trim = function() {
    return (this.replace(/^\s+|\s+$/g, ""));
}

/**
* This is the prototype for the string startswith function. This check if the string starts  
* with the given argument.
* @method startsWith
* @param {String} str is the string that has to be checked
*/
String.prototype.startsWith = function(str) {
    return (this.match("^" + str) == str);
}

var PxUf   = PxU.format;

window.onerror = function(msg, url, line) {
  if ( PxW.ProductionMode ) {
    return false;
  } else {
    log('onerror: '+msg+' url:'+url+' line:'+line,'error','app');
    return true;
  }
}

PHEDEX.Util.stdLoading = function(text) {
  if ( !text ) { text = 'loading, please wait...'; }
  return text+"<br/><img src='" + PxW.WebAppURL + "/images/barbers_pole_loading.gif'/>";
}

PHEDEX.Util.parseDataserviceError = function(str) {
  var text = str.replace(/\n/g,'');
  if ( text.match(/^<html>.*<body>.*<\/h1>(.*)<\/body>.*/) ) {
    text = RegExp.$1;
    text = text.replace(/^<p>/,'');
    text = text.replace(/<\/p>$/,'');
  }
  text = text.replace(/\(.*\) to \(eval\) /,'');
  return text;
}

PHEDEX.Util.protectMe = function(instance) {
  if ( !PxW.ProductionMode ) {
    for (var name in instance) {
      method = instance[name];
      if ( typeof method == 'function' ) {
        instance[name] = function(name, method) {
          return function() {
            try { return method.apply(this,arguments); }
            catch(ex) {
              log(name+'(): '+ex.message,'error',instance.me);
            }
          }
        }(name,method);
      }
    }
  }
}

log('loaded...','info','util');
