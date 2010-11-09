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
                input     = sel,
                container = d.container, id=o.id;
            if ( !container ) { container = d.container = PxU.makeChild(payload.container, 'div'); }
            container.innerHTML = input.innerHTML = '';

            makeList = function(data) {
              if ( !data[dataKey] ) {
                banner('Error making '+api+' call, autocomplete will not work','error');
                log('error making '+api+' call: '+err(data),'error',o.id);
                return;
              }
              data = data[dataKey];
              var list=[], i;
              for (i in data.sort()) {
                list.push(data[i].name);
              }
              if ( list.length == 0 ) {
                payload.el.value = '';
                payload.el.title = 'No values were found for this field';
                payload.el.disabled = true;
                return;
              }
              if ( list.length == 1 ) {
//                 _sbx.notify(obj.id,payload.handler,list[0]); // TODO not enough! the parent object isn't listening yet, it hasn't been constructed!
                payload.el.value = payload.el.title = list[0];
                payload.el.disabled = true;
                return;
              }
              o.buildAutocomplete(input,container,list.sort(),argKey);
            };
            PHEDEX.Datasvc.Call({ api:api, callback:makeList });
//             var k1 = new Yu.KeyListener(
//               input,
//               { keys: Yu.KeyListener.KEY['ENTER'] },
//               { fn:function(o){
//                 return function(_a,_b,_c,_d) {
// // debugger;
// //                   if ( !_typeArgs[_type] ) { _typeArgs[_type] = {}; }
// //                   _typeArgs[_type][argKey] = input.value;
// //                   _sbx.notify(obj.id,'TargetSelected',_type,_typeArgs[_type]);
//                 }
//               }(o), scope:o, correctScope:true }
//             );
//             k1.enable();

            return sel;
          };
        }(this);
        _sbx.listen('InstanceChanged',this.makeSelector);
        this.buildAutocomplete = function(input,container,list,key) {
          if ( this.auto_comp ) { this.auto_comp.destroy(); }
          var ds  = new Yu.LocalDataSource(list),
              cfg = {
                prehighlightClassName:"yui-ac-prehighlight",
                useShadow: true,
                forceSelection: payload.forceSelection,
                queryMatchCase: false,
                queryMatchContains: true
              },
              auto_comp = new Yw.AutoComplete(input, container, ds, cfg),
          selection_callback = function(_dummy, args) {
            if ( !payload.handler ) { return; }
            _sbx.notify(obj.id,payload.handler,args[2][0]);
          },
          unmatchedSelection_callback = function(_evt,_autoComplete) {
            if ( !payload.handler ) { return; }
            _sbx.notify(obj.id,payload.handler,payload.el.value);
          }
          auto_comp.formatResult = function( oResultData, sQuery, sResultMatch ) {
            if ( !oResultData ) { return; }
            var str = '<div class="result" title="'+oResultData+'">'+oResultData+'</div>';
            return str;
          }
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
