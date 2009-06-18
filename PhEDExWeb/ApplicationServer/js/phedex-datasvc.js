// Instantiate a namespace for the data-service calls and the data
// they return, if they do not already exist
PHEDEX.namespace('Datasvc');

/* TODO: 
 - implement retries
 - implement caching
 - expose a function to subscribe to an event that triggers pollStop
 - better OO techniques
*/

// Global variables. TODO: should provide getters & setters
PHEDEX.Datasvc.Instance = 'prod';
PHEDEX.Datasvc.Instances = [{name:'Production',instance:'prod'},
			    {name:'Dev',instance:'dev'},
			    {name:'Debug',instance:'debug'}
			   ];

// Whether we should try again for failed queries
PHEDEX.Datasvc.AutoRetry = 0;

PHEDEX.Datasvc._poll_id = 1;
PHEDEX.Datasvc._nextID = function() {
  return PHEDEX.Datasvc._poll_id++;
}
PHEDEX.Datasvc._poll_timers = {};

/* query object arguments:
   api           : the datasvc api name
   args          : hash of arguments for the api call
   callback      : a callback function for result data
   success_event : an event to fire(data) on success
   failure_event : an event to fire(Error) on failure, defaults to success_event
   limit         : limit to the number of times to poll, default is Number.POSITIVE_INFINITY
   context       : an object to return back with the response, in order to
                   help identify the response or perform some other magic.  Will have
                   .api, .path, .poll_id, and .poll_number set automatically
*/
PHEDEX.Datasvc.Call = function(query) {
  query.text = PHEDEX.Datasvc.BuildQuery(query);
  YAHOO.log('CALL '+query.text,'info','Core.Datasvc');
  query.limit = 1;
  PHEDEX.Datasvc.Poll(query);
}

PHEDEX.Datasvc.Poll = function(query) {
  query.text = PHEDEX.Datasvc.BuildQuery(query);
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

  var id = PHEDEX.Datasvc.GET(query);
  return id;
}

// stop polling a query, given by poll_id
PHEDEX.Datasvc.stopPoll = function(poll_id) {
  var timer = PHEDEX.Datasvc._poll_timers[poll_id];
  if (timer) {
    YAHOO.log('STOP poll_id:'+poll_id+' timer:'+timer,'info','Core.Datasvc');
    clearTimeout(timer);
  }
  delete PHEDEX.Datasvc._poll_timers[poll_id];
}

// Triggers an asyncRequest from a prepared query object
PHEDEX.Datasvc.GET = function(query) {
  YAHOO.log('GET '+query.text,'info','Core.Datasvc');

  !query.poll_number ? query.poll_number = 1 : query.poll_number++;
  query.path = '/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+query.text;

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
  YAHOO.util.Connect.asyncRequest(
                'GET',
                query.path,
		{ success:PHEDEX.Datasvc.GOT,
		  failure:PHEDEX.Datasvc.FAIL,
		  timeout:60*1000, // 1 minute (too soon?)
		  argument:query }
  );

  if (! query.poll_id ) { query.poll_id = PHEDEX.Datasvc._nextID(); }
  query.context.poll_id = query.poll_id;
  return query.poll_id;
}

/*  Basic success callback does the following:
    - parse response
    - unwrap response
    - check for errors from the data service or null responses
    - fire query.success_event
    - requedule query with GET if needed
*/
PHEDEX.Datasvc.GOT = function(response) {
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
    PHEDEX.Datasvc.FAIL(response);
    return;
  }
  YAHOO.log('FIRE '+query.text, 'info', 'Core.Datasvc');
  query.success_event.fire(data, query.context);
  PHEDEX.Datasvc._maybe_schedule(query, response);
}

PHEDEX.Datasvc.FAIL = function(response) {
  var query = response.argument;
  YAHOO.log('FAIL '+response.status+' ('+response.statusText+') for '+query.text,'error','Core.Datasvc');
  query.failure_event.fire(new Error(response.statusText), query.context);
  PHEDEX.Datasvc._maybe_schedule(query);
}

PHEDEX.Datasvc._maybe_schedule = function(query, response) {
  if (query.poll_number < query.limit) {
    if (response) {
      var maxage = response.getResponseHeader['Cache-Control'];
      maxage = maxage.replace(/max-age=(\d+)/, "$1");
      if (maxage) { query.polltime = maxage*1000; }
    }
    if (! query.polltime ) { query.polltime = 600*1000; } // default poll time is 10 minutes
    if ( query.force_polltime ) { query.polltime = query.force_polltime; }
    YAHOO.log('SCHEDULE '+query.text+' in '+query.polltime+' ms', 'info', 'Core.Datasvc');
    var timerid = setTimeout(function() { PHEDEX.Datasvc.GET(query) }, query.polltime);
    PHEDEX.Datasvc._poll_timers[query.poll_id] = timerid;
    return query.poll_id;
  }
  return 0;
}

// For an arbitrary object, construct the query by joining the key=value pairs
// in the right manner.
PHEDEX.Datasvc.BuildQuery = function(query) {
  if (!query.api) { throw new Error("no 'api' in query object"); }
  var argstr = "";
  if (query.args) {
    argstr = "?";
    for (a in query.args) {
      argstr += a.toLowerCase() + "=" + encodeURIComponent(query.args[a]) + ";";
    }
    argstr = argstr.substr(0, argstr.length-1); // chop off trailing ;
  }
  return query.api.toLowerCase() + argstr;
}

YAHOO.log('loaded...','info','Core.Datasvc');
