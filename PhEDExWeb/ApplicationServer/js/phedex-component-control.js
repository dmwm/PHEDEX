PHEDEX.namespace('Component');

PHEDEX.Component.Control = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'Component-Control',
      _sbx = sandbox,
      _notify = function() {};

  _clickHandler=function(ev,obj) {
    if ( ev.type == 'mouseover' ) {
      obj.Show();
    } else if ( ev.type == 'click' ) {
      if ( obj.isHidden() ) { obj.Show(); }
      else { obj.Hide(); }
    }
  };
  _mouseoverHandler = function(ev,obj) {
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
      me: _me,
      enabled: 1,
      payload: {},
      _init: function(args) {
        if ( !args.payload.type ) { args.payload.type = 'a'; }
        this.id = this.me+'_'+PxU.Sequence();
        this.el = document.createElement(args.type);
        if ( args.payload.type == 'img' ) {
          this.el.src = args.src;
        } else if ( args.payload.type == 'a' ) {
          this.el.appendChild(document.createTextNode(args.payload.text || args.name));
        }
        for (var i in args.payload) { this.payload[i] = args.payload[i]; }
        if ( this.payload.target ) {
          if ( this.payload.obj ) {
            if ( typeof(this.payload.target) != 'object' ) {  this.payload.target = this.payload.obj.dom[this.payload.target]; }
          }
          if ( typeof(this.payload.target) != 'object' ) { this.payload.target = document.getElementById(this.payload.target); }
        }
        YAHOO.util.Dom.addClass(this.payload.target,'phedex-invisible');
        this.el.className = args.payload.className || 'phedex-core-control-widget phedex-core-control-widget-inactive';
        if ( !args.events ) {
          args.events = [
                    {event:'mouseover', handler:_mouseoverHandler},
                    {event:'mouseout',  handler:_mouseoutHandler},
                    {event:'click',     handler:_clickHandler}];
        }
        for (var i in args.events) {
          var ev = args.events[i].event,
              fn = args.events[i].handler || PHEDEX.Component.Control.clickHandler,
              el = args.events[i].element || this.el;
          YAHOO.util.Event.addListener(el,ev,fn,this,true);
        }
        if ( this.payload.obj ) {
          var partner = this.payload.obj.id;
          _notify = function() {
            var x = Array.apply(null,arguments);
            x.unshift(partner);
            _sbx.notify.apply(_sbx,x);
          }
        }

        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value = arr[1];
            switch (action) {
              case 'expand': {
                var tgt = obj.payload.target;
                if ( tgt ) {
                  var eHeight = tgt.offsetHeight;
                  _notify('show target',eHeight);
                } else {
                  if ( value == 'done' ) { obj.Hide(); }
                }
                break;
              }
              default: { log('unhandled event: '+action,'warn',me); break; }
            }
          }
        }(this);
        _sbx.listen(this.id,selfHandler);
      },
      Show: function() {
        var p   = this.payload,
            tgt = p.target;
        if ( !this.enabled ) { return; }
        if ( tgt && !YAHOO.util.Dom.hasClass(tgt,'phedex-invisible') ) { return; }
        if ( p.handler ) {
          if ( typeof(p.handler) == 'string' ) {
            _notify('expand',p.handler,this.id);
          }
          else if ( typeof(p.handler) == 'function' ) {
            p.handler();
          }
        }
        if ( tgt ) { YAHOO.util.Dom.removeClass(tgt,'phedex-invisible'); }
        YAHOO.util.Dom.removeClass(this.el,'phedex-core-control-widget-inactive');
        YAHOO.util.Dom.addClass   (this.el,'phedex-core-control-widget-active');
      },
      Hide: function() {
        var tgt = this.payload.target,
            eHeight, reallyHide;
        if ( tgt ) {
          eHeight = tgt.offsetHeight;
          reallyHide=function(ctl) {
            return function() {
              var tgt = ctl.payload.target;
              YAHOO.util.Dom.addClass(tgt,'phedex-invisible');
              YAHOO.util.Dom.removeClass(tgt,'phedex-hide-overflow');
              tgt.style.height=null;
//             if ( ctl.payload.onHideControl ) { ctl.payload.onHideControl.fire(eHeight); }
              _notify('hide target',eHeight);
              YAHOO.util.Dom.addClass   (ctl.el,'phedex-core-control-widget-inactive');
              YAHOO.util.Dom.removeClass(ctl.el,'phedex-core-control-widget-active');
            };
          }(this);
        } else {
          reallyHide=function(ctl) {
            return function() {
              YAHOO.util.Dom.addClass   (ctl.el,'phedex-core-control-widget-inactive');
              YAHOO.util.Dom.removeClass(ctl.el,'phedex-core-control-widget-active');
            };
          }(this);
        }

//      Only fail to animate if payload.animate was explicitly set to 'false'
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
        if ( !tgt ) { return 1; }
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