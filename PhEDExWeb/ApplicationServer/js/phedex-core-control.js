PHEDEX.namespace('Core.Control');

PHEDEX.Core.Control = function(args) {
  var ctl;
  ctl = document.createElement(args.type);
  ctl.payload = [];
  if ( args.type == 'img' ) {
    ctl.src = args.src;
  } else if ( args.type == 'a' ) {
    ctl.href='#';
    ctl.appendChild(document.createTextNode(args.text));
  }
  for (var i in args.payload) { ctl.payload[i] = args.payload[i]; }
  YAHOO.util.Dom.addClass(ctl.payload.target,'phedex-invisible');
  ctl.className = args.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
  for (var i in args.events) {
    var ev = args.events[i].event;
    var fn = args.events[i].handler || PHEDEX.Core.Control;
    var el = args.events[i].element || ctl; // doesn't seem to work when I use something other than the ctl itself...
    YAHOO.util.Event.addListener(el,ev,fn,ctl);
  }
  if ( ctl.payload.render ) {
    var renderInto = ctl.payload.render;
    if ( typeof(renderInto) != 'object' ) { renderInto = document.getElementById(renderInto); }
    renderInto.appendChild(ctl);
  }

  ctl.Show = function() {
    var tgt = this.payload.target;
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
    if ( !YAHOO.util.Dom.hasClass(tgt,'phedex-invisible') ) { return; }
    if ( this.payload.fillFn ) { this.payload.fillFn(tgt); }
    var obj = this.payload.obj || {};
    YAHOO.util.Dom.removeClass(tgt,'phedex-invisible');
    var eHeight = tgt.offsetHeight;
    if ( obj.onShowControl ) { obj.onShowControl.fire(eHeight); }
    YAHOO.util.Dom.removeClass(this,'phedex-core-control-widget-inactive');
    YAHOO.util.Dom.addClass   (this,'phedex-core-control-widget-active');
  }
  ctl.Hide = function() {
    var tgt = this.payload.target;
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
    var eHeight = tgt.offsetHeight;
    var obj = this.payload.obj || {};
    YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
    if ( obj.onHideControl ) { obj.onHideControl.fire(eHeight); }
    YAHOO.util.Dom.addClass   (this,'phedex-core-control-widget-inactive');
    YAHOO.util.Dom.removeClass(this,'phedex-core-control-widget-active');
  }
  return ctl;
}

PHEDEX.Core.Control.controlHandler=function(ev,obj) {
    var eHeight;
    var tgt = this.payload.target;
    if ( typeof(tgt) != 'object' ) { tgt = document.getElementById(tgt); }
    var fillFn = this.payload.fillFn;
    if ( ev.type == 'mouseover' ) {
      this.Show();
    } else if ( ev.type == 'click' ) {
      this.Hide();
    }
  }

YAHOO.log('loaded...','info','Core.Control');