PHEDEX.namespace('Component');
PHEDEX.Component.Subscribe = function(sandbox,args) {
  var _me = 'component-subscribe',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

  if ( !payload.panel ) {
    payload.panel =
    {
      Datasets:{
        fields:{
          dataset:{type:'text', tip:'Dataset name, with or without wildcards', dynamic:true },
        }
      },
      Blocks:{
        fields:{
          block:{type:'text', tip:'Block name, with or without wildcards', dynamic:true },
        }
      },
      Parameters:{
        fields:{
          is_move:  {type:'checkbox', text:'Make a "move" request?', tip:'Check this box to move the data, instead of simply copying it', attributes:{checked:false} },
          custodial:{type:'checkbox', text:'Make custodial request?', tip:'Check this box to make the request custodial', attributes:{checked:false} },
          priority: {type:'radio', fields:['low','medium','high'], text:'Priority', default:'low' },
          userGroup:{type:'regex', text:'User-group', tip:'enter a valid user-group name', nonNegatable:true },
          timeStart:{type:'regex', text:'Start-time for subscription', tip:'This is valid for datasets only. Unix epoch-time', nonNegatable:true }
        }
      }
    }
  }
//   this.id = _me+'_'+PxU.Sequence(); // don't set my own ID, inherit the one I get from the panel!
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));

  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0], field=arr[1], overlay=o.overlay, ctl=o.ctl['panelControl'];
      switch (action) {
        case 'add': {
          var _x=o, c, i, _panel=o.meta._panel;
          for (i in field) {
            c = _panel.fields[i];
            o.AddFieldsetElement(c,field[i]);
          }
          if ( ctl ) { ctl.Enable(); }
          else       { YuD.removeClass(overlay.element,'phedex-invisible'); }
          break;
        }
      }
    }
  }(this);
  _sbx.listen('buildRequest',this.cartHandler);

/**
 * construct a PHEDEX.Component.Subscribe object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      _init: function(args) {
        this.selfHandler = function(o) {
          return function(ev,arr) {
            var action    = arr[0],
                subAction = arr[1],
                value     = arr[2];
            switch (action) {
              case 'Panel': {
                switch (subAction) {
                  case 'Reset': {
                    break;
                  }
                  case 'Apply': {
var x = value;
                    break;
                  }
                }
                break;
              }
              case 'expand': { // set focus appropriately when the panel is revealed
                if ( !o.firstAlignmentDone ) {
                  o.overlay.align(this.context_el,this.align_el);
                  o.firstAlignmentDone = true;
                }
                if ( o.focusOn ) { o.focusOn.focus(); }
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);
      },
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-subscribe');