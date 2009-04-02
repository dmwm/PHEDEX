//This 'class' represents the basic header,extra,children node for a dynamic PhEDEx page.
//Required arguments either a div object or a id name for a div for the item to be built in (divid), a parent node (if one exists).
//The optional opts dictionary can be used to enable/disable the extra area and children, and set the initial expansion states.
//Individual nodes should subclass this, calling the superconstructor with either a ready div or an ID of an existing div, and then
//implement their own methods to generate the header, extra and children content, and handle updates.

PHEDEX.Widget = function(divid,parent,opts) {
  this.options = {expand_extra:false,expand_children:false,extra:true,children:true,fixed_extra:false};
  if (opts) {
    for (o in opts) {
      this.options[o]=opts[o];
    }
  }
  if (typeof(divid)=='object') {
    this.id = divid.id;
    this.div = divid;
  } else {
    this.id = divid;
    this.div = document.getElementById(this.id);
  }
  this.div.objLink = this;
  this.sort_keys={};
  this.children = [];
  this.parent = parent;
  this.updated = false;
  this.last_update = null;
  this.children_fetched = false;
  this.filtered_children = 0;
  this.to_update = [];
  this.marked=false;
  this.main_css='';
  this.closed_children = 0;
  this.clear=function() {
    while (this.div.hasChildNodes())
      this.div.removeChild(this.div.firstChild);
  }
  this.build=function() {
    this.clear();
    
    if (this.options['children']) {
      this.child_link = document.createElement('a');
      this.child_link.href='#';
      this.child_link.setAttribute('onclick',"PHEDEX.Widget.toggleChildren('"+this.id+"');"); //this is an ugly hack to get around execution context - this.id is evaluated now in this context to make a string, instead of later if we set onclick to an actual function.
      this.child_link.innerHTML='+';
      this.child_link.id=this.id+'_children_link';
      this.child_link.className='node-children-link';
      this.children_div=document.createElement('div');
      this.children_div.id = this.id+'_children';
      this.children_div.className = 'node-children';
      this.children_info_div=document.createElement('div');
      this.children_info_div.id=this.id+'_children_info';
      this.children_info_div.className = 'node-children-info';
    }
    
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
        this.extra_expand_div.setAttribute('onclick',"PHEDEX.Widget.toggleExtra('"+this.id+"');");
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
    this.span_header = document.createElement('span');
    this.selected_div = document.createElement('div');
    this.selected_div.className='node-selected';
    this.header_div.appendChild(this.selected_div);
    this.header_div.appendChild(this.sort_div);
    this.header_div.appendChild(this.span_header);
    
    //quick+dirty CSS menu for options
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
      this.main_div.appendChild(this.children_info_div);
      this.div.appendChild(this.children_div);
    }
    
    this.buildHeader(this.span_header);
    if (this.options['extra']) {
      this.buildExtra(this.extra_div);
    }
    
    if (this.options['expand_extra'] && !this.options['fixed_extra']) {
      PHEDEX.Util.toggleExtra(this.id);
    }
    if (this.options['expand_children']) {
      PHEDEX.Widget.toggleChildren(this.id);
    }
  }
  this.buildHeader=function(span) {}
  this.buildExtra=function(div) {}
  this.fillHeader=function() {}
  this.fillExtra=function() {}
  this.startLoading=function() {
    this.progress_img.style.display='block';
  }
  this.finishLoading=function() {
    this.progress_img.style.display='none';
  }
  this.update=function() { alert("Unimplemented update()");}
  this.updateChildren=function() {
    this.update();
    for (var i in this.children) {
      this.children[i].updateChildren();
    }
  }
  this.requestChildren=function() {
    //this should allow for a timeout (after which children will be re-acquired)
    //timeout should be custom depending on data
    if (! this.children_fetched) {
      this.buildChildren(this.children_div);
    }
  }
  this.populate=function() {
    this.fillHeader();
    this.fillExtra();
    if (this.options['children']) {
      if (this.children_div.style.display=='block') {
        this.buildChildren(this.children_div);
      }
    }
  }
  this.buildChildren=function(div) {}
  this.filterClear=function() {
    this.filtered_children=0;
    for (var i in this.children) {
      this.children[i].filterClear();
      this.children[i].div.style.display='block';
    }
    if (this.children.length>0) {
      this.children_info_div.innerHTML='';
    }
  }
  this.filterChildren=function(filter_str) {
    this.filtered_children=0;
    for (var i in this.children) {
      this.children[i].filterChildren(filter_str);
      if (this.children[i].filter(filter_str)) {
         this.children[i].div.style.display='block';
      } else {
        this.children[i].div.style.display='none';
        this.filtered_children+=1;
      }
    }
    if (this.filtered_children>0) {
      this.children_info_div.innerHTML='Filtered children: '+this.filtered_children+' of '+this.children.length;
    } else {
      if (this.filtered_children==0 && this.children.length>0) {
        this.children_info_div.innerHTML='';
      }
    }
  }
  this.closeChild=function(objid) {
    if (typeof(objid)=='object') {
      var uid=objid.uid();
    } else {
      var uid=objid;
    }
    this.removeChild(uid);
  }
  this.getChildByUID=function(uid) {
    for (var i in this.children) {
      if (this.children[i].uid()==uid) {
        return this.children[i];
      }
    }
    return false;
  }
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
  this.setDataExpiry=function(ms) {
    window.setTimeout("PHEDEX.Widget.updateProxy('"+this.id+"');",ms);
  }
  this.selectChildren=function(selected) {
    for (var i in this.children) {
      this.children[i].select(selected);
    }
  }
  this.select=function(selected) {
    this.selected=selected;
    if (selected) {
      this.selected_div.style.display='block';
    } else {
      this.selected_div.style.display='none';
    }
  }
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
    }
    this.event(arg0,arg1,arg2,arg3);
  }
  this.event=function(arg0,arg1,arg2,arg3) {} //must be a better way of doing this
  this.uid = function() {return this.id;}
  this.getChild = function(uid) {
    for (var i in this.children) {
      if (this.children[i].uid()==uid) {
        return this.children[i];
      }
    }
    return false;
  }
  this.markChildren = function() {
    for (var i in this.children) {
      this.children[i].marked=true;
    }
  }
  this.unmarkChildren = function() {
    for (var i in this.children) {
      this.children[i].marked=false;
    }
  }
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
  this.sortChildren=function(key,reverse) {
    var sortCompare=function(child_a,child_b) {
      var key_a = child_a.sortKey(key);
      var key_b = child_b.sortKey(key);
      return (key_a>key_b)-(key_b>key_a);
    }
    this.children.sort(sortCompare);
    while(this.children_div.hasChildNodes())
      this.children_div.removeChild(this.children_div.firstChild);
    for (var i in this.children) {
      this.children_div.appendChild(this.children[i].div);
    }
  }
  this.filter=function(filter_str) {return true;}
  this.sortKey=function(sort_key) {return this.uid();}
  this.removeAllChildren=function() {
    this.children=[];
    while(this.children_div.hasChildNodes()) 
      this.children_div.removeChild(this.children_div.firstChild);
  }
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

PHEDEX.Widget.toggleChildren=function(id) {
    var obj = document.getElementById(id).objLink;
    var children = document.getElementById(id+'_children');
    var link = document.getElementById(id+'_children_link');
    if (children.style.display=='block') {
      children.style.display='none';
      link.innerHTML='+';
    } else {
      obj.requestChildren();
      children.style.display='block';
      link.innerHTML='-';
    }
    return -1;
  }

PHEDEX.Widget.toggleExtra = function(id) {
    var extra = document.getElementById(id+'_extra');
    var link = document.getElementById(id+'_extra_link');
    if (extra.style.display=='block') {
      extra.style.display='none';
      link.innerHTML='expand';
    } else {
      extra.style.display='block';
      link.innerHTML='collapse';
    }
    return -1;
  }

PHEDEX.Widget.eventProxy=function(id,arg0,arg1,arg2,arg3) {
    var obj = document.getElementById(id).objLink;
    obj.eventDefault(arg0,arg1,arg2,arg3);
  }

PHEDEX.Widget.updateProxy=function(id) {
    var obj = document.getElementById(id).objLink;
    obj.update();
}