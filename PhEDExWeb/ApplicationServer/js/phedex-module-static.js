/**
* This is the PhEDEx static module class. It creates and manages modules that show static information to user.
* The static information configuration is present in the PHEDEX.Config namespace
* @namespace PHEDEX.Module
* @class Static
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/

PHEDEX.namespace('Module');
PHEDEX.Module.Static = function(sandbox, string) {
    Yla(this, new PHEDEX.Module(sandbox, string));
    var category,
        _divspanid = '',
        _divInfo,
        _sbx = sandbox,
        _categories = [],
        _me = 'static',
        _id = _me + '_' + PxU.Sequence();
    log('Module: creating a "' + string + '"', 'info', _me);

    /**
    * @method _checkDivSpanID
    * @description This function is used by YUI DOM to get elements having specific id
    * @param {Object} el is element that is being currently checked.
    * @return {boolean} true if HTML element (div or span) with given id is present in the source file and false if not found.
    * @private
    */
    var _checkDivSpanID = function(el) {
        var tempAttr = YuD.getAttribute(el, 'id');
        if (tempAttr && (tempAttr == _divspanid)) {
            return true;
        }
        else {
            return false;
        }
    };

    /**
    * @method _getDivElementById
    * @description This gets ths div or span element having given id from the child nodes of 
    * the given node using an YUI method
    * @param {String} divspanid is the id of the div or span element in HTML source file.
    * @param {HTML Element} node is the HTML element of source file.
    * @return {HTML Element} HTML element (div or span) with given divspanid.
    * @private
    */
    var _getDivElementById = function(divspanid, node) {
        var divStatInfo;
        _divspanid = divspanid;
        divStatInfo = YuD.getElementBy(_checkDivSpanID, 'div', node);
        if (divStatInfo.length == 0) {
            divStatInfo = YuD.getElementBy(_checkDivSpanID, 'span', node);
            if (divStatInfo.length == 0) {
                log('Div or span element having id ' + divspanid + ' not found', 'info', _me);
                return null; //Not found
            }
            else {
                log('Div or span element having id ' + divspanid + ' is found!', 'info', _me);
                return divStatInfo;
            }
        }
        else {
            log('Div or span element having id ' + divspanid + ' is found!', 'info', _me);
            return divStatInfo;
        }
    }

    /**
    * @method _loadSource
    * @description This makes XMLHTTPrequest using YUI connection manager, gets the HTML source file for the given path. 
    * The required information is extracted from the source HTML file and is added to navigator page.
    * @param {Object} source is the object that has source information (path, type and elementids)
    * @private
    */
    var _loadSource = function(source) {
        var callback = {
            success: function(obj) {
                log('YUI Connection manager XMLHTTP response received', 'info', _me);
                var divTemp = document.createElement('div'); //This is temporary to store the response as HTML element and use it
                //This is to append source specific content to one div so that it doesn't get mixed with other source contents
                var divTempInfo = document.createElement('div');
                divTemp.innerHTML = obj.responseText;
                var strInnerHTML, indx = 0;
                var source = obj.argument;
                for (indx = 0; indx < source.divids.length; indx++) {
                    try {
                        strInnerHTML = '';
                        //Parse the HTML content to get div element having given div or span element id
                        var divStatInfo = _getDivElementById(source.divids[indx], divTemp);
                        if (divStatInfo) {
                            if (divStatInfo.innerHTML) {
                                strInnerHTML = divStatInfo.innerHTML;
                            }
                            else {
                                strInnerHTML = new XMLSerializer().serializeToString(divStatInfo);
                            }
                        }
                    }
                    catch (e) {
                        strInnerHTML = '<div><b><i>Error in getting data from source information file</i></b></div>';
                    }
                    var divStaticInfo = document.createElement('div');
                    divStaticInfo.innerHTML = strInnerHTML;
                    divTempInfo.appendChild(divStaticInfo);
                    divTempInfo.appendChild(document.createElement('br'));
                    log('HTML source file content is added to navigator for divid: ' + source.divids[indx], 'info', _me);
                }
                _divInfo.appendChild(divTempInfo);
                return;
            },

            failure: function(obj) {
                log('Communication error. Invalid or unable to read HTML source file ' + source.path, 'error', _me);
                _divInfo.appendChild(document.createElement('br'));
                return;
            },
            timeout: 10000, //YUI connection manager timeout in milliseconds.
            argument: source //source information is required later for processing
        };
        Yu.Connect.asyncRequest('GET', source.path, callback, null);
        log('YUI Connection Manager XMLHTTP Request is made', 'info', _me);
    }

    /**
    * @method _loadCategory
    * @description This loads the static component category in the navigator using its configured sources.
    * @param {HTML Element} divTarget is the HTML element object where the category specific static information has to be appended
    * @private
    */
    this._loadCategory = function(divTarget) {
        var sourcename = '';
        try {
            if (_divInfo) {
                while (_divInfo.hasChildNodes()) {
                    _divInfo.removeChild(_divInfo.lastChild);
                }
                log('The static content is destroyed', 'info', _me);
            }
            _divInfo = PxU.makeChild(divTarget, 'div');
            var categoryinfo = _categories[category]; //Get the category info i.e. sources info
            if ( !categoryinfo ) { return; }
            for (sourcename in categoryinfo.sources) {
                var source = categoryinfo.sources[sourcename];
                if (source.type == 'local') {
                    _loadSource(source);
                    log('local source info is added to navigator for source: ' + source.path, 'info', _me);
                }
                else if (source.type == 'iframe') {
                    //Create iframe element and add to navigator
                    var iframeInfo = document.createElement('iframe');
                    iframeInfo.src = source.path;
                    iframeInfo.className = 'phedex-static-iframe';
                    _divInfo.appendChild(iframeInfo);
                    log('iframe is added to navigator for source: ' + source.path, 'info', _me);
                }
                else if (source.type == 'extra') {
                    var divOutLink = document.createElement('div');
                    if (source.displaytext) {
                        //Create span element and fill it only if there is data to fill
                        var spanDispText = document.createElement('span');
                        spanDispText.innerHTML = source.displaytext;
                        divOutLink.appendChild(spanDispText);
                    }
                    if (source.path) {
                        //Create href element and fill it only if there is external link
                        var elHref = document.createElement('a');
                        elHref.href = source.path;
                        elHref.target = "_blank"; //To make link open in new tab
                        elHref.innerHTML = source.path;
                        divOutLink.appendChild(elHref);
                    }
                    _divInfo.appendChild(divOutLink);
                    log('extra info is added to navigator', 'info', _me);
                }
            }
        }
        catch (ex) {
            log(ex, 'error', _me);
            banner('Error in static component', 'error', _me);
            return;
        }
        this._gettingData = true;
    }

    var configHandler = function(o) {
      return function(ev,arr) {
        var action = arr[0],
            value = arr[1];
        switch (action) {
          case 'Categories': {
            _categories = value;
            o.initData();
            break;
          }
        }
      }
    }(this);
    _sbx.listen('Config',configHandler);

  this.isStateValid = function() { if ( category ) { return true; } return false; };
  this.getState = function() { return category; };
  this.getStatePlugin = function(obj) {
    return function(who) {
      _sbx.notify(who,'statePlugin',
                 {
                  key:'module',
                  state:function() { return obj.getState(); },
                  isValid:function() { return obj.isStateValid(); }
                 });
    };
  }(this);


    /**
    * Used to construct the static component module.
    * @method _construct
    */
    _construct = function() {
      return {
        /**
         * Create a Phedex.Static module to show the static information.
         * @method initData
         * @param {Object} args is the object that has arguments for the module
         */
        initData: function() {
          log('module creation initiated', 'info', _me);
          var OK = true;
          if ( !category ) {
            _sbx.notify( 'module', 'needArguments', this.id );
            OK = false;
          }
          if ( !_categories[category] ) {
            _sbx.notify('Config','getCategories');
            OK = false;
          }
          if ( !OK ) { return; }
          _sbx.notify(this.id,'initData');
        },
        getData: function() {
          if ( this._gettingData ) { return; }
          this.dom.title.innerHTML = 'Loading content.. Please wait...';
          this._loadCategory(this.dom.content);
          log('static content loaded for category ' + category, 'info', _me);
          this.dom.title.innerHTML = '';
        },
            
        /**
         * Sets the category for the module whose information has to be shown on navigator.
         * @method setArgs
         * @param {Object} args is the object that has arguments (category id) for the module
         */
        setArgs: function(args) {
          if ( typeof(args) == 'object' && args['static'] ) {
            category = args['static'];
            log('category is set to ' + category, 'info', _me);
            _sbx.notify(this.id,'setArgs');
          }
        }
      };
    }
    Yla(this, _construct(), true);
    return this;
}
