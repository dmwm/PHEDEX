// Utility functions, not PhEDEx-specific, such as adding listeners for on-load etc.
PHEDEX.namespace('Util');

PHEDEX.Util.findOrCreateWidgetDiv = function(name)
{
// Find a div named 'name' and return it. If that div doesn't exist, create it, append it to a div called
// 'phedex_main', and then return it. This lets me create widgets in the top-level phedex_main div, on demand.
  YAHOO.log('Find or create '+name);
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

/*
PHEDEX.Util.toggleVisible = function (id) {
    var elem = document.getElementById(id);
    if (elem.style.display=='block') { elem.style.display='none'; }
    else { elem.style.display='block'; }
    return -1;
}
*/

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

// create a UL from an array of strings or objects. If given objects, accept 'width' and 'class' elements to apply to each item.
// globally, accept width and class for the entire div. This is a messy but adequate way of getting started with formatting treeview
// leaf nodes to some extent.
PHEDEX.Util.makeInlineDiv = function(args) {
  var wtot = args.width || 900;
  var list = document.createElement('ul');
  var div = document.createElement('div');
  list.className = 'inline_list';
  div.style.width = wtot+'px';
  var n = args.fields.length;
  for ( var i in args.fields )
  {
    if ( typeof(args.fields[i]) == 'object' )
    {
      var w_el = parseInt(args.fields[i].width);
      if ( w_el ) { wtot -= w_el; n--; }
    }
  }
  var w = Math.round(wtot/n);
  for ( var i in args.fields )
  {
    var d1 = document.createElement('div');
    if ( typeof(args.fields[i]) == 'object' )
    {
      d1.innerHTML = args.fields[i].text;
      var w_el = parseInt(args.fields[i].width);
      if ( w_el ) { d1.style.width = args.fields[i].width; }
      else	  { d1.style.width = args.fields[i]; }
      if ( args.fields[i].class ) { d1.className = args.fields[i].class; }
    }
    else
    {
      d1.innerHTML = args.fields[i];
      d1.style.width = w+'px';
    }
//     d1.style.border = '1px solid blue';
    var li = document.createElement('li');
    li.appendChild(d1);
    list.appendChild(li);
  }
  div.appendChild(list);
  if ( args.class ) { list.className += ' '+args.class; } // div.style.border = '1px solid red'; }
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
PHEDEX.Util.generateDivName=function() {
  var j = ++PHEDEX.Page.Config.Count;
  return 'auto_Widget_'+j;
}

// This is for dynamically loading data into YUI TreeViews.
PHEDEX.Util.loadTreeNodeData=function(node, fnLoadComplete) {
// First, create a callback function that uses the payload to identify what to do with the returned data.
  var loadTreeNodeData_callback = function(result) {
// Although 'result' is passed in here, we should not need it. It should have been laundered by the Dataservice
    node.payload.callback(node);
    fnLoadComplete(); // Signal that the operation is complete, the tree can re-draw itself
  }

// Now, find out what to get, if anything...
  if ( typeof(node.payload) == 'undefined' )
  {
//  This need not be an error, so don't log it. Some branches are built on already-known data, and do not require new
//  data to be fetched. If dynamic loading is on for the whole tree this code will be hit for those branches.
    fnLoadComplete();
    return;
  }
  if ( node.payload.call )
  {
    if ( typeof(node.payload.call) == 'string' )
    {
//    payload calls which are strings are assumed to be Datasvc call names, so pick them up from the Datasvc namespace,
//    and conform to the calling specification for the data-service module
      YAHOO.log('in PHEDEX.Util.loadTreeNodeData for '+node.payload.call);
      var fn = PHEDEX.Datasvc[node.payload.call];
      fn(node.payload.args,node.payload.obj,loadTreeNodeData_callback);
    }
    else
    {
//    The call-name isn't a string, assume it's a function and call it directly.
//    I'm guessing there may be a use for this, but I don't know what it is yet...
      YAHOO.log('Apparently require dynamically loaded data from a specified function. This code has not been tested yet','warn');
      node.payload.call(node,loadTreeNodeData_callback);
    }
  }
  else
  {
    YAHOO.log('Apparently require dynamically loaded data but do not know how to get it! (hint: payload probably malformed?)','warn');
    fnLoadComplete();
  }
}
