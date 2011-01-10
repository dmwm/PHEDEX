// When the DOM is available, start loading the essential bits and pieces
// This is where the real application starts.
YAHOO.util.Event.onDOMReady(function() {
  PxW.combineRequests = false;
  log('initialising','info','app');
  PxL  = new PHEDEX.Loader();
  banner('Loading core application...');
//   PxL.load(function() {},'phedex-profiler');
//   PxW.nocache = true;
  PxL.load(createCoreApp,'core','sandbox','datasvc','registry','phedex-datatable');

  var phedex_app_version = document.getElementById('phedex-app-version'),
      phedex_home = document.getElementById('phedex-link-home');
  if ( phedex_app_version ) { phedex_app_version.innerHTML = PxW.Version; }
  if ( phedex_home ) {
    var uri = location.href;
    phedex_home.href = uri.replace(/#.*$/g,'');
  }
});

function createCoreApp() {
// This is called once the core is fully loaded. Now I can create the core
// application and sandbox, and then start creating PhEDEx modules
  banner('Create sandbox and core application...');
  try {
    PxS = new PHEDEX.Sandbox();
  } catch(ex) { log(ex,'error',name); banner('Error creating sandbox!','error'); return; }
  try {
    PxC = new PHEDEX.Core(PxS,PxL);
    PxC.create();
  } catch(ex) { log(ex,'error',name); banner('Error creating Core application!','error'); return; }
  try {
    PxR = new PHEDEX.Registry(PxS);
    PxR.create();
  } catch(ex) { log(ex,'error',name); banner('Error creating Registry!','error'); return; }

  banner('Core application is running, ready to create PhEDEx data-modules...');

//  if ( PxR ) { // TODO this needs a better home!
//    PxS.notify('Registry', 'add', 'phedex-module-agents',            'node',    'Show Agents',             {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-agentlogs',         'node',    'Show Agent Logs',         {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-protovisdemo',      'node',    'Show Agent Update times', {context_item:true, feature_class:'alpha'});
//    PxS.notify('Registry', 'add', 'phedex-module-pendingrequests',   'node',    'Show Pending Requests',   {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-queuedmigrations',  'node',    'Show Queued Migrations',  {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-linkview',          'node',    'Show Links',              {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-nodes',             'none',    'Show Nodes');
//    PxS.notify('Registry', 'add', 'phedex-module-custodiallocation', 'node',    'Show Custodial Data',     {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-custodiallocation', 'block',   'Show Custodial Location', {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-databrowser',       'dataset', 'Show Data',               {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-databrowser',       'block',   'Show Data',               {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-consistencyresults','node',    'Show Consistency Results',{context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-unroutabledata',    'node',    'Show Unroutable Data',    {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-consistencyresults','block',   'Show Consistency Results',{context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-blocklocation',     'block',   'Show Block Location',     {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-missingfiles',      'block',   'Show Missing Files',      {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-groupusage',        'group',   'Show Group Usage',        {context_item:true});
//    PxS.notify('Registry', 'add', 'phedex-module-pendingrequests',   'group',   'Show Pending Requests',   {context_item:true});
//
//    PxS.notify('Registry', 'add', 'phedex-module-shift-requestedqueued', 'none',     'Shift: Requested vs. Queued data', {context_item:false, feature_class:'beta'});
//  }

  PxU.bannerIdleTimer(PxL);

  var page = location.href;
  if ( page.match(/([^/]*)$/) ) { page = RegExp.$1; }
  if ( page.match(/^(.*)\?/) ) { page = RegExp.$1; }
  if ( page != 'Activity::Rate' ) { return; }

  var el = document.getElementById(page);
  try {
    if ( el ) {
      page = page.replace(/::/g,'-');
      page = page.toLowerCase();
      page = 'phedex-nextgen-'+page;
      PxS.notify('Load',page);
  } catch(ex) {
    var a = ex;
  }
};
