// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger = function() {
  return {
    log2Server: { level: { info:false, warn:false, error:false }, group:{ sandbox:false, core:true } },

    _addControls: function(el,type) {
      var ctl = PxU.makeChild(el,'div');
      ctl.appendChild(document.createTextNode(PxU.initialCaps(type)+'s:'));
      var keys = [], _keys = {};
      for (var i in this.log2Server[type]) {
        var j = i.toLowerCase()
        if ( !_keys[j]++ ) { keys.push(j); }
      }
      if ( type == 'group' ) {
        keys.sort( function(a,b) { return (a>b) - (b>a); } );
      }
      for (var i in keys) {
        var c = PxU.makeChild(ctl,'input');
        c.type    = 'checkbox';
        c.onclick = function(obj) {
          return function(ev) {
            obj.log2Server[type][this.value] = this.checked;
            YAHOO.util.Cookie.setSubs('PHEDEX.Logger.'+type,obj.log2Server[type]);
          }
        }(this);
        c.checked = this.log2Server[type][keys[i]];
        ctl.appendChild(document.createTextNode(keys[i]+':  '));
        c.value   = keys[i];
      }
        var div = PxU.makeChild(el,'div');
        div.id = el.id+'_'+PxU.Sequence();
        return div;
    },

    init: function(args) {
      var el   = document.getElementById('phedex-logger'),
          elCtl, elLog2Server, elInner, div, cookie,
          conf = {
            width: "500px",
            height: "20em",
            fontSize: '100%',
            newestOnTop: false,
            footerEnabled: true,
            verboseOutput: false
          };

      if ( !el ) { return; }
      elInner = document.getElementById('phedex-logger-inner')
      elInner.innerHTML = '';
      elInner.style.display = 'none';
      elCtl        = document.getElementById('phedex-logger-controls');
      elLog2Server = document.getElementById('phedex-logger-log2server');

      try {
        var cookie = YAHOO.util.Cookie.getSubs('PHEDEX.Logger.level');
        if ( cookie ) {
          for (var i in cookie) {
            this.log2Server.level[i] = cookie[i] == 'true' ? true : false;
          }
        }
      } catch (ex) {};
      try {
        var cookie = YAHOO.util.Cookie.getSubs('PHEDEX.Logger.group');
        if ( cookie ) {
          for (var i in cookie) {
            if ( i.match('_[0-9]+$') ) { next; }
            this.log2Server.group[i.toLowerCase()] = cookie[i] == 'true' ? true : false;
          }
        }
      } catch (ex) {};

      if ( !args ) { args = {}; }
      if ( args.log2server ) { this.log2Server = args.log2server; }
      var  ctl = PxU.makeChild(elLog2Server,'div');
      var c = PxU.makeChild(ctl,'input');
      c.type    = 'button';
      c.value   = 'clear cookies';
      c.onclick = function(obj) {
        return function(ev) {
          YAHOO.util.Cookie.setSubs('PHEDEX.Logger.group',{});
          YAHOO.util.Cookie.setSubs('PHEDEX.Logger.level',{});
        }
      }(this);
      this._addControls(elLog2Server,'level');
      this._addControls(elLog2Server,'group');

      div = PxU.makeChild(el,'div');
      div.id = el.id +'_yui';

      YAHOO.widget.Logger.reset();
      if (args.config) {
        for (var i in args.config) {
          conf[i]=args.config[i];
        }
      }
      el.style.width = conf.width;
      div.style.width = 'auto';
      el.style.fontSize = div.style.fontSize = conf.fontSize;
      PHEDEX.Logger.Reader = new YAHOO.widget.LogReader(div.id,conf);
      PHEDEX.Logger.Reader.hideSource('global');
      PHEDEX.Logger.Reader.hideSource('LogReader');
      if ( args.opts )
      {
        if ( args.opts.hideSource )
        {
          for (var s in args.opts.hideSource) { PHEDEX.Logger.Reader.hideSource(args.opts.hideSource[s]); }
        }
        if ( args.opts.collapse ) { PHEDEX.Logger.Reader.collapse(); }
      }
      YAHOO.widget.Logger.enableBrowserConsole(); // Enable logging to firebug console, or Safari console.

//    Attempt to harvest any temporarily bufferred log messages
      this.log = function(obj) {
        return function(str,level,group) {
          if ( typeof(str) == 'object' ) {
            try { str = err(str); } // assume it's an exception object!
            catch (ex) { str = 'unknown object passed to logger'; } // ignore the error if it wasn't an exception object...
          }
          if ( !level ) { level = 'info'; }
          if ( !group ) { group = 'app'; }
          if ( !obj.log2Server.group[group] ) {
            obj.log2Server.group[group] = false;
            YAHOO.util.Cookie.setSubs('PHEDEX.Logger.group',obj.log2Server.group);
          }
          YAHOO.log(str, level, group.toLowerCase());
          if ( obj.log2Server.level[level] && obj.log2Server.group[group] && (location.hostname == 'localhost') ) {
            var url = '/log/'+level+'/'+group+'/'+str;
            YAHOO.util.Connect.asyncRequest('GET', url, { onSuccess:function(){}, onFailure:function(){} } );
          }
        };
      }(this);
      try {
        var buffer = log();
        log = this.log;
        for (var i in buffer) {
          this.log(buffer[i][0],buffer[i][1],buffer[i][2]);
        }
      } catch(e) {
        log = this.log; // if I had an error I ignore it, but still need to (re-)define the global 'log' function
      };
    }
  }
}
