// Instantiate a namespace for the data-service calls and the data
// they return, if they do not already exist
PHEDEX.namespace('Datasvc','Data');

// Global variables. Should provide getters & setters
PHEDEX.Datasvc.Instance = 'prod';
PHEDEX.Datasvc.Instances = [{name:'Production',instance:'prod'},
			    {name:'Dev',instance:'dev'},
			    {name:'Debug',instance:'debug'}
			   ];

// Generic retrieval from the data-service. Requires a correctly formatted
// API call, an object to callback to, a Datasvc handler to cache this data
// (this may be data-specific, hence not generic), and a callback function
// within the calling widget. The last defaults to the 'receive()' member of
// the widget that is receiving the call.
//
// This method could also call the obj.startLoading method, to display the
// spinning wheel or other 'loading' indicator
PHEDEX.Datasvc.GET = function(api,obj,datasvc,callback) {
  if ( obj && !callback ) { callback = obj.receive; }

  var url = '/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+api;

// identify ourselves to the web-server logfiles
  YAHOO.util.Connect.initHeader('user-agent','PhEDEx-AppServ/'+PHEDEX.Appserv.Version);
  YAHOO.log('GET '+api,'info','Core.Datasvc');
  YAHOO.util.Connect.asyncRequest(
                'GET',
                 url,
		{success:PHEDEX.Datasvc.Callback,
		 failure:PHEDEX.Datasvc.Failure,
		 timeout:300000, // 5 minutes, in milliseconds
		 argument:{obj:obj,datasvc:datasvc,callback:callback,api:api}
		}
	);
}

// Generic callback, allows one-stop error-handling. Does basic parsing of
// the returned object, should eventually handle any error-responses too.
// Then calls the dataservice-specific callback to process this particular
// response, then the object-specific callback to deal with the widget.
//
// Could call response.argument.obj.finishLoading, to remove the 'loading'
// indicator for the widget that wants the data.
PHEDEX.Datasvc.Callback = function(response) {
    YAHOO.log('GOT '+response.status+' ('+response.statusText+') for '+response.argument.api,'info','Core.Datasvc');
    try {
	if ( response.status != 200 ) { throw "bad response"; }
	var data = YAHOO.lang.JSON.parse(response.responseText);
	YAHOO.log('PARSED '+response.argument.api, 'info', 'Core.Datasvc');

// TODO should handle the cache-control with response.getResponseHeader['Cache-Control']
	data = data['phedex'];
	// barely adequate error-checking! Should also use response-headers
	if ( typeof(data) !== 'object' ) { throw "null response"; }
	YAHOO.log('CALLBACK '+response.argument.api, 'info', 'Core.Datasvc');
	response.argument.datasvc(data,response.argument.obj);
	if ( response.argument.callback ) { response.argument.callback(data,response.argument.obj); }
    } catch (e) {
	response.status = -1;
	response.statusText = e;
	PHEDEX.Datasvc.Failure(response);
    }
}

PHEDEX.Datasvc.Failure = function(response) {
    YAHOO.log('FAILURE '+response.status+' ('+response.statusText+') for '+response.argument.api,'error','Core.Datasvc');
    response.argument.obj.failedLoading();
    if ( response.argument.callback ) { response.argument.callback({},response.argument.obj); }
}

// For an arbitrary object, construct the query by joining the key=value pairs
// in the right manner.
PHEDEX.Datasvc.Query = function(args) {
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

// A generic dataservice call
PHEDEX.Datasvc.Call = function(api,args,obj,callback) {
  api += PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Nodes_callback,callback);
}
PHEDEX.Datasvc.Call_callback = function(data,obj) {
  PHEDEX.Data.Call = data;
}

// data-service-specific functions. Always in pairs, the first builds the URI
// for the call, the second handles the returned object in whatever specific
// manner is necessary. Adopt the convention PHEDEX.Datasvc.X and
// PHEDEX.Datasvc.X_callback for these pairs.
PHEDEX.Datasvc.Nodes = function(node,obj,callback) {
  var api = 'nodes';
  if ( node ) { api += PHEDEX.Datasvc.Query({node:node}); }
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Nodes_callback,callback);
}
PHEDEX.Datasvc.Nodes_callback = function(data,obj) {
  if ( !data.node ) { return; }
  PHEDEX.Data.Nodes = data.node;
}

PHEDEX.Datasvc.Agents = function(node,obj,callback) {
  var api = 'agents' + PHEDEX.Datasvc.Query({node:node});
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Agents_callback,callback);
}
PHEDEX.Datasvc.Agents_callback = function(data,obj) {
  PHEDEX.namespace('Data.Agents');
  PHEDEX.Data.Agents[obj.node] = null;
  if ( ! data['node'] ) { return; }
  if ( ! data['node'][0] ) { return; }
  PHEDEX.Data.Agents[obj.node] = data['node'][0]['agent'];
}

PHEDEX.Datasvc.TransferRequests = function(request,obj,callback) {
  var api = 'TransferRequests' + PHEDEX.Datasvc.Query({request:request});
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferRequests_callback,callback);
}
PHEDEX.Datasvc.TransferRequests_callback = function(data,obj) {
  if ( !data.request ) { return; }
  PHEDEX.namespace('Data.TransferRequests');
  PHEDEX.Data.TransferRequests[obj.request] = data.request[0];
}

PHEDEX.Datasvc.TransferQueueStats= function(args,obj,callback) {
  var api = 'TransferQueueStats' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueStats_callback,callback);
}
PHEDEX.Datasvc.TransferQueueStats_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.TransferQueueStats.'+obj.direction_key());
  PHEDEX.Data.TransferQueueStats[obj.direction_key()][obj.node] = data.link;
}

PHEDEX.Datasvc.TransferHistory= function(args,obj,callback) {
  var api = 'TransferHistory' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferHistory_callback,callback);
}
PHEDEX.Datasvc.TransferHistory_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.TransferHistory.'+obj.direction_key());
  PHEDEX.Data.TransferHistory[obj.direction_key()][obj.node] = data.link;
}

PHEDEX.Datasvc.ErrorLogSummary= function(args,obj,callback) {
  var api = 'ErrorLogSummary' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.ErrorLogSummary_callback,callback);
}
PHEDEX.Datasvc.ErrorLogSummary_callback = function(data,obj) {
  if ( !data.link ) {  return; }
  PHEDEX.namespace('Data.ErrorLogSummary.'+obj.direction_key());
  PHEDEX.Data.ErrorLogSummary[obj.direction_key()][obj.node] = data.link;
}

PHEDEX.Datasvc.TransferQueueBlocks = function(args,obj,callback) {
  var api = 'TransferQueueBlocks'+PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueBlocks_callback,callback);
}
PHEDEX.Datasvc.TransferQueueBlocks_callback = function(data,obj) {
  if ( typeof(data.link) != 'object' ) { return; }
  var link = data.link[0];
  if ( !link ) { return; }
  if ( !link.from || ! link.to ) { return; }
  PHEDEX.namespace('Data.TransferQueueBlocks.'+link.from);
  PHEDEX.Data.TransferQueueBlocks[link.from][link.to] = link;
}

PHEDEX.Datasvc.TransferQueueFiles = function(args,obj,callback) {
  var api = 'TransferQueueFiles'+PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueFiles_callback,callback);
}
PHEDEX.Datasvc.TransferQueueFiles_callback = function(data,obj) {
  if ( typeof(data.link) != 'object' ) { return; }
  var link = data.link[0];
  if ( !link ) { return; }
  if ( !link.from || ! link.to ) { return; }
  PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to);
  var tq = link.transfer_queue[0];

  var q = PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to+'.byName');
  for (var i in tq.block)
  {
    var block = tq.block[i];
    q[block.name] = block;
    q[block.name].priority = tq.priority;
    q[block.name].state    = tq.state;
  }
}
YAHOO.log('loaded...','info','Core.Datasvc');
