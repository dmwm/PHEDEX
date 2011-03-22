// When the DOM is available, start loading the essential bits and pieces
// This is where the real application starts.
YAHOO.util.Event.onDOMReady(function() {
  PxW.combineRequests = false;
  log('initialising','info','app');
  PxL  = new PHEDEX.Loader();
  banner('Loading core application...');
  PxL.load(createCoreApp,'core','sandbox','datasvc');

  var phedex_app_version = document.getElementById('phedex-app-version'),
      phedex_home = document.getElementById('phedex-link-home');
  if ( phedex_app_version ) { phedex_app_version.innerHTML = PxW.Version; }
  if ( phedex_home ) {
    var uri = location.href;
    phedex_home.href = uri.replace(/#.*$/g,'');
  }
});

function createCoreApp() {
// This is called once the core is fully loaded.

  var page=location.href,/* el,*/ uri, params={}, substrs, i, ngoSuccess;
  if ( page.match(/^(.*)\?/)  )        { page = RegExp.$1; }
  if ( page.match(/([^/]*)(.html)$/) ) { page = RegExp.$1; }
  if ( page.match(/([^/]*)?$/) )       { page = RegExp.$1; }
  params.el = document.getElementById(page);
  if ( !params.el ) { return; }
  banner('loading, please wait...');

// Now I can create the core application and sandbox, and then start creating PhEDEx modules
  banner('Create sandbox and core application...');
  try {
    PxS = new PHEDEX.Sandbox();
  } catch(ex) { log(ex,'error',name); banner('Error creating sandbox!','error'); return; }
  try {
    PxC = new PHEDEX.Core(PxS,PxL);
    PxC.create();
  } catch(ex) { log(ex,'error',name); banner('Error creating Core application!','error'); return; }
  banner('Core application is running, ready to create PhEDEx data-modules...');

  uri = location.search;
  if ( uri.match(/^\?(.*)$/) ) {
    substrs = RegExp.$1.split('&')
    for (i in substrs ) {
      if ( substrs[i].match(/^([^=]*)=(.*)$/) ) {
        params[RegExp.$1] = RegExp.$2;
      } else {
        params[substrs[i]] = true;
      }
    }
  }

//Make sure I'm talking to the correct DB instance
  var db=PhedexPage.DBInstance;
  if ( PhedexPage.Instances ) { PHEDEX.Datasvc.Instances(PhedexPage.Instances); }
  if ( db ) { PHEDEX.Datasvc.Instance( db ); }

  page = page.replace(/::/g,'-');
  page = page.toLowerCase();
  page = 'phedex-nextgen-'+page;
  ngoSuccess = function(item,e) {
    return function() {
//    (try to) Create and run the page
      var cTor = PxU.getConstructor(item);
      if ( !cTor ) { return; }
      try {
        var obj = new cTor(PxS,item);
        obj.useElement(params.el);
        obj.init(params);
      } catch(ex) { }
    };
  }(page);
  var callbacks = {
                    Success:  ngoSuccess,
                    Failure:  function(item) { },
                    Timeout:  function(item) { banner('Timeout loading javascript modules'); },
                    Progress: function(item) { banner('Loaded item: '+item.name); }
                  };
  PxL.load(callbacks,page,'datasvc');
  document.body.className = 'yui-skin-sam';
};
