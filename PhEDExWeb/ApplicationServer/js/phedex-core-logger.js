// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger.Create=function(args,opts,divid) {
  if ( !divid ) { divid = 'phedex_logger'; }
  var myDiv = document.getElementById(divid);
  if ( !myDiv ) { return; }

  YAHOO.widget.Logger.reset();
  var LoggerConfig = {
    width: "500px",
    height: "20em",
    newestOnTop: false,
    footerEnabled: true,
    verboseOutput: false
  };
  if (args) {
    for (var i in args) {
      LoggerConfig[i]=args[i];
    }
  }
  myDiv.style.width = LoggerConfig.width;
  PHEDEX.Logger.Reader = new YAHOO.widget.LogReader(divid,LoggerConfig);
  PHEDEX.Logger.Reader.hideSource('global');
  PHEDEX.Logger.Reader.hideSource('LogReader');
  if ( opts.hideSource )
  {
    for (var s in opts.hideSource) { PHEDEX.Logger.Reader.hideSource(opts.hideSource[s]); }
  }
  if ( opts.collapse ) { PHEDEX.Logger.Reader.collapse(); }
}

YAHOO.widget.Logger.enableBrowserConsole(); // Enable logging to firebug console, or Safari console.