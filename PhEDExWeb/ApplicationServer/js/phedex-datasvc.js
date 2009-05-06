PHEDEX.Datasvc=function() {}
PHEDEX.Datasvc.Instance = 'prod';
PHEDEX.Datasvc.Instances = ['prod','dev','debug'];
PHEDEX.Datasvc.GET = function(api,callback,argument) {
  YAHOO.util.Connect.asyncRequest('GET','/phedex/datasvc/json/'+PHEDEX.Datasvc.Instance+'/'+api,{success:callback,argument:argument});
}
