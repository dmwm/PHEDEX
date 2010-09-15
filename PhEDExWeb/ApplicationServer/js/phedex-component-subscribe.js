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
//         map:{from:'phedex-panel-dataset-', to:'P-D'},
        fields:{
          dataset:{type:'text', tip:'Dataset name, with or without wildcards', dynamic:true },
        }
      },
      Blocks:{
//         map:{from:'phedex-panel-block-', to:'P-B'},
        fields:{
          block:{type:'text', tip:'Block name, with or without wildcards', dynamic:true },
        }
      },
      Parameters:{
        fields:{
          custodial:{type:'yesno', fields:['Make custodial request?'], attributes:{checked:false} }
        }
      }
    }
  }
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));

  this.id = _me+'_'+PxU.Sequence();
//   this.selfHandler = function(o) {
//     return function(ev,arr) {
//       var action = arr[0],
//           subAction = arr[1];
//       switch (action) {
//         case 'Panel': {
//           switch (subAction) {
//             case 'Reset': {
//               break;
//             }
//             case 'Validate': {
//               break;
//             }
//             case 'Apply': {
//               break;
//             }
//           }
//           break;
//         }
//         case 'expand': { // set focus appropriately when the panel is revealed
//           if ( !o.firstAlignmentDone ) {
//             o.overlay.align(this.context_el,this.align_el);
//             o.firstAlignmentDone = true;
//           }
//           if ( o.focusOn ) { o.focusOn.focus(); }
//           break;
//         }
//       }
//     }
//   }(this);
//   _sbx.listen(this.id,this.selfHandler);

//   this.partnerHandler = function(o) {
//     return function(ev,arr) {
//       var action = arr[0];
//       switch (action) {
// //         case 'doPanel': {
// //           break;
// //         }
//       }
//     }
//   }(this);
//   _sbx.listen(obj.id,this.partnerHandler);

  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0], overlay=o.overlay, ctl=o.ctl['panelControl'];
      switch (action) {
        case 'add': {
          var _x=o, c, i, _panel=o.meta._panel;
          for (i in arr[1]) {
            c = _panel.fields[i];
            o.AddFieldsetElement(c,arr[1][i]);
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
 * construct a PHEDEX.Component.Panel object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      _init: function(args) {
      },
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-panel');