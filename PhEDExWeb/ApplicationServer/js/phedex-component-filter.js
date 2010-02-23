PHEDEX.namespace('Component');
PHEDEX.Component.Filter = function(sandbox,args) {
  YAHOO.lang.augmentObject(this, new PHEDEX.Base.Object());
  var _me = 'component-filter',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

  YAHOO.lang.augmentObject(this, new PHEDEX[obj.type].Filter(sandbox,obj));

  this.id = _me+'_'+PxU.Sequence();
  this.selfHandler = function(obj) {
    return function(ev,arr) {
      var action = arr[0],
          subAction = arr[1];
      switch (action) {
        case 'Filter': {
          switch (subAction) {
            case 'Cancel': {
              obj._resetFilter( true );
              if ( !obj.dom.cBox.checked ) { obj.ctl.filterControl.Hide(); }
              break;
            }
            case 'Reset': {
              obj._resetFilter( false );
              obj.resetFilter();
              if ( !obj.dom.cBox.checked ) { obj.ctl.filterControl.Hide(); }
              YAHOO.util.Dom.removeClass(obj.ctl.filterControl.el,'phedex-core-control-widget-applied');
              break;
            }
            case 'Validate': {
              obj.Parse();
              break;
            }
            case 'Apply': {
              obj.applyFilter(arr[2]);
              if ( !obj.dom.cBox.checked ) { obj.ctl.filterControl.Hide(); }
              if ( arr[3] ) { YAHOO.util.Dom.addClass(   obj.ctl.filterControl.el,'phedex-core-control-widget-applied'); }
              else          { YAHOO.util.Dom.removeClass(obj.ctl.filterControl.el,'phedex-core-control-widget-applied'); }
              _sbx.notify('Filter',obj.me,arr[2],obj.asString(arr[2]));
              break;
            }
            case 'cBox': {
              if ( !obj.dom.cBox.checked ) { obj.ctl.filterControl.Hide(); }
              break;
            }
          }
          break;
        }
        case 'expand': { // set focus appropriately when the filter is revealed
          if ( !obj.firstAlignmentDone ) {
            obj.overlay.align(this.context_el,this.align_el);
            obj.firstAlignmentDone = true;
          }
          if ( obj.focusOn ) { obj.focusOn.focus(); }
          break;
        }
        case 'setApplied': {
          obj.ctl.filterControl.setApplied(arr[1]);
          break;
        }
      }
    }
  }(this);
  _sbx.listen(this.id,this.selfHandler);

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
            body = o.body,
            b, hId, el;
        hId = this.overlay.header.id;
        ttIds.push(hId);
        ttHelp[hId] = 'click this grey header to drag the filter elsewhere on the screen';

        d.filter  = el = document.createElement('div');
        d.buttons = b  = document.createElement('div');
        b.className = 'phedex-filter-buttons';
        body.appendChild(this.dom.filter);
        body.appendChild(this.dom.buttons);

        YAHOO.util.Dom.removeClass(el,'phedex-invisible'); // div must be visible before overlay is show()n, or it renders in the wrong place!
        o.render(document.body);
//         YAHOO.util.Dom.addClass(el,'phedex-invisible');
        o.cfg.setProperty('zindex',100);

        var cBox = document.createElement('input');
        cBox.type = 'checkbox';
        cBox.checked = false;
        d.cBox = cBox;
        b.appendChild(cBox);
        b.appendChild(document.createTextNode('Keep this window open'));
        b.appendChild(document.createElement('br'));
        var buttonApplyFilter  = new YAHOO.widget.Button({ label:'Apply Changes',  title:'Validate your input and apply the filter', container:b }),
            buttonCancelFilter = new YAHOO.widget.Button({ label:'Cancel Changes', title:"Cancel any changes to the filter options since your last 'apply'. Any non-applied changes you have made will be ignored", container:b }),
            buttonResetFilter = new YAHOO.widget.Button({ label:'Reset Filter', title:'Reset the filter to the initial, null state', container:b }),
            buttonNotifier = function(obj) {
              return function(arg) { _sbx.notify(obj.id,'Filter',arg); }
            }(this);
        buttonApplyFilter.on ('click', function() { buttonNotifier('Validate');  } ); // Validate before Applying!
        buttonCancelFilter.on('click', function() { buttonNotifier('Cancel'); } );
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
//         this.map = [];
        this.context_el = obj.dom[apc.payload.context || 'content'];
        this.align_el   =  apc.payload.align || 'tl';
        o = this.overlay = new YAHOO.widget.Overlay(this.dom.filter,{context:[this.context_el,'tl',this.align_el]}); // obj.dom.content,'tl','tl']});
        o.setHeader('Filter data selection ('+obj.me+')');
        o.setBody('&nbsp;'); // the body-div seems not to be instantiated until you set a value for it!
        o.setFooter('&nbsp;'); this.overlay.setFooter(''); // likewise the footer, but I don't want anything in it, just for it to exist...
        o.header.id = 'hd_'+PxU.Sequence();
        YAHOO.util.Dom.addClass(o.element,'phedex-core-overlay')
        o.body.innerHTML = null;

        this.dragdrop = new YAHOO.util.DD(this.overlay.element); // add a drag-drop facility, just for fun...
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
          this.meta.filter = this.createMeta(obj.meta.filter);
          this.BuildFilter();
        }
      },

      createMeta: function(f) {
        var meta = { structure: { f:[], r:[] }, map:[], fields:[] };  // mapping of field-to-group, and reverse-mapping of same
        for (var i in f) {
          if ( f[i].map ) {
            meta.map[i] = {to:f[i].map.to};
            if ( f[i].map.from ) {
              meta.map[i].from = f[i].map.from;
              meta.map[i].func = function(f,t) {
                return function(str) {
                  var re = new RegExp(f,'g');
                  str = str.replace(re, t+'.');
                  return str;
                }
              }(f[i].map.from,f[i].map.to);
            };
          }
          meta.structure['f'][i] = [];
          for (var j in f[i].fields) {
            meta.structure['f'][i][j]=0;
            meta.structure['r'][j] = i;
            meta.fields[j] = f[i].fields[j];
          }
        }
        return meta;
      },

      typeMap: { // map a 'logical element' (such as 'floating-point range') to one or more DOM selection elements
        regex:       {type:'input', size:20},
        'int':       {type:'input', size:7 },
        'float':     {type:'input', size:7 },
        percent:     {type:'input', size:5 },
        minmax:      {type:'input', size:7, fields:['min','max'], className:'minmax' }, // 'minmax' == 'minmaxInt', the 'Int' is default...
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
          if ( val.match(re) ) { return true; }
          return false;
        },
        'int':   function(arg,val) { return val == arg.value; },
        'float': function(arg,val) { return val == arg.value; },
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
        toPercent: function(x) { return 100*x; },
      },

      isDefined: function() {
        for (var j in this.meta.filter.fields) { return 1; }
        return 0;
      },

      ResetState: function() {
        this.count=0;
        this.args={};
      },

      BuildFilter: function() {
        this.dom.filter.innerHTML = null;
        if ( !this.ctl )  { this.ctl = {}; }
        for (var label in this.meta.filter.structure['f']) {
          var fieldset = document.createElement('fieldset'),
              legend = document.createElement('legend'),

              helpClass = 'phedex-filter-help-class-'+PHEDEX.Util.Sequence(),
              helpCtl = document.createElement('span'),

              hideClass = 'phedex-filter-hide-class-'+PHEDEX.Util.Sequence(),
              hideCtl = document.createElement('span');

          legend.appendChild(document.createTextNode(label));
          fieldset.appendChild(legend);

          helpCtl.appendChild(document.createTextNode('[?]'));
          helpCtl.id = 'help_' +PxU.Sequence();
          ttIds.push(helpCtl.id);
          ttHelp[helpCtl.id] = 'Click here for any additional help that may have been provided';
          YAHOO.util.Event.addListener(helpCtl, 'click', function(aClass,anElement) {
            return function() { PxU.toggleVisible(aClass,anElement) };
          }(helpClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(helpCtl);

          hideCtl.appendChild(document.createTextNode('[x]'));
          hideCtl.id = 'help_' +PxU.Sequence();
          ttIds.push(hideCtl.id);
          ttHelp[hideCtl.id] = 'Click here to collapse or expand this group of filter-elements';
          YAHOO.util.Event.addListener(hideCtl, 'click', function(aClass,anElement) {
              return function() { PxU.toggleVisible(aClass,anElement) };
          }(hideClass,fieldset) );
          legend.appendChild(document.createTextNode(' '));
          legend.appendChild(hideCtl);

          for (var key in this.meta.filter.structure['f'][label]) {
            var c = this.meta.filter.fields[key],
                focusOn, outer, inner, e;
            if ( !c.value ) { c.value = null; }

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
            var fields=e.fields || [''], el, size, def;
            for (var i in fields) {
              if ( i > 0 ) { inner.appendChild(document.createTextNode('  ')); }
              if ( fields[i] != '' ) {
                inner.appendChild(document.createTextNode(fields[i]+' '));
              }
              el = document.createElement(e.type);
              el.id = 'phedex_filter_elem_'+PHEDEX.Util.Sequence(); // needed for focusMap
              this.meta.el[el.id] = el;
              this.meta.inner[inner.id].push(el);
              el.className = 'phedex-filter-elem';
              YAHOO.util.Dom.addClass(el,'phedex-filter-key-'+fields[i]);
              if ( e.className ) { YAHOO.util.Dom.addClass(el,'phedex-filter-elem-'+e.className); }
              size = e.size || c.size;
              if ( size ) { el.setAttribute('size',size); }
              el.setAttribute('type',e.type);
              el.setAttribute('name',key); // is this valid? Multiple-elements per key will get the same name (minmax, for example)
              el.setAttribute('value',c.value);
              inner.appendChild(el);
              if ( !this.meta.focusMap[inner.id] ) { this.meta.focusMap[inner.id] = el.id; }
              if ( !this.focusOn ) { this.focusOn = this.focusDefault = el; }
            }

            var cBox = document.createElement('input'),
                fieldLabel = document.createElement('div');
            cBox.type = 'checkbox';
            cBox.className = 'phedex-filter-checkbox';
            cBox.id = 'cbox_' + PxU.Sequence();
            this.meta.cBox[key] = cBox;
            ttIds.push(cBox.id);
            ttHelp[cBox.id] = '(un)check this box to invert your selection for this element';
            inner.appendChild(cBox);
            outer.appendChild(inner);
            fieldLabel.className = 'float-left';
            fieldLabel.appendChild(document.createTextNode(c.text));
            outer.appendChild(fieldLabel);

            if ( c.tip ) {
              var help = document.createElement('div');
              help.className = 'phedex-filter-help phedex-invisible float-right '+helpClass;
              help.appendChild(document.createTextNode(c.tip));
              outer.appendChild(help);
            }
            fieldset.appendChild(outer);
          }
          this.dom.filter.appendChild(fieldset);
        }
          var tt = new YAHOO.widget.Tooltip("ttB", { context:ttIds }), ttCount={};
          tt.contextMouseOverEvent.subscribe( // prevent tooltip from showing more than a few times, to avoid upsetting experts
            function(type, args) {
              var id = args[0].id,
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
              var text = ttHelp[args[0].id];
              this.element.style.zIndex = 1000;
              this.cfg.setProperty('text', text);
            }
          );
        var k1 = new YAHOO.util.KeyListener(this.dom.filter,
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
            fields = this.meta.filter.fields;
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
                values[key] = el.value;
                a.id[key] = el.id;
                if ( el.value ) { nSet++; }
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
              YAHOO.log('Invalid entry for "'+fields[el.name].text+'", aborting accept','error','Core.Widget');
              this.setInvalid(innerList[i],isValid);
              isValid = false;
            }
          }
        }
        if ( isValid ) {
          _sbx.notify(this.id,'Filter','Validated',this.args);
          _sbx.notify(this.id,'Filter','Apply',this.args,nItems);
        }
        return;
      },

      _resetFilter: function( rollback ) { // rollback to last set values? Or wipe clean?
        var a, el, c, name, key, i;
        for (name in this.args) {
          a = this.args[name];
          i = 0;
          for (key in a.values) {
            el = this.meta.el[a.id[key]];
            c = this.meta.filter.fields[el.name];
            if ( !rollback ) {
              if ( c.value ) { a.values[key] = c.value[key]; }
              else { a.values[key] = null; }
            } else {
            }
            el.value = a.values[key];
            if ( a.values[key] == null ) { delete a.values[key]; }
            if ( a.values[key] ) { i++; }
          }
          if ( !rollback ) {
            this.meta.cBox[name].checked = false;
          } else {
            this.meta.cBox[name].checked = a.negate;
          }
          if ( !i ) { delete this.args[name]; } // no values left, wipe the slate for this field!
        }
        _sbx.notify('Filter',obj.me,this.args,this.asString());
      },

      setValid:   function(el) {
        YAHOO.util.Dom.removeClass(el,'phedex-filter-elem-invalid');
        this.count++;
      },
      setInvalid: function(el,setFocus) {
        YAHOO.util.Dom.addClass(el,'phedex-filter-elem-invalid');
        if ( setFocus ) {
          var focusOn = el[0]; //document.getElementById(this.meta.focusMap[el.id]);
          focusOn.focus();
        }
      },

      isApplied: function() { return this.count; },
      destroy: function() {
        if ( this.overlay && this.overlay.element ) { this.overlay.destroy(); }
      },

      asString: function(args) {
        var str = '', fMeta = this.meta.filter;
        if ( !args ) { args = this.args; }
        for (var key in args) {
          var mKey = key;
          if ( typeof(args[key].values) == 'undefined' ) { continue; }
          var rKey = fMeta.structure['r'][key];
          if ( fMeta.map[rKey].func ) {
            mKey = fMeta.map[rKey].func(key);
          } else {
            mKey = fMeta.map[rKey].to + '.' + key;
          }
          var fValue = args[key].values;
          if ( args[key].format ) { fValue = args[key].format(fValue); }
          var negate = args[key].negate;
          var seg = '';
          if ( negate ) { seg = '!'; }
            if ( fValue.value != null ) {
              seg += mKey+'='+fValue.value;
            } else {
              var c = 0, seg1 = null, seg2 = null;
              if ( fValue.min != null ) { c++; seg1 = mKey+'>'+fValue.min; }
              if ( fValue.max != null ) { c++; seg2 = mKey+'<'+fValue.max; }
              if ( c == 0 ) { /* This shouldn't happen if validation worked! */ continue; }
              if ( c == 1 ) { seg += ( seg1 || seg2 ); } // one or the other is set
              if ( c == 2 ) {  // both are set
                if ( negate ) { seg += '('+ seg1 +'&'+ seg2 + ')'; }
                else          { seg +=      seg1 +'&'+ seg2; }
              }
            }
            if ( str ) { str += ' '; }
            str += seg;
          }
        return str;
      }
    };
  };
  YAHOO.lang.augmentObject(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-filter');
//   PHEDEX.Event.onGlobalFilterCancelled.subscribe( function(obj) {
//     return function() {
//       log('onGlobalFilterCancelled:'+obj.me(),'info','Core.DataTable');
//       YAHOO.util.Dom.removeClass(obj.ctl.filter.el,'phedex-core-control-widget-applied');
//       obj.fillDataSource(obj.data);
//       obj.filter.Reset();
//     }
//   }(this));
//
//   PHEDEX.Event.onGlobalFilterValidated.subscribe( function(obj) {
//     return function(ev,arr) {
//       var args = arr[0];
//       if ( ! obj.filter.args ) { obj.filter.args = []; }
//       for (var i in args) {
//      obj.filter.args[i] = args[i];
//       }
//       obj.applyFilter(arr[0]);
//     }
//   }(this));