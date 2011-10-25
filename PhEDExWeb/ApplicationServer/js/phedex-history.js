PHEDEX.History = new (function() {
debugger;
  var _sbx = new PHEDEX.Sandbox(),
      Dom = YAHOO.util.Dom,
      YuH = YAHOO.util.History.
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
        } catch (e) { return; }

        var bookmarkedSection = YuH.getBookmarkedState("navbar");
        var querySection      = YuH.getQueryStringParameter("section");
        var initialSection    = bookmarkedSection || querySection || "none";
        _sbx.notify(this.id,'init');
      }
    };
  };

  Yla(this, _construct());
  this.init();
  return this;
})();

log('loaded...','info','history');