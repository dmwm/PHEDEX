PHEDEX.History = new (function() {
  var _sbx = new PHEDEX.Sandbox(),
      Dom = YAHOO.util.Dom,
      YuH = YAHOO.util.History,
      id = 'history_'+PxU.Sequence();
  log('creating "'+id+'"','info','history');

  _construct = function() {
    return {
      id: id,
      me: 'history',
      meta: {},
      init: function() {
        try {
          YuH.initialize("yui-history-field", "yui-history-iframe");
        } catch (ex) {
          var _ex=ex;
          return;
        }

debugger;
        var initialState = YuH.getBookmarkedState('page');
        if ( initialState ) { _sbx.notify(this.id,'History',initialState); }
      },
      setState: function() {
debugger;
      },
    };
  };

  Yla(this, _construct());
  this.init();
  return this;
})();

log('loaded...','info','history');