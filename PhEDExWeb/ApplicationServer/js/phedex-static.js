/* PHEDEX.Static
* This is Phedex static component that fetches static information from source HTML files and displays
* it on UI. The static information configuration is present in the PHEDEX.Configuration namespace
*/
PHEDEX.namespace('Static');
PHEDEX.Static = function(category, divStatic, opts) {
    var PxU = PHEDEX.Util;
    var PxC = PHEDEX.Configuration;
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
            alert('Cannot create XMLHTTP instance');
            return null;
        }
        xhttp.open('GET', strFilePath, false);
        xhttp.send("");
        return xhttp.responseText;
    }

    /**
    * @method _getDivElementById
    * @description This gets ths div or span element having given id from the child nodes of the given node
    * @param {String} divspanid is the id of the div or span element in HTML source file.
    * @param {HTML Element} node is the HTML element of source file.
    */
    var _getDivElementById = function (divspanid, node) {
        var divElements = node.getElementsByTagName('div');
        var spanElements = node.getElementsByTagName('span');
        var regexId = new RegExp("(^|\\s)" + divspanid + "(\\s|$)");
        var tempAttr = null, i = 0;
        for (i = 0; i < divElements.length; i++) {
            tempAttr = divElements[i].attributes.getNamedItem('id');
            if (tempAttr) {
                if (regexId.test(tempAttr.value)) {
                    return divElements[i]; //Return the div element
                }
            }
        }
        for (i = 0; i < spanElements.length; i++) {
            tempAttr = spanElements[i].attributes.getNamedItem('id');
            if (tempAttr) {
                if (regexId.test(tempAttr.value)) {
                    return spanElements[i]; //Return the span element
                }
            }
        }
        return null; //Not found
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
        var categoryinfo = PxC.getCategory(category);
        for (sourcename in categoryinfo.sources) {
            var source = categoryinfo.sources[sourcename];
            var htmlDoc = _getHTML(source.path);
            strInnerHTML = '';
            if (htmlDoc) {
                var divTemp = document.createElement('div');
                divTemp.innerHTML = htmlDoc;
                for (indx = 0; indx < source.divids.length; indx++) {
                    try {
                        strInnerHTML = '';
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
                    staticinfo.divInfo.appendChild(divStaticInfo);
                    staticinfo.divInfo.appendChild(document.createElement('br'));
                }
            }
            else {
                var divStaticInfo = document.createElement('div');
                divStaticInfo.innerHTML = strInnerHTML;
                staticinfo.divInfo.appendChild(divStaticInfo);
                staticinfo.divInfo.appendChild(document.createElement('br'));
            }
        }

        staticinfo.destroy = function() {
            while (staticinfo.divStatic.hasChildNodes()) {
                staticinfo.divStatic.removeChild(staticinfo.divStatic.lastChild);
            }
        };
    }
    catch (ex) {
        alert('Error in static component');
    }
    return staticinfo;
}