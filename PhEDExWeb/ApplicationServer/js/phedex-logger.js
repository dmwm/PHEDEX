// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger = function() {
  return {
    log2Server: { info:false, warn:false, error:false },
    init: function(args) {
      var divid = 'phedex-logger',
          div   = document.getElementById(divid);
      if ( !div ) { return; }
      div.innerHTML = '';

      if ( args.log2server ) { this.log2Server = args.log2server; }
      var ctl = PxU.makeChild(div,'div');
      ctl.appendChild(document.createTextNode(' Log to server: '));
      for (var i in this.log2Server) {
        var c = PxU.makeChild(ctl,'input');
        c.type    = 'checkbox';
        c.onclick = function(obj) {
          return function(ev) {
            obj.log2Server[this.value] = this.checked;
          }
        }(this);
        c.checked = this.log2Server[i];
        ctl.appendChild(document.createTextNode(i+':  '));
        c.value   = i;
      }
      div = PxU.makeChild(div,'div');
      divid += '_1';
      div.id = divid;

      YAHOO.widget.Logger.reset();
      var conf = {
        width: "500px",
        height: "20em",
        fontSize: '100%',
        newestOnTop: false,
        footerEnabled: true,
        verboseOutput: false
      };

      if (args.config) {
        for (var i in args.config) {
          conf[i]=args.config[i];
        }
      }
      div.style.width    = conf.width;
      div.style.fontSize = conf.fontSize;
      PHEDEX.Logger.Reader = new YAHOO.widget.LogReader(divid,conf);
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
            for (var i in str) { this.log2Server[i] = str[i]; }
            return;
          }
          if ( !level ) { level = 'info'; }
          if ( !group ) { group = 'app'; }
          YAHOO.log(str, level, group);
          if ( obj.log2Server[level] ) {
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
