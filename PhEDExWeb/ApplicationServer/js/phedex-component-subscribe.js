PHEDEX.namespace('Component');
PHEDEX.Component.Subscribe = function(sandbox,args) {
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));
  var _me = 'component-subscribe',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

//   Yla(this, new PHEDEX[obj.type].Panel(sandbox,obj));

  this.id = _me+'_'+PxU.Sequence();
  this.selfHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          subAction = arr[1];
      switch (action) {
        case 'Panel': {
          switch (subAction) {
            case 'Reset': {
              break;
            }
            case 'Validate': {
              break;
            }
            case 'Apply': {
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
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0];
      switch (action) {
//         case 'doPanel': {
//           break;
//         }
      }
    }
  }(this);
  _sbx.listen(obj.id,this.partnerHandler);
  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0], overlay=o.overlay, ctl=o.ctl['panelControl'];
      switch (action) {
        case 'add': {
          var _x=o, c, i, _panel=o.meta._panel, n=document.createTextNode(Ylang.JSON.stringify(arr[1]));
          n.textContent += '<br/>';
          overlay.appendToBody(n);
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
//         this.BuildPanel();
      },

//       BuildPanel: function() {
//         this.dom.panel.innerHTML = null;
//         if ( !this.ctl )  { this.ctl = {}; }
//         var _panel = this.meta._panel, label, fieldset, legend, helpClass, helpCtl, hideClass, hideCtl, key, tt, id, text, k1;
//         for (label in _panel.structure['f']) {
//           fieldset = document.createElement('fieldset');
//           legend = document.createElement('legend');
// 
//           helpClass = 'phedex-panel-help-class-'+PHEDEX.Util.Sequence();
//           helpCtl = document.createElement('span');
// 
//           hideClass = 'phedex-panel-hide-class-'+PHEDEX.Util.Sequence();
//           hideCtl = document.createElement('span');
// 
//           legend.appendChild(document.createTextNode(label));
//           fieldset.appendChild(legend);
// 
//           helpCtl.appendChild(document.createTextNode('[?]'));
//           helpCtl.id = 'help_' +PxU.Sequence();
//           ttIds.push(helpCtl.id);
//           ttHelp[helpCtl.id] = 'Click here for any additional help that may have been provided';
//           YuE.addListener(helpCtl, 'click', function(aClass,anElement) {
//             return function() { PxU.toggleVisible(aClass,anElement) };
//           }(helpClass,fieldset) );
//           legend.appendChild(document.createTextNode(' '));
//           legend.appendChild(helpCtl);
// 
//           hideCtl.appendChild(document.createTextNode('[x]'));
//           hideCtl.id = 'help_' +PxU.Sequence();
//           ttIds.push(hideCtl.id);
//           ttHelp[hideCtl.id] = 'Click here to collapse or expand this group of panel-elements';
//           YuE.addListener(hideCtl, 'click', function(aClass,anElement) {
//               return function() { PxU.toggleVisible(aClass,anElement) };
//           }(hideClass,fieldset) );
//           legend.appendChild(document.createTextNode(' '));
//           legend.appendChild(hideCtl);
//           for (key in _panel.structure['f'][label]) {
//             var c = _panel.fields[key],
//                 focusOn, outer, inner, e, value, i, fields, cBox, fieldLabel, help,  el, size, def;
// 
//             outer = document.createElement('div');
//             inner = document.createElement('div');
//             outer.className = 'phedex-panel-outer phedex-visible '+hideClass;
//             inner.className = 'phedex-panel-inner';
//             inner.id = 'phedex_panel_inner_'+PHEDEX.Util.Sequence();
//             this.meta.el[inner.id] = inner;
//             this.meta.inner[inner.id] = [];
//             e = this.typeMap[c.type];
//             if ( !e ) {
//               log('unknown panel-type"'+c.type+'", aborting','error',_me);
//               return;
//             }
// 
//             if ( c.tip ) {
//               help = document.createElement('div');
//               help.className = 'phedex-panel-help phedex-invisible float-right '+helpClass;
//               help.appendChild(document.createTextNode(c.tip));
//               outer.appendChild(help);
//             }
//             fieldset.appendChild(outer);
//           }
//           this.dom.panel.appendChild(fieldset);
//         }
//           tt = new Yw.Tooltip("ttB", { context:ttIds }), ttCount={};
//           tt.contextMouseOverEvent.subscribe( // prevent tooltip from showing more than a few times, to avoid upsetting experts
//             function(type, args) {
//               id = args[0].id;
//               text = ttHelp[args[0].id];
//               if ( text ) {
//                 if ( !ttCount[id] ) { ttCount[id]=0; }
//                 if ( ttCount[id]++ > 2 ) { return false; }
//                 return true;
//               }
//             }
//           );
//           tt.contextTriggerEvent.subscribe(
//             function(type, args) {
//               text = ttHelp[args[0].id];
//               this.element.style.zIndex = 1000;
//               this.cfg.setProperty('text', text);
//             }
//           );
//         k1 = new Yu.KeyListener(this.dom.panel,
//                                           { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
//                                           { fn:function(obj){ return function() { _sbx.notify(obj.id,'Panel','Validate'); } }(this),
//                                             scope:this, correctScope:true } );
//         k1.enable();
//       }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-panel');
