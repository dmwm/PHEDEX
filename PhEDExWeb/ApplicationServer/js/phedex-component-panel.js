PHEDEX.namespace('Component');
PHEDEX.Component.Panel = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me  = 'component-panel',
      _sbx = sandbox,
      payload = args.payload,
      obj     = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

//   Yla(this, new PHEDEX[obj.type].Panel(sandbox,obj));

  this.id = _me+'_'+PxU.Sequence();
  this.selfHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          subAction = arr[1];
      switch (action) {
        case 'Panel': {
          switch (subAction) {
            case 'Dismiss': {
              var c = o.ctl[o.panel_control];
              if ( c ) { c.Hide(); }
              else { YuD.addClass(this.dom.panel,'phedex-invisible'); }
              break;
            }
            case 'Reset': {
              break;
            }
            case 'Validate': {
              if ( o.Parse() ) {
                _sbx.notify(o.id,'Panel','Apply',o.args);
              }
              break;
            }
            case 'Apply': {
              break;
            }
          }
          break;
        }
        case 'activate': { // set focus appropriately when the panel is revealed
          if ( !o.firstAlignmentDone ) {
            o.overlay.align(o.dom.context_el,o.dom.align_el);
            o.firstAlignmentDone = true;
          }
          if ( o.focusOn ) { o.focusOn.focus(); }
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.selfHandler);

/**
 * construct a PHEDEX.Component.Panel object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    var _default_validate_function = function(arg) { return { result:true, parsed:{value:arg.value} } };
    return {
      me: _me,
      meta: { inner:{}, cBox:{}, el:{}, focusMap:{} },

      typeMap: { // map a 'logical element' (such as 'floating-point range') to one or more DOM selection elements
        regex:       {type:'input', size:20, negatable:true },
        'int':       {type:'input', size:7,  negatable:true },
        'float':     {type:'input', size:7,  negatable:true },
        yesno:       {type:'input', fields:['yes','no'], attributes:{checked:true, type:'checkbox'}, negatable:false },
        percent:     {type:'input', size:5,  negatable:true },
        minmax:      {type:'input', size:7,  negatable:true, fields:['min','max'], className:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is implied...
        minmaxFloat: {type:'input', size:7,  negatable:true, fields:['min','max'], className:'minmaxFloat' },
        minmaxPct:   {type:'input', size:7,  negatable:true, fields:['min','max'], className:'minmaxPct' },
        radio:       {type:'input', attributes:{type:'radio'}, nonNegatable:true },
        checkbox:    {type:'input', fields:[' '],   attributes:{type:'checkbox'}, negatable:false },
        textarea:    {type:'textarea', className:'textarea', negatable:false },
        text:        {type:'textNode', attributes:{width:'100px'}, negatable:false }
      },
      Validate: {
        regex: function(arg) { return {result:true, parsed:{value:arg.value}}; }, // ...no sensible way to validate a regex except to compile it, assume true...
        'int': function(arg) {
          var i = parseInt(arg.value);
          if ( i == arg.value ) { return {result:true, parsed:{value:i}}; }
          return { result:false };
        },
        'float': function(arg) {
          var i = parseFloat(arg.value);
          if ( isNaN(i) ) { return {result:false}; }
          return {result:true, parsed:{value:i}};
        },
        yesno: function(arg) {
          if ( arg.yes && arg.no ) { return {result:false}; }
          var v = { result:true, parsed:{y:false, n:false} };
          if ( arg.yes ) { v.parsed.y = true; }
          if ( arg.no  ) { v.parsed.n = true; }
          return v;
        },
        percent: function(arg) {
          var i = parseFloat(arg.value);
          if ( isNaN(i) ) { return {result:false}; }
          if ( i>100.0 || i<0.0 ) { return {result:false}; }
          return {result:true, parsed:{value:i}};
        },
        minmax: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min != '' ) { v.parsed.min = parseInt(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max != '' ) { v.parsed.max = parseInt(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          v.result = true;
          return v;
        },
        minmaxFloat: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min ) { v.parsed.min = parseFloat(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max ) { v.parsed.max = parseFloat(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          v.result = true;
          return v;
        },
        minmaxPct: function(arg) {
          var v = { result:false, parsed:{} };
          if ( arg.min ) { v.parsed.min = parseFloat(arg.min); if ( isNaN(v.parsed.min) ) { return v; } }
          if ( arg.max ) { v.parsed.max = parseFloat(arg.max); if ( isNaN(v.parsed.max) ) { return v; } }
          if ( v.parsed.min && v.parsed.max && v.parsed.min > v.parsed.max ) { return v; }
          if ( v.parsed.min && ( v.parsed.min < 0 || v.parsed.min > 100 ) ) { return v; }
          if ( v.parsed.max && ( v.parsed.max < 0 || v.parsed.max > 100 ) ) { return v; }
          v.result = true;
          return v;
        },
        checkbox: _default_validate_function,
        radio:    _default_validate_function,
        textarea: _default_validate_function,
        text:     _default_validate_function
      },

      Apply: {
        regex:   function(arg,val) {
          var re = new RegExp(arg.value);
          if ( !val ) { return false; }
          if ( val.match(re) ) { return true; }
          return false;
        },
        'int':   function(arg,val) { return val == arg.value; },
        'float': function(arg,val) { return val == arg.value; },
        yesno:   function(arg,val) { return arg[val]; },
        percent: function(arg,val) { return val == arg.value; },
        minmax:  function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        },
        minmaxFloat: function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        },
        minmaxPct: function(arg,val) {
          if ( arg.min && val < arg.min ) { return false; }
          if ( arg.max && val > arg.max ) { return false; }
          return true;
        }
      },

      ResetState: function() {
        this.count=0;
        this.args={};
      },
      setValid:   function(el) {
        YuD.removeClass(el,'phedex-filter-elem-invalid');
      },
      setInvalid: function(el,setFocus) {
        YuD.addClass(el,'phedex-filter-elem-invalid');
        if ( setFocus ) {
          var focusOn = el[0];
          focusOn.focus();
        }
      },
      Parse: function() {
        this.ResetState();
        var isValid = true,
            keyMatch = /^phedex-panel-key-/,
            innerList = this.meta.inner,
            nItems, nSet, values, value, el, key, elClasses, type, s, a, nBox, elName,
            fields = this.meta._panel.fields;
        this.args = {};
        nItems = 0;
        for (var i in innerList) {
          nSet = 0;
          values = {};
          a = {id:[], values:{} };
          for (var j in innerList[i]) {
            this.setValid(innerList[i]);
            el = innerList[i][j];
            elName  = el.getAttribute('name');
            a.name = elName;
// 1. pick out the values from the element(s)
//          find the phedex-panel-key-* classname of this element
            elClasses = el.className.split(' ');
            for (var k in elClasses) {
              if ( elClasses[k].match(keyMatch) ) {
                key = elClasses[k].split('-')[3];
                if ( key == '' ) { key = 'value'; }
                if ( el.type == 'checkbox' ) {
                  value = el.checked;
                  values[key] = value;
                  if ( value ) { nSet++; }
                }
                else if ( el.type == 'radio' ) {
                  if ( el.checked ) {
                    value = el.value;
                    if ( fields[elName].byName ) { value = key; }
                    values = {value:value};
                    nSet++;
                  }
                }
                else if ( el.nodeName == 'TEXTNODE' ) {
                  values = {value:el.textContent};
                  nSet++;
                }
                else {
                  value = el.value;
                  values[key] = value;
                  if ( value ) { nSet++; }
                }
                a.id[key] = el.id;
              }
            }
          }

// 2. parse the values and validate them
          if ( nSet ) {
            var x = fields[a.name];
            type = x.type;
            s = this.Validate[type](values);
            if ( s.result ) {
              nItems++;
              a.values = s.parsed;
              if ( x.format ) { this.args[i].format = x.format; }
              if ( x.preprocess ) {
                if ( typeof(x.preprocess) == 'string' ) {
                  a.preprocess = this.Preprocess[x.preprocess];
                } else {
                  a.preprocess = x.preprocess;
                }
              }
              if ( nBox=this.meta.cBox[a.name] ) { a.negate = nBox.checked; }
              else { a.negate = false; }
              this.args[a.name] = a;
            } else {
              log('Invalid entry for "'+x.text+'", aborting accept','error',_me);
              this.setInvalid(innerList[i],isValid);
              isValid = false;
            }
          }
        }
        return isValid;
      },

      Preprocess: {
        toTimeAgo: function(x)
        {
          var d = new Date();
          var now = d.getTime()/1000;
          return now-x;
        },
        toPercent: function(x) { return 100*x; }
      },

      BuildOverlay: function() {
        var o = this.overlay,
            d = this.dom,
            b, hId, el, cBox, i,
            buttonMap = {
              Accept: { title:'Validate your input and apply the panel', action:'Validate'},
              Reset:  { title:'Reset the panel to the initial, null state' },
              Dismiss:{ title:'Dismiss the panel, with no action taken' }
            }, name, buttons, b, bm, pbm, buttonNotifier, title, action;
        hId = this.overlay.header.id;
        ttIds.push(hId);
        ttHelp[hId] = 'click this grey header to drag the panel elsewhere on the screen';

        d.panel = el = document.createElement('div');
        o.body.appendChild(this.dom.panel);
        d.buttons = buttons  = document.createElement('div');
        buttons.className = 'align-right';
        o.footer.appendChild(buttons);

        YuD.removeClass(el,'phedex-invisible'); // div must be visible before overlay is show()n, or it renders in the wrong place!
        o.render(document.body);
        o.cfg.setProperty('zindex',100);

        if ( payload.KeepOpenBox ) {
          cBox = document.createElement('input');
          cBox.type = 'checkbox';
          cBox.checked = false;
          d.cBox = cBox;
          buttons.appendChild(cBox);
          buttons.appendChild(document.createTextNode('Keep this window open'));
          cBox.addEventListener('click', function() { _sbx.notify(id,'Panel','cBox') }, false );
        }

        for (i in payload.buttons) {
          name = payload.buttons[i];
          if ( payload.buttonMap ) { pbm = payload.buttonMap[name] || {} } else { pbm = {}; }
          if ( buttonMap[name] )   { bm = buttonMap[name] } else { bm = {}; }
          title  = pbm.title  || bm.title  || '';
          action = pbm.action || bm.action || name;
          this.ctl[name] = b = new Yw.Button({ label:name, title:title, container:buttons });
          b.on ('click', function(id,_action) {
            return function() { _sbx.notify(id,'Panel',_action); }
          }(this.id,action) );
        }

//      make sure the panel moves with the widget when it is dragged!
        if (obj.options && obj.options.window) { // TODO this shouldn't be looking so close into the OBJ...?
          obj.module.dragEvent.subscribe(function(type,args) { o.align('tl','tl'); }, this, true);
        }
      },
/**
 * Initialise the component
 * @method _init
 * @param args {object} pointer to object containing configuration parameters
 * @private
 */
      _init: function(args) {
        var apc=payload.control, o, p, container, spec;
        if ( apc ) { p = apc.payload; }
        if ( p ) { // create a component-control to use to show/hide the panel
          p.obj     = this;
          p.text    = p.text || 'Panel';
          p.hidden  = 'true';
          p.handler = 'setFocus';
          this.panel_control = apc.name  = 'panel';
          this.dom.align_el =  p.align;
        }
        this.dom.panel = document.createElement('div');
        if ( p.context ) { this.dom.context_el = obj.dom[p.context]; }
        if ( !this.dom.context_el ) { this.dom.context_el = obj.dom['content']; }
        if ( !this.dom.align_el   ) { this.dom.align_el    =  'tl'; }
        o = this.overlay = new Yw.Overlay(this.dom.panel,{context:[this.dom.context_el,'tl',this.dom.align_el]});
        if ( p ) {
          p.target = o.element;
          o.setHeader(p.text);
        } else {
          o.setHeader(args.text || args.name || '&nbsp;');
        }
        o.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
        o.setFooter('&nbsp;');
        o.setFooter(''); // likewise the footer, but I don't want anything in it, not from here, anyway...
        o.header.id = 'hd_'+PxU.Sequence();
        YuD.addClass(o.element,'phedex-core-overlay')
        o.body.innerHTML = null;
        if ( apc ) {
          this.ctl[apc.name] = new PHEDEX.Component.Control( _sbx, apc );
          if ( apc.parent ) { obj.dom[apc.parent].appendChild(this.ctl[apc.name].el); }
        } else {
          YuD.addClass(o.element,'phedex-invisible')
        }

        this.dragdrop = new Yu.DD(o.element); // add a drag-drop facility, just for fun...
        this.dragdrop.setHandleElId(o.header);
        this.BuildOverlay();
        this.meta._panel = this.createPanelMeta();
        this.BuildPanel();
        if ( this.acSpecs.length ) {
          this.dom.container = container = PxU.makeChild(document.body,'div');
          container.className = 'phedex-panel-ac-container';
          for (i in this.acSpecs) {
            spec = this.acSpecs[i];
            spec.payload.container = container;
            spec.payload.obj       = this;
            this.ac[spec.name] = new PHEDEX.Component.AutoComplete(_sbx,spec);
          }
        }
        this.acSpecs = [];
//         if ( args.payload.resize ) {
//           var elResize = new Yu.Resize(o.element,{ handles:['b','br','r'] }); // , draggable:true }); // draggable is cute if I can make it work properly!
//           elResize.subscribe('endResize',function(ev) {
//           });
//         }
      },

      createPanelMeta: function() {
        if ( this.meta._panel ) { return this.meta._panel; }
        var meta = { structure: { f:{}, r:{} }, rFriendly:{}, fields:{}, fieldsets:{} },  // mapping of field-to-group, and reverse-mapping of same
            f = args.payload.panel,
            re, str, i, j, k, l, key, fn;

        for (i in f) {
          l = {};
          for (j in f[i].fields) {
            k = j.replace(/ /g,'');
            l[k] = f[i].fields[j];
            l[k].original = j;
          }
          f[i].fields = l;

          if ( f[i].map ) {
            fn = function( m ) {
              return function(k) {
                var re, str = k;
                if ( m.from ) {
                  re = new RegExp(m.from,'g');
                  str = str.replace(re,'');
                }
                str = m.to + '.' + str;
                return str;
              };
            }(f[i].map);
          } else {
            fn = function( m ) { return m; }
          }

          meta.structure['f'][i] = [];
          for (j in f[i].fields) {
            meta.structure['f'][i][j]=0;
            meta.structure['r'][j] = i;
            var fName = fn(j);
            meta.fields[j] = f[i].fields[j];
            meta.fields[j].friendlyName = fName;
            meta.rFriendly[fName.toLowerCase()] = j;
          }
        }
        return meta;
      },

      BuildPanel: function() {
        this.dom.panel.innerHTML = null;
        this.acSpecs=[];
        if ( !this.ctl )  { this.ctl = {}; }
        if ( !this.ac )   { this.ac  = {}; }
        var _panel = this.meta._panel, label, fieldset, legend, helpClass, helpCtl, hideClass, hideCtl, key, tt, id, text, k1, acSpec, i;
        for (label in _panel.structure['f']) {
          fieldset = document.createElement('fieldset');
          fieldset.id = 'fieldset_'+PxU.Sequence();
          legend = document.createElement('legend');

          helpClass = 'phedex-panel-help-class-'+PHEDEX.Util.Sequence();
          helpCtl = document.createElement('span');

          hideClass = 'phedex-panel-hide-class-'+PHEDEX.Util.Sequence();
          hideCtl = document.createElement('span');

          legend.appendChild(document.createTextNode(label));
          fieldset.appendChild(legend);

          helpCtl.appendChild(document.createTextNode('[?]'));
          helpCtl.id = 'help_' +PxU.Sequence();
          ttIds.push(helpCtl.id);
          ttHelp[helpCtl.id] = 'Click here for any additional help that may have been provided';
          YuE.addListener(helpCtl, 'click', function(aClass,anElement) {
            return function() { PxU.toggleVisible(aClass,anElement) };
          }(helpClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(helpCtl);

          hideCtl.appendChild(document.createTextNode('[-]'));
          hideCtl.id = 'help_' +PxU.Sequence();
          ttIds.push(hideCtl.id);
          ttHelp[hideCtl.id] = 'Click here to collapse or expand this group of panel-elements';
          YuE.addListener(hideCtl, 'click', function(aClass,anElement,aControl) {
              return function() {
                if ( hideCtl.innerHTML == '[-]' ) { aControl.innerHTML = '[+]'; }
                else                              { aControl.innerHTML = '[-]'; }
                PxU.toggleVisible(aClass,anElement)
              };
          }(hideClass,fieldset,hideCtl) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(hideCtl);
          for (key in _panel.structure['f'][label]) {
            _panel.fieldsets[key] = { fieldset:fieldset, hideClass:hideClass, helpClass:helpClass };
            var c = _panel.fields[key];
            c.key = key;
            if ( !c.dynamic ) {
              this.AddFieldsetElement(c);
            }
          }
          var dd;
          dd = document.createElement('div');
          dd.innerHTML='';
          dd.className='phedex-panel-banner-nohelp';
          fieldset.appendChild(dd);
          dd = document.createElement('div');
          dd.innerHTML='';
          dd.className='phedex-panel-banner-help phedex-panel-help phedex-invisible '+helpClass;
          fieldset.appendChild(dd);
          this.dom.panel.appendChild(fieldset);
        }
        tt = new Yw.Tooltip("ttB", { context:ttIds }), ttCount={};
        tt.contextMouseOverEvent.subscribe( // prevent tooltip from showing more than a few times, to avoid upsetting experts
          function(type, args) {
            id = args[0].id;
            text = ttHelp[args[0].id];
            if ( text ) {
              if ( !ttCount[id] ) { ttCount[id]=0; }
              if ( ttCount[id]++ > 2 ) { return false; }
              return true;
            }
          }
        );
        tt.contextTriggerEvent.subscribe(
          function(type, args) {
            text = ttHelp[args[0].id];
            this.element.style.zIndex = 1000;
            this.cfg.setProperty('text', text);
          }
        );
        if ( payload.onEnter ) {
          k1 = new Yu.KeyListener(this.dom.panel,
                               { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
                               { fn:function(obj){ return function() { _sbx.notify(obj.id,'Panel',payload.onEnter); } }(this),
                               scope:this, correctScope:true } );
          k1.enable();
        }
      },

      AddFieldsetElement: function(c,val,title) {
        var outer, inner, e, value, i, j,
            fields, dcwrap, cBox, fieldLabel, help,
            el, size, def, acSpec,
            _panel=this.meta._panel,
            _fsk=_panel.fieldsets[c.key],
            fieldset, helpClass;
        fieldset  = _fsk.fieldset;
        hideClass = _fsk.hideClass;
        helpClass = _fsk.helpClass;
        outer = document.createElement('div');
        inner = document.createElement('div');
        outer.className = 'phedex-panel-outer phedex-visible '+hideClass;
        if ( !c.dynamic ) { inner.className = 'phedex-panel-inner'; }
        if ( c.className ) { YuD.addClass(inner,c.className); }
        inner.title = title || c.title || '';
        inner.id = 'phedex_panel_inner_'+PxU.Sequence();
        this.meta.el[inner.id] = inner;
        this.meta.inner[inner.id] = [];
        e = this.typeMap[c.type];
        if ( !e ) {
          log('unknown panel-type"'+c.type+'", aborting','error',_me);
          return;
        }

        fields = c.fields || e.fields || [''];
        _panel.fields[c.key].inner = inner;
        for (i in fields) {
          if ( i > 0 ) { inner.appendChild(document.createTextNode('  ')); }
          el = document.createElement(e.type);
          el.id = 'phedex_panel_elem_'+PHEDEX.Util.Sequence(); // needed for focusMap
          this.meta.el[el.id] = el;
          this.meta.inner[inner.id].push(el);
          el.className = 'phedex-panel-elem';
          YuD.addClass(el,'phedex-panel-key-'+fields[i]);
          if ( e.className ) { YuD.addClass(el,'phedex-panel-elem-'+e.className); }
          size = c.size || e.size;

          if ( c.focus ) { this.focusOn = this.defaultFocus = el; }
//        set default values. Depends on type of input field...
          if ( c.type == 'radio' ) {
            if ( fields[i] == c.Default ) { el.checked = true; }
            el.value = i;
          } else {
            value = val || c[fields[i] || 'value'];
            if ( value != null ) {
              if ( c.type == 'text' ) { el.innerHTML = value; }
              else {
                el.setAttribute('value',value);
                if ( size ) { el.setAttribute('size',size); }
              }
            }
          }

          el.setAttribute('type',e.type);
          el.setAttribute('name',c.key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
          if ( e.attributes ) {
            for (j in e.attributes) {
                el[j] = e.attributes[j];
            }
          }
          if ( c.attributes ) {
            for (j in c.attributes) {
                el[j] = c.attributes[j];
            }
          }
          inner.appendChild(el);
          if ( !this.meta.focusMap[inner.id] ) { this.meta.focusMap[inner.id] = el.id; }
          if ( !this.focusOn ) { this.focusOn = el; }
          if ( fields[i] != '' ) {
            inner.appendChild(document.createTextNode(fields[i]+' '));
          }

          if ( c.autoComplete ) {
            acSpec = c.autoComplete;
            acSpec.payload.el = el;
            this.acSpecs.push(acSpec);
          }
        }

        dcwrap = document.createElement('div');
        dcwrap.className = 'phedex-panel-cbox-wrap';
        if (  e.negateLeft ) { YuD.addClass(dcwrap,'float-left'); }
        if ( e.Negatable ) {
          cBox = document.createElement('input');
          cBox.type = 'checkbox';
          cBox.className = 'phedex-panel-checkbox';
          cBox.id = 'cbox_' + PxU.Sequence();
          if ( c.negate ) { cBox.checked = true; }
          this.meta.cBox[c.key] = cBox;
          ttIds.push(cBox.id);
          ttHelp[cBox.id] = '(un)check this box to invert your selection for this element';
          dcwrap.appendChild(cBox);
        }
        inner.appendChild(dcwrap);
        outer.appendChild(inner);
        fieldLabel = document.createElement('div');
        fieldLabel.className = 'phedex-panel-label';
        if ( c.text ) { fieldLabel.appendChild(document.createTextNode(c.text)); }

        outer.appendChild(fieldLabel);
        if ( c.tip ) {
          help = document.createElement('div');
          help.className = 'phedex-panel-help phedex-invisible '+helpClass;
          help.appendChild(document.createTextNode(c.tip));
          outer.appendChild(help);
        }
        fieldset.appendChild(outer);
        return outer;
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-panel');
