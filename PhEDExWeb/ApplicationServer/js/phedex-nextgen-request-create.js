PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.Create = function(sandbox) {
  var string = 'nextgen-request-create';
  Yla(this,new PHEDEX.Module(sandbox,string));

  var _sbx = sandbox;
  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      options: {
        width:500,
        height:200,
        minwidth:600,
        minheight:50
      },
      useElement: function(el) {
        this.dom.target = el;
        el.style.border = '1px solid red';
      },
      init: function() {
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr[1];
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action](value);
            }
//            switch ( action ) {
//              case 'useElement':{
//                obj.useElement(value);
//                break;
//              }
//            };
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
      }
    }
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','nextgen-request-create');

