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
  YAHOO.util.Dom.addClass(this.payload.target,'phedex-invisible');
  this.el.className = args.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
  if ( !args.events ) {
    args.events = [{event:'mouseover', handler:PHEDEX.Core.Control.controlHandler},
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
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
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
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
    var eHeight = tgt.offsetHeight;
    var obj = this.payload.obj || {};
    YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
    if ( obj.onHideControl ) { obj.onHideControl.fire(eHeight); }
    YAHOO.util.Dom.addClass   (this.el,'phedex-core-control-widget-inactive');
    YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-active');
  }
  this.Label = function(text) {
    this.el.innerHTML = text;
  }
  return this;
};

PHEDEX.Core.Control.controlHandler=function(ev,obj) {
    var eHeight;
    var tgt = obj.payload.target;
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
    if ( ev.type == 'mouseover' ) {
      obj.Show();
    } else if ( ev.type == 'click' ) {
      obj.Hide();
    }
  }

YAHOO.log('loaded...','info','Core.Control');