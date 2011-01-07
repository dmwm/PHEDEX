/**
 * This class creates a Refresh decorator specification, to allow the user to fetch new data for the module.
 * @namespace PHEDEX.Component
 * @class Refresh
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param args {object} reference to an object that specifies details of how the control should operate.
 */
PHEDEX.namespace('Component');
PHEDEX.Component.Refresh = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-refresh',
      _sbx = sandbox,
      partner = args.partner,
      ap = args.payload,
      defaults = {
        handler: 'getData',
        animate:  false,
        disabled: true,
        control:{
          payload: {
            text:'Refresh',
            hidden:false,
//             disabled:true,
            obj:this
          }
        }
      };
  Yla(ap,defaults);

  _construct = function() {
    var payload=args.payload, obj=payload.obj, apc=payload.control;
    return {
      me: _me,
      id: _me+'_'+PxU.Sequence(),
      payload: {},

      refreshInterval: function() {
        var delta = new Date().getTime()/1000,
            expires = obj.data_expires;
        if ( !expires ) { return 30; }
        return expires-delta;
      },
      setRefreshTimeout: function() {
        var expires = this.refreshInterval();
        if ( expires ) {
          setTimeout( function(obj) {
              if ( !obj.id ) { return; } // I may bave been destroyed before this timer fires
              obj.Enable();
            }, expires*1000, this.ctl.Refresh );
        }
      },
/**
 * Initialise the control. Called internally.
 * @method _init
 * @private
 * @param args {object} the arguments passed into the contructor
 */
      _init: function(args) {
        apc.payload.tooltip = function() {
                var expires = this.obj.refreshInterval();
                if ( !expires ) { return; }
                if ( expires < 0 ) { return; }
                return 'Data expires in '+Math.round(expires)+' seconds';
            };
        apc.payload.handler = 'doRefresh';
        var ctl = this.ctl.Refresh = new PHEDEX.Component.Control( _sbx, apc );
        if ( this.refreshInterval() ) { ctl.Disable(); }
        
        obj.dom.control.appendChild(ctl.el);
        this.setRefreshTimeout();
        this.selfHandler = function(o) {
          return function(ev,arr) {
            switch (arr[0]) {
              case 'gotData': {
                break;
              }
              case 'activate': {
                o.ctl.Refresh.Hide();
                o.ctl.Refresh.Disable();
                obj.getData();
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);
        this.partnerHandler = function(o) {
          return function(ev,arr) {
            switch (arr[0]) {
              case 'gotData': {
                o.setRefreshTimeout();
                break;
              }
            }
          }
        }(this);
        _sbx.listen(obj.id,this.partnerHandler);
      },
    }
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
};

log('loaded...','info','component-refresh');
