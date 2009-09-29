/* A PhEDEx base-class and global definitions
   This file also contains the version number for the entire
   application, which must be updated for new releases! */

PHEDEX= {}
PHEDEX.Appserv = {};
PHEDEX.Appserv.Version = '0.1.0';

// shamelessly cribbed from PHEDEX. For more information, see
// http://yuiblog.com/blog/2007/06/12/module-pattern/
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

PHEDEX.namespace('Base');
PHEDEX.Base.Object = function() {
  return {
// not sure I want to put events here too, do I?
//  onHideFilter: new YAHOO.util.CustomEvent("onHideFilter", this, false, YAHOO.util.CustomEvent.LIST),
    dom: [],
    ctl: [],
    options: {},
    _me: 'undefined',
    me: function() { return this._me; },
  };
}
