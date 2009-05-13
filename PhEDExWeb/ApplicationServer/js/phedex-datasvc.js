// Instantiate a namespace for the data-service object, if one does not already exist
PHEDEX.namespace('Datasvc');

// Global variables. Should provide getters & setters
PHEDEX.Datasvc.Instance = 'prod';
PHEDEX.Datasvc.Instances = ['prod','dev','debug'];

// Generic retrieval from the data-service. Requires a correctly formatted
// API call, an object to callback to, a Datasvc handler to cache this data
// (this may be data-specific, hence not generic), and a callback function
// within the calling widget. The last defaults to the 'receive()' member of
// the widget that is receiving the call.
//
// This method could also call the obj.startLoading method, to display the
// spinning wheel or other 'loading' indicator
PHEDEX.Datasvc.GET = function(api,obj,datasvc,callback) {
  callback = callback || obj.receive;
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
  data = eval('('+data+')');
  data = data['phedex'];
  if ( typeof(data) === 'object' ) {
    response.argument.datasvc(data);
    response.argument.callback(data);
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
PHEDEX.Datasvc.Nodes_callback = function(data) {
  PHEDEX.Data.Nodes = data.node;
}

PHEDEX.Datasvc.Agents = function(site,obj,callback) {
  var api = 'agents?node='+site;
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.Agents_callback,callback);
}
PHEDEX.Datasvc.Agents_callback = function(data) {
  var mynode = data['node'][0]['node'];
  if ( ! mynode ) { return; }
  var agents = PHEDEX.namespace('PHEDEX.Data.Agents');
  agents[mynode] = data['node'][0]['agent'];
  PHEDEX.Data.Agents[mynode] = data['node'][0]['agent'];
}

PHEDEX.Datasvc.TransferRequests = function(req_num,obj,callback) {
  var api = 'TransferRequests?req_num='+req_num+';';
  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferRequests_callback,callback);
}
PHEDEX.Datasvc.TransferRequests_callback = function(data) {
  var req_num = data.request[0].id;
  if ( !req_num ) { return; }
  PHEDEX.Datasvc.TransferRequests[req_num] = data.request[0];
}

// ...not ready yet...
//PHEDEX.Datasvc.TransferQueueBlocks = function(arg,obj,callback) {
//  var api = 'TransferQueueBlocks'+PHEDEX.Datasvc.Query(arg);
//  PHEDEX.Datasvc.GET(api,obj,PHEDEX.Datasvc.TransferQueueBlocks_callback,callback);
//}
//PHEDEX.Datasvc.TransferQueueBlocks_callback = function(data) {
//debugger;
//  var link = data.link[0];
//  if ( !link ) { return; }
//  var from_to = PHEDEX.namespace('PHEDEX.Datasvc.TransferQueueBlocks.'+link['from']+'.'+link['to']);
//  from_to = link;
//}
