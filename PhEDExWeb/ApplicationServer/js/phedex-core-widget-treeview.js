//This 'class' represents a tree-view widget for PhEDEx. It assumes it is derived for proper widget-specific behaviour, and it uses
// the base PHEDEX.Core.Widget for the basic implementation. I.e. it's only the fluff for tree-views that goes in here.

PHEDEX.namespace('Core.Widget.TreeView');

PHEDEX.Core.Widget.TreeView = function(divid,parent,opts) {
  var that=new PHEDEX.Core.Widget(divid,parent,opts);
  that.me=function() { YAHOO.log('unimplemented "me"','warn','Core.TreeView'); return 'PHEDEX.Core.Widget.TreeView'; }

// MouseOver handler, can walk the tree to find interesting elements and fire events on them?
  function mouseOverHandler(e) {
//  get the resolved (non-text node) target:
    var elTarget = YAHOO.util.Event.getTarget(e);
    if ( e.type == 'mouseover' ) {
      elTarget.style.backgroundColor = 'yellow';
    } else {
      elTarget.style.backgroundColor = null;
    }
//  the rest here shows how to walk up the DOM to the element I'm interested in
//    while (elTarget.id != that.div_content.id) {
//     if(elTarget.nodeName.toUpperCase() == "LI") {
//       YAHOO.log("The moused element id/name is " + elTarget.id+", "+elTarget.nodeName, "info", "clickExample");
//       break;
//     } else {
//       elTarget = elTarget.parentNode;
//     }
//   }
//   YAHOO.log("Top container reached..", "info", "clickExample");
  }
  that.buildTree=function(div,dlist,map) {
    that.tree = new YAHOO.widget.TreeView(div);
    var currentIconMode=0;
// turn dynamic loading on for entire tree:
    that.tree.setDynamicLoad(PHEDEX.Util.loadTreeNodeData, currentIconMode);
    var tNode = new YAHOO.widget.TextNode({label: dlist.innerHTML, expanded: false}, that.tree.getRoot());
    tNode.isLeaf = true;
    YAHOO.util.Event.on(div, "mouseover", mouseOverHandler);
    YAHOO.util.Event.on(div, "mouseout",  mouseOverHandler);
  }

// A split-button and menu for the show-all-columns function
  that.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
  that.showColumns = new YAHOO.widget.Button(
    {
      type: "split",
      label: "Show all fields",
      name: 'showColumns_'+PHEDEX.Util.Sequence(),
      menu: that.column_menu,
      container: that.div_header,
      disabled:true
    }
  );
//   that.showColumns.on('render',that.hideDefaultColumns);
// event-handlers for driving the split button
  that.showColumns.on("click", function () {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      that.dataTable.showColumn(that.dataTable.getColumn(m[i].value));
    }
    that.column_menu.clearContent();
    that.refreshButton();
    that.resizePanel(that.dataTable);
  });
  that.showColumns.on("appendTo", function () {
    var m = this.getMenu();
    m.subscribe("click", function onMenuClick(sType, oArgs) {
      var oMenuItem = oArgs[1];
      if (oMenuItem) {
        that.dataTable.showColumn(that.dataTable.getColumn(oMenuItem.value));
        m.removeItem(oMenuItem.index);
        that.refreshButton();
      }
      that.resizePanel(that.dataTable);
    });
  });

// update the 'Show all columns' button state
  that.refreshButton = function() {
    that.column_menu.render(document.body);
    that.showColumns.set('disabled', that.column_menu.getItems().length === 0);
  };

// Create a context menu, with default entries for dataTable widgets
  that.buildContextMenu=function() {
    var args=[];
    for (var i=0; i< arguments.length; i++ ) { args[args.length] = arguments[i]; }
    args.push('dataTable');
    that.contextMenu = PHEDEX.Core.ContextMenu.Create(args[0],{trigger:that.div_content});
    PHEDEX.Core.ContextMenu.Build(that.contextMenu,args);
  }
  that.onContextMenuClick = function(p_sType, p_aArgs, p_TreeView) {
//  Based on http://developer.yahoo.com/yui/examples/menu/treeviewcontextmenu.html
    YAHOO.log('ContextMenuClick for '+that.me(),'info','Core.TreeView');
    var oTarget = this.contextEventTarget,
	Dom = YAHOO.util.Dom,
	oCurrentTextNode;

    var oTextNode = Dom.hasClass(oTarget, "ygtvlabel") ?
	oTarget : Dom.getAncestorByClassName(oTarget, "ygtvlabel");

    if (oTextNode) {
      var tNodeMap  = that.textNodeMap;
      oCurrentTextNode = that.textNodeMap[oTextNode.id];
    }
    else {
// Cancel the display of the ContextMenu instance.
      this.cancel();
      return;
    }
    if ( oCurrentTextNode )
    {
      var direction = oCurrentTextNode.payload.obj.direction;
      if ( direction == 'to' ) { direction = 'from'; } // point the other way...
      else		     { direction = 'to'; }
      var selected_site = oCurrentTextNode.payload.args[direction];
//       YAHOO.log('PHEDEX.Widget.TransferNode: ContextMenu: '+direction+' '+selected_site);
      YAHOO.log('ContextMenu: '+'"'+label+'" for '+that.me()+' ('+selected_site+')','info','Core.TreeView');
      var task = p_aArgs[1];
      if (task) {
	      this.payload[task.index](selected_site);
      }
    }
  }
  PHEDEX.Core.ContextMenu.Add('dataTable','Hide This Column', function(args) {
    YAHOO.log('hideColumn: '+args.col.key,'info','Core.TreeView');
    args.table.hideColumn(args.col);
  });

// This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
// it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
// I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
// complete. This allows me to ignore the menu completely if the user didn't build one.
// If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
// care that the object was assembled in exactly the right way. That would then make things a bit more complex...
  that.onBuildComplete.subscribe(function() {
    YAHOO.log('onBuildComplete: '+that.me(),'info','Core.TreeView');
    if ( that.contextMenu )
    {
      YAHOO.log('subscribing context menu: '+that.me(),'info','Core.TreeView');
      that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.tree.getEl());
      that.contextMenu.render(document.body);

    }
//  Event-subscriptions for the 'Show all columns' button. Require that the dataTable exist, so post-build!
    that.dataTable.subscribe('columnHideEvent', function(ev) {
      var column = this.getColumn(ev.column);
      YAHOO.log('column_menu.addItem: label:'+column.label+' key:'+column.key,'info','Core.TreeView');
      that.column_menu.addItem({text: column.label || column.key,value:column.key});
      that.refreshButton();
    } );
    that.dataTable.subscribe('renderEvent', function() { that.resizePanel(that.dataTable); } );
  });

  that.onPopulateComplete.subscribe(function() {
// Hide columns by default. TODO this is fired on PopulateComplete because I don't know how to do it earlier. Would be better if I did
    if ( !that.hideByDefault ) { return; }
    for (var i in that.hideByDefault)
    {
      var column = that.dataTable.getColumn(that.hideByDefault[i]);
      if ( column ) { that.dataTable.hideColumn(column); }
    }
    that.hideByDefault = null; // don't want to do this every time the build is complete...?
  });

// Allow the table to be build again after updates
  that.onUpdateComplete.subscribe( function() {that.fillDataSource(that.data); } );

// Gratuitously flash yellow when the mouse goes over the rows
//   that.onRowMouseOut = function(event) {
//     event.target.style.backgroundColor = null;
//   }
//   that.onRowMouseOver = function(event) {
//     event.target.style.backgroundColor = 'yellow';
//   }

// Resize the panel when extra columns are shown, to accomodate the width
  that.resizePanel=function(table) {
//I have no idea if this is the _best_ way to calculate the new size, but it seems to work, so I stick with it.
    var old_width = table.getContainerEl().clientWidth;
    var offset = 25; // No idea how to determine the correct value here, but this seems to fit.
    var x = table.getTableEl().clientWidth + offset;
    if ( x >= old_width ) { that.panel.cfg.setProperty('width',x+'px'); }
  }

// Custom formatter for unix-epoch dates
//   that.UnixEpochToGMTFormatter = function(elCell, oRecord, oColumn, oData) {
//     var gmt = new Date(oData*1000).toGMTString();
//     elCell.innerHTML = gmt;
//   };
//   YAHOO.widget.DataTable.Formatter.UnixEpochToGMT = that.UnixEpochToGMTFormatter

  return that;
}
