PHEDEX.namespace('Event');

PHEDEX.Event = {
    onWidgetDestroy:          new YAHOO.util.CustomEvent('onWidgetDestroy',         this, false, YAHOO.util.CustomEvent.LIST),
    onListWidgets:            new YAHOO.util.CustomEvent('onListWidgets',           this, false, YAHOO.util.CustomEvent.LIST),

    onFilterDefined:          new YAHOO.util.CustomEvent('onFilterDefined',         this, false, YAHOO.util.CustomEvent.LIST),

    onWidgetFilterCancelled:  new YAHOO.util.CustomEvent('onWidgetFilterCancelled', this, false, YAHOO.util.CustomEvent.LIST),
    onGlobalFilterCancelled:  new YAHOO.util.CustomEvent('onGlobalFilterCancelled', this, false, YAHOO.util.CustomEvent.LIST),

    onWidgetFilterValidated:  new YAHOO.util.CustomEvent('onGlobalFilterValidated', this, false, YAHOO.util.CustomEvent.LIST),
    onGlobalFilterValidated:  new YAHOO.util.CustomEvent('onGlobalFilterValidated', this, false, YAHOO.util.CustomEvent.LIST),

    onWidgetFilterApplied:    new YAHOO.util.CustomEvent('onWidgetFilterApplied',   this, false, YAHOO.util.CustomEvent.LIST),
    onGlobalFilterApplied:    new YAHOO.util.CustomEvent('onGlobalFilterApplied',   this, false, YAHOO.util.CustomEvent.LIST),

    CreateGlobalFilter:       new YAHOO.util.CustomEvent('CreateGlobalFilter',      this, false, YAHOO.util.CustomEvent.LIST),
}
