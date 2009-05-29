// Manage context-menus for PHEDEX widgets

PHEDEX.namespace('Core.ContextMenu');
PHEDEX.Core.ContextMenu.menus = [];
PHEDEX.Core.ContextMenu.items = [];

PHEDEX.Core.ContextMenu.Create=function(name,trigger) {
  if ( !PHEDEX.Core.ContextMenu.menus[name] )
  {
    PHEDEX.Core.ContextMenu.menus[name] = new YAHOO.widget.ContextMenu("contextmenu_"+name,trigger);
  }
  return PHEDEX.Core.ContextMenu.menus[name];
}

PHEDEX.Core.ContextMenu.Add=function(name,label,callback) {
  if ( !PHEDEX.Core.ContextMenu.items[name] ) { PHEDEX.Core.ContextMenu.items[name] = []; }
  PHEDEX.Core.ContextMenu.items[name].push( { label:label, callback:callback } );
}

PHEDEX.Core.ContextMenu.Build=function(menu,name) {
  menu.clearContent();
  menu.payload = [];
  var l = PHEDEX.Core.ContextMenu.items[name];
  for (var i in l)
  {
    menu.addItem(l[i].label);
    menu.payload[i] = l[i].callback;
  }
}
