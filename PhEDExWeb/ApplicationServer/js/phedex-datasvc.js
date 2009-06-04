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
// TODO This is a hack because '#' seems not to pass through correctly...?
  var hashrep = /#/;
  api = api.replace(hashrep,'*');

// identify ourselves to the web-server logfiles
  YAHOO.util.Connect.initHeader('user-agent','PhEDEx-AppServ/'+PHEDEX.Appserv.Version);
  YAHOO.log('GET '+api,'info','Core.Datasvc');
  YAHOO.util.Connect.asyncRequest(
		'GET',
		'/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+api,
		{success:PHEDEX.Datasvc.Callback,
		 failure:PHEDEX.Datasvc.Callback,
		 timeout: 30000,
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
  var data = response.responseText;

// sample logging...
  if ( response.status == 200 )
  {
    YAHOO.log('GOT '+response.status+' ('+response.statusText+') for '+response.argument.api,'info','Core.Datasvc');
// TODO This should be handled by a JSON parser, rather than an eval
    data = eval('('+data+')');

// TODO should handle the cache-control with response.getResponseHeader['Cache-Control']
    data = data['phedex'];
    if ( typeof(data) === 'object' ) { // barely adequate error-checking! Should also use response-headers
      response.argument.datasvc(data,response.argument.obj);
      response.argument.callback(data,response.argument.obj);
    }
  }
  else
  {
    YAHOO.log('GOT '+response.status+' ('+response.statusText+') for '+response.argument.api,'warn','Core.Datasvc');
    YAHOO.log(response.responseText,'warn','Core.Datasvc');
    response.argument.obj.failedLoading();
    response.argument.callback({},response.argument.obj);
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
  PHEDEX.namespace('Data.Agents');
  PHEDEX.Data.Agents[obj.site] = null;
  if ( ! data['node'] ) { return; }
  if ( ! data['node'][0] ) { return; }
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
  PHEDEX.namespace('Data.TransferQueueStats.'+obj.direction_key());
  PHEDEX.Data.TransferQueueStats[obj.direction_key()][obj.site] = data.link;
}

PHEDEX.Datasvc.TransferHistory= function(args,obj,callback) {
  var api = 'TransferHistory' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferHistory_callback,callback);
}
PHEDEX.Datasvc.TransferHistory_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.TransferHistory.'+obj.direction_key());
  PHEDEX.Data.TransferHistory[obj.direction_key()][obj.site] = data.link;
}
PHEDEX.Datasvc.ErrorLogSummary= function(args,obj,callback) {
  var api = 'ErrorLogSummary' + PHEDEX.Datasvc.Query(args);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.ErrorLogSummary_callback,callback);
}
PHEDEX.Datasvc.ErrorLogSummary_callback = function(data,obj) {
  if ( !data.link ) { return; }
  PHEDEX.namespace('Data.ErrorLogSummary.'+obj.direction_key());
  PHEDEX.Data.ErrorLogSummary[obj.direction_key()][obj.site] = data.link;
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
  PHEDEX.namespace('Data.TransferQueueBlocks.'+link.from);
  PHEDEX.Data.TransferQueueBlocks[link.from][link.to] = link;
}

PHEDEX.Datasvc.TransferQueueFiles = function(arg,obj,callback) {
  var api = 'TransferQueueFiles'+PHEDEX.Datasvc.Query(arg);
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueFiles_callback,callback);
}
PHEDEX.Datasvc.TransferQueueFiles_callback = function(data,obj) {
  if ( typeof(data.link) != 'object' ) { return; }
  var link = data.link[0];
  if ( !link ) { return; }
  if ( !link.from || ! link.to ) { return; }
  PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to);
  var tq = link.transfer_queue[0];

// TODO How do we handle this? What data-structure makes sense here? Do we preserve the structure from the data-service or do we create something that is
// easier to sort/filter inside the widget? If I want to pre-sort, I have to do stuff like this...
//   var q = ['byName','byState','byPriority'];
//   for (var i in q) { PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to+'.'+q[i]); }
//   var q1 = PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to);
//   var q2 = PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to+'.byState');
//   var q3 = PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to+'.byPriority');
//   for (var i in tq.block)
//   {
//     var block = tq.block[i];
//     q1.byName[block.name] = block;
//     q1.byName[block.name].priority = tq.priority;
//     q1.byName[block.name].state    = tq.state;
// 
//     if ( ! q2[tq.state] ) { q2[tq.state] = {}; }
//     q2[tq.state][block.name] = block;
//     q2[tq.state][block.name].priority = tq.priority;
// 
//     if ( ! q3[tq.priority] ) { q3[tq.priority] = {}; }
//     q3[tq.priority][block.name] = block;
//     q3[tq.priority][block.name].state = tq.state;
//   }
// I don't want to do that, so I take the easy way out: flatten the [priority][state] structure into the blocks themselves, and list them 'byName' in the data-result object.
  var q = PHEDEX.namespace('Data.TransferQueueFiles.'+link.from+'.'+link.to+'.byName');
  for (var i in tq.block)
  {
    var block = tq.block[i];
    q[block.name] = block;
    q[block.name].priority = tq.priority;
    q[block.name].state    = tq.state;
  }
}
