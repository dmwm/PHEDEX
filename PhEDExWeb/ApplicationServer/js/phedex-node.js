//This 'class' represents the basic header,extra,children node for a dynamic PhEDEx page.
//Required arguments either a div object or a id name for a div for the item to be built in (divid), a parent node (if one exists).
//The optional opts dictionary can be used to enable/disable the extra area and children, and set the initial expansion states.
//Individual nodes should subclass this, calling the superconstructor with either a ready div or an ID of an existing div, and then
//implement their own methods to generate the header, extra and children content, and handle updates.
Node=function(divid,parent,opts) {
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
  this.children = [];
  this.parent = parent;
  this.updated = false;
  this.last_update = null;
  this.children_fetched = false;
  this.filtered_children = 0;
  this.to_update = [];
  this.clear=function() {
    while (this.div.hasChildNodes())
      this.div.removeChild(this.div.firstChild);
  }
  this.build=function() {
    this.clear();
    
    if (this.options['children']) {
      this.child_link = document.createElement('a');
      this.child_link.href='#';
      this.child_link.setAttribute('onclick',"toggleChildren('"+this.id+"');"); //this is an ugly hack to get around execution context - this.id is evaluated now in this context to make a string, instead of later if we set onclick to an actual function.
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
        this.extra_expand_div.setAttribute('onclick',"toggleExtra('"+this.id+"');");
        this.extra_expand_div.innerHTML='expand';
      }
    }
        
    this.main_div.id = this.id+'_main';
    this.header_div.id = this.id+'_header';

    this.main_div.className = 'node-main';
    this.header_div.className = 'node-header';
    
    
    if (this.options['children']) {
      this.header_div.appendChild(this.child_link);
    }
    this.span_header = document.createElement('span');
    this.header_div.appendChild(this.span_header);
    
    

    this.main_div.appendChild(this.header_div);
    if (this.options['extra']) {
      if (! this.options['fixed_extra']) {
        this.main_div.appendChild(this.extra_expand_div);
      }
      this.main_div.appendChild(this.extra_div);
    }
    
    this.div.appendChild(this.main_div);
    if (this.options['children']) {
      this.div.appendChild(this.children_info_div);
      this.div.appendChild(this.children_div);
    }

    
    this.buildHeader(this.span_header);
    if (this.options['extra']) {
      this.buildExtra(this.extra_div);
    }
    
    if (this.options['expand_extra'] && !this.options['fixed_extra']) {
      toggleExtra(this.id);
    }
    if (this.options['expand_children']) {
      toggleChildren(this.id);
    }    
  }
  this.buildHeader=function(span) {}
  this.buildExtra=function(div) {}
  this.fillHeader=function() {}
  this.fillExtra=function() {}
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
  }
  this.setDataExpiry=function(ms) {
    window.setTimeout("updateProxy('"+this.id+"');",ms);
  }
  this.event=function(arg0,arg1,arg2,arg3) {} //must be a better way of doing this
  this.filterClear=function() {
    this.filtered_children=0;
    for (var i in this.children) {
      this.children[i].filterClear();
      this.children[i].div.style.display='block';
    }
  }
  this.sortChildren=function() {}
  this.filter=function(filter_str) {return true;}
  this.sort=function(sort_key) {return 0;}
  this.clearChildren=function() {
    this.children=[];
    while(this.children_div.hasChildNodes()) 
      this.children_div.removeChild(this.children_div.firstChild);
  }
}
toggleChildren=function(id) {
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
toggleExtra=function(id) {
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

eventProxy=function(id,arg0,arg1,arg2,arg3) {
    var obj = document.getElementById(id).objLink;
    obj.event(arg0,arg1,arg2,arg3);
  }

updateProxy=function(id) {
    var obj = document.getElementById(id).objLink;
    obj.update();
}