PHEDEX.History = function( config ) {
  var _sbx = new PHEDEX.Sandbox(),
      Dom = YAHOO.util.Dom,
      YuH = YAHOO.util.History,
      id = 'history_'+PxU.Sequence(),
      module = 's',
      undefined = 'undefined';
  if ( typeof(config) == 'object' ) {
    if ( config.module ) { module = config.module; }
  }
  log('creating "'+id+'"','info','history');

  _construct = function() {
    return {
      id: id,
      me: 'history',
      meta: {},
      parse: function(state) {
        var key, val, i, params={}, substrs=state, reg=new RegExp('/^'+module+'=');
        if ( state == undefined ) { return params; }
        substrs = substrs.replace(/^.*#/,'')
                         .replace(reg,'');
        substrs = decodeURIComponent(substrs);
        substrs = substrs.replace(/^\?/,'')
                         .replace(/;/g,'&')
                         .replace(/:/g,'=')
        substrs = substrs.split('&');
        for (i in substrs ) {
          if ( substrs[i].match(/^([^=]*)=(.*)$/) ) {
            key = RegExp.$1;
            val = RegExp.$2;
          } else {
            key = substrs[i];
            val = true;
          }
          if ( params[key] ) {
            if ( typeof(params[key]) != 'object'  ) {
              params[key] = [ params[key] ];
            }
            params[key].push(val);
          }
          else { params[key] = val; }
        }
        return params;
      },
      makeHref: function(state) {
        var str='', key, val;
        for (key in state) {
          val = state[key];
          if ( typeof(val) == 'array' ) {
            str += key + '=' + val.join(key+'=');
          } else {
            str += key + '=' + val;
          }
          str += ';';
        }
        str = str.replace(/;$/,'');
        return str;
      },
      onStateChange: function(state) {
        var href = location.pathname + '#' + state,
            params = this.parse(state);
        _sbx.notify('History','stateChange',params);
        _sbx.notify('History','permalink',decodeURIComponent(href));
      },
      init: function() {
        var initialState = YuH.getBookmarkedState(module) ||
                           YuH.getQueryStringParameter(module) ||
                           location.href ||
                            undefined;
            state = this.parse(initialState);
        initialState = this.makeHref(state);
        YuH.register(module,initialState,this.onStateChange,null,this);

        try {
          YuH.initialize('yui-history-field','yui-history-iframe');
        } catch (ex) {
          var _ex=ex;
          return;
        }

        YuH.onReady(function(obj) {
          return function() {
            var href  = location.href, // YuH.getCurrentState(module),
                state = obj.parse(href);
            _sbx.notify('History','initialiseApplication',state);
            href = obj.makeHref(state);
            if ( href /*!= undefined*/ ) {
              _sbx.notify('History','permalink',location.pathname + '#' + href);
            }
          }
        }(this));

        this.handler = function(obj) {
          return function(ev,arr) {
            switch (arr[0]) {
              case 'navigate': {
                var s = arr[1];
                if ( typeof(s) == 'string' ) {
                  s = s.replace(/^.*[\?,#]/,'');
                } else {
                  s = obj.makeHref(s);
                }
                YuH.navigate(module,s);
                break;
              }
              default: {
                break;
              }
            }
          };
        }(this);
        _sbx.listen('History',this.handler);
        _sbx.listen(this.id,  this.handler);
      },
    };
  };

  Yla(this, _construct());
  this.init();
  return this;
}

log('loaded...','info','history');