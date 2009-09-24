PHEDEX.namespace('Event');

PHEDEX.Event = {
    onWidgetDestroy:    new YAHOO.util.CustomEvent('onWidgetDestroy',    this, false, YAHOO.util.CustomEvent.LIST),
    onFilterValidated:  new YAHOO.util.CustomEvent('onFilterValidated',  this, false, YAHOO.util.CustomEvent.LIST),
    onFilterAccept:     new YAHOO.util.CustomEvent('onFilterAccept',     this, false, YAHOO.util.CustomEvent.LIST),
    onFilterCancel:     new YAHOO.util.CustomEvent('onFilterCancel',     this, false, YAHOO.util.CustomEvent.LIST),
    onFilterDefinition: new YAHOO.util.CustomEvent('onFilterDefinition', this, false, YAHOO.util.CustomEvent.LIST),
}
