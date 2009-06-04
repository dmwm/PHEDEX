// Manage context-menus for PHEDEX widgets

PHEDEX.namespace('Core.ContextMenu');
PHEDEX.Core.ContextMenu.menus = [];
PHEDEX.Core.ContextMenu.items = [];

PHEDEX.Core.ContextMenu.Create=function(name,trigger) {
  YAHOO.log('Create: '+name,'info','Core.ContextMenu');
  var i = PHEDEX.Util.Sequence();
//   if ( !i ) { i=0; }
//   PHEDEX.Core.ContextMenu.count = i+1;
  var m = new YAHOO.widget.ContextMenu("contextmenu_"+i+'_'+name,trigger);
  m.cfg.setProperty('zindex',10);
  return m;
}

PHEDEX.Core.ContextMenu.Add=function(name,label,callback) {
  if ( !PHEDEX.Core.ContextMenu.items[name] ) { PHEDEX.Core.ContextMenu.items[name] = []; }
  PHEDEX.Core.ContextMenu.items[name][label] = { label:label, callback:callback };
  YAHOO.log('Add: '+name+': #items:'+PHEDEX.Core.ContextMenu.items[name].length,'info','Core.ContextMenu');
}

PHEDEX.Core.ContextMenu.Build=function(menu,components) {
  menu.clearContent();
  menu.payload = [];

  var name;
  for (var i in components)
  {
    name = components[i];
    var list = PHEDEX.Core.ContextMenu.items[name];
    for (var j in list)
    {
      menu.addItem(list[j].label);
      menu.payload.push(list[j].callback);
      YAHOO.log('Build: '+name+' label:'+list[j].label,'info','Core.ContextMenu');
    }
  }
}
