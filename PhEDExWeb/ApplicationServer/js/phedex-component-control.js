PHEDEX.namespace('Component');

PHEDEX.Component.Control = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _sbx = sandbox,
      _obj_id;

  _clickHandler=function(ev,obj) {
    var eHeight;
    var tgt = obj.payload.target;
    if ( ev.type == 'mouseover' ) {
      obj.Show();
    } else if ( ev.type == 'click' ) {
      if ( obj.isHidden() ) { obj.Show(); }
      else { obj.Hide(); }
    }
  };
  _mouseoverHandler = function(ev, obj) {
    try {
      this.el.style.cursor = "pointer"; //Change the mouse cursor to hand symbol
    }
    catch (ex) { }
    var timeout = obj.payload.hover_timeout;
    if ( !timeout ) { return; }
    obj.payload.timer = setTimeout(function() { _clickHandler(ev,obj) },timeout);
  }
  _mouseoutHandler=function(ev,obj) {
    if ( obj.payload.timer ) {
      clearTimeout(obj.payload.timer);
      obj.payload.timer = null;
    }
  }

  _construct = function() {
    return {
      me: 'ComponentControl_'+PxU.Sequence(),
      _sbx: sandbox,
      enabled: 1,
      payload: {},
      _init: function(args) {
        if ( !args.type ) { args.type = 'a'; }
        this.el = document.createElement(args.type);
        if ( args.type == 'img' ) {
          this.el.src = args.src;
        } else if ( args.type == 'a' ) {
          this.el.appendChild(document.createTextNode(args.text || args.name));
        }
        for (var i in args.payload) { this.payload[i] = args.payload[i]; }
        if ( this.payload.obj ) {
          if ( typeof(this.payload.target) != 'object' ) {  this.payload.target = this.payload.obj.dom[this.payload.target]; }
        }
        if ( typeof(this.payload.target) != 'object' ) { this.payload.target = document.getElementById(this.payload.target); }
        YAHOO.util.Dom.addClass(this.payload.target,'phedex-invisible');
        this.el.className = args.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
        if ( !args.events ) {
          args.events = [
                    {event:'mouseover', handler:_mouseoverHandler},
                    {event:'mouseout',  handler:_mouseoutHandler},
                    {event:'click',     handler:_clickHandler}];
        }
        for (var i in args.events) {
          var ev = args.events[i].event,
              fn = args.events[i].handler || PHEDEX.Component.Control.clickHandler,
              el = args.events[i].element || this.el; // doesn't seem to work when I use something other than the ctl itself...
          YAHOO.util.Event.addListener(el,ev,fn,this,true);
        }
        _obj_id = this.payload.obj.id;
      },
      Show: function() {
        var tgt = this.payload.target;
        if ( !this.enabled ) { return; }
        if ( !YAHOO.util.Dom.hasClass(tgt,'phedex-invisible') ) { return; }
        if ( this.payload.handler ) { this.payload.handler.apply(this.payload.obj,[tgt, this.payload.fillArgs]); } this.payload.target.innerHTML='asdf';
        YAHOO.util.Dom.removeClass(tgt,'phedex-invisible');
        var eHeight = tgt.offsetHeight;
        if ( this.payload.onShowControl ) { this.payload.onShowControl.fire(eHeight); }
        _sbx.notify(_obj_id,'grow header',eHeight);
        YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-inactive');
        YAHOO.util.Dom.addClass   (this.el,'phedex-core-control-widget-active');
      },
      Hide: function() {
        var tgt = this.payload.target,
            eHeight = tgt.offsetHeight,
            reallyHide=function(ctl) {
          return function() {
            var tgt = ctl.payload.target;
            YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
            YAHOO.util.Dom.removeClass(tgt,'phedex-hide-overflow');
            tgt.style.height=null;
            if ( ctl.payload.onHideControl ) { ctl.payload.onHideControl.fire(eHeight); }
            _sbx.notify(_obj_id,'shrink header',eHeight);
            YAHOO.util.Dom.addClass   (ctl.el,'phedex-core-control-widget-inactive');
            YAHOO.util.Dom.removeClass(ctl.el,'phedex-core-control-widget-active');
          };
        }(this);
//      Only fail to animate if payload.animate was explicitly set to 'false'
        if ( typeof(this.payload.animate) == 'undefined' ) { this.payload.animate=true; }
        if ( this.payload.animate ) {
          var attributes = { height: { to: 0 }  }; 
          if ( typeof(this.payload.animate) == 'object' ) { attributes = this.payload.animate.attributes; }
          var duration = this.payload.animate.duration_hide || this.payload.animate.duration || 0.5,
              anim = new YAHOO.util.Anim(tgt, attributes, duration);
          YAHOO.util.Dom.addClass(tgt,'phedex-hide-overflow');
          anim.onComplete.subscribe(reallyHide);
          anim.animate();
        } else {
          reallyHide();
        }
      },
      isHidden: function() {
        var tgt = this.payload.target;
        return YAHOO.util.Dom.hasClass(tgt,'phedex-invisible');
      },
      Label: function(text) {
        this.el.innerHTML = text;
      },
      Enable: function() {
        YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-disabled');
        this.enabled = 1;
      },
      Disable: function() {
        YAHOO.util.Dom.addClass(this.el,'phedex-core-control-widget-disabled');
        this.enabled = 0;
      },
      setApplied: function(isApplied) {
        if ( typeof(isApplied) == 'undefined' ) { return; }
        if ( isApplied ) { YAHOO.util.Dom.addClass   (this.el,'phedex-core-control-widget-applied'); }
        else             { YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-applied'); }
      }
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
}

YAHOO.log('loaded...','info','Component.Control');