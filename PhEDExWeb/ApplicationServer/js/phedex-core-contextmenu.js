// Manage context-menus for PHEDEX widgets

PHEDEX.namespace('Core.ContextMenu');
PHEDEX.Core.ContextMenu.menus = [];
PHEDEX.Core.ContextMenu.items = [];

PHEDEX.Core.ContextMenu.Create=function(name,trigger) {
  var m = PHEDEX.Core.ContextMenu.menus[name];
  if ( !m )
  {
    m = new YAHOO.widget.ContextMenu("contextmenu_"+name,trigger);
    m.cfg.setProperty('zindex',10);
    PHEDEX.Core.ContextMenu.menus[name] = m;
  }
  return m;
}

PHEDEX.Core.ContextMenu.Add=function(name,label,callback) {
  if ( !PHEDEX.Core.ContextMenu.items[name] ) { PHEDEX.Core.ContextMenu.items[name] = []; }
  PHEDEX.Core.ContextMenu.items[name].push( { label:label, callback:callback } );
}

PHEDEX.Core.ContextMenu.Build=function(menu) {
  menu.clearContent();
  menu.payload = [];

  var idx = 1;
  var name;
  while (idx < PHEDEX.Core.ContextMenu.Build.arguments.length)
  {
    name = PHEDEX.Core.ContextMenu.Build.arguments[idx++];
    var l = PHEDEX.Core.ContextMenu.items[name];
    for (var i in l)
    {
      menu.addItem(l[i].label);
      menu.payload.push(l[i].callback);
    }
  }
}

// some default contexts...
PHEDEX.Core.ContextMenu.hideColumn=function(args) {
  YAHOO.log('hideColumn: '+args.col.key);
  args.table.hideColumn(args.col);
}
PHEDEX.Core.ContextMenu.Add('dataTable','Hide This Column',PHEDEX.Core.ContextMenu.hideColumn);
