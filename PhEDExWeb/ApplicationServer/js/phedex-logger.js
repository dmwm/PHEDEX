// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger = function() {
  var YuCookie = Yu.Cookie,
      _reader,
      log2Server,
      Dom = YAHOO.util.Dom;
  return {
    log2Server: {
      level: { info:false, warn:false, error:false },
      group: { sandbox:false, core:true },
      option:{ 'log to console':true }
    },
    _addControls: function(el,type) {
      var ctl = PxU.makeChild(el,'div');
      ctl.appendChild(document.createTextNode(PxU.initialCaps(type)+'s:'));
      var keys = [], _keys = {};
      for (var i in log2Server[type]) {
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
            log2Server[type][this.value] = this.checked;
            YuCookie.setSubs('PHEDEX.Logger.'+type,log2Server[type]);
          }
        }(this);
        c.checked = log2Server[type][keys[i]];
        ctl.appendChild(document.createTextNode(keys[i]+':  '));
        c.value   = keys[i];
      }
        var div = PxU.makeChild(el,'div');
        div.id = el.id+'_'+PxU.Sequence();
        return div;
    },

    init: function(args) {
      var el   = Dom.get('phedex-logger'),
          elCtl, elLog2Server, elInner, div, cookie,
          conf = {
            width: "500px",
            height: "20em",
            fontSize: '100%',
            newestOnTop: false,
            footerEnabled: true,
            verboseOutput: false
          };

      log2Server = this.log2Server;
      Yw.Logger.reset();
      if ( !args ) { args = {}; }
      if (args.config) {
        for (var i in args.config) {
          conf[i]=args.config[i];
        }
      }

      try {
        var cookie = YuCookie.getSubs('PHEDEX.Logger.option');
        if ( cookie ) {
          for (var i in cookie) {
            log2Server.option[i] = cookie[i] == 'true' ? true : false;
          }
        }
      } catch (ex) {};
      try {
        var cookie = YuCookie.getSubs('PHEDEX.Logger.level');
        if ( cookie ) {
          for (var i in cookie) {
            log2Server.level[i] = cookie[i] == 'true' ? true : false;
          }
        }
      } catch (ex) {};
      try {
        var cookie = YuCookie.getSubs('PHEDEX.Logger.group');
        if ( cookie ) {
          for (var i in cookie) {
            if ( i.match('_[0-9]+$') ) { next; }
            var j = i.toLowerCase();
            log2Server.group[j] = cookie[j] == 'true' ? true : false;
          }
        }
      } catch (ex) {};

      if ( args.log2Server ) { log2Server = args.log2server; }

      if ( el ) {
        elInner = Dom.get('phedex-logger-inner')
        elInner.innerHTML = '';
        elInner.style.display = 'none';
        elCtl        = Dom.get('phedex-logger-controls');
        elLog2Server = Dom.get('phedex-logger-log2server');
      }

      if ( elCtl && elLog2Server ) {
        var ctl = PxU.makeChild(elLog2Server,'div'),
            c = PxU.makeChild(ctl,'input');
        c.type    = 'button';
        c.value   = 'clear cookies';
        c.onclick = function(obj) {
          return function(ev) {
            YuCookie.setSubs('PHEDEX.Logger.option',{});
            YuCookie.setSubs('PHEDEX.Logger.group',{});
            YuCookie.setSubs('PHEDEX.Logger.level',{});
          }
        }(this);
        this._addControls(elLog2Server,'option');
        this._addControls(elLog2Server,'level');
        this._addControls(elLog2Server,'group');

        div = PxU.makeChild(el,'div');
        div.id = el.id +'_yui';

        el.style.width = conf.width;
        conf.width = 'auto'; // apply the width to the container, but not to the logger inside it
        el.style.fontSize = div.style.fontSize = conf.fontSize;
        _reader = new Yw.LogReader(div.id,conf);
        _reader.hideSource('global');
        _reader.hideSource('LogReader');
      }
      if ( args.opts )
      {
        if ( args.opts.hideSource )
        {
          for (var s in args.opts.hideSource) { _reader.hideSource(args.opts.hideSource[s]); }
        }
        if ( args.opts.collapse ) { PLR.collapse(); }
      }
      if ( log2Server.option['log to console'] ) { Yw.Logger.enableBrowserConsole(); } // Enable logging to firebug console, or Safari console.

//    Attempt to harvest any temporarily buffered log messages
      this.log = function(obj) {
        var lastMsg='', lastLevel='', lastGroup='', lastCount=1;
        return function(str,level,group) {
          var l = log2Server, url;
          if ( typeof(str) == 'object' ) {
            try { str = err(str); } // assume it's an exception object!
            catch (ex) { str = 'unknown object passed to logger'; } // ignore the error if it wasn't an exception object...
          }
          if ( !level ) { level = 'info'; }
          if ( !group ) { group = 'app'; }
          group = group.toLowerCase();
          if ( !l.group[group] ) {
            l.group[group] = false;
            YuCookie.setSubs('PHEDEX.Logger.group',l.group);
          }
          if ( !l.level[level] ) {
            l.level[level] = false;
            YuCookie.setSubs('PHEDEX.Logger.level',l.level);
          }
          if ( lastMsg == str && lastGroup == group && lastLevel == level ) {
            lastCount++;
          } else {
            if ( lastCount > 1 ) {
              lastMsg = 'last message occurred '+lastCount+' times';
              if ( ( level == 'error' || ( l.level[level] && l.group[group] ) ) && location.hostname == 'localhost' ) {
                url = '/phedex/datasvc/log/'+lastLevel+'/'+lastGroup+'/'+lastMsg;
                Yu.Connect.asyncRequest('GET', url, { onSuccess:function(){}, onFailure:function(){} } );
              }
              lastCount = 1;
              Ylog(lastMsg, lastLevel, lastGroup);
            }
            Ylog(str, level, group);
            if ( ( level == 'error' || ( l.level[level] && l.group[group] ) ) && location.hostname == 'localhost' ) {
              url = '/phedex/datasvc/log/'+level+'/'+group+'/'+str;
              Yu.Connect.asyncRequest('GET', url, { onSuccess:function(){}, onFailure:function(){} } );
            }
            lastMsg   = str;
            lastGroup = group;
            lastLevel = level;
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
