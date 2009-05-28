// A PhEDEx logging class. Only instantiates the logger if the required div exists. This way we can keep it out of
// production pages by simply not declaring the div in the html.
PHEDEX.namespace('Logger');

PHEDEX.Logger.Create=function(opts,divid) {
  if ( !divid ) { divid = 'phedex_logger'; }
  var myDiv = document.getElementById(divid);
  if ( myDiv )
  {
    YAHOO.widget.Logger.reset();
    var LoggerConfig = {
      width: "500px",
      height: "20em",
      newestOnTop: false,
      footerEnabled: true,
      verboseOutput: false
    };
    if (opts) {
      for (o in opts) {
        LoggerConfig[o]=opts[o];
      }
    }
    myDiv.style.width = LoggerConfig.width;
    PHEDEX.Logger.Reader= new YAHOO.widget.LogReader(divid,LoggerConfig);
  }
}
