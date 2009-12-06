/* PHEDEX.Static
* This is Phedex static component that fetches static information from source HTML files and displays
* it on UI. The static information configuration is present in the PHEDEX.Configuration namespace
*/
PHEDEX.namespace('Static');
PHEDEX.Static = function(category, divStatic, opts) {
    var PxU = PHEDEX.Util;
    var PxC = PHEDEX.Configuration;
    var DOM = YAHOO.util.Dom;
    var _divspanid = '';
    if (!divStatic) { divStatic = PHEDEX.Util.generateDivName(); }

    /**
    * @method _getHTML
    * @description This makes XMLHTTPrequest and gets the HTML source file for the given path
    * @param {String} strFilePath is the HTML source file path (local or web file).
    */
    var _getHTML = function(strFilePath) {
        var xhttp;
        if (window.XMLHttpRequest) {
            xhttp = new XMLHttpRequest();
        }
        else if (window.ActiveXObject) { // For older IE
            try {
                xhttp = new ActiveXObject("Msxml2.XMLHTTP");
            }
            catch (e) {
                try {
                    xhttp = new ActiveXObject("Microsoft.XMLHTTP");
                }
                catch (e) {
                }
            }
        }
        if (!xhttp) {
            YAHOO.log('Cannot create XMLHTTP instance', 'error', 'PHEDEX.Static');
            return null;
        }
        xhttp.open('GET', strFilePath, false);
        YAHOO.log('XMLHTTP Request is going to be made', 'info', 'Phedex.Static');
        xhttp.send("");
        YAHOO.log('XMLHTTP Response is received', 'info', 'Phedex.Static');
        return xhttp.responseText;
    }

    /**
    * @method _checkDivSpanID
    * @description This function is used by YUI DOM to get elements having specific id
    * @param {Object} el is element that is being currently checked.
    */
    var _checkDivSpanID = function(el) {
        var tempAttr = DOM.getAttribute(el, 'id');
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
    */
    var _getDivElementById = function(divspanid, node) {
        var divStatInfo;
        _divspanid = divspanid;
        divStatInfo = DOM.getElementBy(_checkDivSpanID, 'div', node);
        if (divStatInfo.length == 0) {
            divStatInfo = DOM.getElementBy(_checkDivSpanID, 'span', node);
            if (divStatInfo.length == 0) {
                YAHOO.log('Div or span element having id ' + divspanid + ' not found', 'info', 'Phedex.Static');
                return null; //Not found
            }
            else {
                return divStatInfo;
                YAHOO.log('Div or span element having id ' + divspanid + ' is found!', 'info', 'Phedex.Static');
            }
        }
        else {
            return divStatInfo;
            YAHOO.log('Div or span element having id ' + divspanid + ' is found!', 'info', 'Phedex.Static');
        }
    }

    var staticinfo = {};
    var indx = 0, sourcename = '', strInnerHTML = '';
    try {
        if (typeof (divStatic) == 'obj') {
            staticinfo.divStatic = divStatic;
        }
        else {
            staticinfo.divStatic = document.getElementById(divStatic);
        }
        staticinfo._me = 'PHEDEX.Static';
        staticinfo.me = function() { return that._me; }
        staticinfo.divInfo = PxU.makeChild(divStatic, 'div');
        var categoryinfo = PxC.getCategory(category); //Get the category info i.e. sources info
        for (sourcename in categoryinfo.sources) {
            var source = categoryinfo.sources[sourcename];
            if (source.type == 'local') {
                var htmlDoc = _getHTML(source.path);
                YAHOO.log(source.path + ' source file content is obtained!', 'info', 'Phedex.Static');
                strInnerHTML = '';
                if (htmlDoc) {
                    var divTemp = document.createElement('div');
                    divTemp.innerHTML = htmlDoc;
                    for (indx = 0; indx < source.divids.length; indx++) {
                        try {
                            strInnerHTML = '';
                            var divStatInfo = _getDivElementById(source.divids[indx], divTemp); //Parse the HTML content to get div element having given divid
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
                            YAHOO.log('Error while parsing read HTML source file ' + source.path, 'error', 'Phedex.Static');
                        }
                        var divStaticInfo = document.createElement('div');
                        divStaticInfo.innerHTML = strInnerHTML;
                        staticinfo.divInfo.appendChild(divStaticInfo);
                        staticinfo.divInfo.appendChild(document.createElement('br'));
                        YAHOO.log('HTML source file content is added to navigator for divid: ' + source.divids[indx], 'info', 'Phedex.Static');
                    }
                }
                else {
                    YAHOO.log('Invalid or unable to read HTML source file ' + source.path, 'error', 'Phedex.Static');
                    staticinfo.divInfo.appendChild(document.createElement('br'));
                }
            }
            else if (source.type == 'iframe') {
                //Create iframe element and add to navigator
                var iframeInfo = document.createElement('iframe');
                iframeInfo.src = source.path;
                iframeInfo.className = 'phedex-static-iframe';
                staticinfo.divInfo.appendChild(iframeInfo);
                YAHOO.log('iframe is added to navigator for source: ' + source.path, 'info', 'Phedex.Static');
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
                staticinfo.divInfo.appendChild(divOutLink);
                YAHOO.log('extra info is added to navigator', 'info', 'Phedex.Static');
            }
        }

        staticinfo.destroy = function() {
            while (staticinfo.divStatic.hasChildNodes()) {
                staticinfo.divStatic.removeChild(staticinfo.divStatic.lastChild);
            }
            YAHOO.log('The static content is destroyed', 'info', 'Phedex.Static');
        };
    }
    catch (ex) {
        YAHOO.log('Error in static component', 'error', 'PHEDEX.Static');
    }
    return staticinfo;
}