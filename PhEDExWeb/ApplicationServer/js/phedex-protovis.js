/**
* This is the base class for all PhEDEx nested datatable-related modules. It extends PHEDEX.Module to provide the functionality needed for modules that use a YAHOO.Widget.NestedDataTable.
* @namespace PHEDEX
* @class PHEDEX.DataTable
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.Protovis = function (sandbox, string) {
    Yla(this, new PHEDEX.Module(sandbox, string));
    var _me = 'protovis', _sbx = sandbox;

    /**
    * this instantiates the actual object, and is called internally by the constructor. This allows control of the construction-sequence, first augmenting the object with the base-class, then constructing the specific elements of this object here, then any post-construction operations before returning from the constructor
    * @method _construct
    * @private
    */
    _construct = function () {
        return {
            /**
            * Used in PHEDEX.Module and elsewhere to derive the type of certain decorator-style objects, such as mouseover handlers etc. These can be different for TreeView and DataTable objects, so will be picked up as PHEDEX.[this.type].function(), or similar.
            * @property type
            * @default DataTable
            * @type string
            * @private
            * @final
            */
            type: 'Protovis',

            /** return a boolean indicating if the module is in a fit state to be bookmarked
            * @method isStateValid
            * @return {boolean} <strong>false</strong>, must be over-ridden by derived types that can handle their separate cases
            */
            isStateValid: function () {
                if (this.obj.data) { return true; } // TODO is this good enough...? Use _needsParse...?
                return false;
            },

            /** Initialise the data-table, using the parameters in this.meta.table, set in the module during construction
            * @method initDerived
            * @private
            */
            initDerived: function () {
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
}

PHEDEX.Protovis.MouseOver = function(sandbox,args) {
    var obj = args.payload.obj,
        _sbx = sandbox;

    _construct = function() {
      return {
        id: 'mouseover_' + PxU.Sequence(),
        _init: function() {
        }
      };
    };
    Yla(this,_construct(this),true);
    this._init();
    return this;
};

log('loaded...', 'info', 'protovis');
