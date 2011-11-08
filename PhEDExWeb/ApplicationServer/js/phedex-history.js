PHEDEX.History = function( config ) {
  var _sbx = new PHEDEX.Sandbox(),
      Dom = YAHOO.util.Dom,
      YuH = YAHOO.util.History,
      id = 'history_'+PxU.Sequence(),
      module = 'state',
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
      config: config,
      module: module,
      moduleRegex: new RegExp('^'+module+'='),
      parse: function(href) {
        var key, val, i, state={}, substrs=href;
        if ( href == undefined ) { return state; }
        substrs = substrs.replace(/^.*#/,'')
                         .replace(this.moduleRegex,'');
        substrs = decodeURIComponent(substrs);
        substrs = substrs.replace(/^.*\?/,'')
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
          if ( state[key] ) {
            if ( typeof(state[key]) != 'object'  ) {
              state[key] = [ state[key] ];
            }
            state[key].push(val);
          }
          else { state[key] = val; }
        }
        return state;
      },
      makeHref: function(state) {
        var href='', i, key, val, stateKeys=[];
        for (key in state) {
          stateKeys.push(key);
        }
        if ( !stateKeys.length ) { return ''; }
        stateKeys = stateKeys.sort();
        for (i in stateKeys) {
          key = stateKeys[i];
          val = state[key];
          if ( typeof(val) == 'array' || typeof(val) == 'object' ) {
            href += key + '=' + val.join(';'+key+'=');
          } else {
            href += key + '=' + val;
          }
          href += ';';
        }
        href = href.replace(/;$/,'');
        return href;
      },
      onStateChange: function(state) {
        if ( typeof(state) == 'string' ) { state = this.parse(state); }
        var href = this.makeHref(state);
        if ( this.href == href ) { return; }
        this.href = href;
        _sbx.notify('History','stateChange',state,href);
        log('history','info','state change: '+href);
        this.notifyApplication(href);
      },
      notifyApplication: function(href) {
        if ( this.href == href ) { return; }
        this.href = href;
        _sbx.notify('History','permalink',href);
        log('history','info','notify application: '+href);
      },
      reveal: function() {
        var container = config.container;
        if ( typeof(container) == 'string' ) {
          container = Dom.get(container);
        }
        if ( !container ) { return; }
        config.container = container;
        container.style.display = '';
        container.style.color = '';
        this.reveal = function() {}; // make idempotent
        log('history','info','revealing permalink');
      },
      setLink: function(href) {
        var el = config.el,
            uri = location.href;
        if ( typeof(el) == 'string' ) {
          el = Dom.get(el);
        }
        if ( !el ) { return; }
        config.el = el;
        uri = uri.replace(/#.*$/,'')
                 .replace(/\?.*$/,'');
        href = uri + '#' + href;
        el.setAttribute('href',href);
        log('history','info','set permalink: '+href);
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
            var state, href = location.href;
            state = obj.parse(href);
            _sbx.notify('History','initialiseApplication',state);
            href = obj.makeHref(state);
            if ( href ) {
              obj.notifyApplication(href);
            }
          }
        }(this));

        this.handler = function(obj) {
          return function(ev,arr) {
            switch (arr[0]) {
              case 'navigate': {
                var href = arr[1];
                if ( typeof(href) == 'string' ) {
                  href = href.replace(/^.*[\?,#]/,'');
                } else {
                  href = obj.makeHref(href);
                }
                _sbx.notify('History','navigatedTo',href);
                YuH.navigate(module,href);
                log('history','info','navigated to '+href);
                break;
              }
              case 'permalink': {
                obj.setLink(arr[1]);
                obj.reveal();
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