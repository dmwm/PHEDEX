PHEDEX.namespace('Component');
PHEDEX.Component.ContextMenu=function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());

  var _me = 'ContextMenu',
      _sbx = sandbox,
      _notify = function() {};

  var obj = args.payload.obj;
  if ( obj ) {
    try {
      var f = PHEDEX[obj.type];
      YAHOO.lang.augmentObject(this,f.ContextMenu(obj,args),true);
    } catch(ex) {
      log('cannot augment object of type '+obj.type,'warn',_me);
    }
  }

  _construct = function() {
    return {
      Create: function(config) {
        var i = PHEDEX.Util.Sequence();
        if ( !config.lazyload ) { config.lazyload = true; }
        var menu = new YAHOO.widget.ContextMenu("contextmenu_"+i,config);

        menu.cfg.setProperty('zindex',10);
        return menu;
      },

      _init: function(args) {
        var tMap = args.payload.typeMap,
            obj  = args.payload.obj;
        this.contextMenuTypeMap = tMap || {};
        this.contextMenuArgs=[];
        for (var type in tMap) {
          this.contextMenuArgs.push(tMap[type]);
        }
        var config = args.payload.config || {};
        this.contextMenu = this.Create(config);
        this.Build(this.contextMenu,this.contextMenuArgs);
        this.contextMenu.clickEvent.subscribe(this.onContextMenuClick, obj);
        this.contextMenu.render(document.body);
      },

      Add: function(name,label,callback) {
        if ( !PHEDEX.Component.ContextMenu.items[name] ) { PHEDEX.Component.ContextMenu.items[name] = []; }
        PHEDEX.Component.ContextMenu.items[name][label] = { label:label, callback:callback };
        log('Add: '+name+': #items:'+PHEDEX.Component.ContextMenu.items[name].length,'info',_me);
      },

      Clear: function(menu) { menu.clearContent(); },

      Build: function(menu,components) {
        var name;
        for (var i in components)
        {
          name = components[i];
//           var w = PHEDEX.Core.Widget.Registry.getWidgetsByInputType(name);
// 
// //         First check the core widget registry to see if any widgets can be made
//           for (var j in w)
//           {
//             var widget = w[j];
//             if (widget.context_item) {
//               log('Adding Widget name='+name+' label='+w[j].label, 'info', _me);
//               var item = new YAHOO.widget.MenuItem(w[j].label);
//               menu.addItem(item);
//               // Build a constructor function (fn) in the menu value object
//               item.value = { 'widget': widget.widget,
//                              'type': widget.type,
//                              'fn':function(opts,el) {
//                                 var arg = opts[this.type];
//                                 log('Construct registered widget:'+
//                                     ' widget='+this.widget+
//                                     ' type='+this.type+
//                                     ' arg='+arg,
//                                     'info', _me);
//                                 var w = PHEDEX.Core.Widget.Registry.construct(this.widget,
//                                                                               this.type,
//                                                                               arg);
//                                 if ( w ) { w.update(); }
//                               }
//                             };
//                 menu.addItem(item);
//                 log('Build: '+name+' label:'+w[j].label,'info',_me);
//             }
//           }

//        Next check our own registry
          var list = PHEDEX.Component.ContextMenu.items[name];
          for (var j in list)
          {
            var item = new YAHOO.widget.MenuItem(list[j].label);
            item.value = { 'type':name,
                           'fn':list[j].callback };
            menu.addItem(item);
            log('Build: '+name+' label:'+list[j].label,'info',_me);
          }
        }
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
}

// some static methods/variables for adding 'global' menu-items
PHEDEX.Component.ContextMenu.items={};
PHEDEX.Component.ContextMenu.Add = function(name,label,callback) {
  var _items = PHEDEX.Component.ContextMenu.items;
  if ( !_items[name] ) { _items[name] = {}; }
  if ( _items[name][label] ) { return; }
  _items[name][label] = { label:label, callback:callback };
  log('Add: '+name+': #items:'+_items[name].length,'info','ContextMenu');
};

// this is dataTable-specific, but putting it anywhere else means the dataTable has to know when the ContextMenu
// has been loaded, and then call this function. Calling it more than once is wasteful, so let's just do it here
// when the context menu is loaded.
// PHEDEX.Component.ContextMenu.Add('dataTable','Hide This Field',function(opts, el) {
//   log('hideField: ' + el.col.key, 'info', 'ContextMenu');
//   el.table.hideColumn(el.col);
// });

log('loaded...','info','ContextMenu');