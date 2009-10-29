PHEDEX.namespace('Component');
PHEDEX.Component.ContextMenu=function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'Component-ContextMenu',
      _sbx = sandbox,
      _notify = function() {},
      _items = [];
// debugger;
  _construct = function() {
    return {
      Create: function(config) {
        var i = PHEDEX.Util.Sequence();
        if ( !config.lazyload ) { config.lazyload = true; }
        var menu = new YAHOO.widget.ContextMenu("contextmenu_"+i,config);

        menu.cfg.setProperty('zindex',10);
        return menu;
      },
_init: function(args) { this.Create(args); },

      Add: function(name,label,callback) {
        if ( !_items[name] ) { _items[name] = []; }
        _items[name][label] = { label:label, callback:callback };
        log('Add: '+name+': #items:'+_items[name].length,'info',_me);
      },

      Clear: function(menu) { menu.clearContent(); },

      Build: function(menu,components) {
        var name;
        for (var i in components)
        {
          name = components[i];
          var w = PHEDEX.Core.Widget.Registry.getWidgetsByInputType(name);

//         First check the core widget registry to see if any widgets can be made
          for (var j in w)
          {
            var widget = w[j];
            if (widget.context_item) {
              log('Adding Widget name='+name+' label='+w[j].label, 'info', _me);
              var item = new YAHOO.widget.MenuItem(w[j].label);
              menu.addItem(item);
              // Build a constructor function (fn) in the menu value object
              item.value = { 'widget': widget.widget,
                             'type': widget.type,
                             'fn':function(opts,el) {
                                var arg = opts[this.type];
                                log('Construct registered widget:'+
                                    ' widget='+this.widget+
                                    ' type='+this.type+
                                    ' arg='+arg,
                                    'info', _me);
                                var w = PHEDEX.Core.Widget.Registry.construct(this.widget,
                                                                              this.type,
                                                                              arg);
                                if ( w ) { w.update(); }
                              }
                            };
                menu.addItem(item);
                log('Build: '+name+' label:'+w[j].label,'info',_me);
            }
          }

//        Next check our own registry
          var list = _items[name];
          for (var j in list)
          {
            var item = new YAHOO.widget.MenuItem(list[j].label);
            item.value = { 'type':name,
                           'fn':list[j].callback };
            menu.addItem(item);
            log('Build: '+name+' label:'+list[j].label,'info','Component.ContextMenu');
          }
        }
      }
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','Component-ContextMenu');
