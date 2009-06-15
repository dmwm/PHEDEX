//This 'class' represents a tree-view widget for PhEDEx. It assumes it is derived for proper widget-specific behaviour, and it uses
// the base PHEDEX.Core.Widget for the basic implementation. I.e. it's only the fluff for tree-views that goes in here.
PHEDEX.namespace('Core.Widget.TreeView');

PHEDEX.Core.Widget.TreeView = function(divid,parent,opts) {
  var that=new PHEDEX.Core.Widget(divid,parent,opts);
  that.me=function() { YAHOO.log('unimplemented "me"','error','Core.TreeView'); return 'PHEDEX.Core.Widget.TreeView'; }
  that.headerNames=[];

// MouseOver handler, can walk the tree to find interesting elements and fire events on them?
  function mouseOverHandler(e) {
//  get the resolved (non-text node) target:
    var elTarget = YAHOO.util.Event.getTarget(e);
    var el = that.locateNode(elTarget);
    if ( ! el ) { return; }
    var colour, colour_alt;
    if ( e.type == 'mouseover' ) {
      colour = 'yellow';
      colour_alt = '#ffa'; // pale yellow
    } else {
      colour = null; // not a mouse-over, must be a mouse-out, restore the colours
      colour_alt = null;
    }
    var elList = that.locatePartnerFields(el);
    for (var i in elList )
    {
      elList[i].style.backgroundColor = colour_alt;
    }
    el.style.backgroundColor = colour;
  }
  function clickHandler(e) {
    var elTarget = YAHOO.util.Event.getTarget(e);
    var el = that.locateNode(elTarget);
    if ( !el ) { return; }
    var fieldClass = that.getPhedexFieldClass(el);
    YAHOO.log("el id/name "+el.id+"/"+el.nodeName+' class:'+el.className+' contents:'+el.innerHTML, 'info', 'Core.TreeView');
  }

  that.getPhedexFieldClass=function(el) {
//  find the phedex-tree-* classname of this element
    var treeMatch = /^phedex-tree-/;
    var elClasses = el.className.split(' ');
    for (var i in elClasses) {
      if ( elClasses[i].match(treeMatch) ) {
	return elClasses[i];
      }
    }
    return;
  }
  that.locatePartnerFields=function(el) {
//  for a header-field, find all displayed nodes of that type. For a value-field, find only the header
    var treeMatch = /^phedex-tree-/;
    var treeOther;
    var candList;
    var elList=[];
    if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-header')) { treeOther = 'phedex-tnode-field'; }
    else						  { treeOther = 'phedex-tnode-header'; }
    var elClasses = el.className.split(' ');
    for (var i in elClasses) {
      if ( elClasses[i].match(treeMatch) ) {
	candList = YAHOO.util.Dom.getElementsByClassName(elClasses[i], 'div', that.div_body);
      }
    }
    for (var i in candList )
    {
      if ( YAHOO.util.Dom.hasClass(candList[i],treeOther) )
      {
	elList.push(candList[i]);
      }
    }
    return elList;
  }
  that.locateNode=function(el) {
//  find the nearest ancestor that has a phedex-tnode-* class applied to it, either
//  phedex-thode-field or phedex-tnode-header
    while (el.id != that.div_content.id) { // walk up only as far as the content-div
      if ( that.textNodeMap[el.id] ) { // look for tree-nodes
        YAHOO.log('Activated element: '+el.id,'info','Core.TreeView');
      }
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
        return el;
      }
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
        return el;
      }
      el = el.parentNode;
    }
  }
  that.buildTree=function(div,dlist) {
    that.tree = new YAHOO.widget.TreeView(div);
    var currentIconMode=0;
// turn dynamic loading on for entire tree?
    if ( that.isDynamic ) {
      that.tree.setDynamicLoad(PHEDEX.Util.loadTreeNodeData, currentIconMode);
    }
    YAHOO.util.Event.on(div, "mouseover", mouseOverHandler);
    YAHOO.util.Event.on(div, "mouseout",  mouseOverHandler);
  }
  that.addNode=function(spec,values,parent,opts) {
    var el = PHEDEX.Util.makeNode(spec,values);
    if ( !parent ) { parent = that.tree.getRoot(); }
    if ( !opts ) { opts = {}; }
    var tNode = new YAHOO.widget.TextNode({label: el.innerHTML, expanded: false}, parent);
    that.textNodeMap[tNode.labelElId] = tNode;
    if ( opts.payload ) { tNode.payload = opts.payload; }
    if ( opts.isHeader ) {
      for (var i in spec.format) {
	var className = spec.format[i].className;
	var value = values[i];
	if ( opts.prefix ) { value = opts.prefix+': '+value; }
	if ( that.headerNames[className] ) {
	  YAHOO.log('duplicate entry for '+className+': "'+that.headerNames[className]+'" and "'+value+'"','error','Core.TreeView');
	} else {
	  var classNames = className.split(' ');
	  that.headerNames[classNames[0]] = value;
	}
      }
    }
    for (var i in spec.format) {
      if ( spec.format[i].hideByDefault )
      {
	var classNames = spec.format[i].className.split(' ');
	that.hideByDefault[classNames[0]]=1;
      }
    }
    return tNode;
  }

// A split-button and menu for the show-all-fields function
  that.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
  that.showFields = new YAHOO.widget.Button(
    {
      type: "split",
      label: "Show all fields",
      name: 'showFields_'+PHEDEX.Util.Sequence(),
      menu: that.column_menu,
      container: that.div_header,
      disabled:true
    }
  );
// event-handlers for driving the split button
  that.showFields.on("click", function () {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      YAHOO.util.Dom.getElementsByClassName(m[i].value,null,that.div_content,function(element) {
	element.style.display = null;
      });
    }
    that.column_menu.clearContent();
    that.refreshButton();
    that.resizePanel(that.tree);
  });
  that.showFields.on("appendTo", function () {
    var m = this.getMenu();
    m.subscribe("click", function onMenuClick(sType, oArgs) {
      var oMenuItem = oArgs[1];
      if (oMenuItem) {
      YAHOO.util.Dom.getElementsByClassName(oMenuItem.value,null,that.div_content,function(element) {
	element.style.display = null;
      });
        m.removeItem(oMenuItem.index);
        that.refreshButton();
      }
      that.resizePanel(that.tree);
    });
  });

// update the 'Show all columns' button state
  that.refreshButton = function() {
    that.column_menu.render(document.body);
    that.showFields.set('disabled', that.column_menu.getItems().length === 0);
  };

// Create a context menu, with default entries for dataTable widgets
  that.buildContextMenu=function() {
    var args=[];
    for (var i=0; i< arguments.length; i++ ) { args[args.length] = arguments[i]; }
    args.push('treeView');
    that.contextMenu = PHEDEX.Core.ContextMenu.Create(args[0],{trigger:that.div_content});
    PHEDEX.Core.ContextMenu.Build(that.contextMenu,args);
  }
  that.onContextMenuClick = function(p_sType, p_aArgs, p_TreeView) {
//  Based on http://developer.yahoo.com/yui/examples/menu/treeviewcontextmenu.html
    YAHOO.log('ContextMenuClick for '+that.me(),'info','Core.TreeView');
    var oTarget = this.contextEventTarget,
	oCurrentTextNode;
    var oTextNode = YAHOO.util.Dom.hasClass(oTarget, "ygtvlabel") ?
	oTarget : YAHOO.util.Dom.getAncestorByClassName(oTarget, "ygtvlabel");

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
      var label = p_aArgs[0].explicitOriginalTarget.textContent;
      var task = p_aArgs[1];
      var args = {}, opts = {};
      if ( oCurrentTextNode.payload )	{
	args = oCurrentTextNode.payload.args;
	opts = oCurrentTextNode.payload.opts;
      }
      YAHOO.log('ContextMenu: '+'"'+label+'" for '+that.me()+' ('+opts.selected_node+')','info','Core.TreeView');
      if (task) {
	this.payload[task.index](args, opts, {tree:p_TreeView, node:oCurrentTextNode, target:oTarget, textNode:oTextNode});
      }
    }
  }
  PHEDEX.Core.ContextMenu.Add('treeView','Hide This Field', function(args,opts,el) {
    var elPhedex = that.locateNode(el.target);
    var elClass = that.getPhedexFieldClass(elPhedex);
    that.hideFieldByClass(elClass);
  });
  that.hideFieldByClass=function(className) {
    YAHOO.log('hideField: '+className,'info','Core.TreeView');
    YAHOO.util.Dom.getElementsByClassName(className,null,that.div_content,function(element) {
      element.style.display = 'none';
    });
    var elHeader = that.headerNames[className];
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      YAHOO.log(m[i].value+' _ '+className,'info','debug');
      if ( m[i].value == className )
      {
	YAHOO.log(m[i].value+' _ '+className,'error','debug');
      }
    }
    that.column_menu.addItem({text: that.headerNames[className],value: className});
    that.refreshButton();
  }
  that.hideAllFieldsThatShouldBeHidden=function() {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      YAHOO.util.Dom.getElementsByClassName(m[i].value,null,that.div_content,function(element) {
	element.style.display = 'none';
      });
    }
  }

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
    that.tree.subscribe('expandComplete',function(node) {
      that.hideAllFieldsThatShouldBeHidden();
    });
  });

  that.onDataFailed.subscribe(function() {
    if ( that.tree ) { that.tree.destroy(); that.tree = null; }
    that.div_content.innerHTML='Data-load error, try again later...';
  });

  that.onPopulateComplete.subscribe(function() {
    for (var className in that.hideByDefault) { that.hideFieldByClass(className); }
    that.hideByDefault = []; // don't want to do this every time the build is complete...?
  });

// Resize the panel when extra columns are shown, to accomodate the width
  that.resizePanel=function(tree) {
//I have no idea if this is the _best_ way to calculate the new size, but it seems to work, so I stick with it.
// debugger;
//     var old_width = 1500; // tree.getContainerEl().clientWidth;
//     var offset = 25; // No idea how to determine the correct value here, but this seems to fit.
//     var x = table.getTableEl().clientWidth + offset;
//     var x = 700;
//     if ( x >= old_width ) { that.panel.cfg.setProperty('width',x+'px'); }
  }

  return that;
}

YAHOO.log('loaded...','info','Core.TreeView');
