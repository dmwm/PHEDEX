PHEDEX.History = function( config ) {
  var _sbx = new PHEDEX.Sandbox(),
      Dom = YAHOO.util.Dom,
      YuH = YAHOO.util.History,
      id = 'history_'+PxU.Sequence(),
      module = 's',
      undefined = 'undefined';
  if ( typeof(config) == 'object' ) {
    if ( config.module ) { module = config.module; }
  }
  log('creating "'+id+'"','info','history');

  _construct = function() {
    return {
      id: id,
      me: 'history',
      meta: {},
      handler: function(obj) {
        return function(ev,arr) {
          switch (arr[0]) {
            case 'navigate': {
              var s = YAHOO.util.History.getQueryStringParameter(module,arr[1]) || undefined;
              YuH.navigate(module,s);
              break;
            }
            default: {
              break;
            }
          }
        };
      }(this),
      onStateChange: function(state) {
        _sbx.notify('History','onStateChange',state);
      },
      init: function() {
        var initialState = YuH.getBookmarkedState(module) ||
                           YuH.getQueryStringParameter(module) ||
                           undefined;
        YuH.register(module,initialState,this.onStateChange,null,this);

        try {
          YuH.initialize('yui-history-field','yui-history-iframe');
        } catch (ex) {
          var _ex=ex;
          return;
        }

        YuH.onReady(function(obj) {
          return function() {
            var currentState = YuH.getCurrentState(module);
            _sbx.notify('History','initialiseApplication',currentState);
          }
        }(this));

        _sbx.listen('History',this.handler);
        _sbx.listen(this.id,  this.handler);
      },
    };
  };

  Yla(this, _construct());
try {
  this.init();
} catch (ex) {
var _ex = ex;
debugger;
}
  return this;
}

log('loaded...','info','history');