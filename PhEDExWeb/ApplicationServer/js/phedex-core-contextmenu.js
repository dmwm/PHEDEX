// Manage context-menus for PHEDEX widgets

PHEDEX.namespace('Core.ContextMenu');
PHEDEX.Core.ContextMenu.items = [];

PHEDEX.Core.ContextMenu.Create=function(config) {
  var i = PHEDEX.Util.Sequence();
  if ( !config.lazyload ) { config.lazyload = true; }
  var menu = new YAHOO.widget.ContextMenu("contextmenu_"+i,config);

  menu.cfg.setProperty('zindex',10);
  menu.payload = [];
  return menu;
}

PHEDEX.Core.ContextMenu.Add=function(name,label,callback) {
  if ( !PHEDEX.Core.ContextMenu.items[name] ) { PHEDEX.Core.ContextMenu.items[name] = []; }
  PHEDEX.Core.ContextMenu.items[name][label] = { label:label, callback:callback };
  YAHOO.log('Add: '+name+': #items:'+PHEDEX.Core.ContextMenu.items[name].length,'info','Core.ContextMenu');
}

PHEDEX.Core.ContextMenu.Clear=function(menu) {
  menu.clearContent();
  menu.payload = [];
}

PHEDEX.Core.ContextMenu.Build=function(menu,components) {
  var name;
  for (var i in components)
  {
    name = components[i];
    var w = PHEDEX.Core.Widget.Registry.getWidgetsByInputType(name);
    for (var j in w)
    {
      menu.addItem(w[j].label);
      menu.payload.push(w[j].construct);
      YAHOO.log('Build: '+name+' label:'+w[j].label,'info','Core.ContextMenu');
    }
    var list = PHEDEX.Core.ContextMenu.items[name];
    for (var j in list)
    {
      menu.addItem(list[j].label);
      menu.payload.push(list[j].callback);
      YAHOO.log('Build: '+name+' label:'+list[j].label,'info','Core.ContextMenu');
    }
  }
}

YAHOO.log('loaded...','info','Core.ContextMenu');