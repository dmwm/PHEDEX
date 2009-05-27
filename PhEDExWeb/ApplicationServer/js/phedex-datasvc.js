// Instantiate a namespace for the data-service calls and the data they return, if they do not already exist
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
//
// Should also set a timeout, and provide a failure-callback as well.
PHEDEX.Datasvc.GET = function(api,obj,datasvc,callback) {
  callback = callback || obj.receive;
// This is a hack because '#' seems not to pass through correctly...?
  var hashrep = /#/;
  api = api.replace(hashrep,'*');

// identify ourselves to the web-server logfiles
  YAHOO.util.Connect.initHeader('user-agent','PhEDEx-AppServ/'+PHEDEX.Appserv.Version);
  
  YAHOO.util.Connect.asyncRequest(
		'GET',
		'/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+api,
		{success:PHEDEX.Datasvc.Callback,
		 argument:{obj:obj,datasvc:datasvc,callback:callback}
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
  var data = response.responseText;
// TODO This should be handled by a JSON parser, rather than an eval
  data = eval('('+data+')');

// TODO should handle the cache-control with response.getResponseHeader['Cache-Control']
  data = data['phedex'];
  if ( typeof(data) === 'object' ) { // barely adequate error-checking! Should also use response-headers
    response.argument.datasvc(data,response.argument.obj);
    response.argument.callback(data,response.argument.obj);
  }
}

// For an arbitrary object, construct the query by joining the key=value pairs
// in the right manner.
PHEDEX.Datasvc.Query = function(args) {
  var argstr = "";
  if (args) {
    argstr = "?";
    for (a in args) {
      argstr+=a+"="+args[a]+";";
    }
  }
  return argstr;
}

// data-service-specific functions. Always in pairs, the first builds the URI
// for the call, the second handles the returned object in whatever specific
// manner is necessary. Adopt the convention PHEDEX.Datasvc.X and
// PHEDEX.Datasvc.X_callback for these pairs.
PHEDEX.Datasvc.Nodes = function(site,obj,callback) {
  var api = 'nodes';
  if ( site ) { api += '?node='+site; }
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Nodes_callback,callback);
}
PHEDEX.Datasvc.Nodes_callback = function(data,obj) {
  if ( !data.node ) { return; }
  PHEDEX.Data.Nodes = data.node;
}

PHEDEX.Datasvc.Agents = function(site,obj,callback) {
  var api = 'agents?node='+site;
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Agents_callback,callback);
}
PHEDEX.Datasvc.Agents_callback = function(data,obj) {
  if ( ! data['node'] ) { return; }
  PHEDEX.namespace('Data.Agents');
  PHEDEX.Data.Agents[obj.site] = data['node'][0]['agent'];
}

PHEDEX.Datasvc.TransferRequests = function(request,obj,callback) {
  var api = 'TransferRequests?request='+request+';';
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
  PHEDEX.namespace('Data.TransferQueueStats.'+obj.direction);
  PHEDEX.Data.TransferQueueStats[obj.direction][obj.site] = data.link;
}

PHEDEX.Datasvc.TransferHistory= function(args,obj,callback) {
  var api = 'TransferHistory' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferHistory_callback,callback);
}
PHEDEX.Datasvc.TransferHistory_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.TransferHistory.'+obj.direction);
  PHEDEX.Data.TransferHistory[obj.direction][obj.site] = data.link;
}
PHEDEX.Datasvc.ErrorLogSummary= function(args,obj,callback) {
  var api = 'ErrorLogSummary' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.ErrorLogSummary_callback,callback);
}
PHEDEX.Datasvc.ErrorLogSummary_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.ErrorLogSummary.'+obj.direction);
  PHEDEX.Data.ErrorLogSummary[obj.direction][obj.site] = data.link;
}

PHEDEX.Datasvc.TransferQueueBlocks = function(arg,obj,callback) {
  var api = 'TransferQueueBlocks'+PHEDEX.Datasvc.Query(arg);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueBlocks_callback,callback);
}
PHEDEX.Datasvc.TransferQueueBlocks_callback = function(data,obj) {
  if ( typeof(data.link) != 'object' ) { return; }
  var link = data.link[0];
  if ( !link ) { return; }
  if ( !link.from || ! link.to ) { return; }
  var from_to = PHEDEX.namespace('PHEDEX.Datasvc.TransferQueueBlocks.'+link['from']+'.'+link['to']);
  from_to = link;
}

PHEDEX.Datasvc.TransferQueueFiles = function(arg,obj,callback) {
  var api = 'TransferQueueFiles'+PHEDEX.Datasvc.Query(arg);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueFiles_callback,callback);
}
PHEDEX.Datasvc.TransferQueueFiles_callback = function(data,obj) {
  if ( !data ) { return; }
  var link = data.link; //[0];
  var queueFiles = PHEDEX.namespace('PHEDEX.Datasvc.TransferQueueFiles');
  queueFiles = data;
}
