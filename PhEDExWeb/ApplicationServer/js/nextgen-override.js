// When the DOM is available, start loading the essential bits and pieces
// This is where the real application starts.
YAHOO.util.Event.onDOMReady(function() {
  log('initialising','info','app');
  PxL  = new PHEDEX.Loader();
  banner('Loading core application...');
  PxL.load(createCoreApp,'core','sandbox','datasvc','logger');

  var phedex_app_version = document.getElementById('phedex-app-version');
  if ( phedex_app_version ) { phedex_app_version.innerHTML = PxW.Version; }
});

function createCoreApp() {
// This is called once the core is fully loaded.

  PHEDEX.namespace('Nextgen');
  var page=location.pathname, uri, params={}, substrs, i, ngoSuccess;
  if ( page.match(/([^/]*)(.html)$/) ) { page = RegExp.$1; }
  if ( page.match(/([^/]*)?$/) )       { page = RegExp.$1; }
  params.el = document.getElementById(page);
  if ( !params.el ) { return; }
  banner('loading, please wait...');
  params.el.innerHTML  = 'loading application, please wait...' +
          '<br/>' +
          "<img src='" + PxW.WebAppURL + "/images/barbers_pole_loading.gif'/>";

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
  new PHEDEX.Logger().init();

  uri = location.search;
  if ( uri.match(/^\?(.*)$/) ) {
    substrs = decodeURIComponent(RegExp.$1);
    substrs = substrs.replace(/;/g,'&')
    substrs = substrs.split('&');
    var key, val;
    for (i in substrs ) {
      if ( substrs[i].match(/^([^=]*)=(.*)$/) ) {
        key = RegExp.$1;
        val = RegExp.$2;
      } else {
        key = substrs[i];
        val = true;
      }
      if ( params[key] ) {
        if ( typeof(params[key]) != 'object'  ) {
          params[key] = [ params[key] ];
        }
        params[key].push(val);
      }
      else { params[key] = val; }
    }
  }

//Make sure I'm talking to the correct DB instance
  var db=PhedexPage.DBInstance;
  if ( PhedexPage.Instances ) { PHEDEX.Datasvc.Instances(PhedexPage.Instances); }
  if ( db ) { PHEDEX.Datasvc.Instance( db ); }

  page = page.replace(/::/g,'-');
  page = page.toLowerCase();
  page = 'phedex-nextgen-'+page;
  ngoSuccess = function(p) {
    return function(item) {
//    (try to) Create and run the page
      var cTor = PxU.getConstructor(p);
      if ( !cTor ) {
        params.el.innerHTML  = 'Error loading application!';
        return;
      }
      try {
        var obj = new cTor(PxS,p);
        obj.init(params);
      } catch(ex) {
        var _ex = ex;
        params.el.innerHTML  = 'Error creating application module!';
      }
    };
  }(page);
  var callbacks = {
                    Success:  ngoSuccess,
                    Failure:  function(item) { },
                    Timeout:  function(item) { banner('Timeout loading javascript modules'); },
                    Progress: function(item) { banner('Loaded item: '+item.name); }
                  };
  params.el.innerHTML  = 'loading page-specific modules, please wait...' +
          '<br/>' +
          "<img src='" + PxW.WebAppURL + "/images/barbers_pole_loading.gif'/>";
  PxL.load(callbacks,page,'datasvc');
  document.body.className = 'yui-skin-sam';
};
