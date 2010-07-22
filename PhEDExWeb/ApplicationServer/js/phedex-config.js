/* PHEDEX.Config
* This is Phedex configuration component for static information. The configuration file has uri 
* of local and web HTML source files that has static information about Phedex.
*/
// PHEDEX.namespace('Configuration');
PHEDEX.Config = function(sandbox) {
  var _sbx = sandbox,
      _categories = {},
      _me = 'config',
      _id = _me + '_' + PxU.Sequence();

  /**
  * @method _addCategory
  * @description This adds new category (similar to widget) within static information option. Each category
  * has html source information along with div ids from which information has to be fetched and shown on UI
  * @param {String} unique id to identify the category internally
  * @param {String} displayname of the category to be used for UI
  */
  var _addCategory = function(id, displayname) {
    if (!_categories[id]) {
      var category = {};
      category['id'] = id;
      category['name'] = displayname;
      category['sources'] = {};
      _categories[id] = category;
      log('Category ' + displayname + ' added', 'info', _me);
    }
  };

  /**
  * @method _addSource
  * @description This adds source information for the given category. The source includes URI of source file,
  * source type (local file or web file) ,div ids within source file from which information has to be fetched
  * @param {String} catid is the id of the category to which source information has to be added
  * @param {String} sourcename is unique name to identify source within a category
  * @param {String} type is type of source file (local or web)
  * @param {String} path is the URI of the source HTML file
  * @param {Array} divids is array of unique divids of elements within source file
  */
  var _addSource = function(catid, sourcename, sourcecfg) {
    var category = _categories[catid];
    if (category) {
      if (!category.sources[sourcename]) {
        var source = {};
        source['name'] = sourcename;
        for (var key in sourcecfg) {
          source[key] = sourcecfg[key];
        }
        category.sources[sourcename] = source;
        log('Source ' + sourcename + ' added to Category ' + catid, 'info', _me);
      }
    }
  };

  var selfHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          value = arr[1];
      switch (action) {
        case 'getCategories': {
          _sbx.notify('Config','Categories',_categories);
          break;
        }
        case 'getCategory': {
          _sbx.notify('Config','Category',_categories[value]);
          break;
        }
      }
    }
  }(this);
  _sbx.listen('Config',selfHandler);

  return {
    init: function(args) {
      //Add and register category # 1 (out link type)
      var fn1 = function(text) { return "<div style='width:250px; text-align:right; display:inline-block'>"+text+'</div>'; },
          fn2 = function(text) { return '<a href='+text+'>'+text+'</a>'; },
          fn3 = function(link,text) { return '<div>'+fn1(text)+fn2(link)+'</div>'; }
      _addCategory('aboutphedex1', 'Phedex Documentation Links'); //displaytext

      _addSource('aboutphedex1', 'source1', { type: 'extra', displaytext:fn3('https://twiki.cern.ch/twiki/bin/viewauth/CMS/PhEDEx','PhEDEx TWiki home:') });
      _addSource('aboutphedex1', 'source2', { type: 'extra', displaytext:fn3('https://twiki.cern.ch/twiki/bin/viewauth/CMS/PhedexDraftDocumentation','PhEDEx Documentation:') });
      _addSource('aboutphedex1', 'source3', { type: 'extra', displaytext:fn3('https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjWebsite', 'PhEDEx WebSite planning: ') });
      _addSource('aboutphedex1', 'source4', { type: 'extra', displaytext:fn3('https://twiki.cern.ch/twiki/bin/view/CMS/PhEDExWebsiteDeveloperGuide','PhEDEx WebSite Developer guide:') });
      _addSource('aboutphedex1', 'source5', { type: 'extra', displaytext:fn3('/phedex/datasvc/app/examples/index.html','PhEDEx WebSite coding examples:') });

//    _addSource('aboutphedex1', 'source1', { type: 'extra', path: 'https://twiki.cern.ch/twiki/bin/viewauth/CMS/PhEDEx', displaytext: 'PhEDEx TWiki home: ' });
//    _addSource('aboutphedex1', 'source2', { type: 'extra', path: 'https://twiki.cern.ch/twiki/bin/viewauth/CMS/PhedexDraftDocumentation', displaytext: 'PhEDEx Documentation: ' });
//    _addSource('aboutphedex1', 'source3', { type: 'extra', path: 'https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjWebsite', displaytext: fn('PhEDEx WebSite planning: ') });
//    _addSource('aboutphedex1', 'source4', { type: 'extra', path: 'https://twiki.cern.ch/twiki/bin/view/CMS/PhEDExWebsiteDeveloperGuide', displaytext: 'PhEDEx WebSite Developer guide: ' });
//    _addSource('aboutphedex1', 'source5', { type: 'extra', path: '/phedex/datasvc/app/examples/index.html', displaytext: 'PhEDEx WebSite coding examples: ' });
//    _addSource('aboutphedex1', 'source99', { type: 'extra', displaytext: '<i>This is testing for displaying direct text in Phedex static component</i>' });
      _sbx.notify('Registry', 'add', 'phedex-module-static', 'static', 'Phedex Documentation Links', { args:{'static':'aboutphedex1'} });

      //Add and register category # 2 (local type)
//       _addCategory('aboutphedex2', 'Phedex Local');
//       _addSource('aboutphedex2', 'source1', { type: 'local', path: '/html/AboutPhedex.html', divids: ['phedex-about1', 'phedex-about2', 'phedex-about3'] });
//       _addSource('aboutphedex2', 'source2', { type: 'local', path: '/html/PhedexInfo.html', divids: ['phedex-about1', 'phedex-about3'] });
//       _sbx.notify('Registry', 'add', 'phedex-module-static', 'static', 'Phedex Local',  { args:{'static':'aboutphedex2'} });

      //Add and register category # 3 (iframe type)
      _addCategory('aboutphedex3', 'Phedex TWiki');
      _addSource('aboutphedex3', 'source1', { type: 'iframe', path: 'https://twiki.cern.ch/twiki/bin/viewauth/CMS/PhedexDraftDocumentation' });
      _sbx.notify('Registry', 'add', 'phedex-module-static', 'static', 'Phedex TWiki', { args:{'static':'aboutphedex3'} });

//       //Add and register category # 4 (local type)
//       _addCategory('aboutphedex4', 'Phedex Webapp coding examples');
//       _addSource('aboutphedex4', 'source1', { type: 'local', path: '/examples/index.html', divids: ['phedex-webapp-examples'] });
//       _sbx.notify('Registry', 'add', 'phedex-module-static', 'static', 'Phedex Webapp coding examples',  { args:{'static':'aboutphedex4'} });
    },

    /**
    * @method categories
    * @description This returns the available configured categories
    */
    categories: function() {
      return _categories;
    },

    /**
    * @method getCategory
    * @description This returns the available configured categories
    */
    getCategory: function(catname) {
      return _categories[catname];
    }
  };
};

PHEDEX.Core.onLoaded('config');
log('loaded...','info','config');
