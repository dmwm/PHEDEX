PHEDEX.namespace('Event');

PHEDEX.Event = {
    onFilterValidated: new YAHOO.util.CustomEvent('onFilterValidated', this, false, YAHOO.util.CustomEvent.LIST),
    onFilterAccept:    new YAHOO.util.CustomEvent('onFilterAccept', this, false, YAHOO.util.CustomEvent.LIST),
    onFilterCancel:    new YAHOO.util.CustomEvent('onFilterCancel', this, false, YAHOO.util.CustomEvent.LIST),
}
