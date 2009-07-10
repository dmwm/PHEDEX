PHEDEX.namespace('Core.Widget.TreeView');

PHEDEX.Core.Widget.TreeView = function(divid,parent,opts) {
  var that=new PHEDEX.Core.Widget(divid,parent,opts);
  that.me=function() { YAHOO.log('unimplemented "me"','error','Core.TreeView'); return 'PHEDEX.Core.Widget.TreeView'; }
  that.structure={headerNames:[], hideByDefault:[], contextArgs:[]};

// MouseOver handler, can walk the tree to find interesting elements and fire events on them?
  function mouseOverHandler(e) {
//  get the resolved (non-text node) target:
    var elTarget = YAHOO.util.Event.getTarget(e);
    var el = that.locateNode(elTarget);
    if ( ! el ) { return; }
    var aList = YAHOO.util.Dom.getElementsByClassName('spanWrap','span',el);
    for (var i in aList) {
      YAHOO.log('Found span '+aList[i].innerHTML,'debug','Core.TreeView');
    }
    var action;
    var class     = 'phedex-tnode-highlight';
    var class_alt = 'phedex-tnode-highlight-associated';
    if ( e.type == 'mouseover' ) {
      action = YAHOO.util.Dom.addClass;
    } else {
      action = YAHOO.util.Dom.removeClass;
    }
    var elList = that.locatePartnerFields(el);
    for (var i in elList )
    {
      action(elList[i],class_alt);
    }
    action(el,class);
  }
  function clickHandler(e) {
    var elTarget = YAHOO.util.Event.getTarget(e);
    var el = that.locateNode(elTarget);
    if ( !el ) { return; }
    var fieldClass = that.getPhedexFieldClass(el);
    YAHOO.log("el id/name "+el.id+"/"+el.nodeName+' class:'+el.className+' contents:'+el.innerHTML, 'debug', 'Core.TreeView');
  }

// Now a series of functions for manipulating an element based on its CSS classes. Use two namespaces, phedex-tnode-* which describes
// the tree structure, and phedex-tree-* which describe the data-contents.
  that.getPhedexFieldClass=function(el) {
    var treeMatch = /^phedex-tree-/;
//  find the phedex-tree-* classname of this element
    var elClasses = el.className.split(' ');
    for (var i in elClasses) {
      if ( elClasses[i].match(treeMatch) ) {
	return elClasses[i];
      }
    }
    return;
  }
  that.locatePartnerFields=function(el) {
//  for a header-field, find all displayed nodes of that type. For a value-field, find only the header node that matches
    var treeMatch = /^phedex-tree-/;
    var treeOther;
    var candList;
    var elList=[];
    if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-header')) { treeOther = 'phedex-tnode-field'; }
    else						  { treeOther = 'phedex-tnode-header'; }
    var elClasses = el.className.split(' ');
    for (var i in elClasses) {
      if ( elClasses[i].match(treeMatch) ) {
	candList = YAHOO.util.Dom.getElementsByClassName(elClasses[i], 'div', that.div);
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
//  phedex-tnode-field or phedex-tnode-header
    while (el.id != that.div.id) { // walk up only as far as the widget-div
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
        return el;
      }
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
        return el;
      }
      el = el.parentNode;
    }
  }
  that.locateHeader=function(el) {
//  find the phedex-tnode-header element for this element
    while (el.id != that.div.id) { // walk up only as far as the widget-div
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
        var elList = that.locatePartnerFields(el);
        return elList[0];
      }
      if(YAHOO.util.Dom.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
        return el;
      }
      el = el.parentNode;
    }
  }

  that.buildExtra=function(div) {
    that.headerTree = new YAHOO.widget.TreeView(div);
    YAHOO.util.Event.on(div, "mouseover", mouseOverHandler);
    YAHOO.util.Event.on(div, "mouseout",  mouseOverHandler);
  }
  that.buildTree=function(div) {
    that.tree = new YAHOO.widget.TreeView(div);
    var currentIconMode=0;
// turn dynamic loading on for entire tree?
    if ( that.isDynamic ) {
      that.tree.setDynamicLoad(PHEDEX.Util.loadTreeNodeData, currentIconMode);
    }
    YAHOO.util.Event.on(div, "mouseover", mouseOverHandler);
    YAHOO.util.Event.on(div, "mouseout",  mouseOverHandler);
  }
  that.addNode=function(spec,values,parent) {
    if ( !parent ) { parent = that.tree.getRoot(); }
    var isHeader = false;
    if ( !values ) { isHeader = true; }
    if ( values && (spec.format.length != values.length) )
    {
      throw new Error('PHEDEX.Core.TreeView: length of "values" array and "format" arrays differs ('+values.length+' != '+spec.format.length+'). Not good!');
    }
    if ( ! spec.className )
    {
      if ( isHeader ) { spec.className = 'phedex-tnode-header'; }
      else            { spec.className = 'phedex-tnode-field'; }
    }
    var el = PHEDEX.Util.makeNode(spec,values);
    var tNode = new YAHOO.widget.TextNode({label: el.innerHTML, expanded: false}, parent);
    that.textNodeMap[tNode.labelElId] = tNode;
    tNode.data.values = values;
    tNode.data.spec   = spec;
    if ( spec.payload ) { tNode.payload = spec.payload; }
    if ( isHeader ) {
      for (var i in spec.format) {
	var className = spec.format[i].className;
	var value;
	if ( values ) { value = values[i]; }
	else { value = spec.format[i].text; }
	if ( spec.prefix ) { value = spec.prefix+': '+value; }
	if ( that.structure.headerNames[className] ) {
	  YAHOO.log('duplicate entry for '+className+': "'+that.structure.headerNames[className]+'" and "'+value+'"','error','Core.TreeView');
	} else {
	  that.structure.headerNames[className] = value;
	  if ( spec.format[i].contextArgs )
	  {
	    that.structure.contextArgs[className]=[];
	    if ( typeof(spec.format[i].contextArgs) == 'string' ) {
	      that.structure.contextArgs[className].push(spec.format[i].contextArgs);
	    } else {
	      for (var j in spec.format[i].contextArgs) {
		that.structure.contextArgs[className].push(spec.format[i].contextArgs[j]);
	      }
	    }
	  }
	}
      }
    }
    for (var i in spec.format) {
      if ( spec.format[i].hideByDefault )
      {
	that.structure.hideByDefault[spec.format[i].className]=1;
      }
    }
    return tNode;
  }

// A split-button and menu for the show-all-fields function. Use a separate span for this so I can insert other stuff before it, easily, in the derived widgets.
  that.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
  var aSpan = document.createElement('span');
  that.span_param.appendChild(aSpan);
  that.showFields = new YAHOO.widget.Button(
    {
      type: "split",
      label: "Show all fields",
      name: 'showFields_'+PHEDEX.Util.Sequence(),
      menu: that.column_menu,
      container: aSpan,
      disabled:true
    }
  );
// event-handlers for driving the split button
  that.showFields.on("click", function () {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      YAHOO.util.Dom.getElementsByClassName(m[i].value,null,that.div,function(element) {
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
      YAHOO.util.Dom.getElementsByClassName(oMenuItem.value,null,that.div,function(element) {
	element.style.display = null;
      });
        m.removeItem(oMenuItem.index);
//         that.refreshButton();
      }
      that.refreshButton();
      that.resizePanel(that.tree);
    });
  });

// update the 'Show all columns' button state
  that.refreshButton = function() {
// debugger;
//     if ( that.column_menu.parent ) { // hack to prevent premature display? Probably better ways to do this...
      that.column_menu.render(document.body);
//     }
      that.showFields.set('disabled', that.column_menu.getItems().length === 0);
//     }
  };

// Context-menu handlers: onContextMenuBeforeShow allows to (re-)build the menu based on the element that is clicked.
  that.onContextMenuBeforeShow=function(p_sType, p_aArgs) {
    var oTarget = this.contextEventTarget,
      aMenuItems = [],
      aClasses;
    if (this.getRoot() != this) { return; } // Not sure what this means, but YUI use it in their examples!
    var tgt = that.locateNode(this.contextEventTarget);
    if ( ! tgt ) { return; }
    var isHeader;
    if      ( YAHOO.util.Dom.hasClass(tgt,'phedex-tnode-header') ) { isHeader = true; }
    else if ( YAHOO.util.Dom.hasClass(tgt,'phedex-tnode-field' ) ) { isHeader = false; }
    else    { return; }

//  Highlight the <tr> element in the table that was the target of the "contextmenu" event.
    YAHOO.util.Dom.addClass(tgt, "phedex-core-selected");
    var label = tgt.textContent;
    var payload = {};

//  Get the array of MenuItems for the CSS class name from the "oContextMenuItems" map.
    aClasses = tgt.className.split(" ");

    PHEDEX.Core.ContextMenu.Clear(this);
    var treeMatch = /^phedex-tree-/;
    for (var i in aClasses) {
      if ( aClasses[i].match(treeMatch) ) {
	YAHOO.log('found '+aClasses[i]+' to key new menu entries','info','Core.TreeView');
	if ( !isHeader && that.structure.contextArgs[aClasses[i]] ) {
	  for(var j in that.structure.contextArgs[aClasses[i]]) {
	    aMenuItems[aMenuItems.length] = that.structure.contextArgs[aClasses[i]][j];
	  }
	}
      }
    }
    if ( aMenuItems.length ) { PHEDEX.Core.ContextMenu.Build(this,aMenuItems); }
    PHEDEX.Core.ContextMenu.Build(this,that.contextMenuArgs);
    this.render();
  }

  that.onContextMenuHide= function(p_sType, p_aArgs) {
    var tgt = that.locateNode(this.contextEventTarget);
    if (this.getRoot() == this && tgt ) {
      YAHOO.util.Dom.removeClass(tgt, "phedex-core-selected");
    }
  }

// Create a context menu, with default entries for treeView widgets
  that.buildContextMenu=function() {
    that.contextMenuArgs=[];
    for (var i=0; i< arguments.length; i++ ) { that.contextMenuArgs[that.contextMenuArgs.length] = arguments[i]; }
    that.contextMenuArgs.push('treeView');
    that.contextMenu = PHEDEX.Core.ContextMenu.Create(that.contextMenuArgs[0],{trigger:that.div_content});
    that.contextMenu.subscribe("beforeShow", that.onContextMenuBeforeShow);
    that.contextMenu.subscribe("hide",       that.onContextMenuHide);
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
	this.payload[task.index](args, opts, {container:p_TreeView, node:oCurrentTextNode, target:oTarget, textNode:oTextNode, obj:that});
      }
    }
  }
  PHEDEX.Core.ContextMenu.Add('treeView','Hide This Field', function(args,opts,el) {
    var elPhedex = that.locateNode(el.target);
    var elClass = that.getPhedexFieldClass(elPhedex);
    that.hideFieldByClass(elClass);
  });
  that.hideFieldByClass=function(className) {
    YAHOO.log('hideFieldByClass: '+className,'info','Core.TreeView');
    YAHOO.util.Dom.getElementsByClassName(className,null,that.div,function(element) {
      element.style.display = 'none';
    });
    that.column_menu.addItem({text: that.structure.headerNames[className],value: className});
    that.refreshButton();
  }
  that.hideAllFieldsThatShouldBeHidden=function() {
    var m = that.column_menu.getItems();
    for (var i = 0; i < m.length; i++) {
      YAHOO.util.Dom.getElementsByClassName(m[i].value,null,that.div,function(element) {
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
    var ctl = new PHEDEX.Core.Control( {name:'Headers', type:'a', text:'Headers',
                    payload:{target:that.div_extra, fillFn:that.fillExtra, obj:that, animate:false, hover_timeout:200} } );
    YAHOO.util.Dom.insertBefore(ctl.el,that.span_control.firstChild);
  });
  that.resizeFields=function(el) {
    var tgt = that.locateHeader(el);
    var elList = that.locatePartnerFields(tgt);
    for (var i in elList ) { elList[i].style.width = tgt.style.width; }
  }
  that.addResizeHandles=function() {
    var elList = YAHOO.util.Dom.getElementsByClassName('phedex-tnode-header',null,that.div);
    for (var i in elList)
    {
      var el = elList[i];
      var elResize = new YAHOO.util.Resize(el,{ handles:['r'] }); // , draggable:true }); // draggable is cute if I can make it work properly!
      elResize.payload = el;
      elResize.subscribe('endResize',function(e) {
	var elTarget = YAHOO.util.Event.getTarget(e);
	var el = elTarget.payload
	that.resizeFields(el);
      });
    }
  }
  that.onDataFailed.subscribe(function() {
    if ( that.tree ) { that.tree.destroy(); that.tree = null; }
    that.div_content.innerHTML='Data-load error, try again later...';
    that.finishLoading();
  });

  that.onPopulateComplete.subscribe(function() {
    for (var className in that.structure.hideByDefault) { that.hideFieldByClass(className); }
    that.structure.hideByDefault = []; // don't want to do this every time the tree is populated, such as opening sub-trees!
    that.addResizeHandles();
  });

// Resize the panel when extra columns are shown, to accomodate the width
  that.resizePanel=function(tree) {
//   var w1 = that.div_body.clientWidth;
//   var el = that.tree._el;
// debugger;
//     var old_width = 1500; // tree.getContainerEl().clientWidth;
//     var x = 700;
//     if ( x >= old_width ) { that.panel.cfg.setProperty('width',x+'px'); }
  }
  return that;
}

// Sort tree-branches!
PHEDEX.Core.Widget.TreeView.sort=function(args,opts,el,sortFn) {
    var textNode  = el.textNode;
    var container = el.tree;
    var node      = el.node;
    var target    = el.target;
    var obj       = el.obj;

// find which value-index corresponds to my class, so I know which field to sort on
    target = obj.locateNode(target);
    var thisClass = obj.getPhedexFieldClass(target);
    var index;
    for (var i in node.data.spec.format) {
      var f = node.data.spec.format[i];
      if ( f.className == thisClass ) { index = i; break; }
    }
    if ( !index ) {
      YAHOO.log('cannot identify class-type','error','Core.TreeView');
      return;
    }

    var parent = node.parent;
    var map = [];
    map.push( {node:node, value:node.data.values[index]} );
// this retrieves the other branches at the same level, but then what...?
    var siblings = node.getSiblings();
    for (var i in siblings) {
      map.push( {node:siblings[i], value:siblings[i].data.values[index]} );
    }
    map.sort(function(a,b){ return sortFn(a.value,b.value); });
    for (var i in map) {
      parent.children[i] = map[i].node;
    }
    obj.tree.render();
    obj.hideAllFieldsThatShouldBeHidden();
debugger;
// this doesn't work, because locateHeader wants an element, not a classname...
    for (var i in node.data.spec.format) {
      var header = obj.locateHeader(node.data.spec.format[i].className);
      obj.resizeFields(header);
    }
  }

PHEDEX.Core.ContextMenu.Add('sort-files','Sort Files Ascending', function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.files.asc ); });
PHEDEX.Core.ContextMenu.Add('sort-files','Sort Files Descending',function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.files.desc); });
PHEDEX.Core.ContextMenu.Add('sort-bytes','Sort Bytes Ascending', function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.bytes.asc ); });
PHEDEX.Core.ContextMenu.Add('sort-bytes','Sort Bytes Descending',function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.bytes.desc); });
PHEDEX.Core.ContextMenu.Add('sort-alpha','Sort Ascending',       function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.alpha.asc ); });
PHEDEX.Core.ContextMenu.Add('sort-alpha','Sort Descending',      function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.alpha.desc); });
PHEDEX.Core.ContextMenu.Add('sort-num',  'Sort Ascending',       function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.numeric.asc ); });
PHEDEX.Core.ContextMenu.Add('sort-num',  'Sort Descending',      function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,PHEDEX.Util.Sort.numeric.desc); });
PHEDEX.Core.ContextMenu.Add('treeView','Move branch to top',     function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,function() { return 0; } ); });
PHEDEX.Core.ContextMenu.Add('treeView','Move branch to bottom',  function(args,opts,el) { PHEDEX.Core.Widget.TreeView.sort(args,opts,el,function() { return 1; } ); });
YAHOO.log('loaded...','info','Core.TreeView');