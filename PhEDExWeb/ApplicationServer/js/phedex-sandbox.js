PHEDEX.Sandbox = function() {
  var _events = [];
  var _getEvent = function(event) {
    if ( !_events[event] ) {
      _events[event] = new YAHOO.util.CustomEvent(event, this, false, YAHOO.util.CustomEvent.LIST);
      log('Sandbox: new listen-event: '+event);
    }
    return _events[event];
  }
  return {
    notify: function() {
      var event, arr=[];
      event = arguments[0];
      for (var i=1; i<arguments.length; i=i+1) { arr.push(arguments[i]); }
      log('Sandbox: notify event: '+event);
//    by using setTimeout here, I can allow the flow to continue in the 'parent thread', and deal with the
//    handlers afterwards. Essentially I queue the event for later.
      setTimeout(function() {
        _getEvent(event).fire(arr);
      }, 0);
    },
    listen: function(event,fn) {
      _getEvent(event).subscribe( function(ev,arr) { fn(ev,arr[0]); } );
      log('Sandbox: new listener for event: '+event);
    },
//     stopListening: function(event,fn) {
//	  I don't know how I would do this. I would need to know the function that was subscribed, so would
//	  need an array of subscribers/callbacks, maintained in the sandbox. If I go that far, I may as well
//	  simply call the callbacks directly, instead of firing events!
//     }
  }
};
