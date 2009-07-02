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
  ctl.className = args.className || 'phedex-core-control-widget-inactive';
  if ( !ctl.payload.render ) { ctl.payload.render = document.body; }
  for (var i in args.events) {
    var ev = args.events[i].event;
    var fn = args.events[i].handler || PHEDEX.Core.Control;
    var el = args.events[i].element || ctl; // doesn't seem to work when I use something other than the ctl itself...
    YAHOO.util.Event.addListener(el,ev,fn,ctl);
  }
  return ctl;
}

PHEDEX.Core.Control.controlHandler=function(ev,obj) {
    var eHeight;
    var tgt = this.payload.target || obj.div_extra;
    var fillFn = this.payload.fillFn || obj.fillExtra;
    if ( ev.type == 'mouseover' ) {
      if ( !YAHOO.util.Dom.hasClass(tgt,'phedex-invisible') ) { return; } // if ( !tgt.style.display ) { return; }
      if ( fillFn ) { fillFn(tgt); }
      YAHOO.util.Dom.removeClass(tgt,'phedex-invisible');
      eHeight = tgt.offsetHeight;
      if ( obj.onShowControl ) { obj.onShowControl.fire(eHeight); }
      YAHOO.util.Dom.removeClass(this,'phedex-core-control-widget-inactive');
      YAHOO.util.Dom.addClass   (this,'phedex-core-control-widget-active');
    } else if ( ev.type == 'click' ) {
      eHeight = tgt.offsetHeight;
      YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
      if ( obj.onHideControl ) { obj.onHideControl.fire(eHeight); }
      YAHOO.util.Dom.addClass   (this,'phedex-core-control-widget-inactive');
      YAHOO.util.Dom.removeClass(this,'phedex-core-control-widget-active');
    }
  }

YAHOO.log('loaded...','info','Core.Control');