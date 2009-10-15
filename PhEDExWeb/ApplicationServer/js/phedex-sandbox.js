PHEDEX.Sandbox = function() {
  var _events = [];
  var _getEvent = function(event) {
    if ( !_events[event] ) {
      _events[event] = new YAHOO.util.CustomEvent(event, this, false, YAHOO.util.CustomEvent.LIST);
    }
    return _events[event];
  }
  return {
    notify: function() {
      var event, arr=[];
      event = arguments[0];
      for (var i=1; i<arguments.length; i=i+1) { arr.push(arguments[i]); }
      _getEvent(event).fire(arr);
    },
    listen: function(event,fn) {
      _getEvent(event).subscribe( function(ev,arr) { fn(ev,arr[0]); } );
    },
//     stopListening: function(event,fn) {
//	  I don't know how I would do this. I would need to know the function that was subscribed, so would
//	  need an array of subscribers/callbacks, maintained in the sandbox. If I go that far, I may as well
//	  simply call the callbacks directly, instead of firing events!
//     }
  }
};
