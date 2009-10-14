/**
 * The PhEDEx Application.
 * @module PHEDEX
 */

/**
 * The PHEDEX global namespace object.
 * @class PHEDEX
 */
PHEDEX= {}

/** 
 * Creates a namespace rooted from PHEDEX.
 * @method namespace
 * @param namespace {string} Namespace to create, optionally with  dot-notation, e.g. 'Appserv' or 'Base.Object'.
 * @return {object} The namespace created.
 */
// For more information, see:
//   http://yuiblog.com/blog/2007/06/12/module-pattern/
PHEDEX.namespace = function() {
    var a=arguments, o=null, i, j, d;
    for (i=0; i<a.length; i=i+1) {
        d=(""+a[i]).split(".");
        o=PHEDEX;

        // PHEDEX is implied, so it is ignored if it is included
        for (j=(d[0] == "PHEDEX") ? 1 : 0; j<d.length; j=j+1) {
            o[d[j]]=o[d[j]] || {};
            o=o[d[j]];
        }
    }

    return o;
};

/**
 * Contains application globals.
 * @namespace PHEDEX
 * @class Appserv
 */
PHEDEX.Appserv = {};

/**
 * Sets the version of the application, using a string set by the RPM build or a default.
 * @method makeVersion
 * @namespace PHEDEX.Appserv
 * @protected
 * @return {string} The version string
 */
PHEDEX.Appserv.makeVersion = function() {
  var version = '@APPSERV_VERSION@'; // set when RPM is built
  return version.match(/APPSERV_VERSION/) ? '0.0.0' : version;
};

/**
 * The version of the application.
 * @property Version
 * @type string
 * @public
 */
PHEDEX.Appserv.Version = PHEDEX.Appserv.makeVersion();


/**
 * Base object for all graphical entities in the application.
 * @namespace PHEDEX.Base
 * @class Object
 * @constructor
 */
PHEDEX.namespace('Base');
PHEDEX.Base.Object = function() {
  return {
// not sure I want to put events here too, do I?
//  onHideFilter: new YAHOO.util.CustomEvent("onHideFilter", this, false, YAHOO.util.CustomEvent.LIST),

    /**
     * Fired when the "extra" div has been populated.
     * @event onFillExtra
     */
    onFillExtra: new YAHOO.util.CustomEvent("onFillExtra", this, false, YAHOO.util.CustomEvent.LIST),

    /**
     * Namespace for DOM elements managed by this object.
     * @property dom
     * @type array
     * @protected
     */
    dom: [],

    /**
     * Namespace for control elements managed by this object.
     * @property ctl
     * @type array
     * @protected
     */
    ctl: [],

    /**
     * Namespace for options in effect for this object.
     * @property options
     * @type object
     * @protected
     */
    options: {},

    /**
     * The class name of this object.
     * @property _me
     * @type string
     * @protected
     */
    _me: 'undefined',

    /**
     * Returns the class name of this object
     * @method me
     * @returns string
     */
    // TODO:  There must be a lower-level way to do this, using obj.constructor or simmilar
    me: function() { return this._me; },
  };
}
