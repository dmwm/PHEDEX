/**
 * The sandbox is used for managing communication between components without them having direct knowledge of each other. It allows components to listen for interesting events or to notify other components about interesting things they have done.
 * @namespace PHEDEX
 * @class Sandbox
 * @constructor
 */

PHEDEX.Sandbox = function() {
  var _events = [],
      _me = 'Sandbox';
/**
 * get or create a YAHOO.util.CustomEvent for a given event-name
 * @method _getEvent
 * @private
 * @param event {string} name of the event to retrieve or create
 * @param create {boolean} <strong>true</strong> if the event should be created if it does not exist. Defaults to <strong>false</strong>
 */
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
/**
 * Notify subscribed listeners about an event. Notification is asynchronous, this function will return before the notification is actually sent.
 * @method notify
 * @param event {string} the name of the event (obligatory)
 * @param arguments {arbitrary number of arbitrary arguments} arguments to be sent with the notification. Listeners receive these arguments as an array
 */
    notify: function() {
      var event,
          arr = Array.apply(null,arguments);
      event = arr.shift();
      log('notify event: '+event+' ('+YAHOO.lang.dump(arr)+')','info',_me);
      setTimeout(function() { var ev = _getEvent(event); if ( ev ) { ev.fire(arr); } }, 0);
    },

/**
 * subscribe to an event. The callback function receives all the extra arguments that the notification sent. It is up to the callback function to know what to do with them!
 * The same event can be subscribed by multiple listeners, in which case they will all be called, sequentially. Do not rely on the order of listening to match the order of calling, it may not.
 * @method listen
 * @param event {string} event-name to listen for
 * @param fn {function} callback function to handle the event. The function is called in the scope of the object that called listen.
 */
    listen: function(event,fn) {
      _getEvent(event,true).subscribe( function(ev,arr) { fn(ev,arr[0]); } );
      log('new listener for event: '+event,'info',_me);
    },

/**
 * delete an event entirely, removing all listeners for it. If the event does not exist, silently return.
 * @method deleteEvent
 * @param event {string} name of event to be removed.
 */
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
