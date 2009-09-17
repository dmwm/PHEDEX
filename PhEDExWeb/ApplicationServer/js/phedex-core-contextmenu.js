// Manage context-menus for PHEDEX widgets

PHEDEX.namespace('Core.ContextMenu');
PHEDEX.Core.ContextMenu.items = [];

PHEDEX.Core.ContextMenu.Create=function(config) {
  var i = PHEDEX.Util.Sequence();
  if ( !config.lazyload ) { config.lazyload = true; }
  var menu = new YAHOO.widget.ContextMenu("contextmenu_"+i,config);

  menu.cfg.setProperty('zindex',10);
  return menu;
}

PHEDEX.Core.ContextMenu.Add=function(name,label,callback) {
  if ( !PHEDEX.Core.ContextMenu.items[name] ) { PHEDEX.Core.ContextMenu.items[name] = []; }
  PHEDEX.Core.ContextMenu.items[name][label] = { label:label, callback:callback };
  YAHOO.log('Add: '+name+': #items:'+PHEDEX.Core.ContextMenu.items[name].length,'info','Core.ContextMenu');
}

PHEDEX.Core.ContextMenu.Clear=function(menu) {
  menu.clearContent();
}

PHEDEX.Core.ContextMenu.Build=function(menu,components) {
  var name;
  for (var i in components)
  {
    name = components[i];
    var w = PHEDEX.Core.Widget.Registry.getWidgetsByInputType(name);

    // First check the core widget registry to see if any widgets can be made
    for (var j in w)
    {
      var widget = w[j];
      if (widget.context_item) {
	YAHOO.log('Adding Widget name='+name+' label='+w[j].label, 'info', 'Core.ContextMenu');
	var item = new YAHOO.widget.MenuItem(w[j].label);
	menu.addItem(item);
	// Build a constructor function (fn) in the menu value object
	item.value = { 'widget': widget.widget,
		       'type': widget.type,
		       'fn':function(opts,el) {
			 var arg = opts[this.type];
			 YAHOO.log('Construct registered widget:'+
				   ' widget='+this.widget+
				   ' type='+this.type+
				   ' arg='+arg,
				   'info', 'Core.ContextMenu');
			 PHEDEX.Core.Widget.Registry.construct(this.widget,
							       this.type,
							       arg).update();
		       }
		     };
	menu.addItem(item);
	YAHOO.log('Build: '+name+' label:'+w[j].label,'info','Core.ContextMenu');
      }
    }

    // Next check our own registry
    var list = PHEDEX.Core.ContextMenu.items[name];
    for (var j in list)
    {
      var item = new YAHOO.widget.MenuItem(list[j].label);
      item.value = { 'type':name,
		     'fn':list[j].callback };
      menu.addItem(item);
      YAHOO.log('Build: '+name+' label:'+list[j].label,'info','Core.ContextMenu');
    }
  }
}

YAHOO.log('loaded...','info','Core.ContextMenu');
