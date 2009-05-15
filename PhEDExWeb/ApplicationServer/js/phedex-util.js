// Utility functions, not PhEDEx-specific, such as adding listeners for on-load etc.
PHEDEX.Util=function() {}
PHEDEX.Util.addLoadListener = function(fn) {
  if (typeof window.addEventListener != 'undefined')
  {
    window.addEventListener('load', fn, false);
  }
  else if (typeof document.addEventListener != 'undefined')
  {
    document.addEventListener('load', fn, false);
  }
  else if (typeof window.attachEvent != 'undefined')
  {
  window.attachEvent('onload', fn);
  }
  else
  {
    var oldfn = window.onload;
    if (typeof window.onload != 'function')
    {
      window.onload = fn;
    }
    else
    {
      window.onload = function()
      {
        oldfn();
        fn();
      };
    }
  }
}

PHEDEX.Util.toggleExtra = function(id) {
    var extra = document.getElementById(id+'_extra');
    var link = document.getElementById(id+'_extra_link');
    if (extra.style.display=='block') {
      extra.style.display='none';
      link.innerHTML='expand';
    } else {
      extra.style.display='block';
      link.innerHTML='collapse';
    }
    return -1;
  }

PHEDEX.Util.findOrCreateWidgetDiv = function(name)
{
// Find a div named 'name' and return it. If that div doesn't exist, create it, append it to a div called
// 'phedex_main', and then return it. This lets me create widgets in the top-level phedex_main div, on demand.
  var div = document.getElementById(name);
  if ( !div )
  {
    div = document.createElement('div');
    div.className = 'node';
    div.id = name;
    var phedex_main = document.getElementById('phedex_main');
    phedex_main.appendChild(div);
  }
  return div;
}

PHEDEX.Util.toggleVisible = function (id) {
    var elem = document.getElementById(id);
    if (elem.style.display=='block') { elem.style.display='none'; }
    else { elem.style.display='block'; }
    return -1;
}

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
      var str = f+' files';
      if ( f ) { str += " / "+PHEDEX.Util.format.bytes(b); }
      return str;
    }
}
