PHEDEX.namespace('Core.Control');

PHEDEX.Core.Control = function(args) {
  if ( !args.type ) { args.type = 'a'; }
  this.el = document.createElement(args.type);
  this.payload = [];
  if ( args.type == 'img' ) {
    this.el.src = args.src;
  } else if ( args.type == 'a' ) {
    this.el.href='#';
    this.el.appendChild(document.createTextNode(args.text));
  }
  for (var i in args.payload) { this.payload[i] = args.payload[i]; }
  if ( typeof(this.payload.target) != 'object' ) { this.payload.target = document.getElementById(this.payload.target); }
  YAHOO.util.Dom.addClass(this.payload.target,'phedex-invisible');
  this.el.className = args.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
  if ( !args.events ) {
    args.events = [{event:'mouseover', handler:PHEDEX.Core.Control.mouseoverHandler},
                   {event:'mouseout',  handler:PHEDEX.Core.Control.mouseoutHandler},
                   {event:'click',     handler:PHEDEX.Core.Control.controlHandler}];
  }
  for (var i in args.events) {
    var ev = args.events[i].event;
    var fn = args.events[i].handler || PHEDEX.Core.Control.controlHandler;
    var el = args.events[i].element || this.el; // doesn't seem to work when I use something other than the ctl itself...
    YAHOO.util.Event.addListener(el,ev,fn,this,true);
  }
  if ( this.payload.render ) {
    var renderInto = this.payload.render;
    if ( typeof(renderInto) != 'object' ) { renderInto = document.getElementById(renderInto); }
    renderInto.appendChild(this.el);
  }
  this.Show = function() {
    var tgt = this.payload.target;
    if ( !YAHOO.util.Dom.hasClass(tgt,'phedex-invisible') ) { return; }
    if ( this.payload.fillFn ) { this.payload.fillFn(tgt); }
    var obj = this.payload.obj || {};
    YAHOO.util.Dom.removeClass(tgt,'phedex-invisible');
    var eHeight = tgt.offsetHeight;
    if ( obj.onShowControl ) { obj.onShowControl.fire(eHeight); }
    YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-inactive');
    YAHOO.util.Dom.addClass   (this.el,'phedex-core-control-widget-active');
  }
  this.Hide = function() {
    var tgt = this.payload.target;
    var eHeight = tgt.offsetHeight;
    var reallyHide=function(ctl) {
      return function() {
        var tgt = ctl.payload.target;
        YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
        YAHOO.util.Dom.removeClass(tgt,'phedex-hide-overflow');
        tgt.style.height=null;
        var obj = ctl.payload.obj || {};
        if ( obj.onHideControl ) { obj.onHideControl.fire(eHeight); }
        YAHOO.util.Dom.addClass   (ctl.el,'phedex-core-control-widget-inactive');
        YAHOO.util.Dom.removeClass(ctl.el,'phedex-core-control-widget-active');
      };
    }(this);
//  Only fail to animate if payload.animate was explicitly set to 'false'
    if ( typeof(this.payload.animate) == 'undefined' ) { this.payload.animate=true; }
    if ( this.payload.animate ) {
      var attributes = { height: { to: 0 }  }; 
      if ( typeof(this.payload.animate) == 'object' ) { attributes = this.payload.animate.attributes; }
      var duration = this.payload.animate.duration_hide || this.payload.animate.duration || 0.5;
      var anim = new YAHOO.util.Anim(tgt, attributes, duration);
      YAHOO.util.Dom.addClass(tgt,'phedex-hide-overflow');
      anim.onComplete.subscribe(reallyHide);
      anim.animate();
    } else {
      reallyHide();
    }
  }
  this.isHidden = function() {
    var tgt = this.payload.target;
    return YAHOO.util.Dom.hasClass(tgt,'phedex-invisible');
  }
  this.Label = function(text) {
    this.el.innerHTML = text;
  }
  return this;
};

PHEDEX.Core.Control.mouseoverHandler=function(ev,obj) {
  var timeout = obj.payload.hover_timeout || 500;
  obj.payload.timer = setTimeout(function() { PHEDEX.Core.Control.controlHandler(ev,obj) },timeout);
}
PHEDEX.Core.Control.mouseoutHandler=function(ev,obj) {
  if ( obj.payload.timer ) { clearTimeout(obj.payload.timer); }
  obj.payload.timer = null
}

PHEDEX.Core.Control.controlHandler=function(ev,obj) {
    var eHeight;
    var tgt = obj.payload.target;
    if ( ev.type == 'mouseover' ) {
      obj.Show();
    } else if ( ev.type == 'click' ) {
      if ( obj.isHidden() ) { obj.Show(); }
      else { obj.Hide(); }
    }
  }

YAHOO.log('loaded...','info','Core.Control');