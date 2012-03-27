/**
 * This is the base class for all PhEDEx treeview-related modules. It extends PHEDEX.Module to provide the functionality needed for modules that use a YAHOO.Widget.TreeView.
 * @namespace PHEDEX
 * @class TreeView
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.TreeView = function(sandbox,string) {
  Yla(this,new PHEDEX.Module(sandbox,string));
  var _me  = 'treeview',
      _sbx = sandbox;

  /**
   * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
   * @method _construct
   * @private
   */
  _construct = function() {
    return {

/**
 * An object containing metadata that describes the treeview internals. Used as a convenience to keep from polluting the namespace too much with public variables that the end-module does not need. This is essentially re-hashed data from the 'meta' construct used to describe the tree. Keeping this data here distinguishes it from the 'meta' in the debugger, and emphasises that it is not needed for the description of the tree, only to make it work in the application.
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
      _cfg: { textNodeMap:[], headerNodeMap:[], sortFields:{}, formats:{}, hiddenBranches:{} },
/**
 * An object for caching DOM<->JSON mappings for faster lookup
 * @property _cache
 * @type array
 * @private
 */
      _cache:{ node:{}, partners:{} },

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
            className,
            elList=[],
            elClasses;
        if(YuD.hasClass(el,'phedex-tnode-header')) { treeOther = 'phedex-tnode-field'; }
        else                                       { treeOther = 'phedex-tnode-header'; }
        elClasses = el.className.split(' ');
        for (var i in elClasses) {
          if ( elClasses[i].match(treeMatch) ) {
            className = elClasses[i];
            if ( !this._cache.partners[className] ) {
              this._cache.partners[className] = {};
            }
            if ( this._cache.partners[className][treeOther] ) {
              return this._cache.partners[className][treeOther];
            }
            candList = YuD.getElementsByClassName(className, 'div', this.el);
            break;
          }
        }
        for (var i in candList )
        {
          if ( YuD.hasClass(candList[i],treeOther) )
          {
            elList.push(candList[i]);
          }
        }
        this._cache.partners[className][treeOther] = elList;
        return elList;
      },

      locateNode: function(el) {
//      find the nearest ancestor that has a phedex-tnode-* class applied to it, either phedex-tnode-field or phedex-tnode-header
//      Explicitly do this as two separate loops as an optimisation. Most of the time I expect to be looking at a value-node, in the data,
//      so search the headers only as a second step. Cache the result to speed things up should we be asked again for the same lookup
        if ( !el.id ) { el.id = 'px-gen-'+PxU.Sequence(); }
        if ( this._cache.node[el.id] ) {
          return this._cache.node[el.id];
        }
        var el1 = el; // preserve the original el in case it's a header
        while (el1.id != this.el.id) { // walk up only as far as the widget-div
          if(YuD.hasClass(el1,'phedex-tnode-field')) { // phedex-tnode fields hold the values.
            this._cache.node[el.id] = el1;
            return el1;
          }
          el1 = el1.parentNode;
        }
        el1 = el;
        while (el.id != this.el.id) { // walk up only as far as the widget-div
          if(YuD.hasClass(el,'phedex-tnode-header')) { // phedex-tnode headers hold the value-names.
            this._cache.node[el1.id] = el;
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

      locateBranch: function(el) {
//      find the tree-branch that this DOM node is in
        var tgt;// = YuD.hasClass(el, "ygtvlabel") ? el : YuD.getAncestorByClassName(el, "ygtvlabel");
        if ( !tgt ) { tgt = YuD.hasClass(el, "ygtvcontent") ? el : YuD.getAncestorByClassName(el, "ygtvcontent"); }
        if ( tgt ) {
          return this._cfg.textNodeMap[tgt.id];
        }
      },

/** create the treeview structures for the headers, create the empty tree for the contents (waiting for data), and initialise dynamic loading for the tree, if required. Driven mostly by the <strong>meta</strong> field.
 * @method initDerived
 */
      initDerived: function() {
        this.tree       = new Yw.TreeView(this.dom.content);
        this.headerTree = new Yw.TreeView(this.dom.extra);
        var root = this.headerTree.getRoot(),
            t = this.meta.tree,
            htNode, i, moduleHandler;

//      render all data, not just the visible branches
// TODO this doesn't seem to work...?
        this.tree.renderHidden = true;

//      turn dynamic loading on for entire tree?
        if ( this.meta.isDynamic ) {
          this.tree.setDynamicLoad(this.loadTreeNodeData, 0);
        }
        for (i in t)
        {
          htNode = this.addNode( t[i], null, root );
          htNode.expand();
          root = htNode;
        }
        htNode.isLeaf = true;

        this.tree.subscribe('expandComplete', function(obj) {
          return function(node) {
            if ( !obj.isDynamic ) { obj.postGotData(); }
          }
        }(this));
        this.headerTree.render();

        this.decorators.push( { name:'Refresh', source:'component-refresh' });
        this.decorators.push(
          {
            name:'Filter',
            source:'component-filter',
            payload:{
              control: {
                parent: 'control',
                payload:{
                  disabled: false,
                  hidden:   true
                },
                el: 'content'
              }
            },
            target:  'filter'
          });
        this.decorators.push({ name:'Sort' });
        this.decorators.push({ name:'Resize' });
        this.allowNotify['markOverflows'] = 1;

        moduleHandler = function(o) {
          return function(ev,arr) {
            var action = arr[0];
            switch ( action ) {
              case 'gotData': {
                o.postGotData();
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,moduleHandler);
      },

      postGotData: function(step,node) {
        this._cache.partners = {};
        var i, steps = ['doSort', 'doFilter', 'hideFields', 'markOverflows'];
        for (i in steps) { _sbx.notify(this.id,steps[i]); }
      },

      // build a tree-node. Takes a Specification-object and a Value-object. Specification and Value are
      // nominally identical, except values in the Value object can override the Specification object.
      // This lets us create a template Specification and use it in several places (header, body) with
      // different Values.
      makeNode: function(spec,val) {
        if ( !val ) { val = {}; }
        var wtot = spec.width || 0,
            list = document.createElement('ul'),
            div = document.createElement('div'),
            sf = spec.format,
            f, i, n, w_el, w, d1, v, c, oc, li;
        list.className = 'inline_list';
        if ( wtot )
        {
          div.style.width = wtot+'px'; // TODO does this matter...?
          n = sf.length;
          for (i in sf)
          {
            if ( typeof(sf[i]) == 'object' )
            {
              w_el = parseInt(sf[i].width);
              if ( w_el ) { wtot -= w_el; n--; }
            }
          }
        }
        w = Math.round(wtot/n);
        if ( w < 0 ) { w=0; }
        for (i in sf)
        {
          f = sf[i];
          d1 = document.createElement('div');
          if ( val.length > 0 )
          {
            v = val[i];
            if ( f.format ) { v = f.format(val[i]); }
            d1.innerHTML = v;
          } else {
            d1.innerHTML = sf[i].text;
          }
          w_el = parseInt(f.width);
          if ( w_el ) {
            d1.style.width = w_el+'px';
          } else {
            if ( w ) { d1.style.width = w+'px'; }
          }
          if ( spec.className ) { d1.className = spec.className; }
          if ( f.className ) {
            YuD.addClass(d1,f.className);
          }
          if ( f.otherClasses ) {
            oc = f.otherClasses.split(' ');
            for (c in oc) { YuD.addClass(d1,oc[c]); }
          }
          if ( f.hide ) {
            YuD.addClass(d1,'phedex-invisible');
          }
          li = document.createElement('li');
          li.appendChild(d1);
          list.appendChild(li);
        }
        div.appendChild(list);
        return div;
      },

      getContentHtml: function() { // Override for YAHOO.widget.TextNode.getContentHtml in YUI 2.9.0, because of the escaping
        var Lang = YAHOO.lang, sb = [];
        sb[sb.length] = this.href ? '<a' : '<span';
        sb[sb.length] = ' id="' + Lang.escapeHTML(this.labelElId) + '"';
        sb[sb.length] = ' class="' + Lang.escapeHTML(this.labelStyle)  + '"';
        if (this.href) {
            sb[sb.length] = ' href="' + Lang.escapeHTML(this.href) + '"';
            sb[sb.length] = ' target="' + Lang.escapeHTML(this.target) + '"';
        }
        if (this.title) {
            sb[sb.length] = ' title="' + Lang.escapeHTML(this.title) + '"';
        }
        sb[sb.length] = ' >';
        sb[sb.length] = this.label; // Lang.escapeHTML(this.label); // this is what I changed
        sb[sb.length] = this.href?'</a>':'</span>';
        return sb.join("");
      },

      addNode: function(spec,values,parent) {
        if ( !parent ) { parent = this.tree.getRoot(); }
        var isHeader = false,
            el, tNode, i, f, className, value;
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

//      If I'm building the header-nodes, do some metadata management at this point.
        if ( isHeader ) {
          for (i in spec.format) {
            f = spec.format[i];
            if ( f.spanWrap ) {
              f.format = PxUf.spanWrap;
              if ( !f.otherClasses ) { f.otherClasses = ''; }
              f.otherClasses += ' span-wrap';
            }
            className = f.className;
            if ( f.format ) {
              if ( typeof(f.format) == 'string' ) {
                f.format = PHEDEX.TreeView.format[f.format];
              }
            }
            f.width = f.width + 'px';
            this._cfg.formats[className] = f;
            if ( values ) { value = values[i]; }
            else { value = f.text; }
            if ( spec.name ) { value = spec.name+': '+value; }
            if ( f.ctx ) {
              log('duplicate entry for '+className+': "'+f.ctx.value+'" and "'+value+'"','error','treeview');
            } else {
              f.ctx = {value:value, group:spec.name};
              this._cfg.sortFields[spec.name] = {};
              if ( spec.format[i].ctxArgs )
              {
                if ( typeof(f.ctxArgs) == 'string' ) {
                  f.ctxArgs = [f.ctxArgs];
                }
              }
            }
          }
        }

        el = this.makeNode(spec,values);
        tNode = new Yw.TextNode({label:el.innerHTML, expanded:false}, parent);
        tNode.getContentHtml = this.getContentHtml;
        this._cfg.textNodeMap[tNode.contentElId] = tNode;
        if ( isHeader ) { this._cfg.headerNodeMap[tNode.contentElId] = tNode; }
        tNode.data.values = values;
        tNode.data.spec   = spec;
        if ( spec.payload ) { tNode.payload = spec.payload; }
        return tNode;
      },

/** Remove all dhild branches from the tree, i.e. wipe it out. Useful when changing parameters and getting fresh data for an already existing tree, or during destruction of the module
 * @method truncateTree
 */
      truncateTree: function() {
        var i;
        while (i = this.tree.root.children[0]) { this.tree.removeNode(i); }
        this._cfg.textNodeMap = [];
        for (i in this._cfg.headerNodeMap) { this._cfg.textNodeMap[i] = this._cfg.headerNodeMap[i]; }
      },

      menuSelectItem: function(args) {
        var i, formats=this._cfg.formats;
        for (i in args) {
          YuD.getElementsByClassName(args[i],null,this.el,function(element) {
            YuD.removeClass(element,'phedex-invisible');
          });
          formats[args[i]].hide=false;
        }
        _sbx.notify(this.id, 'updateHistory');
      },

      syncNodeFromDom: function(element) {
        var el, node, _html;
        node  = this.locateBranch(element);
        el = document.getElementById(node.contentElId);
        node.label = el.childNodes[0].innerHTML;
      },

      hideFieldByClass: function(className,el) {
        log('hideFieldByClass: '+className,'info','treeview');
        var _hideElement = function(o) {
        return function(element) {
          YuD.addClass(element,'phedex-invisible');
          o.syncNodeFromDom(element);
        } }(this);
        YuD.getElementsByClassName(className,null,el,_hideElement);
        var fmt = this._cfg.formats[className];
        _sbx.notify(this.id,'hideColumn',{text: fmt.ctx.value, value:className});
        fmt.hide = true;
      },

      /**
      * hide all columns which have been declared to be hidden. Needed on initial rendering, on update, or after filtering. Uses <strong>this.meta.hide</strong> to determine what to hide.
      * @method hideFields
      */
      hideFields: function(el) {
        var i, j, format, spec, tree=this.meta.tree;
        for (i in tree) {
          format = tree[i].format;
          for (j in format) {
            spec = format[j];
            if ( spec.hide ) {
              this.hideFieldByClass(spec.className,this.el);
            }
          }
        }
      },

      markOverflows: function(list) {
        var i, j=0, h1, h2,
            el, elList = list || YuD.getElementsByClassName('span-wrap','span',this.el);
        log('markOverflows: '+elList.length+' entries total','info','treeview');
        while (i = elList.shift()) {
          el = this.locateNode(i);
          h1 = i.offsetHeight,
          h2 = el.offsetHeight;
          if ( h1/h2 > 1.2 ) { // the element overflows its container, by a generous amount...
            YuD.addClass(el,'phedex-tnode-overflow');
          } else {
            YuD.removeClass(el,'phedex-tnode-overflow');
          }
          this.syncNodeFromDom(el);
          if ( j++ >= 25 ) {
            log('markOverflows: defer with '+elList.length+' entries left','info','treeview');
            _sbx.notify(this.id,'markOverflows',elList);
            return;
          }
        }
      },

//    This is for dynamically loading data into YUI TreeViews.
      loadTreeNodeData: function(node, fnLoadComplete) {
//    First, create a callback function that uses the payload to identify what to do with the returned data.
        var tNode,
            p = node.payload,
            loadTreeNodeData_callback = function(result) {
            if ( result.stack ) {
              log('loadTreeNodeData: failed to get data','error',_me);
            } else {
              try {
                p.callback(node,result);
              } catch(ex) {
                banner('error fetching data for tree-branch','error',_me);
                log('Error in loadTreeNodeData_callback ('+err(ex)+')','error',_me);
                tNode = new Yw.TextNode({label: 'Data-loading error, try again later...', expanded: false}, node);
                tNode.getContentHtml = this.getContentHtml;
                tNode.isLeaf = true;
              }
            }
            fnLoadComplete();
            p.obj.postGotData();
          }

//      Now, find out what to get, if anything...
        if ( typeof(p) == 'undefined' )
        {
//        This need not be an error, so don't log it. Some branches are built on already-known data, and do not require new
//        data to be fetched. If dynamic loading is on for the whole tree this code will be hit for those branches.
          fnLoadComplete();
          return;
        }
        if ( p.call )
        {
          if ( typeof(p.call) == 'string' )
          {
//          payload calls which are strings are assumed to be Datasvc call names, so pick them up from the Datasvc namespace,
//          and conform to the calling specification for the data-service module
            log('in PHEDEX.TreeView.loadTreeNodeData for '+p.call,'info',_me);
            var query = [];
            query.api = p.call;
            query.args = p.args;
            query.callback = loadTreeNodeData_callback;
            PHEDEX.Datasvc.Call(query);
          } else {
//          The call-name isn't a string, assume it's a function and call it directly.
//          I'm guessing there may be a use for this, but I don't know what it is yet...
            log('Apparently require dynamically loaded data from a specified function. This code has not been tested yet','error',_me);
            p.call(node,loadTreeNodeData_callback);
          }
        } else {
          log('Apparently require dynamically loaded data but do not know how to get it! (hint: payload probably malformed?)','error',_me);
          fnLoadComplete();
        }
      },

      revealAllBranches: function() {
        this.revealAllElements('ygtvtable');
        this._cfg.hiddenBranches = {};
      },

/** return a boolean indicating if the module is in a fit state to be bookmarked
 * @method isStateValid
 * @return {boolean} <strong>false</strong>, must be over-ridden by derived types that can handle their separate cases
 */
      isStateValid: function() {
        if ( this.obj.data ) { return true; } // TODO is this good enough...? Use _needsParse...?
        return false;
      },

      decoratorsConstructed: function() {
        if ( !this.data ) { return; }
        this.postGotData();
      },

      dirMap: function(dir) { return dir; } // dummy to maintain code-compatibility with data-table
    };
  };
  Yla(this,_construct(),true);
  return this;
}

PHEDEX.TreeView.ContextMenu = function(obj,args) {
  var p = args.payload;
  if ( !p.config ) { p.config={}; }
  if ( !p.typeNames ) { p.typeNames=[]; }
  p.typeNames.push('treeview');
  if ( !p.config.trigger ) { p.config.trigger = obj.dom.content };
  var fn = function(o) {
    return function(opts,el) {
      var elPhedex = o.locateNode(el.target),
          elClass  = o.getPhedexFieldClass(elPhedex);
      o.hideFieldByClass(elClass,o.el);
    }
  }(obj);
  PHEDEX.Component.ContextMenu.Add('treeview','Hide This Field', fn);

  var fnDump = function(opts,el) {
    var w = window.open('', 'Window_'+PxU.Sequence(), 'width=640,height=480,scrollbars=yes');
    w.document.writeln(Ylang.JSON.stringify(el.obj.data));
  }
  PHEDEX.Component.ContextMenu.Add('treeview', 'Show tree data (JSON)', fnDump);

  return {
    getExtraContextTypes: function() {
      var cArgs = obj._cfg.formats, cUniq = {}, i, j;
      for (i in cArgs) {
        for(j in cArgs[i].ctxArgs) {
          cUniq[cArgs[i].ctxArgs[j]] = 1;
        }
      }
      return cUniq;
    },

//  Context-menu handlers: onContextMenuBeforeShow allows to (re-)build the menu based on the element that is clicked.
    onContextMenuBeforeShow: function(target, typeNames) {
      var classes, tgt,
          isHeader, treeMatch,
          payload = {},
          i, j, ctxArgs,
          formats=obj._cfg.formats, f;
      tgt = obj.locateNode(target);
      if ( !tgt ) { return; }
      if      ( YuD.hasClass(tgt,'phedex-tnode-header') ) { isHeader = true; }
      else if ( YuD.hasClass(tgt,'phedex-tnode-field' ) ) { isHeader = false; }
      else    { return; }

//    Get the array of MenuItems for the CSS class name from the "oContextMenuItems" map.
      classes = tgt.className.split(" ");

//    Highlight the <tr> element in the table that was the target of the "contextmenu" event.
      YuD.addClass(tgt, "phedex-core-selected");

//    Now extract the set of context-arguments for the classes applied to this element, and return them in the typeNames array.
      if ( !isHeader ) {
        treeMatch = /^phedex-tree-/;
        for (i in classes) {
          if ( f = formats[classes[i]]  ) {
            if ( ctxArgs = f.ctxArgs ) {
              if ( classes[i].match(treeMatch) ) {
              log('found '+classes[i]+' to key new menu entries','info',obj.me);
                for(j in ctxArgs) {
                  typeNames.unshift(ctxArgs[j]);
                }
              }
            }
          }
        }
      }
      return typeNames;
    },

    onContextMenuHide: function(target) {
      var tgt = obj.locateNode(target);
      if ( tgt ) {
        YuD.removeClass(tgt, "phedex-core-selected");
      }
    },

    onContextMenuClick: function(p_sType, p_aArgs, p_TreeView) {
//    Based on http://developer.yahoo.com/yui/examples/menu/treeviewcontextmenu.html
      log('ContextMenuClick for '+obj.me,'info','treeview');
      var target = this.contextEventTarget,
          node = obj.locateBranch(target),
          el   = obj.locateNode(target),
          className = obj.getPhedexFieldClass(el),
          label = p_aArgs[0].explicitOriginalTarget.textContent,
          task  = p_aArgs[1],
          opts  = {},
          i, j, f, key;
      if ( !node ) {
        this.cancel();
        return;
      }
      if ( node.payload ) {
        for (i in node.payload.opts) { opts[i] = node.payload.opts[i]; }
      }
      f = node.data.spec.format;
      for (i in f) {
        if (key = f[i].ctxKey) {
          if ( f[i].className == className || !opts[key] ) {
            opts[key] = node.data.values[i];
          }
        }
      }
      log('ContextMenu: '+'"'+label+'" for '+obj.me+' ('+opts.selected_node+')','info','treeview');
      if (task) {
        task.value.fn(opts, {node:node, target:target, obj:obj});
      }
    }
  };
}

PHEDEX.TreeView.Resize = function(sandbox,args) {
  var obj  = args.payload.obj,
      _sbx = sandbox,
      elList = YuD.getElementsByClassName('phedex-tnode-header',null,obj.el);
  for (var i in elList)
  {
    var el = elList[i],
        elResize = new Yu.Resize(el,{ handles:['r'] }); // , draggable:true }); // draggable is cute if I can make it work properly!
    elResize.payload = el;
    elResize.subscribe('endResize',function(ev) {
//    find the class that is being resized, update the spec for that class, and update the nodes that are affected by the change.
      var tgt = obj.locateHeader(YuE.getTarget(ev).payload),
          elList = obj.locatePartnerFields(tgt),
          i, el, className, f, node, el1;
      for (i in elList) {
        el = elList[i];
        YuD.removeClass(el,'phedex-tnode-highlight-associated'); // TODO I shouldn't really have to do this here, should I?
        el.style.width = tgt.style.width;
        obj.syncNodeFromDom(el);
      }
      obj._cache.node = {};

//    update the spec object with the new width, in case any more branches at this level are created
      el = obj.locateNode(tgt);
      className = obj.getPhedexFieldClass(el);
      f = obj._cfg.formats[className];
      f.width = tgt.style.width;
      if ( YuD.hasClass(el,'span-wrap') ) {
        obj.markOverflows();
      }
    });
  }

  _construct = function() {
    return {
      _init: function() {
        var moduleHandler = function(o) {
          return function(ev,arr) {
            var action = arr[0];
            if ( action && o[action] && typeof(o[action]) == 'function' ) {
              o[action](arr[1]);
              return;
            }
          }
        }(this);
        _sbx.listen(obj.id,moduleHandler);
      }
    };
  }
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

PHEDEX.TreeView.Sort = function(sandbox,args) {
  var _sbx = sandbox,
      obj = args.payload.obj;
  _construct = function() {
    return {
      execute: function(o,s) {
//      node is a tree-node that needs to be sorted, along with its siblings.
//      className is the class to use as the sort-key. If not given, look to see if a default is already set for this group
//      sortFn is the actual sorting function, either passed or taken from set defaults
        var className=s.field, type=s.type, dir=s.dir,
            sortFn = PxU.Sort[type][dir],
            index, parent, children, f, i, j,
            map, indices, elList,
            nodes = {}, node;

//      locate all fields of the target-type, find their parents, and sort all children of each parent. This may not be cheap
//      operation, I have to look up all the elements of this CSS class, then get the node they are in, then the parents,
//      make a unique list of the parents, and sort each of them. I can gain something by looking up only every other node,
//      because that way I may miss a parent with a single child, but single-children are already sorted anyway.
//      Also, skip the first element, because that will be the header, which can be ignored
        elList = YuD.getElementsByClassName(className,null,o.el);
        j = elList.length;
        for (i=1; i<j; i+=2) {
          node = o.locateBranch(elList[i]);
          parent = node.parent;
          nodes[parent.index] = parent;
        }

        for (j in nodes) {
          parent = nodes[j];
          children = parent.children;
          node = children[0];
          if ( !node ) { continue; }
          for (i in node.data.spec.format) {
            f = node.data.spec.format[i];
            if ( f.className == className ) { index = i; break; }
          }
          if ( !index ) {
            log('cannot identify class-type','error','treeview');
            return;
          }

          map = [];
          indices = [];
          for (i in children)
          {
            elList = YuD.getElementsByClassName(className,null,children[i].getEl());
            if ( elList.length ) {
              map.push( {node:children[i], value:children[i].data.values[index]} );
              indices.push( i );
            }
          }
          map.sort(function(a,b){ return sortFn(a.value,b.value); });
          children = parent.children;
          for (i in map) {
            var _n = map[i].node,
                _el = document.getElementById(_n.contentElId);
            _n.label = _el.childNodes[0].innerHTML;
            parent.children[indices[i]] = _n;
          }
        }

        o.tree.render();
//      Rendering rebuilds the DOM somehow, so the partner-cache is invalid.
        o._cache.partners = {};

//      Rendering the tree resets the classNames of the elements, because it uses the node innerHTML instead of the DOM. Hence this comes here, after the render!
// TODO need to manually preserve the DOM content of each node and use it to replace the node innerHTML?
// take node.labelElId, find the element, extract the innerHTML, set it into the Node.label before rendering!
        YuD.getElementsByClassName('phedex-sorted','div',o.el,function(element) {
          YuD.removeClass(element,'phedex-sorted');
        });
        YuD.getElementsByClassName(className,null,o.el,function(element) {
          YuD.addClass(element,'phedex-sorted');
        });

//      add a visual indicator that the module has been sorted
        var sortIndicator = o.dom.sorted;
        if ( !sortIndicator ) {
          o.dom.sorted = sortIndicator = PxU.makeChild(o.dom.control,'span');
          sortIndicator.innerHTML = 'S';
          sortIndicator.title = 'This is a visual marker to show that the tree has been sorted, in case the sorted field is currently hidden from display. Click this button to cancel sorting (may be useful for performance reasons)';
        }
        sortIndicator.className = 'phedex-sorted';

// TODO Why do I need this...?
        for (i in o._cfg.hiddenBranches) {
//        I have to look up the ancestor again, because re-rendering the tree makes the DOM-reference no longer valid if I cached it.
          var elAncestor = YuD.getAncestorByClassName(document.getElementById(i),'ygtvtable');
          YuD.addClass(elAncestor,'phedex-invisible');
        }

        o.meta.sort.type = type;
        o.meta.sort.dir  = dir;
        _sbx.notify(o.id, 'updateHistory');
      },

      prepare: function(el,type,dir) {
//     simply unpack the interesting bits and feed it to the object
        var obj    = el.obj,
            target = obj.locateNode(el.target),
            field  = obj.getPhedexFieldClass(target),
            s      = obj.meta.sort;
        if ( !s ) { s = obj.meta.sort = {}; }
        s.field = field;
        s.dir   = dir;
        s.type  = type;
        this.execute(obj,s);
      },

      doSort: function() {
        var s = obj.meta.sort;
        if ( !s )       { return; } // no sort-column defined...
        if ( !s.field ) { return; } // no sort-column defined...
        this.execute(obj,s);
      },

      _init: function() {
        try {
          var x = function(o) {
//          TODO strictly speaking, I should not call the context-menu directly here, in case it isn't loaded yet. However, treeview depends
//          on it, so that should not be a problem. For now, the try-catch block will suffice to protect if the contextmenu is not loaded.
//          Doing it 'right' would require either an instance of the context-menu to be instantiated (to provide a listener), or for a
//          global listener, neither of which are obviously better ways of doing this...
            PHEDEX.Component.ContextMenu.Add('sort-files','Sort Files Ascending', function(opts,el) { o.prepare(el,'files',  'asc' ); });
            PHEDEX.Component.ContextMenu.Add('sort-files','Sort Files Descending',function(opts,el) { o.prepare(el,'files',  'desc'); });
            PHEDEX.Component.ContextMenu.Add('sort-bytes','Sort Bytes Ascending', function(opts,el) { o.prepare(el,'bytes',  'asc' ); });
            PHEDEX.Component.ContextMenu.Add('sort-bytes','Sort Bytes Descending',function(opts,el) { o.prepare(el,'bytes',  'desc'); });
            PHEDEX.Component.ContextMenu.Add('sort-alpha','Sort Ascending',       function(opts,el) { o.prepare(el,'alpha',  'asc' ); });
            PHEDEX.Component.ContextMenu.Add('sort-alpha','Sort Descending',      function(opts,el) { o.prepare(el,'alpha',  'desc'); });
            PHEDEX.Component.ContextMenu.Add('sort-num',  'Sort Ascending',       function(opts,el) { o.prepare(el,'numeric','asc' ); });
            PHEDEX.Component.ContextMenu.Add('sort-num',  'Sort Descending',      function(opts,el) { o.prepare(el,'numeric','desc'); });
          }(this);
        } catch(ex) { log(ex,'error',obj.me); };

        var moduleHandler = function(o) {
          return function(ev,arr) {
            var action = arr[0];
            if ( action && o[action] && typeof(o[action]) == 'function' ) {
              o[action](arr[1]);
            }
          }
        }(this);
        _sbx.listen(obj.id,moduleHandler);
      }
    };
  }
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

/** This class is invoked by PHEDEX.Module to create the correct handler for datatable mouse-over events.
 * @namespace PHEDEX.TreeView
 * @class MouseOver
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object (unused)
 * @param args {object} reference to an object that specifies details of how the control should operate. Only <strong>args.payload.obj.dataTable</strong> is used, to subscribe to the <strong>onRowMouseOver</strong> and >strong>onRowMouseOut</strong> events.
 */
PHEDEX.TreeView.MouseOver = function(sandbox,args) {
  var obj = args.payload.obj;
  function mouseOverHandler(e) {
//  get the resolved (non-text node) target:
    var elTarget = YuE.getTarget(e),
        el = obj.locateNode(elTarget),
        action, className, class_alt, elList, i;
    if ( ! el ) { return; }
    className = 'phedex-tnode-highlight';
    class_alt  = 'phedex-tnode-highlight-associated';
    if ( e.type == 'mouseover' ) {
      action = YuD.addClass;
    } else {
      action = YuD.removeClass;
    }
    elList = obj.locatePartnerFields(el);
    for (i in elList )
    {
      action(elList[i],class_alt);
    }
    action(el,className);
  }
  YuE.on(obj.dom.content, "mouseover", mouseOverHandler);
  YuE.on(obj.dom.content, "mouseout",  mouseOverHandler);
  YuE.on(obj.dom.extra,   "mouseover", mouseOverHandler);
  YuE.on(obj.dom.extra,   "mouseout",  mouseOverHandler);
}

PHEDEX.TreeView.Filter = function(sandbox,obj) {
  var _sbx = sandbox;
  _construct = function() {
    return {
        /**
        * Resets the filter in the module.
        * @method resetFilter
        * @param arg {Object} The array of column keys with user entered filter values.
        * @private
        */
        resetFilter: function(args) {
// TODO This is a big hammer. Would be better to cache the original tree and work with that...
          this.applyFilter({});
        },

      _init: function() {
        var moduleHandler = function(o) {
          return function(ev,arr) {
            var action = arr[0];
            if ( action && o[action] && typeof(o[action]) == 'function' ) {
              o[action](arr[1]);
            }
          }
        }(this);
        _sbx.listen(obj.id,moduleHandler);
      },

      applyFilter: function(args) {
//      First, reveal any filtered branches, in case the filter has changed (as opposed to being created)
        obj.revealAllBranches();
        var elParents={}, i, status, key, fValue, negate, elId, tNode, className, kValue, elParent, elAncestor;
        if ( !args ) { args = this.args; }
        this.count=0;
        for (key in args) {
          fValue = args[key].values;
          negate = args[key].negate;
          for (elId in obj._cfg.textNodeMap) {
            tNode = obj._cfg.textNodeMap[elId];
            if ( tNode.data.spec.className == 'phedex-tnode-header' ) { continue; }
            for (i in tNode.data.spec.format) {
              className = tNode.data.spec.format[i].className;
              if ( className != key ) { continue; }
              kValue = tNode.data.values[i];
              if ( args[key].preprocess ) { kValue = args[key].preprocess(kValue); }
              status = this.Apply[this.meta._filter.fields[key].type](fValue,kValue);
              if ( args[key].negate ) { status = !status; }
              if ( !status ) { // Keep the element if the match succeeded!
                tNode.collapse();
                elAncestor = YuD.getAncestorByClassName(elId,'ygtvtable');
                YuD.addClass(elAncestor,'phedex-invisible');
                obj._cfg.hiddenBranches[elId] = 1;
                this.count++;
                if ( tNode.parent ) {
                  if ( tNode.parent.labelElId ) { elParents[tNode.parent.labelElId] = 1; }
                }
              }
              break;
            }
          }
        }
        for (elParent in elParents) {
          elAncestor = YuD.getAncestorByClassName(elParent,'ygtvtable');
          YuD.addClass(elAncestor,'phedex-core-control-widget-applied');
        }
        this.updateGUIElements(this.count);
        return;
      }
    }
  };
  Yla(this,_construct(this),true);
  this._init();
  return this;
};

PHEDEX.TreeView.format = {
  UnixEpochToGMT: PHEDEX.Util.format.UnixEpochToGMT,
  UnixEpochToUTC: PHEDEX.Util.format.UnixEpochToUTC
}

log('loaded...','info','treeview');
