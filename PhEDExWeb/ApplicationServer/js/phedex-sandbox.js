/**
 * The sandbox is used for managing communication between components without them having direct knowledge of each other. It allows components to listen for interesting events or to notify other components about interesting things they have done.
 * @namespace PHEDEX
 * @class PHEDEX.Sandbox
 * @constructor
 */

PHEDEX.Sandbox = function() {
  var _events = [],
      _map = {},
      _me = 'sandbox',
/**
 * get or create a Yu.CustomEvent for a given event-name
 * @method _getEvent
 * @private
 * @param event {string} name of the event to retrieve or create
 * @param create {boolean} <strong>true</strong> if the event should be created if it does not exist. Defaults to <strong>false</strong>
 */
      _getEvent = function(event,create) {
        if ( _events[event] ) { return _events[event]; }
        if ( create ) {
          _events[event] = new Yu.CustomEvent(event, this, false, Yu.CustomEvent.LIST);
          log('new listen-event: '+event,'info',_me);
          return _events[event];
        }
        log('non-existant event: '+event,'warn',_me);
      },
     _stats = {};

  var obj = {
    _events:[], _map:{}, _stats:{}, _me:'sandbox',
      _getEvent: function(event,create) {
        if ( _events[event] ) { return _events[event]; }
        if ( create ) {
          _events[event] = new Yu.CustomEvent(event, this, false, Yu.CustomEvent.LIST);
          log('new listen-event: '+event,'info',_me);
          return _events[event];
        }
        log('non-existant event: '+event,'warn',_me);
      },

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
      if ( _map[event] ) {
        log('remap: '+event+' ('+_map[event]+')','info',_me);
        event = _map[event];
      }
      if ( !_stats[event] ) { _stats[event] = 0; }
      _stats[event]++;
      log('notify: '+event+' ('+Ylangd(arr,1)+')','info',_me);
      setTimeout(function() {
        var ev = _getEvent(event);
        if ( !ev ) { return; }
        log('fire: '+event+' ('+Ylangd(arr,1)+')','info',_me);
        ev.fire(arr);
      }, 0);
    },

/**
 * Delay-notify subscribed listeners about an event. Notification is asynchronous, this function will return before the notification is actually sent.
 * @method delay
 * @param interval {int} the number of milliseconds to delay the notification
 * @param event {string} the name of the event (obligatory)
 * @param arguments {arbitrary number of arbitrary arguments} arguments to be sent with the notification. Listeners receive these arguments as an array
 */
    delay: function() {
      var event,
          delay,
          arr = Array.apply(null,arguments);
      delay = arr.shift();
      event = arr.shift();
      if ( _map[event] ) {
        log('remap: '+event+' ('+_map[event]+')','info',_me);
        event = _map[event];
      }
      log('notify: '+event+' ('+Ylangd(arr,1)+')','info',_me);
      setTimeout(function() {
        var ev = _getEvent(event);
        if ( !ev ) { return; }
        log('fire: '+event+' ('+Ylangd(arr,1)+')','info',_me);
        ev.fire(arr);
      }, delay);
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
      log('listener for: '+event,'info',_me);
    },

/**
 * delete an event entirely, removing all listeners for it. If the event does not exist, silently return. Do this delayed, so any outstanding handlers still get the chance to respond to the event before it disappears forever.
 * @method deleteEvent
 * @param event {string} name of event to be removed.
 */
    deleteEvent: function(event) {
      setTimeout( function() {
        var ev = _getEvent(event);
        if ( !ev ) { return; }
        ev.unsubscribeAll();
        delete _events[event];
      } );
    },
/** redirect an event, replacing it with another event. This is two-way, if the event is signalled then it is re-mapped to the replacement,
 * and if the replacement is sent, it is remapped to the original. This allows a component to intervene in the normal workflow of the core
 * and take some other action. One example would be the <strong>navigator</strong>, which remaps the <strong>CreateModule</strong> event
 * so it can update its nagivation elements first.<br/>
 * N.B. only one remapping of each event is allowed at present, for simplicity.
 * @method replaceEvent
 * @param event {string} the event to remap
 * @param remap {string} the name of the event to remap the original event to
 * @param oneWay {boolean} set to <strong>true</strong> to make the mapping only one-way. Use this if you need complex re-mapping
 */
    replaceEvent: function(event,remap,oneWay) {
      if ( _map[event] && _map[event] != remap ) {
        throw new Error('Mapping already declared for event='+event+' ('+_map[event]+' trumps '+remap+')');
      }
      if ( _map[remap] && _map[remap] != event ) {
        throw new Error('Mapping already declared for remap='+remap+' ('+_map[remap]+' trumps '+event+')');
      }
      _map[event] = remap;
      if ( !oneWay ) { _map[remap] = event; }
    },

//     stopListening: function(event,fn) {
//	  I don't know how I would do this. I would need to know the function that was subscribed, so would
//	  need an array of subscribers/callbacks, maintained in the sandbox.
//     }

    getStats: function() {
      return _stats;
    }
  };

// make the sandbox unique!
  PHEDEX.Sandbox = function() { return obj; };
  return obj;
};

log('loaded...','info','sandbox');
