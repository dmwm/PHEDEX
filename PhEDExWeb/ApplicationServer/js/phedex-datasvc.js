// Instantiate a namespace for the data-service calls and the data
// they return, if they do not already exist
PHEDEX.namespace('Datasvc');

// TODO ... turn this into a respectable object?

// Global variables. Should provide getters & setters
PHEDEX.Datasvc.Instance = 'prod';
PHEDEX.Datasvc.Instances = [{name:'Production',instance:'prod'},
			    {name:'Dev',instance:'dev'},
			    {name:'Debug',instance:'debug'}
			   ];

// Whether we should try again for failed queries
PHEDEX.Datasvc.AutoRetry = 0;

/* query object arguments:
   api           : the datasvc api name
   args          : hash of arguments for the api call
   callback      : a callback function for result data
   success_event : an event to fire(data) on success
   failure_event : an event to fire(Error) on failure, defaults to success_event
   limit         : limit to the number of times to poll, default is Number.POSITIVE_INFINITY
*/
PHEDEX.Datasvc.Call = function(query) {
  YAHOO.log('CALL '+query.api,'info','Core.Datasvc');
  query.limit = 1;
  PHEDEX.Datasvc.Poll(query);
}

PHEDEX.Datasvc.Poll = function(query) {
  YAHOO.log('POLL '+query.api,'info','Core.Datasvc');
  if ( (!query.success_event) && query.callback) {
    query.success_event = new YAHOO.util.CustomEvent('CallbackSuccessEvent');
    query.success_event.subscribe(function (type, data) { query.callback(data[0])} );
  } else if ( !query.success_event ) {
    throw new Error("no 'success_event' or 'callback' provided"); 
  }

  if (!query.failure_event) {
    query.failure_event = query.success_event;
  }

  query.text = query.api + PHEDEX.Datasvc.BuildQuery(query.args);
  
  if (query.limit == null || query.limit < 0) {
    query.limit = Number.POSITIVE_INFINITY; 
  }

  var poll_id = PHEDEX.Datasvc.GET(query);
  return poll_id;
}

// Triggers an asyncRequest from a prepared query object
// TODO:  do not GET if no one is listening to the result events
PHEDEX.Datasvc.GET = function(query) {
  YAHOO.log('GET '+query.text,'info','Core.Datasvc');
  query.uri = '/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+query.text;

  // TODO:  transparent caching goes here

  // identify ourselves to the web-server logfiles
  YAHOO.util.Connect.initHeader('user-agent','PhEDEx-AppServ/'+PHEDEX.Appserv.Version);
  YAHOO.util.Connect.asyncRequest(
                'GET',
                query.uri,
		{ success:PHEDEX.Datasvc.GOT,
		  failure:PHEDEX.Datasvc.FAIL,
		  timeout:300000, // 5 minutes, in milliseconds
		  argument:query }
  );

  // TODO:  return poll_id to give caller a possibility to turn off the polling...
  return 1;
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
  }
  YAHOO.log('FIRE '+query.text, 'info', 'Core.Datasvc');
  query.success_event.fire(data);

  // reschedule if needed
  !query.poll ? query.poll = 1 : query.poll++;
  if (query.poll < query.limit) {
    var maxage = response.getResponseHeader['Cache-Control'];
    maxage = maxage.replace(/max-age=(\d+)/, "$1");
    if (!maxage) { maxage = 600; } // default poll time is 10 minutes
    YAHOO.log('maxage "'+maxage+'"', 'info', 'Core.Datasvc');
    var timerid = setTimeout(PHEDEX.Datasvc.GET(query, maxage*1000));
    // TODO: associate this timer with poll_id above to turn off polling
  }
}

PHEDEX.Datasvc.FAIL = function(response) {
  var query = response.argument;
  YAHOO.log('FAIL '+response.status+' ('+response.statusText+') for '+query.text,'error','Core.Datasvc');
  query.failure_event.fire(new Error(response.statusText));
  // TODO:  also reschedule
}

// For an arbitrary object, construct the query by joining the key=value pairs
// in the right manner.
PHEDEX.Datasvc.BuildQuery = function(args) {
  var argstr = "";
  if (args) {
    argstr = "?";
    for (a in args) {
	argstr += a + "=" + encodeURIComponent(args[a]) + ";";
    }
    argstr = argstr.substr(0, argstr.length-1); // chop off trailing ;
  }
  return argstr;
}

// TODO:  some function to turn off polling

YAHOO.log('loaded...','info','Core.Datasvc');
