PHEDEX.Sandbox = function() {
  var _events = [],
      _me = 'Sandbox';
  var _getEvent = function(event,create) {
    if ( _events[event] ) { return _events[event]; }
    if ( create ) {
      _events[event] = new YAHOO.util.CustomEvent(event, this, false, YAHOO.util.CustomEvent.LIST);
      log('new listen-event: '+event,'info',_me);
      return _events[event];
    }
    log('non-existant event: '+event,'warn',_me);
  }
  return {
    notify: function() {
      var event,
          arr = Array.apply(null,arguments);
      event = arr.shift();
      log('notify event: '+event+' ('+arr.join(', ')+')','info',_me);
//    by using setTimeout here, I can allow the flow to continue in the 'parent thread', and deal with the
//    handlers afterwards. Essentially I queue the event for later. I think I also keep the stack shorter too
      setTimeout(function() { var ev = _getEvent(event); if ( ev ) { ev.fire(arr); } }, 0);
    },

    listen: function(event,fn) {
      _getEvent(event,true).subscribe( function(ev,arr) { fn(ev,arr[0]); } );
      log('new listener for event: '+event,'info',_me);
    },

    deleteEvent: function(event) {
      var ev = _getEvent(event);
      if ( !ev ) { return; }
      ev.unsubscribeAll();
      delete _events[event];
    },
//     stopListening: function(event,fn) {
//	  I don't know how I would do this. I would need to know the function that was subscribed, so would
//	  need an array of subscribers/callbacks, maintained in the sandbox.
//     }
  }
};
