/**
 * This class creates an AutoComplete decorator specification, to allow auto-completion of user-input.
 * @namespace PHEDEX.Component
 * @class AutoComplete
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate.
 */
PHEDEX.namespace('Component');
PHEDEX.Component.AutoComplete = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-autocomplete',
      _sbx = sandbox;

  _construct = function() {
    var payload=args.payload, obj=payload.obj;
    return {
      me: _me,
      id: _me+'_'+PxU.Sequence(),
      payload: {},
      dom: {},

/**
 * Initialise the control. Called internally..
 * @method _init
 * @private
 * @param args {object} the arguments passed into the contructor
 */
      _init: function(args) {
        var el = payload.el,
            type,
            dataKey = payload.dataKey,
            api     = payload.api,
            argKey  = payload.argKey;
        this.makeSelector = function(o) {
          return function() {
            var d         = o.dom,
                sel       = el || d.sel,
                input     = sel/*d.input*/,
                container = d.container, id=o.id;
//               sel = PxU.makeChild(el, 'div', { 'className': 'phedex-nav-component' }),
//             input     = PxU.makeChild(sel, 'input', { type: 'text', title: 'enter a valid "'+dataKey+'" name (wildcards allowed)' }),
            if ( !container ) { container = d.container = PxU.makeChild(payload.container, 'div'); }
            container.innerHTML = input.innerHTML = '';

            makeList = function(data) {
              if ( !data[dataKey] ) {
                banner('Error making '+api+' call, autocomplete will not work','error');
                log('error making '+api+' call: '+err(data),'error',me);
                return;
              }
              data = data[dataKey];
              var list=[], i;
              for (i in data.sort()) {
                list.push(data[i].name);
              }
              if ( list.length == 0 ) { return; }
              o.buildAutocomplete(input,container,list.sort(),argKey);
            };
            PHEDEX.Datasvc.Call({ api:api, callback:makeList });
//             _selectors[type].needValue = true;
//             _selectors[type].updateGUI = function(i) {
//               return function(value) {
//                 log('updateGUI for _selectors['+type+'], value='+value,'info',me);
//                 i.value = value;// || _state[_type]; // Is this correct? What if Instance has changed? What if the target is coming from history?
//               }
//             }(input);
//             _selectors[type].value = function(i) {
//               return function() {
//                 return i.value;
//               }
//             }(input);

            var k1 = new Yu.KeyListener(
              input,
              { keys: Yu.KeyListener.KEY['ENTER'] },
              { fn:function(o){
                return function() {
                  if ( !_typeArgs[_type] ) { _typeArgs[_type] = {}; }
                  _typeArgs[_type][argKey] = input.value;
                  _sbx.notify(obj.id,'TargetSelected',_type,_typeArgs[_type]);
                }
              }(o), scope:o, correctScope:true }
            );
            k1.enable();

            return sel;
          };
        }(this);

        this.buildAutocomplete = function(input,container,list,key) {
          var ds  = new Yu.LocalDataSource(list),
              cfg = {
                prehighlightClassName:"yui-ac-prehighlight",
                useShadow: true,
//                forceSelection: true,
                queryMatchCase: false,
                queryMatchContains: true
              },
              auto_comp = new Yw.AutoComplete(input, container, ds, cfg),
          selection_callback = function(_dummy, args) {
            var value = args[2][0];
//             _state[_type] = value;
//             if ( ! _typeArgs[_type] ) { _typeArgs[_type] = {}; }
//             _typeArgs[_type][key] = value;
//             _sbx.notify(obj.id,'TargetSelected',_type,_typeArgs[_type]);
// debugger;
          },
          unmatchedSelection_callback = function(_k) {
            return function(_dummy, args) {
// debugger;
//               var value = _selectors[_t].value();
//               _state[_t] = value;
//               if ( ! _typeArgs[_t] ) { _typeArgs[_t] = {}; }
//               if ( _typeArgs[_t][_k] == value ) { return; }
//               _typeArgs[_t][_k] = value;
//               _sbx.notify(obj.id,'TargetSelected',_t,_typeArgs[_t]);
            }
          }(key);
          auto_comp.itemSelectEvent.subscribe(selection_callback);
          auto_comp.unmatchedItemSelectEvent.subscribe(unmatchedSelection_callback);
          this.auto_comp = auto_comp;
        };
        this.makeSelector();
      }
    }
  }
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
};

log('loaded...','info','component-autocomplete');
