// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger.Create=function(args,opts,divid) {
  if ( !divid ) { divid = 'phedex-logger'; }
  var _div = document.getElementById(divid);
  if ( !_div ) { return; }
  _div.innerHTML = '';

  YAHOO.widget.Logger.reset();
  var _conf = {
    width: "500px",
    height: "20em",
    fontSize: '100%',
    newestOnTop: false,
    footerEnabled: true,
    verboseOutput: false
  };
  if (args) {
    for (var i in args) {
      _conf[i]=args[i];
    }
  }
  _div.style.width = _conf.width;
  _div.style.fontSize = _conf.fontSize;
  PHEDEX.Logger.Reader = new YAHOO.widget.LogReader(divid,_conf);
  PHEDEX.Logger.Reader.hideSource('global');
  PHEDEX.Logger.Reader.hideSource('LogReader');
  if ( opts )
  {
    if ( opts.hideSource )
    {
      for (var s in opts.hideSource) { PHEDEX.Logger.Reader.hideSource(opts.hideSource[s]); }
    }
    if ( opts.collapse ) { PHEDEX.Logger.Reader.collapse(); }
  }
  YAHOO.widget.Logger.enableBrowserConsole(); // Enable logging to firebug console, or Safari console.

// Attempt to harvest any temporarily bufferred log messages
  var _log = function(str,level,group) { YAHOO.log(str, level || 'info', group || 'app'); };
  try {
    var buffer = log();
    log = _log;
    for (var i in buffer) {
      log(buffer[i][0],buffer[i][1],buffer[i][2]);
    }
  } catch(e) {
    log = _log; // if I had an error I ignore it, but still need to (re-)define the global 'log' function
  };
}
