/* PHEDEX.Configuration
* This is Phedex configuration component for static information. The configuration file has uri 
* of local and web HTML source files that has static information about Phedex.
*/
PHEDEX.namespace('Configuration');
PHEDEX.Configuration = (function() {
    var _categories = {};

    /**
    * @method _addCategory
    * @description This adds new category (similar to widget) within static information option. Each category 
    * has html source information along with div ids from which information has to be fetched and shown on UI
    * @param {String} unique id to identify the category internally
    * @param {String} displayname of the category to be used for UI
    */
    var _addCategory = function(id, displayname) {
        if (!_categories[id])
        {
            var category = {};
            category['id'] = id;
            category['name'] = displayname;
            category['sources'] = {};
            _categories[id] = category;
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
    var _addSource = function(catid, sourcename, type, path, divids){
        var category = _categories[catid];
        if (category)
        {
            if (!category.sources[sourcename])
            {
                var source = {};
                source['name'] = sourcename;
                source['type'] = type;
                source['path'] = path;
                source['divids'] = divids;
                category.sources[sourcename] = source;
            }
        }
    };
    
    //Add and register category # 1
    _addCategory('aboutphedex1','About Phedex 1');
    _addSource('aboutphedex1', 'source1', 'local', '/html/AboutPhedex.html', ['phedex-about1', 'phedex-about2', 'phedex-about3']);
    _addSource('aboutphedex1', 'source2', 'local', '/html/PhedexInfo.html', ['phedex-about1', 'phedex-about2', 'phedex-about3']);
    PHEDEX.Core.Widget.Registry.add('aboutphedex1', 'static', 'About Phedex 1', PHEDEX.Static);

    //Add and register category # 2
    _addCategory('aboutphedex2', 'About Phedex 2');
    _addSource('aboutphedex2', 'source12', 'local', '/html/PhedexInfo.html', ['phedex-about1', 'phedex-about2', 'phedex-about3']);
    PHEDEX.Core.Widget.Registry.add('aboutphedex2', 'static', 'About Phedex 2', PHEDEX.Static);
    
    return {
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
})();
YAHOO.log('loaded...','info','Core.Configuration');