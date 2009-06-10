// A page-manager. Creates pages from configuration objects, saves their defaults and creation order, allows for saving and restoring full pages (eventually)

PHEDEX.namespace('Page.Widget','Page.Config.Elements','Page.Config.Order');
PHEDEX.Page.Config.Count=0;

PHEDEX.Page.Create = function( config ) {
  if ( !config ) { config = Page.Config; }
  for ( var i in config )
  {
    var myDivId = config[i].div;
    var call = config[i].call;
    if ( ! myDivId )
    {
      var pattern = /PHEDEX.Page.Widget./;
      myDivId = call.replace(pattern,'');
    }
    var myDiv = PHEDEX.Util.findOrCreateWidgetDiv(myDivId);

    var input_box = document.createElement('input');
    input_box.setAttribute('type','text');
    input_box.setAttribute('id',myDivId+'_select');
    if ( config[i].value )
    { input_box.setAttribute('value',config[i].value); }

    var a = document.createElement('a');
    a.setAttribute('href','#');
    myDiv.handler=call;
    YAHOO.util.Event.addListener(a, 'click', function() { PHEDEX.Page.Widget[this.parentNode.handler](this.parentNode.id); } );

    var aText = document.createTextNode(config[i].text);
    if ( ! aText ) { aText = 'Show ' + call; }
    a.appendChild(aText);
    myDiv.appendChild(input_box);
    myDiv.appendChild(a);

// Save the widget-config for later use
    PHEDEX.Page.Config.Elements[myDivId] = config[i];
    PHEDEX.Page.Config.Order[PHEDEX.Page.Config.Count++] = myDivId;
  }
}
