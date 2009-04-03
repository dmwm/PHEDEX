//This 'class' represents the basic header,extra,children node for a dynamic PhEDEx page.
//Required arguments either a div object or a id name for a div for the item to be built in (divid), a parent node (if one exists).
//The optional opts dictionary can be used to enable/disable the extra area and children, and set the initial expansion states.
//Individual nodes should subclass this, calling the superconstructor with either a ready div or an ID of an existing div, and then
//implement their own methods to generate the header, extra and children content, and handle updates.

//This should be subclassed for each class and then specific child node.
//TODO: Prototype instead of instance based subclassing.

PHEDEX.Widget = function(divid,parent,opts) {
  // Copy the options over the defaults.
  // There should probably be further options here such as closeable, updateable, sortable, filterable...
  this.options = {expand_extra:false,expand_children:false,extra:true,children:true,fixed_extra:false};
  if (opts) {
    for (o in opts) {
      this.options[o]=opts[o];
    }
  }
  // Test whether we were passed an object (assumed div) or something else (assumed element.id)
  // Set the div and id appropriately.
  if (typeof(divid)=='object') {
    this.id = divid.id;
    this.div = divid;
  } else {
    this.id = divid;
//  this.div = document.getElementById(this.id);
    this.div = PHEDEX.Util.findOrCreateWidgetDiv(this.id);
  }
  // This is used to get round execution scope issues. The object is bound to the top-level div, which can be looked up easily by ID, and the object recovered.
  // TODO: does this work in all browsers?
  this.div.objLink = this;
  // Sort keys is a key_name: Key Label dictionary of keys the children of this node will understand (when called with child.sort_key(key_name))
  // Used to build the sort menu. Should be appended to before build() time.
  this.sort_keys={};
  // List of children
  this.children = [];
  // Reference to parent (or null)
  this.parent = parent;
  // TODO: Currently unused. Intended for future auto-update/manual update after data expiry
  this.last_update = null;
  // Used to indicate whether the children have ever been fetched when the children area is expanded (so they can be fetched first time and just shown subsequently).
  this.children_fetched = false;
  // Indicates the number of children the node has currently hidden by filtering.
  this.filtered_children = 0;
  // Mark of the Beast. Used during updates by the parent to detect which children have neither been freshly created or updated (and so are based on data no longer returned and can be safely deleted).
  this.marked=false;
  // Can be set by the subclass to append one or more extra CSS classes to this node for skinning purposes.
  this.main_css='';
  // Counter for number of children disposed of.
  this.closed_children = 0;
  
  // Clears the node of all content (not just children).
  this.clear=function() {
    while (this.div.hasChildNodes())
      this.div.removeChild(this.div.firstChild);
  }
  
  // Build contructs all the basic unfilled markup required before the implementation starts doing specific tasks.
  this.build=function() {
    //Start off by clearing the top-level div (we might be being inserted into an already used div).
    this.clear();
    
    // Create children area and control
    if (this.options['children']) {
      this.child_link = document.createElement('a');
      this.child_link.href='#';
      this.child_link.setAttribute('onclick',"PHEDEX.Widget.eventProxy('"+this.id+"','toggleChildren');"); //this is an ugly hack to get around execution context - this.id is evaluated now in this context to make a string, instead of later if we set onclick to an actual function.
      this.child_link.innerHTML='+';
      this.child_link.id=this.id+'_children_link';
      this.child_link.className='node-children-link';
      this.children_div=document.createElement('div');
      this.children_div.id = this.id+'_children';
      this.children_div.className = 'node-children';
      //this.children_info_div=document.createElement('div');
      //this.children_info_div.id=this.id+'_children_info';
      // Children-info is a div to contain info such as # filtered, # closed, none returned.
      // TODO: However, it's messy when each of these conditions arises to have to check that none of the other conditions apply to maintain the appropriate message in this field and not risk overwriting other ones. It could probably be quite easily expanded to 3 divs, which would remain hidden until some content was added.
      //this.children_info_div.className = 'node-children-info';
      this.children_info_none = document.createElement('div');
      this.children_info_none.className = 'node-children-info';
      this.children_info_filter = document.createElement('div');
      this.children_info_filter.className = 'node-children-info';
    }
    
    // Create a primitive dialog and event connections for a search dialog.
    // TODO: This is basically non-functional. This should either be re-done as a proper slide-out pane, or set up as a proper dialog using YUI widgets. There is probably scope to create a standard dialog or slide-element for either.
    this.sort_div=document.createElement('div');
    this.sort_div.className='node-sort-dialog';
    this.sort_opts = document.createElement('select');
    for (var k in this.sort_keys) {
      var o = document.createElement('option');
      o.innerHTML=this.sort_keys[k];
      o.value=k;
      this.sort_opts.appendChild(o);
    }
    this.sort_div.appendChild(this.sort_opts);
    var sort_close = document.createElement('a');
    sort_close.innerHTML='close';
    sort_close.href='#';
    sort_close.setAttribute('onclick',"PHEDEX.Widget.eventProxy('"+this.id+"','sort_Close');");
    this.sort_div.appendChild(sort_close);
    var sort_sort = document.createElement('a');
    sort_sort.innerHTML='sort';
    sort_sort.href='#';
    sort_sort.setAttribute('onclick',"PHEDEX.Widget.eventProxy('"+this.id+"','sort_Sort');");
    this.sort_div.appendChild(sort_sort);
    this.sort_reverse = document.createElement('checkbox');
    this.sort_div.appendChild(this.sort_reverse);   
    
    
    this.main_div=document.createElement('div');
    this.header_div=document.createElement('div');
    
    // Create the extra area, if required. TODO: Extra-expand should probably show a wide up/down arrow (and possibly function on mouseover).
    if (this.options['extra']) {
      this.extra_div=document.createElement('div');
      this.extra_div.id = this.id+'_extra';
      this.extra_div.className = 'node-extra';
      if (this.options['fixed_extra']) {
        this.extra_div.style.display='block';
      } else {
        this.extra_expand_div=document.createElement('div');
        this.extra_expand_div.id = this.id+'_extra_link';
        this.extra_expand_div.className = 'node-extra-link';
        this.extra_expand_div.setAttribute('onclick',"PHEDEX.Widget.eventProxy('"+this.id+"','toggleExtra');");
        this.extra_expand_div.innerHTML='expand';
      }
    }
        
    this.main_div.id = this.id+'_main';
    this.header_div.id = this.id+'_header';

    this.main_div.className = 'node-main '+this.main_css;
    this.header_div.className = 'node-header';
    
    
    if (this.options['children']) {
      this.header_div.appendChild(this.child_link);
    }
    // The header is currently a relative-positioned div so that absolute-positioned dialog elements can be placed within it. TODO: It may be better to move to a series of floated div columns and a seperate relative-absolute element for dialogs.
    this.span_header = document.createElement('span');
    this.selected_div = document.createElement('div');
    this.selected_div.className='node-selected';
    this.header_div.appendChild(this.selected_div);
    this.header_div.appendChild(this.sort_div);
    this.header_div.appendChild(this.span_header);
    
    // Create a quick and dirty menu using CSS only.
    // TODO: The list of items should probably be a property of this, so implementations can alter it before build()
    // TODO: Most browsers have a bleed-through problem with the CSS here. This may be solvable with messing around with z-index, :hover etc but may need the menu redone in javascript.
    this.menu_div = document.createElement('div');
    this.menu_div.className='node-menu';
    var menu_ul = document.createElement('ul');
    var menu_items = ['Select','Unselect','Update','Update Children','Sort Children','Filter Children','Select Children','Unselect Children'];
    var menu_top = document.createElement('li');
    menu_top.innerHTML='menu';
    menu_ul.className='node-menu-ul';
    menu_ul.appendChild(menu_top);
    for (var i in menu_items) {
      var mi = document.createElement('li');
      mi.className='node-menu-item';
      var mia = document.createElement('a');
      mia.setAttribute('onclick',"PHEDEX.Widget.eventProxy('"+this.id+"','menu_"+menu_items[i]+"');");
      mia.className='node-menu-item';
      mia.innerHTML=menu_items[i];
      mia.href='#';
      mi.appendChild(mia);
      menu_ul.appendChild(mi);
    }
    this.menu_div.appendChild(menu_ul);
    this.header_div.appendChild(this.menu_div);
    // Create a (usually hidden) progress indicator.
    this.progress_img = document.createElement('img');
    this.progress_img.src = '/readfile/progress.gif';
    this.progress_img.className = 'node-progress';
    this.header_div.appendChild(this.progress_img);

    this.main_div.appendChild(this.header_div);
    if (this.options['extra']) {
      if (! this.options['fixed_extra']) {
        this.main_div.appendChild(this.extra_expand_div);
      }
      this.main_div.appendChild(this.extra_div);
    }
    
    this.div.appendChild(this.main_div);
    if (this.options['children']) {
      this.main_div.appendChild(this.children_info_none);
      this.main_div.appendChild(this.children_info_filter);
      this.div.appendChild(this.children_div);
    }
    
    this.buildHeader(this.span_header);
    if (this.options['extra']) {
      this.buildExtra(this.extra_div);
    }
    
    // If the extra and/or children are expanded by default, do so.
    // TODO: If the toggle* functions are moved into eventDefault they can be called directly and we don't need to mess about with proxy functions here.
    if (this.options['expand_extra'] && !this.options['fixed_extra']) {
      //PHEDEX.Widget.toggleExtra(this.id);
      this.eventDefault('toggleExtra');
    }
    if (this.options['expand_children']) {
      //PHEDEX.Widget.toggleChildren(this.id);
      this.eventDefault('toggleChildren');
    }
  }
  // Implementations should provide their own versions of these functions. The build* functions should be used to create a layout and store references to each element , which the fill* functions should populate with data when it arrives (but not usually alter the HTML) - this is to prevent issues like rebuilding select lists and losing your place.
  this.buildHeader=function(span) {}
  this.buildExtra=function(div) {}
  this.fillHeader=function() {}
  this.fillExtra=function() {}
  // Start/FinishLoading, surprisingly, show and hide the progress icon.
  this.startLoading=function() {this.progress_img.style.display='block';}
  this.finishLoading=function() {this.progress_img.style.display='none';}
  
  // Update is the core method that is called both after the object is first created and when the data expires. Depending on whether the implementation node is a level that fetches data itself or that has data injected by a parent, update() should either make a data request (and then parse it when it arrives) or do any data processing necessary and finally call populate() to fill in the header, extra and if necessary children. Start/FinishLoading should be used if data is being fetched.
  this.update=function() { alert("Unimplemented update()");}
  // Recursively update all children.
  this.updateChildren=function() {
    this.update();
    for (var i in this.children) {
      this.children[i].updateChildren();
    }
  }
  // Called whenever the child area is expanded. Checks whether we've already populated this area, and does so if not.
  this.requestChildren=function() {
    if (! this.children_fetched) {
      this.buildChildren(this.children_div);
      this.children_fetched=true;
    }
  }
  // Intended to be called by nodes after update() has been called and they've updated their internal data structures. Refills the header and extra info, and if the children are currently open attempts to update them as well.
  this.populate=function() {
    this.fillHeader();
    this.fillExtra();
    if (this.options['children']) {
      if (this.children_div.style.display=='block') {
        this.buildChildren(this.children_div);
      }
    }
  }
  // Implement for nodes that have child elements. When this is called it should either, if fresh data is necessary, request it, or if data is already available, build the children. At this time this function lacks a default implementation and a number of housekeeping operations have to be performed by the implementation. Specifically, the implementation should:
  // mark all children for deletion
  // iterate over data, calculating an ID for each data object
  // test if a child with that ID already exists
  //   inject the new data into the child
  //   unmark the child for deletion
  //   update() the child to display the new data
  // else
  //   create a new div with this ID
  //   create a new child node in this div
  //   add the child node to children
  //   add the div to children_div
  //   update() the child
  // delete any still-marked children
  // display 'no children' in children_info if we got nothing
  // TODO: Most of this should be done by a default implementation. Only parsing the data and create new nodes should be specific.
  // TODO: Respect sort, filter parameters at creation/update time
  this.buildChildren=function(div) {}
  // Redisplay all filtered nodes.
  this.filterClear=function() {
    this.filtered_children=0;
    for (var i in this.children) {
      this.children[i].filterClear();
      this.children[i].div.style.display='block';
    }
    if (this.children.length>0) {
      this.children_info_filter.innerHTML='';
    }
  }
  // Iterate over children, using their inbuilt filter methods. child.filter(filter_str) should return true to remain visible, false to be hidden (filtered). If a child receives a filter string it doesn't understand it should return true. Optionally recursive to all children.
  this.filterChildren=function(filter_str,recursive) {
    this.filtered_children=0;
    for (var i in this.children) {
      if (recursive)
        this.children[i].filterChildren(filter_str,recursive);
      if (this.children[i].filter(filter_str)) {
         this.children[i].div.style.display='block';
      } else {
        this.children[i].div.style.display='none';
        this.filtered_children+=1;
      }
    }
    if (this.filtered_children>0) {
      this.children_info_filter.innerHTML='Filtered children: '+this.filtered_children+' of '+this.children.length;
    } else {
      this.children_info_filter.innerHTML='';
    }
  }
  // Deletes a child from the current list of children permanently (well, until next update when it will be replaced).
  // TODO: Increment closed_children and display a message (and possibility to bring them back?)
  this.closeChild=function(objid) {
    if (typeof(objid)=='object') {
      var uid=objid.uid();
    } else {
      var uid=objid;
    }
    this.removeChild(uid);
  }
  // Removes a child both from the children list and removes its div from children_div.
  this.removeChild=function(uid) {
    var newchildren = [];
    for (var i in this.children) {
      if (! this.children[i].uid()==uid) {
        newchildren.push(this.children[i]);
      } else {
        this.children_div.removeChild(this.children[i].div);
      }
    }
    this.children=newchildren;
  }
  // Iterates down the tree from this node returning a flat list of all selected children.
  this.getSelectedChildren = function() {
    var result = [];
    for (var i in this.children) {
      if (this.children[i].selected) {
        result.push(this.children[i]);
      }
      var recurseSelect = this.children[i].getSelectedChildren();
      for (var j in recurseSelect) {
        result.push(recurseSelect[j]);
      }
    }
    return result;
  }
  // Set an automatic update after the given interval (assuming this node still exists then).
  // TODO: Updating should be improved with automatic getting of expiry headers and a display element for data age.
  this.setDataExpiry=function(ms) {
    window.setTimeout("PHEDEX.Widget.eventProxy('"+this.id+"','update');",ms);
  }
  // Select or unselect all the children of this node.
  this.selectChildren=function(selected) {
    for (var i in this.children) {
      this.children[i].select(selected);
    }
  }
  // Select or unselect this node. Displays a marker on the left-hand side of the header.
  this.select=function(selected) {
    this.selected=selected;
    if (selected) {
      this.selected_div.style.display='block';
    } else {
      this.selected_div.style.display='none';
    }
  }
  // This is the main event handling mechanism. All calls to PHEDEX.Widget.eventProxy(id,args...) where the ID resolves to the div associated with this object land here. This is intended to perform standard functions (such as the menu). All calls are then passed to event(), which implementations should overwrite to handle their own events.
  // TODO: Move toggleChildren, toggleExtra, updateProxy into this function. They don't need to be separate.
  // TODO: Look into how argument lists can be done in JS instead of the fixed 4-arg maximum I've done here.
  this.eventDefault=function(arg0,arg1,arg2,arg3) {
    switch(arg0) {
    case 'menu_Update':
      this.update();
      break;
    case 'menu_Update Children':
      this.updateChildren();
      break;
    case 'menu_Select':
      this.select(true);
      break;
    case 'menu_Unselect':
      this.select(false);
      break;
    case 'menu_Select Children':
      this.selectChildren(true);
      break
    case 'menu_Unselect Children':
      this.selectChildren(false);
      break;  
    case 'menu_Sort Children':
      this.sort_div.style.display='block';
      break;
    case 'menu_Filter Children':
      break;
    case 'sort_Close':
      this.sort_div.style.display='none';
      break;
    case 'sort_Sort':
      this.sortChildren(this.sort_select.value,this.sort_reverse.checked);
      break;
    case 'toggleChildren':
      if (this.children_div.style.display=='block') {
        this.children_div.style.display='none';
        this.child_link.innerHTML='+';
      } else {
        this.requestChildren();
        this.children_div.style.display='block';
        this.child_link.innerHTML='-';
      }
      break;
    case 'toggleExtra':
      if (this.extra_div.style.display=='block') {
        this.extra_div.style.display='none';
        this.extra_expand_div.innerHTML='expand';
      } else {
        this.extra_div.style.display='block';
        this.extra_expand_div.innerHTML='collapse';
      }
      break;
    case 'update':
      this.update();
      break;
    }
    this.event(arg0,arg1,arg2,arg3);
  }
  // Implement this to handle custom events
  this.event=function(arg0,arg1,arg2,arg3) {}
  // Return a unique ID number for this child. Default implementation returns the top-level div ID, which should be unique or Bad Things will happen. But if for some reason you need to override it...
  this.uid = function() {return this.id;}
  // Get a child from a UID.
  this.getChild = function(uid) {
    for (var i in this.children) {
      if (this.children[i].uid()==uid) {
        return this.children[i];
      }
    }
    return false;
  }
  // Mark all children for deletion.
  this.markChildren = function() {
    for (var i in this.children) {
      this.children[i].marked=true;
    }
  }
  // Unmark all children for deletion.
  this.unmarkChildren = function() {
    for (var i in this.children) {
      this.children[i].marked=false;
    }
  }
  // Delete those children who are marked for deletion (funnily enough).
  this.removeMarkedChildren = function() {
    var newchildren=[];
    for (var i in this.children) {
      if (this.children[i].marked) {
        this.children_div.removeChild(this.children[i].div);
      } else {
        newchildren.push(this.children[i]);
      }
    }
    this.children=newchildren;
  }
  // Sort the children of this node. Uses a keytype (the list of valid ones which should have been set in sort_keys). Each child's sortKey function should return a valid sorting key for each keytype defined in the parent. The child divs are then removed (but not destroyed), the child list sorted (and if necessary reversed), and then the divs re-added in the new order. (warning: untested).
  this.sortChildren=function(key,reverse) {
    var sortCompare=function(child_a,child_b) {
      var key_a = child_a.sortKey(key);
      var key_b = child_b.sortKey(key);
      return (key_a>key_b)-(key_b>key_a);
    }
    this.children.sort(sortCompare);
    while(this.children_div.hasChildNodes())
      this.children_div.removeChild(this.children_div.firstChild);
    if (reverse) this.children.reverse();
    for (var i in this.children) {
      this.children_div.appendChild(this.children[i].div);
    }
  }
  // Filter function. Each node that wants to be filterable needs to implement this, writing a function that picks out understood filter strings (eg something like 'link: T1*' might be understood by link level nodes and ignored by all others). Return true to remain visible, false to be hidden.
  this.filter=function(filter_str) {return true;}
  // Sort function. Each sortable node's parent should have a list of known sort keytypes (eg 'name', 'size', 'last updated'), and for each keytype the child should provide an appropriate key.
  this.sortKey=function(sort_key) {return this.uid();}
  // Infanticide();
  this.removeAllChildren=function() {
    this.children=[];
    while(this.children_div.hasChildNodes()) 
      this.children_div.removeChild(this.children_div.firstChild);
  }
  // Data formatting table. This is a look-up table of functions which take a raw string as argument and return a string intended to be injected as innerHTML into (usually) a span object.
  // TODO: Return instead TextNodes/Elements? May be unnecessarily complicated.
  // TODO: Anonymous functions inside the table have no access to properties of the outside object. Importantly, this means we cannot create events here as we have no access to this.id. Using switch() instead of a table would allow access to this (eg to expand shortened strings).
  this.format={
    bytes:function(raw) {
      var f = parseFloat(raw);
      if (f>=1099511627776) return (f/1099511627776).toFixed(1)+' TiB';
      if (f>=1073741824) return (f/1073741824).toFixed(1)+' GiB';
      if (f>=1048576) return (f/1048576).toFixed(1)+' MiB';
      if (f>=1024) return (f/1024).toFixed(1)+' KiB';
      return f.toFixed(1)+' B';
    },
    '%':function(raw) {
      return (100*parseFloat(raw)).toFixed(2)+'%';
    },
    block:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    },
    file:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    },
    date:function(raw) {
      var d =new Date(parseFloat(raw)*1000); 
      return d.toGMTString();
    },
    dataset:function(raw) {
      if (raw.length>50) {
        var short = raw.substring(0,50);
        return "<acronym title='"+raw+"'>"+short+"...</acronym>";
      } else {
        return raw;
      }
    }
  };
}

// eventProxy is a function designed to be called in global scope with the ID of a top-level div associated with a PHEDEX.Widget. The actual widget can then be retrieved using the objLink parameter set in the constructor, and the default event-handler called.
PHEDEX.Widget.eventProxy=function(id,arg0,arg1,arg2,arg3) {
    var obj = document.getElementById(id).objLink;
    obj.eventDefault(arg0,arg1,arg2,arg3);
}