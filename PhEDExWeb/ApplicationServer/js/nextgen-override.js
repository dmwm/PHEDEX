// When the DOM is available, start loading the essential bits and pieces
// This is where the real application starts.
YAHOO.util.Event.onDOMReady(function() {
  PxW.combineRequests = false;
  log('initialising','info','app');
  PxL  = new PHEDEX.Loader();
  banner('Loading core application...');
  PxL.load(createCoreApp,'core','sandbox');

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

  banner('Core application is running, ready to create PhEDEx data-modules...');
//   PxU.bannerIdleTimer(PxL,{active:'&nbsp;'});

  var page=location.href, el, uri, params={}, substrs, i, ngoSuccess;
  if ( page.match(/^(.*)\?/)  )        { page = RegExp.$1; }
  if ( page.match(/([^/]*)(.html)$/) ) { page = RegExp.$1; }
  if ( page.match(/([^/]*)?$/) )       { page = RegExp.$1; }
  el = document.getElementById(page);

  if ( el ) {
    banner('loading, please wait...');
    page = page.replace(/::/g,'-');
    page = page.toLowerCase();
    page = 'phedex-nextgen-'+page;

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
    ngoSuccess = function(item,e) {
      return function() {
        var db, cTor;
//      Make sure I'm talking to the correct DB instance
        db=PhedexPage.DBInstance;
        if ( PhedexPage.Instances ) { PxW.Instances = PhedexPage.Instances; }
        PHEDEX.Datasvc.Instance( db );
//      (try to) Create and run the page
        cTor = PxU.getConstructor(item);
        if ( !cTor ) { return; }
        try {
          var obj = new cTor(PxS,item);
          obj.useElement(e);
          obj.init(params);
        } catch(ex) { }
      };
    }(page,el);
    var callbacks = {
                      Success:  ngoSuccess,
                      Failure:  function(item) { },
                      Timeout:  function(item) { banner('Timeout loading javascript modules'); },
                      Progress: function(item) { banner('Loaded item: '+item.name); }
                    };
    PxL.load(callbacks,page,'datasvc');
    document.body.className = 'yui-skin-sam';
  }
};
