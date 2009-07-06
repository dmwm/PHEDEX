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

PHEDEX.Page.Widget.About = function(el) {
  if ( !el ) { el = document.body; }
  if ( typeof(el) != 'object' ) { el = document.getElementById(el); }
  var div = document.createElement('div');
  div.className='phedex-heading-display';
  var divLogo = document.createElement('div');
  div.appendChild(divLogo);
  divLogo.className = 'phedex-heading-logo';
  var a = document.createElement('a');
  a.setAttribute('href','/html/phedex.html');
  a.setAttribute('title','PhEDEx Home Page');
  var img = document.createElement('img');
  img.setAttribute('src','/images/phedex-logo-small.gif');
  img.setAttribute('alt','PhEDEx');
  img.setAttribute('height','80px');
  a.appendChild(img);
  divLogo.appendChild(a);
  div.appendChild(divLogo);

  var divHeading = document.createElement('div');
  divHeading.className='phedex-heading';
  divHeading.innerHTML = '<h1>PhEDEx Web Interface</h1>' +
      '<h2>Next-generation Alpha Version</h1>' +
      '<p>Send feedback to <a href="mailto:cms-phedex-admins@cern.ch">cms-phedex-admins@cern.ch</a></p>';
  div.appendChild(divHeading);
  el.appendChild(div);
  return div;
}

PHEDEX.Page.Widget.Instance = function(el) {
  if ( !el ) { throw new Error('PHEDEX.Page.Widget.Instance: expect an element name or object'); }
  if ( typeof(el) != 'object' ) { el = document.getElementById(el); }
  while ( el.hasChildNodes() ) { el.removeChild(el.firstChild); }
  var div = document.createElement('div');
  div.className='phedex-heading-instance';
  div.appendChild(document.createTextNode('Select an instance:'));
  var ul = document.createElement('ul');
  var currentInstance = PHEDEX.Datasvc.Instance();
  var instances = PHEDEX.Datasvc.Instances();
    var clickFn = function(ev,x) { YAHOO.log('Set instance '+x,'info','Core.Control'); PHEDEX.Datasvc.Instance(x); }
  for (var i in instances ) {
    var instance = instances[i];
    var a = document.createElement('a');
    a.setAttribute('href','#');
    a.setAttribute('title',instance.name);
    a.appendChild(document.createTextNode(instance.name));
    YAHOO.util.Event.on(a,'click',clickFn,instance.instance);
    a.className = 'phedex-link';
    if ( instance.name == currentInstance.name ) { a.className += ' phedex-link-current'; }
    var li = document.createElement('li');
    li.appendChild(a);
    ul.appendChild(li);
  };
  div.appendChild(ul);
  el.appendChild(div);
  return div;
}
