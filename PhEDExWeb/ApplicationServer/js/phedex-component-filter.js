PHEDEX.namespace('Component');
PHEDEX.Component.Filter = function(sandbox,args) {
  Yla(this, new PHEDEX.Base.Object());
  var _me = 'component-filter',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

  Yla(this, new PHEDEX[obj.type].Filter(sandbox,obj));

  this.id = _me+'_'+PxU.Sequence();
  this.selfHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0],
          subAction = arr[1];
      switch (action) {
        case 'Filter': {
          switch (subAction) {
            case 'Reset': {
              o._resetFilter();
              o.resetFilter();
              if ( !o.dom.cBox.checked ) { o.ctl.filterControl.Hide(); }
              YuD.removeClass(o.ctl.filterControl.el,'phedex-core-control-widget-applied');
              _sbx.notify(obj.id,'doSort'); // TODO This is ugly, having to know that sorting is needed. However, it's the only way to avoid doing it twice at the moment...
              break;
            }
            case 'Validate': {
              if ( o.Parse() ) {
                _sbx.notify(o.id,'Filter','Apply',o.args);
              }
              break;
            }
            case 'Apply': {
              o.applyFilter(arr[2]);
              _sbx.notify(obj.id,'doSort'); // TODO see comment above...
              break;
            }
            case 'cBox': {
              if ( !o.dom.cBox.checked ) { o.ctl.filterControl.Hide(); }
              break;
            }
          }
          break;
        }
        case 'activate': { // set focus appropriately when the filter is revealed
          if ( !o.firstAlignmentDone ) {
            o.overlay.align(this.context_el,this.align_el);
            o.firstAlignmentDone = true;
          }
          if ( o.focusOn ) { o.focusOn.focus(); }
          break;
        }
        case 'setApplied': {
          o.ctl.filterControl.setApplied(arr[1]);
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
        case 'doFilter': {
          o.applyFilter();
          break;
        }
      }
    }
  }(this);
  _sbx.listen(obj.id,this.partnerHandler);

/**
 * construct a PHEDEX.Component.Filter object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      meta: { inner:{}, cBox:{}, el:{}, focusMap:{} },

      BuildOverlay: function() {
        var o = this.overlay,
            d = this.dom,
            b, hId, el;
        hId = this.overlay.header.id;
        ttIds.push(hId);
        ttHelp[hId] = 'click this grey header to drag the filter elsewhere on the screen';

        d.filter  = el = document.createElement('div');
        d.buttons = b  = document.createElement('div');
        o.body.appendChild(this.dom.filter);
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
        var buttonApplyFilter = new Yw.Button({ label:'Apply Filter',  title:'Validate your input and apply the filter', container:b }),
            buttonResetFilter = new Yw.Button({ label:'Reset Filter', title:'Reset the filter to the initial, null state', container:b }),
            buttonNotifier = function(obj) {
              return function(arg) { _sbx.notify(obj.id,'Filter',arg); }
            }(this);
        buttonApplyFilter.on ('click', function() { buttonNotifier('Validate');  } ); // Validate before Applying!
        buttonResetFilter.on ('click', function() { buttonNotifier('Reset');  } );
        cBox.addEventListener('click', function() { buttonNotifier('cBox') }, false );
//      make sure the filter moves with the widget when it is dragged!
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
        var apc = payload.control, o, p;
        this.dom.filter = document.createElement('div');
        this.context_el = obj.dom[apc.payload.context || 'content'];
        this.align_el   =  apc.payload.align || 'tl';
        o = this.overlay = new Yw.Overlay(this.dom.filter,{context:[this.context_el,'tl',this.align_el]});
        o.setHeader('Filter data selection ('+obj.me+')');
        o.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
        o.setFooter('&nbsp;'); this.overlay.setFooter(''); // likewise the footer, but I don't want anything in it, not from here, anyway...
        o.header.id = 'hd_'+PxU.Sequence();
        YuD.addClass(o.element,'phedex-core-overlay')
        o.body.innerHTML = null;

        this.dragdrop = new Yu.DD(this.overlay.element); // add a drag-drop facility, just for fun...
        this.dragdrop.setHandleElId( this.overlay.header );
        if ( apc ) { // create a component-control to use to show/hide the filter
          p = apc.payload;
          p.obj     = this;
          p.target  = this.overlay.element;
          p.text    = p.text || 'Filter';
          p.hidden  = 'true';
          p.handler = 'setFocus';
          apc.name = 'filterControl';
          this.ctl[apc.name] = new PHEDEX.Component.Control( _sbx, apc );
          if ( apc.parent ) { obj.dom[apc.parent].appendChild(this.ctl[apc.name].el); }
        }
        this.BuildOverlay();
        if ( obj.meta ) {
          this.meta._filter = obj.createFilterMeta();
          this.BuildFilter();
        }
      },

      typeMap: { // map a 'logical element' (such as 'floating-point range') to one or more DOM selection elements
        regex:       {type:'input', size:20},
        'int':       {type:'input', size:7 },
        'float':     {type:'input', size:7 },
        yesno:       {type:'input', fields:['yes','no'], attributes:{checked:true, type:'checkbox'}, nonNegatable:true },
        percent:     {type:'input', size:5 },
        minmax:      {type:'input', size:7, fields:['min','max'], className:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is implied...
        minmaxFloat: {type:'input', size:7, fields:['min','max'], className:'minmaxFloat' },
        minmaxPct:   {type:'input', size:7, fields:['min','max'], className:'minmaxPct' }
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

      isDefined: function() {
        for (var j in this.meta._filter.fields) { return 1; }
        return 0;
      },

      ResetState: function() {
        this.count=0;
        this.args={};
      },

      BuildFilter: function() {
        this.dom.filter.innerHTML = null;
        if ( !this.ctl )  { this.ctl = {}; }
        var _filter = this.meta._filter, label, fieldset, legend, helpClass, helpCtl, hideClass, hideCtl, key, tt, id, text, k1;
        for (label in _filter.structure['f']) {
          fieldset = document.createElement('fieldset');
          legend = document.createElement('legend');

          helpClass = 'phedex-filter-help-class-'+PHEDEX.Util.Sequence();
          helpCtl = document.createElement('span');

          hideClass = 'phedex-filter-hide-class-'+PHEDEX.Util.Sequence();
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
          ttHelp[hideCtl.id] = 'Click here to collapse or expand this group of filter-elements';
          YuE.addListener(hideCtl, 'click', function(aClass,anElement) {
              return function() { PxU.toggleVisible(aClass,anElement) };
          }(hideClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(hideCtl);
          for (key in _filter.structure['f'][label]) {
            var c = _filter.fields[key],
                focusOn, outer, inner, e, value, i, fields, cBox, fieldLabel, help,  el, size, def;

            outer = document.createElement('div');
            inner = document.createElement('div');
            outer.className = 'phedex-filter-outer phedex-visible '+hideClass;
            inner.className = 'phedex-filter-inner';
            inner.id = 'phedex_filter_inner_'+PHEDEX.Util.Sequence();
            this.meta.el[inner.id] = inner;
            this.meta.inner[inner.id] = [];
            e = this.typeMap[c.type];
            if ( !e ) {
              log('unknown filter-type"'+c.type+'", aborting','error',_me);
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
              el.setAttribute('name',key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
              value = c[fields[i] || 'value'];
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
            this.meta.cBox[key] = cBox;
            ttIds.push(cBox.id);
            ttHelp[cBox.id] = '(un)check this box to invert your selection for this element';
            inner.appendChild(cBox);
            if ( e.nonNegatable ) {
              cBox.disabled = true;
              ttHelp[cBox.id] = 'this checkbox is redundant, use the fields to the left to make your selection';
            }
            fieldLabel = document.createElement('div');
            outer.appendChild(inner);
            fieldLabel.className = 'phedex-filter-label';
            fieldLabel.appendChild(document.createTextNode(c.text));
            outer.appendChild(fieldLabel);

            if ( c.tip ) {
              help = document.createElement('div');
              help.className = 'phedex-filter-help phedex-invisible '+helpClass;
              help.appendChild(document.createTextNode(c.tip));
              outer.appendChild(help);
            }
            fieldset.appendChild(outer);
          }
          var dd;
          dd = document.createElement('div');
          dd.innerHTML='';
          dd.className='phedex-filter-banner-nohelp';
          fieldset.appendChild(dd);
          dd = document.createElement('div');
          dd.innerHTML='';
          dd.className='phedex-filter-banner-help phedex-filter-help phedex-invisible '+helpClass;
          fieldset.appendChild(dd);
          this.dom.filter.appendChild(fieldset);
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
        k1 = new Yu.KeyListener(this.dom.filter,
                                          { keys:13 }, // '13' is the enter key, seems there's no mnemonic for this?
                                          { fn:function(obj){ return function() { _sbx.notify(obj.id,'Filter','Validate'); } }(this),
                                            scope:this, correctScope:true } );
        k1.enable();
      },

      Parse: function() {
        this.ResetState();
        var isValid = true,
            keyMatch = /^phedex-filter-key-/,
            innerList = this.meta.inner,
            nItems, nSet, values, value, el, key, elClasses, type, s, a,
            fields = this.meta._filter.fields;
        this.args = {};
        nItems = 0;
        for (var i in innerList) {
          nSet = 0;
          values = {};
          a = {id:[], values:{} };
          for (var j in innerList[i]) {
            this.setValid(innerList[i]);
            el = innerList[i][j];
            a.name = el.name;
// 1. pick out the values from the element(s)
//          find the phedex-filter-key-* classname of this element
            elClasses = el.className.split(' ');
            for (var k in elClasses) {
              if ( elClasses[k].match(keyMatch) ) {
                key = elClasses[k].split('-')[3];
                if ( key == '' ) { key = 'value'; }
                if ( el.type == 'checkbox' ) {
                  value = el.checked;
                  if ( !value ) { nSet++; }
                } else {
                  value = el.value;
                  if ( value ) { nSet++; }
                }
                values[key] = value;
                a.id[key] = el.id;
              }
            }
          }

// 2. parse the values and validate them
          if ( nSet ) {
            var x = fields[el.name];
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
              a.negate = this.meta.cBox[a.name].checked;
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

      _resetFilter: function() {
        var a, el, name, key, i, m=this.meta;
        for (name in this.args) {
          a = this.args[name];
          for (key in a.values) {
            if ( key == 'y' ) { key = 'yes'; }
            if ( key == 'n' ) { key = 'no'; }
            el = m.el[a.id[key]];
            if ( el.type == 'checkbox' ) { el.checked = true; }
            else { el.value = null; }
            delete this.args[name];
          }
          m.cBox[name].checked = false;
        }
        _sbx.notify('Filter',obj.me,this.args,this.asString());
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

      isApplied: function() { return this.count; },
      destroy: function() {
        if ( this.overlay && this.overlay.element ) { this.overlay.destroy(); }
      },

      asString: function(args) {
        var str = '',
            _filter = this.meta._filter,
            key, mKey, rKey, fValue, negate, seg, c, seg1, deg2,
            str = '';
        if ( !args ) { args = this.args; }
        for (key in args) {
          mKey = key;
          if ( typeof(args[key].values) == 'undefined' ) { continue; }
          mKey = obj.friendlyName(key);
          fValue = args[key].values;
          if ( args[key].format ) { fValue = args[key].format(fValue); }
          negate = args[key].negate;
          seg = '';
          if ( negate ) { seg = '!'; }
            if ( fValue.value != null ) {
              seg += mKey+'='+fValue.value;
            } else {
              c = 0;
              seg1 = seg2 = null;
              if ( fValue.min != null ) { c++; seg1 = mKey+'>'+fValue.min; }
              if ( fValue.max != null ) { c++; seg2 = mKey+'<'+fValue.max; }
              if ( c == 0 ) { /* This shouldn't happen if validation worked! */ continue; }
              if ( c == 1 ) { seg += ( seg1 || seg2 ); } // one or the other is set
              if ( c == 2 ) {  // both are set
                if ( negate ) { seg += '('+ seg1 +' '+ seg2 + ')'; }
                else          { seg +=      seg1 +' '+ seg2; }
              }
            }
            if ( str ) { str += ' '; }
            str += seg;
          }
        return str;
      },
      updateGUIElements: function(n) {
        if ( n ) { YuD.addClass(   this.ctl.filterControl.el,'phedex-core-control-widget-applied'); }
        else     { YuD.removeClass(this.ctl.filterControl.el,'phedex-core-control-widget-applied'); }
        if ( !this.dom.cBox.checked ) { this.ctl.filterControl.Hide(); }
        _sbx.notify('Filter',this.me,this.args,this.asString());
        _sbx.notify(this.id,'updateHistory');
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  if ( this.meta._filter ) { this.Parse(); } // in case a default filter was set
  return this;
}

log('loaded...','info','component-filter');
