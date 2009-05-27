// A PhEDEx logging class. Only instantiates the logger if the 'phedex_logger' div exists.

PHEDEX.namespace('Logger');

var createLogger=function() {
  var myDiv = document.getElementById('phedex_logger');
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
    myDiv.style.width = LoggerConfig.width;
    PHEDEX.Logger.Reader= new YAHOO.widget.LogReader('phedex_logger',LoggerConfig);
  }
}
YAHOO.util.Event.onDOMReady(createLogger);
