// PHEDEX.Datasvc - manage calls to the data service

/* TODO: 
 - implement retries
 - implement caching
*/

/**
 * implement AJAX-communication with the PhEDEx data-service, handling errors for the client
 * @namespace PHEDEX
 * @class Datasvc
 */

PHEDEX.namespace('Datasvc');
PHEDEX.Datasvc = (function() {
  // TODO: should provide getters & setters
  var _instances = PHEDEX.Webapp.Instances,
      _instance = _instances[0].instance,
      _me = 'datasvc',

  // Whether we should try again for failed queries
  // TODO:  retries not implemented
      _autoretry = 0,

  // unique id for polling
    _poll_id = 1,
 
  // method _nextID : generates next polling id
      _nextID = function() {
    return _poll_id++;
  },

  // hash to store timers (setTimeout) by their poll id
      _poll_timers = {},

  // declare variables for private methods
      _get, _got, _fail, _maybe_schedule, _build_query,

  // convenience alias and others
      YuC = Yu.Connect, _first=0;

  // method _instanceURL : make the instance URL from the component bits. Hardly worth making it a separate function,
  // but it can then at least be overridden
  _instanceURL = function(base,component) {
    return base + component;
  }

  // method _get : triggers an asyncRequest from a prepared query object
  _get = function(query) {
    var context = query.context;
    Ylog('GET '+query.text,'info',_me);

    !query.poll_number ? query.poll_number = 1 : query.poll_number++;
    query.path = _instanceURL(PHEDEX.Webapp.DataserviceURL,_instance) + '/'+query.text;

    context.poll_number = query.poll_number;
    context.path = query.path;
    context.timeout = query.timeout || 60*1000; // 1 minute (too soon?)

    // Check that events were defined
    if (!(query.success_event && query.failure_event)) {
      throw new Error('success_event and failure_event not defined for '+query.text);
    }

    // Check that the events have consequences.  This should allow
    // polling to be stopped by simply destroying the objects that are
    // subscribed to the result events
    if (!( query.success_event.subscribers[0] && query.failure_event.subscribers[0] ) ) {
      Ylog('Not getting '+query.text+' , no one is listening...','info',_me);
      PHEDEX.Datasvc.stopPoll(query.poll_id);
      return;
    }

    // TODO:  transparent caching goes here

    // identify ourselves to the web-server logfiles
    YuC.initHeader('user-agent',PxU.UserAgent());
    YuC.asyncRequest(query.method,
                     query.path,
                     {
                       success:_got,
                       failure:_fail,
                       timeout:context.timeout,
                       argument:query
                     },
                     query.postData
                     );

    if (! query.poll_id ) { query.poll_id = _nextID(); }
    context.poll_id = query.poll_id;
    context.start_time = new Date().getTime();
    return query.poll_id;
  }

  /*   method _got : basic success callback does the following:
   *    - parse response
   *    - unwrap response
   *    - check for errors from the data service or null responses
   *    - fire query.success_event
   *    - schedule query again (poll) with _get() if needed
   */
  _got = function(response) {
    var query = response.argument,
        data = {}, context;
    Ylog('GOT '+response.status+' ('+response.statusText+') for '+query.text,'info',_me);
    if ( response.status != 200 ) {
      _fail(response);
      return;
    }

    try {
//       if ( response.status != 200 ) { throw new Error("bad response"); } // should be unnecessary, but isn't, because we don't have kosher return codes...
      data = Ylang.JSON.parse(response.responseText);
      Ylog('PARSED '+query.text, 'info', _me);
      if (data['error']) { throw new Error(data['error']) }
      data = data['phedex'];
      // barely adequate error-checking! Should also use response-headers
      if ( typeof(data) !== 'object' ) { throw new Error("null response"); }
    } catch (e) {
      response.status = -1;
      response.statusText = e.message;
      _fail(response);
      return;
    }

    try {
      var age    = response.getResponseHeader['Age'] || 0,
          maxAge = response.getResponseHeader['Cache-Control'];
      if ( maxAge.match(/max-age/) ) {
        maxAge = maxAge.replace(/^.*max-age=(\d+).*$/, "$1");
        if (maxAge) { query.context.maxAge = maxAge - age; }
      }
    } catch(ex) { Ylog('cannot calculate max-age, ignoring...','warn',_me); }
    Ylog('FIRE '+query.text, 'info', _me);
    context = query.context;
    context.call_time = new Date().getTime() - context.start_time;
    query.success_event.fire(data,context);
    _maybe_schedule(query, response);

    // set the version number, if not already done...
    if ( _first == 0 ) {
      _first = 1;
      PHEDEX.Datasvc.Version = data.request_version;
      var el = document.getElementById('phedex-app-version');
      if ( el ) { el.title = 'Data-service version: '+PHEDEX.Datasvc.Version; }
    }
  }

  // method _fail : fires the error handler
  _fail = function(response) {
    var query = response.argument,
        context = query.context;
        context.call_time = new Date().getTime() - context.start_time;
        message = 'Error from "'+context.api+'" call: '+response.status+' ('+response.statusText+')';
    Ylog('FAIL '+response.status+' ('+response.statusText+') for '+query.text,'error',_me);
    query.failure_event.fire({error:message}, context, response);
    _maybe_schedule(query);
  }

  // method _maybe_schedule : decides whether a query should be scheduled again for polling 
  _maybe_schedule = function(query, response) {
    if (query.poll_number < query.limit) {
      if (response) {
        var maxage = response.getResponseHeader['Cache-Control'];
        maxage = maxage.replace(/max-age=(\d+)/, "$1");
        if (maxage) { query.polltime = maxage*1000; }
      }
      if (! query.polltime ) { query.polltime = 600*1000; } // default poll time is 10 minutes
      if ( query.force_polltime ) { query.polltime = query.force_polltime; }
      Ylog('SCHEDULE '+query.text+' in '+query.polltime+' ms', 'info', _me);
      var timerid = setTimeout(function() { _get(query) }, query.polltime);
      _poll_timers[query.poll_id] = timerid;
      return query.poll_id;
    } else {
      PHEDEX.Datasvc.stopPoll(query.poll_id);
      return 0;
    }
  }

    //_build_query method : for an arbitrary object, construct the URL query by joining the key=value pairs
    _build_query = function(query) {
        var argstr='', argvals=null, indx=0, a, separator=';';
        if ( query.method ) { query.method = query.method.toUpperCase(); }
        else { query.method = 'GET'; }
        if ( query.method == 'POST' ) { query.post = true; separator = '&'; }
        if (!query.api) { throw new Error("no 'api' in query object"); }

        if (query.args)
        {
            for (a in query.args)
            {
                argvals = query.args[a];
                if ( !query.post ) { a = a.toLowerCase(); }
                if (argvals instanceof Array)
                {
                    for (indx in argvals)
                    {
                        argstr += a + "=" + encodeURIComponent(argvals[indx]) + separator;
                    }
                }
                else
                {
                    argstr += a + "=" + encodeURIComponent(argvals) + separator;
                }
            }
            argstr = argstr.substr(0, argstr.length-1); // chop off trailing separator
        }
        query.text = query.api.toLowerCase();
        if ( query.post ) {
          query.postData = argstr;
        } else {
          query.text += '?' + argstr;
        }
        if ( PHEDEX.Webapp.nocache ) {
          if ( query.args ) { query.text += '&'; }
          query.text += 'nocache=1';
        }
    }
  
  // public methods/properties below
  return {
    Version: '0',
/**
 * the query-object describes the data that must be fetched from the data-service and how to handle it or how to handle failure.
 * @property query
 * @type object
 * @protected
 */
/** (input, mandatory) the dataservice API name
 * @property query.api
 * @type string
 */

/** (input, optional) reference to an object containing arguments for the call. See the data-service documentation for the API you are using to find out what set of valid arguments you may use
 * @property query.args
 * @type object
 */
/** (input, optional) a callback function for results. Takes two arguments, (data, context). The data is API-specific, see the data-service documentation for each API to understand it. The context object is described below. The callback argument may be omitted if a success_event is given instead
 * @property query.callback
 * @type function
 */
/**
 * (input, optional) An event to fire when the data is ready. Used instead of a callback if it is provided. The event is fired with the same arguments as the callback would have received
 * @property query.success_event
 * @type YAHOO.util.CustomEvent
 */
/**
 * (input, optional) An event to fire on failure. If not given, the success_event or callback will be called for failed transfers, and it is up to them to understand from the response that the call has failed.
 *  @property query.failure_event
 * @type YAHOO.util.CustomEvent
 */
/**
 * (output) An object, containing <strong>.api</strong>, <strong>.path</strong>, <strong>.poll_id</strong>, and <strong>.poll_number</strong> keys, with values set automatically. Can be used by the caller for advanced data-service call management, apparently.
 * @property query.context
 * @type object
 */
   /**
     * access the data service once, sending the result data to a callback function
     * or firing an event when the data is returned and validated.
     * @method Call
     * @param query {object} object defining the API and parameters to pass to the data-service
     */
    Call: function(query) {
      _build_query(query);
      Ylog('CALL '+query.text,'info',_me);
      query.limit = 1;
      PHEDEX.Datasvc.Poll(query);
    },

    /**
     * access the data service repeatedly, sending the result data to a callback function
     * or firing an event when the data is returned and validated. The period of the poll is
     * determined by the data service API.
     * the query object is the same as in Call, except that the <strong>limit</strong> and <strong>force_polltime</strong> fields only apply to <strong>Poll</strong>
     * @method Poll
     * @param query {object} object defining the API and parameters to pass to the data-service
     */
/**
 * (input,optional) limit to the number of times to poll, default is Number.POSITIVE_INFINITY. Only valid with the <strong>Poll</strong> method
 * @property query.limit
 * @type {integer}
 */
/**
 * (input,optional) time in milliseconds to poll the query, ignoring the api preferences. Use for testing only. Only valid with the <strong>Poll</strong> method
 * @property query.force_polltime
 * @type {integer}
 */
    Poll: function(query) {
      _build_query(query); // TODO this is wasteful, calling _build_query a second time...
      Ylog('POLL '+query.text,'info',_me);

      if (!query.context) { query.context = { args:{} }; }
      query.context.api   = query.api;
      query.context.magic = query.magic || 0;
      for (var i in query.args) { query.context.args[i] = query.args[i]; }

      if ( (!query.success_event) && query.callback) {
        query.success_event = new YuCE('CallbackSuccessEvent');
        query.success_event.subscribe(function (type, data) { query.callback(data[0], data[1])} );
      } else if ( !query.success_event ) {
        throw new Error("no 'success_event' or 'callback' provided");
      }

      if (!query.failure_event) {
//        query.failure_event = query.success_event;
        query.failure_event = new YuCE('CallbackSuccessEvent');
        query.failure_event.subscribe(function (type, data) { query.callback(data[0], data[1], data[2])} );
      }

      if (query.limit == null || query.limit < 0) {
        query.limit = Number.POSITIVE_INFINITY;
      }

      var id = _get(query);
      return id;
    },

    // stopPoll : stop polling a query given by poll_id (returned by Poll)
    stopPoll: function(poll_id) {
      var timer = _poll_timers[poll_id];
      if (timer) {
        Ylog('STOP poll_id:'+poll_id+' timer:'+timer,'info',_me);
        clearTimeout(timer);
      }
      delete _poll_timers[poll_id];
    },

    // Instances: set or return the array of instances
    Instances: function(instances) {
      if ( instances ) {
        _instances = instances;
        PHEDEX.Webapp.Instances = instances;
      }
      return _instances;
    },

    // Instance: return the current instance. Set the current instance if a name is given.
    // Fire the InstanceChanged event if indeed the instance has been changed
    Instance: function(instance) {
      var i, current, changed=false;
      if ( instance && instance != _instance )
      {
        _instance = instance;
        changed=true;
      }
      for (i in _instances) {
        if ( _instances[i].instance == _instance ) { current = _instances[i]; }
      }
      if ( changed ) {
        PHEDEX.Datasvc.InstanceChanged.fire(current);
      }
      return current;
    },

    // InstanceByName: return the instance whose name matches the input string.
    InstanceByName: function(name) {
      for (var i in _instances ) {
        if ( _instances[i].name == name ) { return _instances[i]; }
      }
    },

    throwIfError: function(message,response) {
      if ( !response ) { return; }
//     'banner' may not be defined if running outside the PhEDEx environment
      try {
        banner(message.error+'. Aborting application','error');
      } catch(ex) {};
      throw new Error('error from datasvc, cannot continue');
    }
  };
})();

PHEDEX.Datasvc.InstanceChanged = new YuCE('InstanceChanged');
YAHOO.log('loaded...','info','datasvc');
