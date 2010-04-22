// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger = function() {
  var YuC = YAHOO.util.Cookie,
      _reader;
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
            YuC.setSubs('PHEDEX.Logger.'+type,obj.log2Server[type]);
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

      if ( elCtl && elLog2Server ) {
        try {
          var cookie = YuC.getSubs('PHEDEX.Logger.level');
          if ( cookie ) {
            for (var i in cookie) {
              this.log2Server.level[i] = cookie[i] == 'true' ? true : false;
            }
          }
        } catch (ex) {};
        try {
          var cookie = YuC.getSubs('PHEDEX.Logger.group');
          if ( cookie ) {
            for (var i in cookie) {
              if ( i.match('_[0-9]+$') ) { next; }
              var j = i.toLowerCase();
              this.log2Server.group[j] = cookie[j] == 'true' ? true : false;
            }
          }
        } catch (ex) {};

        if ( !args ) { args = {}; }
        if ( args.log2server ) { this.log2Server = args.log2server; }
        var ctl = PxU.makeChild(elLog2Server,'div'),
            c = PxU.makeChild(ctl,'input');
        c.type    = 'button';
        c.value   = 'clear cookies';
        c.onclick = function(obj) {
          return function(ev) {
            YuC.setSubs('PHEDEX.Logger.group',{});
            YuC.setSubs('PHEDEX.Logger.level',{});
          }
        }(this);
        this._addControls(elLog2Server,'level');
        this._addControls(elLog2Server,'group');
      }

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
      _reader = new YAHOO.widget.LogReader(div.id,conf);
      _reader.hideSource('global');
      _reader.hideSource('LogReader');
      if ( args.opts )
      {
        if ( args.opts.hideSource )
        {
          for (var s in args.opts.hideSource) { _reader.hideSource(args.opts.hideSource[s]); }
        }
        if ( args.opts.collapse ) { PLR.collapse(); }
      }
      YAHOO.widget.Logger.enableBrowserConsole(); // Enable logging to firebug console, or Safari console.

//    Attempt to harvest any temporarily bufferred log messages
      this.log = function(obj) {
        var Yl   = YAHOO.log,
            PL = PHEDEX.Logger;
        return function(str,level,group) {
          var l = obj.log2Server;
          if ( typeof(str) == 'object' ) {
            try { str = err(str); } // assume it's an exception object!
            catch (ex) { str = 'unknown object passed to logger'; } // ignore the error if it wasn't an exception object...
          }
          if ( !level ) { level = 'info'; }
          if ( !group ) { group = 'app'; }
          group = group.toLowerCase();
          if ( !l.group[group] ) {
            l.group[group] = false;
            YuC.setSubs('PL.group',l.group);
          }
          if ( !l.level[level] ) {
            l.level[level] = false;
            YuC.setSubs('PL.level',l.level);
          }
          Yl(str, level, group);
          if ( ( level == 'error' || ( l.level[level] && l.group[group] ) ) && location.hostname == 'localhost' ) {
            var url = '/log/'+level+'/'+group+'/'+str;
            YAHOO.util.Connect.asyncRequest('GET', url, { onSuccess:function(){}, onFailure:function(){} } );
            var x = 1;
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
