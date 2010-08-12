/*
 * Stuff specific to tony's debugging efforts
 */

stressTest = function(type) {
  var el = document.getElementById('phedex-debug'),
      d  = document.getElementById('phedex-debug-status'),
      i  = 0,
      run = 1;
  if ( !d ) {
    d = document.createElement('div');
    d.id = 'phedex-debug-status';
    el.appendChild(d);
  }
  d.innerHTML='starting...';
  var start = new Date();
  var moduleHandler = function(who,arr) {
    switch ( arr[0] ) {
      case 'gotData': {
        if ( run == 0 ) { break; }
        PxS.notify('module',who,'destroy');
        break;
      }
      case 'destroy': {
        if ( run == 0 ) { break; }
        i++;
        d.innerHTML = 'iterations so far: '+i;
//         setTimeout(function() { PxS.notify('CreateModule',type); }, 0);
        setTimeout(PxS.notify, 0, 'CreateModule', type);
        break;
      }
    }
  };

  var _moduleExists = function(ev,arr) {
    PxS.listen(arr[0].id,moduleHandler);
  };
  PxS.listen('ModuleExists', _moduleExists);
  setTimeout(function() {
      run = 0;
      var stop = new Date();
      stop = (stop.getTime() - start.getTime())/1000;
      d.innerHTML += '<br />Test took '+stop+'seconds';
    }, 60000);
  PxS.notify('CreateModule',type);
}

makeNavigator = function() {
  PxS.notify('Load','phedex-navigator', {
    el: 'phedex-navigator',
    cfg: {
      typecfg: {
        none:    { label: 'Explore global',   order: 10 },
        node:    { label: 'Explore by node',  order: 20 },
        block:   { label: 'Explore by block', order: 30 },
        group:   { label: 'Explore by group', order: 40 },
       'static': { label: 'Explore Information', order: 99 },
      }
    }
  });
};

var fn=[];
debugLinks = function() {
// cheat, providing a few links to create modules from...
  var el = document.getElementById('phedex-debug'),
      methods = [ 'show','hide','destroy' ];
  el.appendChild(document.createTextNode('Core operations (all modules)'));
  for (var i in methods) {
    var div = document.createElement('div'),
        a   = document.createElement('a');
    a.href='#';
    a.innerHTML = methods[i];
    a.setAttribute('onclick',"PxS.notify('module','*','"+methods[i]+"');");
    div.appendChild(a);
    el.appendChild(div);
  };
  el.appendChild(document.createTextNode('Create module(s)'));
  var modules = PxL.knownModules();
  for (var i in modules) {
    var div = document.createElement('div'),
        a   = document.createElement('a');
    a.href='#';
    a.innerHTML = modules[i];
    a.setAttribute('onclick',"PxS.notify('CreateModule','"+modules[i]+"');");
    div.appendChild(a);
    el.appendChild(div);
  }

    var div = document.createElement('div'),
        a   = document.createElement('a');
    a.href='#';
    a.innerHTML = 'navigator';
    a.setAttribute('onclick','makeNavigator()');
    div.appendChild(a);
    el.appendChild(div);

  el.appendChild(document.createTextNode('Stress-test modules'));
  modules.push('dummy');
  for (var i in modules) {
    var type = PxU.initialCaps(modules[i]);
    var d = document.createElement('div');
    var a = document.createElement('a');
    a.href='#';
    a.innerHTML = '"infinite" '+type;

    a.setAttribute('onclick',"stressTest('"+type+"')");
    d.appendChild(a);
    el.appendChild(d);
  }

  el.appendChild(document.createTextNode('Load objects'));
  var objects = PxL.knownObjects();
  for (var i in objects) {
    var div = document.createElement('div'),
        a   = document.createElement('a');
    a.href='#';
    a.innerHTML = objects[i];
    fn[i] = function(obj) {
      return function() {
        PxL.load({
              Success:  function(item) { banner('Successfully loaded '+obj); },
              Progress: function(item) { banner('Loaded item: '+obj); },
              Failure:  function(item) { banner('Failed to load '+obj); }
        },obj);
      }
    }(objects[i]);

    a.setAttribute('onclick',"fn["+[i]+"]();");
    div.appendChild(a);
    el.appendChild(div);
  }
}

Tony = function(PxS,PxL) {
  PxL.load(function() {
    var ctl, el, dDebug;
    el = document.getElementById('phedex-separator');
    dDebug = document.createElement('div');
    dDebug.id = 'phedex-debug';
    dDebug.className = 'float-right';
    YuD.insertAfter(dDebug,el);

    ctl = new PHEDEX.Component.Control(PxS,{
        payload: {
          text:'Debug controls',
          title:'this opens a panel of debugging controls, for experts only',
          target:'phedex-debug',
          className: 'float-right phedex-core-control-widget phedex-core-control-widget-inactive',
        }
      }
    );
    document.getElementById('phedex-controls').appendChild(ctl.el);
    debugLinks();

    ctl = new PHEDEX.Component.Control(PxS,{
        payload: {
          text:'Show Logger',
          title:'This shows the logger component, for debugging. For experts only',
          target:'phedex-logger',
          animate:false,
          className: 'float-right phedex-core-control-widget phedex-core-control-widget-inactive',
        }
      }
    );
    document.getElementById('phedex-controls').appendChild(ctl.el);
    ctl = new PHEDEX.Component.Control(PxS,{
        payload: {
          text:'Show Log2Server controls',
          title:'You can log messages to the proxy-server, if you are using one. This control gives you access to a configuration panel that allows you to set preferences via a cookie, so you can reload and keep the same logging configuration',
          target:'phedex-logger-log2server',
          animate:false,
          className: 'float-right phedex-core-control-widget phedex-core-control-widget-inactive',
        }
      }
    );
    document.getElementById('phedex-logger-controls').appendChild(ctl.el);

    ctl = new PHEDEX.Component.Control(PxS,{
        payload: {
          text:'Show Profiler',
          title:'This shows the profiler component, for debugging. For experts only',
          target:'phedex-profiler',
          animate:false,
          className: 'float-right phedex-core-control-widget phedex-core-control-widget-inactive',
        }
      }
    );
    document.getElementById('phedex-controls').appendChild(ctl.el);
    if ( !PHEDEX.Profiler ) {
      ctl.Disable();
      ctl.el.title = 'Profiler was not loaded, this control is disabled';
    }

  },'component-control');
  PxS.notify('Load','phedex-logger'); //, { log2server:{info:true,warn:true,error:true} } );

  var fn = function() {
    log(Ylang.JSON.stringify(PxS.getStats()),'info','profiler');
    setTimeout(fn, 60000);
  }
  fn();

};
