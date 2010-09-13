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
          apc.name = 'panelControl'; // +PxU.Sequence(); ???
          this.ctl[apc.name] = new PHEDEX.Component.Control( _sbx, apc );
          if ( apc.parent ) { obj.dom[apc.parent].appendChild(this.ctl[apc.name].el); }
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
        o.setFooter('&nbsp;'); this.overlay.setFooter(''); // likewise the footer, but I don't want anything in it, not from here, anyway...
        o.header.id = 'hd_'+PxU.Sequence();
        YuD.addClass(o.element,'phedex-core-overlay')
        o.body.innerHTML = null;

        this.dragdrop = new Yu.DD(o.element); // add a drag-drop facility, just for fun...
        this.dragdrop.setHandleElId(o.header);
        this.BuildOverlay();
debugger;
        this.meta._panel = this.createPanelMeta();
        this.BuildPanel();
      },

      createPanelMeta: function() {
        if ( this.meta._panel ) { return this.meta._panel; }
        var meta = { structure: { f:{}, r:{} }, rFriendly:{}, fields:{} },  // mapping of field-to-group, and reverse-mapping of same
            f = this.meta.panel,
            re, str, i, j, k, l, key;

        for (i in f) {
          l = {};
          for (j in f[i].fields) {
            k = j.replace(/ /g,'');
            l[k] = f[i].fields[j];
            l[k].original = j;
          }
          f[i].fields = l;

          if ( f[i].map ) {
            var fn = function( m ) {
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
            var c = _panel.fields[key],
                focusOn, outer, inner, e, value, i, fields, cBox, fieldLabel, help,  el, size, def;

            outer = document.createElement('div');
            inner = document.createElement('div');
            outer.className = 'phedex-panel-outer phedex-visible '+hideClass;
            inner.className = 'phedex-panel-inner';
            inner.id = 'phedex_panel_inner_'+PHEDEX.Util.Sequence();
            this.meta.el[inner.id] = inner;
            this.meta.inner[inner.id] = [];
            e = this.typeMap[c.type];
            if ( !e ) {
              log('unknown panel-type"'+c.type+'", aborting','error',_me);
              return;
            }

            if ( c.tip ) {
              help = document.createElement('div');
              help.className = 'phedex-panel-help phedex-invisible float-right '+helpClass;
              help.appendChild(document.createTextNode(c.tip));
              outer.appendChild(help);
            }
            fieldset.appendChild(outer);
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
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-panel');
