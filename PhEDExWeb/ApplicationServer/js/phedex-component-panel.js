PHEDEX.namespace('Component');
PHEDEX.Component.Panel = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-panel',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
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
            case 'Reset': {
              break;
            }
            case 'Validate': {
              break;
            }
            case 'Apply': {
              break;
            }
          }
          break;
        }
        case 'expand': { // set focus appropriately when the panel is revealed
          if ( !o.firstAlignmentDone ) {
            o.overlay.align(this.context_el,this.align_el);
            o.firstAlignmentDone = true;
          }
          if ( o.focusOn ) { o.focusOn.focus(); }
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.selfHandler);
  this.partnerHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0];
      switch (action) {
//         case 'doPanel': {
//           break;
//         }
      }
    }
  }(this);
  _sbx.listen(obj.id,this.partnerHandler);

/**
 * construct a PHEDEX.Component.Panel object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      meta: { inner:{}, cBox:{}, el:{}, focusMap:{} },

      typeMap: { // map a 'logical element' (such as 'floating-point range') to one or more DOM selection elements
        regex:       {type:'input', size:20},
        'int':       {type:'input', size:7 },
        'float':     {type:'input', size:7 },
        yesno:       {type:'input', fields:['yes','no'], attributes:{checked:true, type:'checkbox'}, nonNegatable:true },
        percent:     {type:'input', size:5 },
        minmax:      {type:'input', size:7, fields:['min','max'], className:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is implied...
        minmaxFloat: {type:'input', size:7, fields:['min','max'], className:'minmaxFloat' },
        minmaxPct:   {type:'input', size:7, fields:['min','max'], className:'minmaxPct' },
        input:       {type:'input', size:70, nonNegatable:true },
        text:        {type:'text',  size:50 }
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
        }
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
            b, hId, el;
        hId = this.overlay.header.id;
        ttIds.push(hId);
        ttHelp[hId] = 'click this grey header to drag the panel elsewhere on the screen';

        d.panel  = el = document.createElement('div');
        d.buttons = b  = document.createElement('div');
        o.body.appendChild(this.dom.panel);
        o.footer.appendChild(this.dom.buttons);

        YuD.removeClass(el,'phedex-invisible'); // div must be visible before overlay is show()n, or it renders in the wrong place!
        o.render(document.body);
        o.cfg.setProperty('zindex',100);

        var cBox = document.createElement('input');
        cBox.type = 'checkbox';
        cBox.checked = false;
        d.cBox = cBox;
        b.appendChild(cBox);
        b.appendChild(document.createTextNode('Keep this window open'));
        var buttonApplyPanel = new Yw.Button({ label:'Apply',  title:'Validate your input and apply the panel', container:b }),
            buttonResetPanel = new Yw.Button({ label:'Reset', title:'Reset the panel to the initial, null state', container:b }),
            buttonNotifier = function(obj) {
              return function(arg) { _sbx.notify(obj.id,'Panel',arg); }
            }(this);
        buttonApplyPanel.on ('click', function() { buttonNotifier('Validate');  } ); // Validate before Applying!
        buttonResetPanel.on ('click', function() { buttonNotifier('Reset');  } );
        cBox.addEventListener('click', function() { buttonNotifier('cBox') }, false );
//      make sure the panel moves with the widget when it is dragged!
        if (obj.options.window) { // TODO this shouldn't be looking so close into the OBJ...?
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
        var apc=payload.control, o, p;
        if ( apc ) { p = apc.payload; }
        if ( p ) { // create a component-control to use to show/hide the panel
          p.obj     = this;
          p.text    = p.text || 'Panel';
          p.hidden  = 'true';
          p.handler = 'setFocus';
          apc.name = 'panelControl';
          this.context_el = obj.dom[p.context];
          this.align_el   =  p.align;
        }
        this.dom.panel = document.createElement('div');
        if ( !this.context_el ) { this.context_el = obj.dom['content']; }
        if ( !this.align_el   ) {this.align_el    =  'tl'; }
        o = this.overlay = new Yw.Overlay(this.dom.panel,{context:[this.context_el,'tl',this.align_el]});
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
        if ( !this.ctl )  { this.ctl = {}; }
        var _panel = this.meta._panel, label, fieldset, legend, helpClass, helpCtl, hideClass, hideCtl, key, tt, id, text, k1;
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

          hideCtl.appendChild(document.createTextNode('[x]'));
          hideCtl.id = 'help_' +PxU.Sequence();
          ttIds.push(hideCtl.id);
          ttHelp[hideCtl.id] = 'Click here to collapse or expand this group of panel-elements';
          YuE.addListener(hideCtl, 'click', function(aClass,anElement) {
              return function() { PxU.toggleVisible(aClass,anElement) };
          }(hideClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(hideCtl);
          for (key in _panel.structure['f'][label]) {
            _panel.fieldsets[key] = { fieldset:fieldset, hideClass:hideClass };
            var c = _panel.fields[key];
            c.key = key;
            if ( !c.dynamic ) {
              this.AddFieldsetElement(c);
            }
          }
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
        k1 = new Yu.KeyListener(this.dom.panel,
                               { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
                               { fn:function(obj){ return function() { _sbx.notify(obj.id,'Panel','Validate'); } }(this),
                               scope:this, correctScope:true } );
        k1.enable();
      },

      AddFieldsetElement: function(c,val) {
        var outer, inner, e, value, i, fields, cBox, fieldLabel, help,  el, size, def, _panel = this.meta._panel, _fsk=_panel.fieldsets[c.key], fieldset, helpClass;
        fieldset  = _fsk.fieldset;
        hideClass = _fsk.hideClass;
        outer = document.createElement('div');
        inner = document.createElement('div');
        outer.className = 'phedex-panel-outer phedex-visible '+hideClass;
        inner.className = 'phedex-panel-inner';
        inner.id = 'phedex_panel_inner_'+PxU.Sequence();
        this.meta.el[inner.id] = inner;
        this.meta.inner[inner.id] = [];
        e = this.typeMap[c.type];
        if ( !e ) {
          log('unknown panel-type"'+c.type+'", aborting','error',_me);
          return;
        }

        fields = e.fields || [''];
        for (i in fields) {
          if ( i > 0 ) { inner.appendChild(document.createTextNode('  ')); }
          if ( fields[i] != '' ) {
            inner.appendChild(document.createTextNode(fields[i]+' '));
          }
          el = document.createElement(e.type);
          el.id = 'phedex_filter_elem_'+PHEDEX.Util.Sequence(); // needed for focusMap
          this.meta.el[el.id] = el;
          this.meta.inner[inner.id].push(el);
          el.className = 'phedex-filter-elem';
          YuD.addClass(el,'phedex-filter-key-'+fields[i]);
          if ( e.className ) { YuD.addClass(el,'phedex-filter-elem-'+e.className); }
          size = e.size || c.size;
          if ( size ) { el.setAttribute('size',size); }
          el.setAttribute('type',e.type);
          el.setAttribute('name',c.key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
          value = val || c[fields[i] || 'value'];
          if ( value != null ) { el.setAttribute('value',value); }
          if ( e.attributes ) {
            for (j in e.attributes) {
              el.setAttribute(j,e.attributes[j]);
            }
          }
          inner.appendChild(el);
          if ( !this.meta.focusMap[inner.id] ) { this.meta.focusMap[inner.id] = el.id; }
          if ( !this.focusOn ) { this.focusOn = this.focusDefault = el; }
        }

        cBox = document.createElement('input');
        cBox.type = 'checkbox';
        cBox.className = 'phedex-filter-checkbox';
        cBox.id = 'cbox_' + PxU.Sequence();
        if ( c.negate ) { cBox.checked = true; }
        this.meta.cBox[c.key] = cBox;
        ttIds.push(cBox.id);
        ttHelp[cBox.id] = '(un)check this box to invert your selection for this element';
        inner.appendChild(cBox);
        if ( e.nonNegatable ) {
          cBox.disabled = true;
          ttHelp[cBox.id] = 'this checkbox is redundant, use the fields to the left to make your selection';
        }
        outer.appendChild(inner);
        fieldLabel = document.createElement('div');
        fieldLabel.className = 'float-left';
        if ( c.text ) { fieldLabel.appendChild(document.createTextNode(c.text)); }
        outer.appendChild(fieldLabel);

        if ( c.tip ) {
          help = document.createElement('div');
          help.className = 'phedex-panel-help phedex-invisible float-right '+helpClass;
          help.appendChild(document.createTextNode(c.tip));
          outer.appendChild(help);
        }
        fieldset.appendChild(outer);
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-panel');
