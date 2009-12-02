/**
 * This is the base class for all PhEDEx treeview-related modules. It extends PHEDEX.Module to provide the functionality needed for modules that use a YAHOO.Widget.TreeView.
 * @namespace PHEDEX
 * @class TreeView
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.TreeView = function(sandbox,string) {
  YAHOO.lang.augmentObject(this,new PHEDEX.Module(sandbox,string));
  var _me  = 'TreeView',
      _sbx = sandbox;

/**
 * An object containing metadata that describes the treeview internals. Used as a convenience to keep from polluting the namespace too much with public variables that the end-module does not need.
 * @property _cfg
 * @type object
 * @private
 */
/**
 * An array mapping DOM element-iDs to treeview-branches, for use in mouse-over handlers etc
 * @property _cfg.textNodeMap
 * @type array
 * @private
 */
      _cfg = { textNodeMap:[], headerNames:{}, hideByDefault:[], contextArgs:[], sortFields:{} };

  /**
   * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
   * @method _construct
   * @private
   */
  _construct = function() {
    return {
/**
 * Used in PHEDEX.Module and elsewhere to derive the type of certain decorator-style objects, such as mouseover handlers etc. These can be different for TreeView and DataTable objects, so will be picked up as PHEDEX.[this.type].function(), or similar.
 * @property type
 * @default TreeView
 * @type string
 * @private
 * @final
 */
      type: 'TreeView',

// Now a series of functions for manipulating an element based on its CSS classes. Use two namespaces, phedex-tnode-* which describes
// the tree structure, and phedex-tree-* which describe the data-contents.
      getPhedexFieldClass: function(el) {
//      find the phedex-tree-* classname of this element
        var treeMatch = /^phedex-tree-/,
            elClasses = el.className.split(' ');
        for (var i in elClasses) {
          if ( elClasses[i].match(treeMatch) ) {
            return elClasses[i];
          }
        }
        return;
      },

      locatePartnerFields: function(el) {
//      for a tnode-header, find all tnode-fields of that type. For a tnode-field, find only the tnode-header that matches
//      assumes that the element it is given is already either a tnode-header or a tnode-field, use locateNode to ensure that
//      before calling this function
        var treeMatch = /^phedex-tree-/,
            treeOther,
            candList,
            elList=[],
            elClasses;
        if(YuD.hasClass(el,'phedex-tnode-header')) { treeOther = 'phedex-tnode-field'; }
        else                                       { treeOther = 'phedex-tnode-header'; }
        elClasses = el.className.split(' ');
        for (var i in elClasses) {
          if ( elClasses[i].match(treeMatch) ) {
            candList = YuD.getElementsByClassName(elClasses[i], 'div', this.el);
          }
        }
        for (var i in candList )
        {
          if ( YuD.hasClass(candList[i],treeOther) )
          {
            elList.push(candList[i]);
          }
        }
        return elList;
      },

      locateNode: function(el) {
//      find the nearest ancestor that has a phedex-tnode-* class applied to it, either
//      phedex-tnode-field or phedex-tnode-header
        while (el.id != this.el.id) { // walk up only as far as the widget-div
          if(YuD.hasClass(el,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
            return el;
          }
          if(YuD.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
            return el;
          }
          el = el.parentNode;
        }
      },

      locateHeader: function(el) {
//      find the phedex-tnode-header element for this element
        while (el.id != this.el.id) { // walk up only as far as the widget-div
          if(YuD.hasClass(el,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
            var elList = this.locatePartnerFields(el);
            return elList[0];
          }
          if(YuD.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
            return el;
          }
          el = el.parentNode;
        }
      },

/** create the treeview structures for the headers, create the empty tree for the contents (waiting for data), and initialise dynamic loading for the tree, if required. Driven mostly by the <strong>meta</strong> field.
 * @method initDerived
 */
      initDerived: function() {
        this.tree = new YAHOO.widget.TreeView(this.dom.content);
        this.headerTree = new YAHOO.widget.TreeView(this.dom.extra);
        var currentIconMode=0;
//      turn dynamic loading on for entire tree?
        if ( this.meta.isDynamic ) {
          this.tree.setDynamicLoad(PxU.loadTreeNodeData, currentIconMode);
        }
        var root = this.headerTree.getRoot(),
            t = this.meta.tree,
            htNode;
        for (var i in t)
        {
          htNode = this.addNode( t[i], null, root );
          htNode.expand();
          root = htNode;
        }
        htNode.isLeaf = true;
        this.headerTree.render();
        _sbx.notify(this.id,'initDerived');
      },

      addNode: function(spec,values,parent) {
        if ( !parent ) { parent = this.tree.getRoot(); }
        var isHeader = false;
        if ( !values ) { isHeader = true; }
        if ( values && (spec.format.length != values.length) )
        {
          throw new Error('PHEDEX.TreeView: length of "values" array and "format" arrays differs ('+values.length+' != '+spec.format.length+'). Not good!');
        }
        if ( ! spec.className )
        {
          if ( isHeader ) { spec.className = 'phedex-tnode-header'; }
          else            { spec.className = 'phedex-tnode-field'; }
        }
        var el = PxU.makeNode(spec,values);
        var tNode = new YAHOO.widget.TextNode({label: el.innerHTML, expanded: false}, parent);
        _cfg.textNodeMap[tNode.labelElId] = tNode;
        tNode.data.values = values;
        tNode.data.spec   = spec;
        if ( spec.payload ) { tNode.payload = spec.payload; }
        if ( isHeader ) {
          for (var i in spec.format) {
            var className = spec.format[i].className;
            var value;
            if ( values ) { value = values[i]; }
            else { value = spec.format[i].text; }
            if ( spec.name ) { value = spec.name+': '+value; }
            if ( _cfg.headerNames[className] ) {
              log('duplicate entry for '+className+': "'+_cfg.headerNames[className].value+'" and "'+value+'"','error','Core.TreeView');
            } else {
              _cfg.headerNames[className] = {value:value, group:spec.name};
              _cfg.sortFields[spec.name] = {};
              if ( spec.format[i].contextArgs )
              {
                _cfg.contextArgs[className]=[];
                if ( typeof(spec.format[i].contextArgs) == 'string' ) {
                  _cfg.contextArgs[className].push(spec.format[i].contextArgs);
                } else {
                  for (var j in spec.format[i].contextArgs) {
                    _cfg.contextArgs[className].push(spec.format[i].contextArgs[j]);
                  }
                }
              }
            }
          }
        }
        for (var i in spec.format) {
          if ( spec.format[i].hideByDefault )
          {
            _cfg.hideByDefault[spec.format[i].className]=1;
          }
        }
        return tNode;
      },

// // A split-button and menu for the show-all-fields function. Use a separate span for this so I can insert other stuff before it, easily, in the derived widgets.
//   that.column_menu = new YAHOO.widget.Menu('menu_'+PHEDEX.Util.Sequence());
//   var aSpan = document.createElement('span');
//   that.dom.param.appendChild(aSpan);
//   that.showFields = new YAHOO.widget.Button(
//     {
//       type: "split",
//       label: "Show all fields",
//       name: 'showFields_'+PHEDEX.Util.Sequence(),
//       menu: that.column_menu,
//       container: aSpan,
//       disabled:true
//     }
//   );
// // event-handlers for driving the split button
//   that.showFields.on("click", function () {
//     var m = that.column_menu.getItems();
//     for (var i = 0; i < m.length; i++) {
//       YuD.getElementsByClassName(m[i].value,null,that.div,function(element) {
// 	element.style.display = null;
//       });
//     }
//     that.column_menu.clearContent();
//     that.refreshButton();
//     that.resizePanel(that.tree);
//   });
//   that.showFields.on("appendTo", function () {
//     var m = this.getMenu();
//     m.subscribe("click", function onMenuClick(sType, oArgs) {
//       var oMenuItem = oArgs[1];
//       if (oMenuItem) {
// 	YuD.getElementsByClassName(oMenuItem.value,null,that.div,function(element) {
// 	  element.style.display = null;
// 	});
//         m.removeItem(oMenuItem.index);
//       }
//       that.refreshButton();
//       that.resizePanel(that.tree);
//     });
//   });
// 
// // update the 'Show all columns' button state
//   that.refreshButton = function() {
//     try {
//       that.column_menu.render(document.body);
//       that.showFields.set('disabled', that.column_menu.getItems().length === 0);
//     } catch(e) {};
//   };
// 
// // Context-menu handlers: onContextMenuBeforeShow allows to (re-)build the menu based on the element that is clicked.
//   that.onContextMenuBeforeShow=function(p_sType, p_aArgs) {
//     var oTarget = this.contextEventTarget,
//       aMenuItems = [],
//       aClasses;
//     if (this.getRoot() != this) { return; } // Not sure what this means, but YUI use it in their examples!
//     var tgt = that.locateNode(this.contextEventTarget);
//     if ( ! tgt ) { return; }
//     var isHeader;
//     if      ( YuD.hasClass(tgt,'phedex-tnode-header') ) { isHeader = true; }
//     else if ( YuD.hasClass(tgt,'phedex-tnode-field' ) ) { isHeader = false; }
//     else    { return; }
// 
// //  Get the array of MenuItems for the CSS class name from the "oContextMenuItems" map.
//     aClasses = tgt.className.split(" ");
// 
// //  Highlight the <tr> element in the table that was the target of the "contextmenu" event.
//     YuD.addClass(tgt, "phedex-core-selected");
//     var label = tgt.textContent;
//     var payload = {};
// 
//     PHEDEX.Core.ContextMenu.Clear(this);
//     var treeMatch = /^phedex-tree-/;
//     for (var i in aClasses) {
//       if ( aClasses[i].match(treeMatch) ) {
// 	log('found '+aClasses[i]+' to key new menu entries','info','Core.TreeView');
// 	if ( !isHeader && that._cfg.contextArgs[aClasses[i]] ) {
// 	  for(var j in that._cfg.contextArgs[aClasses[i]]) {
// 	    aMenuItems[aMenuItems.length] = that._cfg.contextArgs[aClasses[i]][j];
// 	  }
// 	}
//       }
//     }
//     if ( aMenuItems.length ) { PHEDEX.Core.ContextMenu.Build(this,aMenuItems); }
//     PHEDEX.Core.ContextMenu.Build(this,that.contextMenuArgs);
//     this.render();
//   }
// 
//   that.onContextMenuHide= function(p_sType, p_aArgs) {
//     var tgt = that.locateNode(this.contextEventTarget);
//     if (this.getRoot() == this && tgt ) {
//       YuD.removeClass(tgt, "phedex-core-selected");
//     }
//   }
// 
// // Create a context menu, with default entries for treeView widgets
//   that.buildContextMenu=function(typeMap) {
//     that.contextMenuArgs=[];
//     that.contextMenuArgs.push('treeView');
//     that.contextMenu = PHEDEX.Core.ContextMenu.Create({trigger:that.dom.content});
//     that.contextMenu.subscribe("beforeShow", that.onContextMenuBeforeShow);
//     that.contextMenu.subscribe("hide",       that.onContextMenuHide);
//   }
// 
//   that.onContextMenuClick = function(p_sType, p_aArgs, p_TreeView) {
// //  Based on http://developer.yahoo.com/yui/examples/menu/treeviewcontextmenu.html
//     log('ContextMenuClick for '+that.me(),'info','Core.TreeView');
//     var oTarget = this.contextEventTarget,
// 	oCurrentTextNode;
//     var oTextNode = YuD.hasClass(oTarget, "ygtvlabel") ?
// 	oTarget : YuD.getAncestorByClassName(oTarget, "ygtvlabel");
// 
//     if (oTextNode) {
//       oCurrentTextNode = that.textNodeMap[oTextNode.id];
//     }
//     else {
//       this.cancel();
//       return;
//     }
//     if ( oCurrentTextNode )
//     {
//       var label = p_aArgs[0].explicitOriginalTarget.textContent;
//       var task = p_aArgs[1];
//       var args = {}, opts = {};
//       if ( oCurrentTextNode.payload )	{
// 	args = oCurrentTextNode.payload.args;
// 	opts = oCurrentTextNode.payload.opts;
//       }
//       log('ContextMenu: '+'"'+label+'" for '+that.me()+' ('+opts.selected_node+')','info','Core.TreeView');
//       if (task) {
//         this.activeItem.value.fn(opts, {container:p_TreeView, node:oCurrentTextNode, target:oTarget, textNode:oTextNode, obj:that});
//       }
//     }
//   }
//   PHEDEX.Core.ContextMenu.Add('treeView','Hide This Field', function(opts,el) {
//     var elPhedex = that.locateNode(el.target);
//     var elClass = that.getPhedexFieldClass(elPhedex);
//     that.hideFieldByClass(elClass);
//   });

      hideFieldByClass: function(className) {
debugger;
        log('hideFieldByClass: '+className,'info','Core.TreeView');
        YuD.getElementsByClassName(className,null,this.el,function(element) {
          element.style.display = 'none';
        });
        this.column_menu.addItem({text: this._cfg.headerNames[className].value,value: className});
        this.refreshButton();
      },
      hideAllFieldsThatShouldBeHidden: function() {
debugger;
        var m = this.column_menu.getItems();
        for (var i = 0; i < m.length; i++) {
          YuD.getElementsByClassName(m[i].value,null,this.el,function(element) {
            element.style.display = 'none';
          });
        }
      },
    };
  };
  YAHOO.lang.augmentObject(this,_construct(),true);
  return this;
}

//   that.onPopulateComplete.subscribe( that.hideAllFieldsThatShouldBeHidden );

//   that.onUpdateBegin.subscribe(function() {
//     var node;
//     while ( node = that.tree.root.children[0] ) { that.tree.removeNode(node); }
//     that.tree.render();
//   });

// // This is a bit contorted. I provide a call to create a context menu, adding the default 'dataTable' options to it. But I leave
// // it to the client widget to call this function, just before calling build(), so the object is fairly complete. This is because
// // I need much of the object intact to do it right. I also leave the subscription and rendering of the menu till the build() is
// // complete. This allows me to ignore the menu completely if the user didn't build one.
// // If I didn't do it like this then the user would have to pass the options in to the constructor, and would then have to take
// // care that the object was assembled in exactly the right way. That would then make things a bit more complex...
//   that.onBuildComplete.subscribe(function() {
//     log('onBuildComplete: '+that.me(),'info','Core.TreeView');
//     if ( that.contextMenu )
//     {
//       log('subscribing context menu: '+that.me(),'info','Core.TreeView');
//       that.contextMenu.clickEvent.subscribe(that.onContextMenuClick, that.tree.getEl());
//       that.contextMenu.render(document.body);
//     }
//     that.tree.subscribe('expandComplete',function(node) {
//       if ( node.children ) { that.sort(node.children[0]); }
//       that.hideAllFieldsThatShouldBeHidden();
//       that.applyFilter();
//     });
//     that.ctl.extra.el.innerHTML = 'Headers';
//   });
// 
//   that.resizeFields=function(el) {
//     var tgt = that.locateHeader(el);
//     var elList = that.locatePartnerFields(tgt);
//     for (var i in elList ) { elList[i].style.width = tgt.style.width; }
//   }
//   var populateCompleteHandler=function() {
//     var elList = YuD.getElementsByClassName('phedex-tnode-header',null,that.div);
//     for (var i in elList)
//     {
//       var el = elList[i];
//       var elResize = new YAHOO.util.Resize(el,{ handles:['r'] }); // , draggable:true }); // draggable is cute if I can make it work properly!
//       elResize.payload = el;
//       elResize.subscribe('endResize',function(e) {
// 	var elTarget = YuE.getTarget(e);
// 	var el = elTarget.payload
// 	that.resizeFields(el);
//       });
//     }
//     for (var className in that._cfg.hideByDefault) { that.hideFieldByClass(className); }
// //  All this only needed doing once, so unsubscribe myself now!
//     that.onPopulateComplete.unsubscribe(populateCompleteHandler);
//   }
//   that.onPopulateComplete.subscribe(populateCompleteHandler);
// 
//   that.onDataFailed.subscribe(function() {
//     if ( that.tree ) { that.tree.destroy(); that.tree = null; }
//     that.dom.content.innerHTML='Data-load error, try again later...';
//     that.finishLoading();
//   });
// 
// // Resize the panel when extra columns are shown, to accomodate the width
//   that.resizePanel=function(tree) {  }
// 
//   that.sort=function(node,thisClass,sortFn) {
// //  node is a tree-node that needs to be sorted, along with its siblings.
// //  thisClass is the class to use as the sort-key. If not given, look to see if a default is already set for this group
// //  sortFn is the actual sorting function, either passed or taken from set defaults
// 
//     var s = that._cfg.sortFields;
//     var sNode;
// //  find which value-index corresponds to my class, so I know which field to sort on
//     if ( !thisClass ) {
//       sNode = s[node.data.spec.name];
//       if ( sNode ) { thisClass = sNode.className; }
//       if ( !thisClass ) { return; } // nothing to sort...
//       sortFn = sNode.func;
//     }
//     that.showBusy();
//     var index;
//     for (var i in node.data.spec.format) {
//       var f = node.data.spec.format[i];
//       if ( f.className == thisClass ) { index = i; break; }
//     }
//     if ( !index ) {
//       log('cannot identify class-type','error','Core.TreeView');
//       return;
//     }
//     sNode = s[that._cfg.headerNames[thisClass].group];
//     sNode.className = thisClass;
//     sNode.func  = sortFn;
//     var parent = node.parent;
//     var children = parent.children;
//     var map = [], indices=[];
//     for (var i in children)
//     {
//       var elList = YuD.getElementsByClassName(thisClass,null,children[i].getEl());
//       if ( elList.length ) {
//         map.push( {node:children[i], value:children[i].data.values[index]} );
//         indices.push( i );
//       }
//     }
//     map.sort(function(a,b){ return sortFn(a.value,b.value); });
//     for (var i in map) {
//       parent.children[indices[i]] = map[i].node;
//     }
// 
//     that.tree.render();
//     that.hideAllFieldsThatShouldBeHidden();
//     for (var i in node.data.spec.format) {
//       var className = node.data.spec.format[i].className;
//       var container = node.getEl();
//       var tgt = YuD.getElementsByClassName(node.data.spec.format[i].className,null,node.getEl());
//       var header = that.locateHeader(tgt[0]);
//       that.resizeFields(header);
//     }
//     that.showNotBusy();
//   }
// 
//   that.filter.onFilterCancelled.subscribe( function(obj) {
//     return function() {
//       log('onWidgetFilterCancelled:'+obj.me(),'info','Core.TreeView');
//       YuD.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.revealAllBranches();
//       obj.filter.Reset();
//       obj.ctl.filter.Hide();
//       PHEDEX.Event.onWidgetFilterCancelled.fire(obj.filter);
//     }
//   }(that));
//   PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
//     return function() {
//       log('onGlobalFilterCancelled:'+obj.me(),'info','Core.TreeView');
//       YuD.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.revealAllBranches();
//       obj.filter.Reset();
//     }
//   }(that));
// 
// // This uses a closure to capture the 'this' we are dealing with and then subscribe it to the onFilterCancel event.
// // Note the pattern: Event.subscribe( function(obj) { return function() { obj.whatever(); ...; } }(this) );
//   that.revealAllBranches=function() {
//     that.filter.revealAllElements('ygtvrow');
//   }
// 
//   that.filter.onFilterApplied.subscribe(function(obj) {
//     return function(ev,arr) {
//       obj.applyFilter(arr[0]);
//       obj.ctl.filter.Hide();
//     }
//   }(that));
// 
//   PHEDEX.Event.onGlobalFilterValidated.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       if ( ! obj.filter.args ) { obj.filter.args = []; }
//       for (var i in args) {
// 	obj.filter.args[i] = args[i];
//       }
//       obj.applyFilter(arr[0]);
//     }
//   }(that));
// 
//   that.applyFilter=function(args) {
// //  First, reveal any filtered branches, in case the filter has changed (as opposed to being created)
//     that.revealAllBranches();
//     var elParents={};
//     if ( ! args ) { args = that.filter.args; }
//     for (var key in args) {
//       if ( typeof(args[key].value) == 'undefined' ) { continue; }
//       var fValue = args[key].value;
//       var negate = args[key].negate;
//       for (var elId in that.textNodeMap) {
// 	var tNode = that.textNodeMap[elId];
// 	if ( tNode.data.spec.className == 'phedex-tnode-header' ) { continue; }
// 	for (var i in tNode.data.spec.format) {
// 	  var className = tNode.data.spec.format[i].className;
// 	  if ( className != key ) { continue; }
// 	  var kValue = tNode.data.values[i];
// 	  if ( args[key].preprocess ) { kValue = args[key].preprocess(kValue); }
// 	  var status = that.filter.Apply[this.filter.fields[key].type](fValue,kValue);
// 	  if ( args[key].negate ) { status = !status; }
// 	  if ( !status ) { // Keep the element if the match succeeded!
// 	    tNode.collapse();
// 	    var elAncestor = YuD.getAncestorByClassName(elId,'ygtvrow');
// 	    YuD.addClass(elAncestor,'phedex-invisible');
// 	    that.filter.count++;
// 	    if ( tNode.parent ) {
// 	      elParents[tNode.parent.labelElId] = 1;
// 	    }
// 	  }
// 	  break;
// 	}
//       }
//     }
//     for (var elParent in elParents) {
//       var ancestor = YuD.getAncestorByClassName(elParent,'ygtvrow');
//       YuD.addClass(ancestor,'phedex-core-control-widget-applied');
//     }
//     return this.filter.count;
//   }
//   return that;
// }

// PHEDEX.TreeView.prepareSort=function(el,sortFn) {
// // simply unpack the interesting bits and feed it to the object
//   var node      = el.node;
//   var obj       = el.obj;
//   var target    = obj.locateNode(el.target);
//   var thisClass = obj.getPhedexFieldClass(target);
//   obj.sort(node,thisClass,sortFn);
//   obj.applyFilter();
// }
// PHEDEX.Core.ContextMenu.Add('sort-files','Sort Files Ascending', function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.files.asc ); });
// PHEDEX.Core.ContextMenu.Add('sort-files','Sort Files Descending',function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.files.desc); });
// PHEDEX.Core.ContextMenu.Add('sort-bytes','Sort Bytes Ascending', function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.bytes.asc ); });
// PHEDEX.Core.ContextMenu.Add('sort-bytes','Sort Bytes Descending',function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.bytes.desc); });
// PHEDEX.Core.ContextMenu.Add('sort-alpha','Sort Ascending',       function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.alpha.asc ); });
// PHEDEX.Core.ContextMenu.Add('sort-alpha','Sort Descending',      function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.alpha.desc); });
// PHEDEX.Core.ContextMenu.Add('sort-num',  'Sort Ascending',       function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.numeric.asc ); });
// PHEDEX.Core.ContextMenu.Add('sort-num',  'Sort Descending',      function(opts,el) { PHEDEX.Core.Widget.TreeView.prepareSort(el,PHEDEX.Util.Sort.numeric.desc); });

/** This class is invoked by PHEDEX.Module to create the correct handler for datatable mouse-over events.
 * @namespace PHEDEX.DataTable
 * @class MouseOver
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object (unused)
 * @param args {object} reference to an object that specifies details of how the control should operate. Only <strong>args.payload.obj.dataTable</strong> is used, to subscribe to the <strong>onRowMouseOver</strong> and >strong>onRowMouseOut</strong> events.
 */
PHEDEX.TreeView.MouseOver = function(sandbox,args) {
  var obj = args.payload.obj;
  function mouseOverHandler(e) {
//  get the resolved (non-text node) target:
    var elTarget = YuE.getTarget(e);
    var el = obj.locateNode(elTarget);
    if ( ! el ) { return; }
    var aList = YuD.getElementsByClassName('spanWrap','span',el);
    for (var i in aList) {
      log('Found span '+aList[i].innerHTML,'debug','Core.TreeView');
    }
    var action;
    var className = 'phedex-tnode-highlight';
    var class_alt  = 'phedex-tnode-highlight-associated';
    if ( e.type == 'mouseover' ) {
      action = YuD.addClass;
    } else {
      action = YuD.removeClass;
    }
    var elList = obj.locatePartnerFields(el);
    for (var i in elList )
    {
      action(elList[i],class_alt);
    }
    action(el,className);
  }
//   function clickHandler(e) {
//     var elTarget = YuE.getTarget(e);
//     var el = obj.locateNode(elTarget);
//     if ( !el ) { return; }
//     var fieldClass = that.getPhedexFieldClass(el);
//     log("el id/name "+el.id+"/"+el.nodeName+' class:'+el.className+' contents:'+el.innerHTML, 'debug', 'Core.TreeView');
//   }
  YuE.on(obj.dom.content, "mouseover", mouseOverHandler);
  YuE.on(obj.dom.content, "mouseout",  mouseOverHandler);
  YuE.on(obj.dom.extra,   "mouseover", mouseOverHandler);
  YuE.on(obj.dom.extra,   "mouseout",  mouseOverHandler);
}

log('loaded...','info','TreeView');
