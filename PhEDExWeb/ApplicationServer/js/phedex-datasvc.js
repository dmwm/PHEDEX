// PHEDEX.Datasvc - manage calls to the data service

/* TODO: 
 - implement retries
 - implement caching
*/

/**
 * implement AJAX-communication with the PhEDEx data-service, handling errors for the client
 * @class Datasvc
 */

PHEDEX.namespace('Datasvc');
PHEDEX.Datasvc = (function() {
  // TODO: should provide getters & setters
  var _instance = 'prod';
  var _instances = [{name:'Production',instance:'prod'},
		    {name:'Dev',instance:'test'},
		    {name:'Debug',instance:'debug'}
		   ];

  // Whether we should try again for failed queries
  // TODO:  retries not implemented
  var _autoretry = 0;

  // unique id for polling
  var _poll_id = 1;
 
  // method _nextID : generates next polling id
  var _nextID = function() {
    return _poll_id++;
  }

  // hash to store timers (setTimeout) by their poll id
  var _poll_timers = {};

  // method _get : triggers an asyncRequest from a prepared query object
  var _get = function(query) {
    YAHOO.log('GET '+query.text,'info','Core.Datasvc');

    !query.poll_number ? query.poll_number = 1 : query.poll_number++;
    query.path = '/phedex/datasvc/json/'+_instance+'/'+query.text;

    query.context.poll_number = query.poll_number;
    query.context.path = query.path;

    // Check that events were defined
    if (!(query.success_event && query.failure_event)) {
      throw new Error('success_event and failure_event not defined for '+query.text);
    }

    // Check that the events have consequences.  This should allow
    // polling to be stopped by simply destroying the objects that are
    // subscribed to the result events
    if (!( query.success_event.subscribers[0] && query.failure_event.subscribers[0] ) ) {
      YAHOO.log('Not getting '+query.text+' , no one is listening...','info','Core.Datasvc');
      PHEDEX.Datasvc.stopPoll(query.poll_id);
      return;
    }

    // TODO:  transparent caching goes here

    // identify ourselves to the web-server logfiles
    YAHOO.util.Connect.initHeader('user-agent',
				  'PhEDEx-AppServ/'+PHEDEX.Appserv.Version+' (CMS) '+navigator.userAgent);
    YAHOO.util.Connect.asyncRequest('GET',
				    query.path,
				    { success:_got,
				      failure:_fail,
				      timeout:60*1000, // 1 minute (too soon?)
				      argument:query }
				   );

    if (! query.poll_id ) { query.poll_id = _nextID(); }
    query.context.poll_id = query.poll_id;
    return query.poll_id;
  }

  /*   method _got : basic success callback does the following:
   *    - parse response
   *    - unwrap response
   *    - check for errors from the data service or null responses
   *    - fire query.success_event
   *    - schedule query again (poll) with _get() if needed
   */
  var _got = function(response) {
    var query = response.argument;
    YAHOO.log('GOT '+response.status+' ('+response.statusText+') for '+query.text,'info','Core.Datasvc');
    var data = {};
    try {
      if ( response.status != 200 ) { throw new Error("bad response"); } // should be unnecessary...
      data = YAHOO.lang.JSON.parse(response.responseText);
      YAHOO.log('PARSED '+query.text, 'info', 'Core.Datasvc');
      
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
    YAHOO.log('FIRE '+query.text, 'info', 'Core.Datasvc');
    query.success_event.fire(data, query.context);
    _maybe_schedule(query, response);
  }

  // method _fail : fires the error handler
  var _fail = function(response) {
    var query = response.argument;
    YAHOO.log('FAIL '+response.status+' ('+response.statusText+') for '+query.text,'error','Core.Datasvc');
    query.failure_event.fire(new Error(response.statusText), query.context);
    _maybe_schedule(query);
  }

  // method _maybe_schedule : decides whether a query should be scheduled again for polling 
  var _maybe_schedule = function(query, response) {
    if (query.poll_number < query.limit) {
      if (response) {
	var maxage = response.getResponseHeader['Cache-Control'];
	maxage = maxage.replace(/max-age=(\d+)/, "$1");
	if (maxage) { query.polltime = maxage*1000; }
      }
      if (! query.polltime ) { query.polltime = 600*1000; } // default poll time is 10 minutes
      if ( query.force_polltime ) { query.polltime = query.force_polltime; }
      YAHOO.log('SCHEDULE '+query.text+' in '+query.polltime+' ms', 'info', 'Core.Datasvc');
      var timerid = setTimeout(function() { _get(query) }, query.polltime);
      _poll_timers[query.poll_id] = timerid;
      return query.poll_id;
    } else {
      PHEDEX.Datasvc.stopPoll(query.poll_id);
      return 0;
    }
  }

    //_build_query method : for an arbitrary object, construct the URL query by joining the key=value pairs
    var _build_query = function(query) 
    {
        if (!query.api) { throw new Error("no 'api' in query object"); }
        var argstr = "", argvals = null, indx = 0;
        if (query.args) 
        {
            argstr = "?";
            for (a in query.args) 
            {
                argvals = query.args[a];
                if (argvals instanceof Array)
                {
                    for (indx = 0; indx < argvals.length; indx++)
                    {
                        argstr += a.toLowerCase() + "=" + encodeURIComponent(argvals[indx]) + "&";
                    }
                    argstr = argstr.substr(0, argstr.length-1); // chop off trailing ;
                    argstr += ";";
                }
                else
                {
                    argstr += a.toLowerCase() + "=" + encodeURIComponent(query.args[a]) + ";";
                }
            }
            argstr = argstr.substr(0, argstr.length-1); // chop off trailing ;
        }
        return query.api.toLowerCase() + argstr;
    }
  
  // public methods/properties below
  return {

    /**
     * access the data service once, sending the result data to a callback function
     * or firing an event when the data is returned and validated.
     * @method Call
     * @param query {object} object defining the API and parameters to pass to the data-service
     * <br/>query object attributes:<br/>
     * <pre><table>
     * <tr><td><strong>api</strong></td><td>the datasvc api name</td>
     * <tr><td><strong>args</strong></td><td>hash of arguments for the api call</td>
     * <tr><td><strong>callback</strong></td><td>a callback function for result (data, context)</td>
     * <tr><td><strong>success_event</strong></td><td>an event to fire(data, context)) on success</td>
     * <tr><td><strong>failure_event</strong></td><td>an event to fire(Error, context) on failure, defaults to success_event</td>
     * <tr><td><strong>context</strong></td><td>an object to return back with the response, in order to help identify the response or perform some other magic.<br/>Will have <strong>.api</strong>, <strong>.path</strong>, <strong>.poll_id</strong>, and <strong>.poll_number</strong> set automatically</td>
     * </table>
     * </pre>
     */
    Call: function(query) {
      query.text = _build_query(query);
      YAHOO.log('CALL '+query.text,'info','Core.Datasvc');
      query.limit = 1;
      PHEDEX.Datasvc.Poll(query);
    },

    /* Poll(query) : access the data service repeatedly, sending the result data to a callback function
     *               or firing an event when the data is returned and validated.  The period of the poll is
     *               determined by the data service API.
     *   the query object is the same as in Call, with the following additions:
     *   limit          : limit to the number of times to poll, default is Number.POSITIVE_INFINITY
     *   force_polltime : time in milliseconds to poll the query, ignoring
     *                    the api preferences.  Use for testing only.
     */
    Poll: function(query) {
      query.text = _build_query(query);
      YAHOO.log('POLL '+query.text,'info','Core.Datasvc');

      if (!query.context) { query.context = {}; }
      query.context.api = query.api;

      if ( (!query.success_event) && query.callback) {
	query.success_event = new YAHOO.util.CustomEvent('CallbackSuccessEvent');
	query.success_event.subscribe(function (type, data) { query.callback(data[0], data[1])} );
      } else if ( !query.success_event ) {
	throw new Error("no 'success_event' or 'callback' provided"); 
      }
      
      if (!query.failure_event) {
	query.failure_event = query.success_event;
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
	YAHOO.log('STOP poll_id:'+poll_id+' timer:'+timer,'info','Core.Datasvc');
	clearTimeout(timer);
      }
      delete _poll_timers[poll_id];
    },

    // Instances: return the array of instances
    Instances: function() {
      return _instances;
    },

    // Instance: return the current instance. Set the current instance if a name is given.
    // Fire the InstanceChanged event if indeed the instance has been changed
    Instance: function(instance) {
      if ( instance && instance != _instance )
      {
        _instance = instance;
        PHEDEX.Datasvc.InstanceChanged.fire();
      }
      for (var i in _instances) {
        if ( _instances[i].instance == _instance ) { return _instances[i]; }
      }
    }
  };
})();

PHEDEX.Datasvc.InstanceChanged = new YAHOO.util.CustomEvent('InstanceChanged');
YAHOO.log('loaded...','info','Core.Datasvc');
