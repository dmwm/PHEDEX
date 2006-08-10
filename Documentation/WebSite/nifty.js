/* Cleaned up from http://webdesign.html.it/articoli/leggi/528/more-nifty-corners/ */
function NiftyCheck()
{
  if (!document.getElementById || !document.createElement)
    return false;

  isXHTML=/html\:/.test(document.getElementsByTagName('body')[0].nodeName);
  if (Array.prototype.push==null)
  {
    Array.prototype.push=function()
    {
      this[this.length]=arguments[0];
      return this.length;
    }
  }
  return true;
}

function Rounded(selector,which,bk,color,opt)
{
  var i,prefixt,prefixb,cn="r",ecolor="",edges=false,eclass="",b=false,t=false;
  if (color == "transparent")
  {
    cn = cn+"x";
    ecolor = bk;
    bk = "transparent";
  }
  else if (opt && opt.indexOf("border") >= 0)
  {
    var optar = opt.split(" ");
    for (i=0; i<optar.length; i++)
      if (optar[i].indexOf("#") >= 0)
         ecolor = optar[i];
    if (ecolor=="") ecolor="#666";
    cn += "e";
    edges = true;
  }
  else if (opt && opt.indexOf("smooth") >= 0)
  {
    cn += "a";
    ecolor = Mix(bk,color);
  }

  if (opt && opt.indexOf("small") >= 0)
    cn+="s";

  prefixt=cn;
  prefixb=cn;
  if (which.indexOf("all") >= 0)
    t = b = true;
  else if (which.indexOf("top") >= 0)
    t = true;
  else if (which.indexOf("tl") >= 0)
  {
    t = true;
    if (which.indexOf("tr") < 0)
      prefixt += "l";
  }
  else if (which.indexOf("tr") >= 0)
  {
    t = true;
    prefixt += "r";
  }
  if (which.indexOf("bottom") >= 0)
    b = true;
  else if (which.indexOf("bl") >= 0)
  {
    b = true;
    if (which.indexOf("br") < 0)
      prefixb += "l";
  }
  else if (which.indexOf("br") >= 0)
  {
    b = true;
    prefixb += "r";
  }

  var v=getElementsBySelector(selector);
  var l=v.length;
  for(i=0;i<l;i++)
  {
    if (edges) AddBorder(v[i],ecolor);
    if (t) AddTop(v[i],bk,color,ecolor,prefixt);
    if (b) AddBottom(v[i],bk,color,ecolor,prefixb);
  }
}

function AddBorder(el,bc)
{
  var i;
  if (! el.passed)
  {
    if (el.childNodes.length==1 && el.childNodes[0].nodeType==3)
    {
      var t=el.firstChild.nodeValue;
      el.removeChild(el.lastChild);
      var d=CreateEl("span");
      d.style.display="block";
      d.appendChild(document.createTextNode(t));
      el.appendChild(d);
    }
    for(i=0;i<el.childNodes.length;i++)
      if(el.childNodes[i].nodeType==1)
      {
        el.childNodes[i].style.borderLeft="1px solid "+bc;
        el.childNodes[i].style.borderRight="1px solid "+bc;
      }
  }
  el.passed=true;
}
    
function AddTop(el,bk,color,bc,cn)
{
  var i,lim=4,d=CreateEl("b");

  if (cn.indexOf("s") >= 0)
    lim=2;
  d.className = bc ? "artop" : "rtop";
  d.style.backgroundColor = bk;
  for (i=1;i<=lim;i++)
  {
    var x=CreateEl("b");
    x.className=cn + i;
    x.style.backgroundColor=color;
    if (bc) x.style.borderColor=bc;
    d.appendChild(x);
  }
  el.style.paddingTop=0;
  el.insertBefore(d,el.firstChild);
}

function AddBottom(el,bk,color,bc,cn)
{
  var i,lim=4,d=CreateEl("b");

  if (cn.indexOf("s") >= 0)
    lim=2;
  d.className = bc ? "artop" : "rtop";
  d.style.backgroundColor = bk;
  for (i=lim;i>0;i--)
  {
    var x=CreateEl("b");
    x.className=cn + i;
    x.style.backgroundColor=color;
    if (bc) x.style.borderColor=bc;
    d.appendChild(x);
  }
  el.style.paddingBottom=0;
  el.appendChild(d);
}

function CreateEl(x)
{
  if(isXHTML)
    return document.createElementNS('http://www.w3.org/1999/xhtml',x);
  else
    return document.createElement(x);
}

function getElementsBySelector(selector)
{
  var i,selid="",selclass="",tag=selector,f,s=[],objlist=[];

  if(selector.indexOf(" ")>0)
  {  //descendant selector like "tag#id tag"
    s=selector.split(" ");
    var fs=s[0].split("#");
    if(fs.length==1) return(objlist);
    f=document.getElementById(fs[1]);
    if(f) return(f.getElementsByTagName(s[1]));
    return(objlist);
  }

  if(selector.indexOf("#")>0)
  { //id selector like "tag#id"
    s=selector.split("#");
    tag=s[0];
    selid=s[1];
  }

  if(selid!="")
  {
    f=document.getElementById(selid);
    if(f) objlist.push(f);
    return(objlist);
  }

  if(selector.indexOf(".")>0)
  {  //class selector like "tag.class"
    s=selector.split(".");
    tag=s[0];
    selclass=s[1];
  }

  var v=document.getElementsByTagName(tag);  // tag selector like "tag"
  if(selclass=="")
    return(v);

  for(i=0;i<v.length;i++)
    if(v[i].className.indexOf(selclass)>=0)
      objlist.push(v[i]);

  return objlist;
}

function Mix(c1,c2)
{
  var r=new Array(3);
  var step1 = (c1.length==4 ? 1 : 2);
  var step2 = (c2.length==4 ? 1 : 2);
  for(var i=0;i<3;i++)
  {
    var x=parseInt(c1.substr(1+step1*i,step1),16);
    if(step1==1) x=16*x+x;
    var y=parseInt(c2.substr(1+step2*i,step2),16);
    if(step2==1) y=16*y+y;
    r[i]=Math.floor((x*50+y*50)/100);
  }
  return("#"+r[0].toString(16)+r[1].toString(16)+r[2].toString(16));
}
