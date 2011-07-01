PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.Create = function(sandbox) {
  var string = 'nextgen-request-create',
      _sbx = sandbox,
      Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      NUtil = PHEDEX.Nextgen.Util;
  Yla(this,new PHEDEX.Module(_sbx,string));

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
        var d = this.dom;
        d.target = el;
        d.container  = document.createElement('div'); d.container.className  = 'phedex-nextgen-container'; d.container.id = 'doc2';
        d.hd         = document.createElement('div'); d.hd.className         = 'phedex-nextgen-hd phedex-silver-border'; d.hd.id = 'hd';
        d.bd         = document.createElement('div'); d.bd.className         = 'phedex-nextgen-bd phedex-silver-border'; d.bd.id = 'bd';
        d.ft         = document.createElement('div'); d.ft.className         = 'phedex-nextgen-ft phedex-silver-border'; d.ft.id = 'ft';
        d.main       = document.createElement('div'); d.main.className       = 'yui-main';
        d.main_block = document.createElement('div'); d.main_block.className = 'yui-b phedex-nextgen-main-block';

        d.bd.appendChild(d.main);
        d.main.appendChild(d.main_block);
        d.container.appendChild(d.hd);
        d.container.appendChild(d.bd);
        d.container.appendChild(d.ft);
        el.innerHTML = '';
        el.appendChild(d.container);

        d.floating_help = document.createElement('div'); d.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible';
        document.body.appendChild(d.floating_help);
      },
      Help:function(arg) {
        var item      = this[arg],
            help_text = item.help_text,
            elSrc     = item.help_align,
            elContent = this.dom.floating_help,
            elRegion  = Dom.getRegion(elSrc);
        if ( this.help_item != arg ) {
          Dom.removeClass(elContent,'phedex-invisible');
          Dom.setX(elContent,elRegion.left);
          Dom.setY(elContent,elRegion.bottom);
          elContent.innerHTML = help_text;
          this.help_item = arg;
        } else {
          Dom.addClass(elContent,'phedex-invisible');
          delete this.help_item;
        }
      },
      init: function(params) {
        if ( !params ) { params={}; }
        this.params = params;
        var type=params.type, el;
        if ( type == 'xfer' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Xfer(_sbx,params), true);
        } else if ( type == 'delete' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Delete(_sbx,params), true);
        } else if ( !type ) {
          var l = location, href = location.href;
          var e = document.createElement('div');
          e.innerHTML = '<h1>Choose a request type</h1>' +
                      '<ul>' +
                        "<li><a href='" + location.pathname + "?type=xfer'>Transfer Request</a></li>" +
                        "<li><a href='" + location.pathname + "?type=delete'>Deletion Request</a></li>" +
                      '</ul>';
          params.el.innerHTML='';
          params.el.appendChild(e);
          return;
        } else {
          throw new Error('type is defined but unknown: '+type);
        }
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                value  = arr.shift();
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              obj[action].apply(obj,arr);//(value);
              return;
            }
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
        this.initSub();
        this.initButtons();
      },
      initButtons: function() {
        var ft=this.dom.ft, Reset, //, Validate, Cancel;
            el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-left');
        el.id='buttons-left';
        ft.appendChild(el);

        el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-centre');
        el.id='buttons-centre';
        ft.appendChild(el);

        el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-buttons phedex-nextgen-buttons-right');
        el.id='buttons-right';
        ft.appendChild(el);

        var label='Reset', id='button'+label;
        Reset = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-left' });
        label='Preview', id='button'+label;
        this.Preview = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
        this.Preview.set('disabled',true);
        this.Preview.on('click', this.onPreviewSubmit);
        label='Accept', id='button'+label;
        this.Accept = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
        this.Accept.set('disabled',true);
        this.Accept.on('click', this.onAcceptSubmit);

        this.onResetSubmit = function(obj) {
          return function(id,action) {
            var dbs = obj.dbs,
                dom = obj.dom,
                user_group  = obj.user_group,
                email       = obj.email,
                time_start  = dom.time_start,
                data_items  = dom.data_items,
                comments    = dom.comments,
                menu, menu_items,
                tmp, elList, _default, el, i;

// Subscription level: hardwired to 'block' in the request

// Data Items
            data_items.value = '';
            data_items.onblur();

// DBS
            if ( dbs.gotMenu ) {
              dbs.value.innerHTML = dbs._default;
              menu       = dbs.MenuButton.getMenu();
              menu_items = menu.getItems();
              menu.activeItem = menu_items[dbs.defaultId];
            }

// Destination
            elList = obj.destination.Panel.elList;
            for (i in elList) {
              elList[i].checked = false;
            }

// Remove Subscription
            if ( tmp = obj.remove_subscription ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Site Custodial
            if ( tmp = obj.site_custodial ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Subscription Type
            if ( tmp = obj.subscription_type ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Transfer Type
            if ( tmp = obj.transfer_type ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// Priority
            if ( tmp = obj.priority ) {
              elList = tmp.elList;
              _default = tmp._default;
              for (i in elList) {
                el = elList[i];
                if ( el.value == _default ) { el.checked = true; }
                else                        { el.checked = false; }
              }
            }

// User Group
            if ( user_group ) {
              user_group.MenuButton.set('label', user_group._default);
              user_group.value = null;
            }

// Time Start
// TODO need to reset the calendar YUI module too
            if ( time_start ) {
              time_start.value = '';
              time_start.onblur();
            }

// Email
            if ( email ) {
              email.value.innerHTML = email.input.value = email._default;
            }

// Comments
            if ( comments ) {
              comments.value = '';
              comments.onblur();
            }

            obj.Accept.set('disabled',false);
            dom.preview_text.innerHTML = dom.preview_label.innerHTML = '';
            Dom.addClass(dom.preview,'phedex-invisible');
            Dom.addClass(dom.results,'phedex-invisible');
          }
        }(this);
        Reset.on('click', this.onResetSubmit);
      },
      processNestedrequest: function (record) {
        try {
          var nesteddata = record.getData('nesteddata');
          this.nestedDataSource = new YuDS(nesteddata);
          return nesteddata;
        }
        catch (ex) {
          log('Error in expanding nested table.. ' + ex.Message, 'error', _me);
        }
      },
      synchronise: function(item,state) {
        this[item].set('disabled', state == 'allSet' ? false : true );
      },
      setValueFor: function(label) {
        var key, i, j, ok=true, synchronise=this.meta.synchronise;
        if ( !synchronise ) { return; }
        for (i in synchronise) {
          key = synchronise[i];
          if ( typeof(key[label]) != 'undefined' ) {
            if ( key[label] ) { return; } // no change in value, so nothing to notify
            key[label] = true;
            for (j in key) {
              ok = ok && key[j];
            }
            if ( ok ) {
              PxS.notify(this.id,'synchronise',i,'allSet');
            }
          }
        }
      },
      unsetValueFor: function(label) {
        var key, i, j, ok=true, synchronise=this.meta.synchronise;
        if ( !synchronise ) { return; }
        for (i in synchronise) {
          key = synchronise[i];
          if ( typeof(key[label]) != 'undefined' ) {
            if ( !key[label] ) { return; } // no change in value, so nothing to notify
            for (j in key) {
              ok = ok && key[j];
            }
            key[label] = false;
            if ( ok ) {
              PxS.notify(this.id,'synchronise',i,'notAllSet');
            }
          }
        }
      },
      makeControlDBS: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, resize, helpStr='',
            instance = PHEDEX.Datasvc.Instance();
        config._default = config.instanceDefault[instance.instance] || '(not defined)';

        el = document.createElement('div');
        el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                          "<div class='phedex-nextgen-label'>"+label+"</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='dbs_selected'>" + "<span id='dbs_value'>" + config._default + "</span>" +
                            "<span>&nbsp;</span>" + "<a id='change_dbs' class='phedex-nextgen-form-link' href='#'>change</a>" +
                          "</div>" +
                        "<div id='dbs_menu''></div>" +
                        "</div>" +
                      "</div>";
        parent.appendChild(el);
        config.menu     = Dom.get('dbs_menu');
        config.value    = Dom.get('dbs_value');
        config.selected = Dom.get('dbs_selected');
        Dom.setStyle(config.value,'color','grey');

        var makeDBSMenu = function(obj) {
          return function(data,context,response) {
            PHEDEX.Datasvc.throwIfError(data,response);
            var onMenuItemClick, onChangeDBSClick, dbsMenuItems=[], dbsList, dbsEntry, i, dDiv;
            onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
              var sText = p_oItem.cfg.getProperty('text');
              if ( sText.match(/<strong>(.*)<\/strong>/) ) { sText = RegExp.$1; }
              config.MenuButton.set('label', '<em>'+sText+'</em>');
            };

            dbsList = data.dbs;
            if ( !dbsList ) {
              dDiv = Dom.get('dbs_menu');
              dDiv.innerHTML = '&nbsp;<strong>Error</strong> loading dbs names, cannot continue';
              Dom.addClass(dDiv,'phedex-box-red');
              obj.Preview.set('disabled',true);
              obj.Accept.set('disabled',true);
              Dom.get('data_items').disabled = true;
              return;
            }
            for (i in dbsList ) {
              dbsEntry = dbsList[i];
              if ( dbsEntry.name == config._default ) {
                dbsEntry.name = '<strong>'+dbsEntry.name+'</strong>';
                config.defaultId = i;
              }
              dbsMenuItems.push( { text:dbsEntry.name, value:dbsEntry.id, onclick:{ fn:onMenuItemClick } } );
            }
            config.menu.innerHTML = '';
            config.MenuButton = new YAHOO.widget.Button({  type: 'menu',
                                    label: '<em>'+config._default+'</em>',
                                    id:   'dbsMenuButton',
                                    name: 'dbsMenuButton',
                                    menu:  dbsMenuItems,
                                    container: 'dbs_menu' });
            config.MenuButton.on('selectedMenuItemChange',function(event) {
              var menuItem = event.newValue,
                  value    = menuItem.cfg.getProperty('text');
                  if ( value.match(/<strong>(.*)</) ) { value = RegExp.$1; }
              config.value.innerHTML = value;
              Dom.removeClass(config.selected,'phedex-invisible');
              Dom.setStyle(config.MenuButton,'display','none');
            });
            config.gotMenu = true;
          }
        }(this);

        onChangeDBSClick = function(obj) {
          return function() {
            if ( !config.gotMenu ) {
              PHEDEX.Datasvc.Call({ api:'dbs', callback:makeDBSMenu });
              config.menu.innerHTML = '<em>loading menu, please wait...</em>';
              Dom.addClass(dbs.selected,'phedex-invisible');
            } else {
              Dom.setStyle(config.MenuButton,'display',null);
              Dom.addClass(config.selected,'phedex-invisible');
            }
          };
        }(this);
        Event.on(Dom.get('change_dbs'),'click',onChangeDBSClick);
      },
      makeControlOutputbox: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, className;
        if ( config.className ) { className = "class='"+config.className+"'"; }
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-nextgen-"+labelLower+"'"+className+"'>" +
                         "<div class='phedex-nextgen-form-element'>" +
                            "<div id='phedex-nextgen-"+labelLower+"-label' class='phedex-nextgen-label'></div>" +
                            "<div class='phedex-nextgen-control'>" +
                              "<div id='phedex-nextgen-"+labelLower+"-text'></div>" +
                            "</div>" +
                          "</div>" +
                        "</div>";
        parent.appendChild(el);
        d[labelLower] = Dom.get('phedex-nextgen-'+labelLower);
        d[labelLower+'_label'] = Dom.get('phedex-nextgen-'+labelLower+'-label');
        d[labelLower+'_text']  = Dom.get('phedex-nextgen-'+labelLower+'-text');
      },
      makeControlDestination: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, resize, className;
        if ( config.className ) { className = "class='"+config.className+"'"; }
        el = document.createElement('div');
        Dom.addClass(el,'phedex-nextgen-form-element');
        el.innerHTML = "<div id='"+labelLower+"-container' class='phedex-nextgen-form-element'>" +
                         "<div class='phedex-nextgen-label'>"+label+"</div>" +
                         "<div id='"+labelLower+"-panel-wrapper' class='phedex-nextgen-control'>" +
                           "<div id='"+labelLower+"-panel' class='phedex-nextgen-nodepanel'>" +
                             "<em>loading "+labelLower+" list...</em>" +
                           "</div>" +
                         "</div>" +
                       "</div>";
        parent.appendChild(el);
        resize = config.resize || {maxWidth:745, minWidth:100};
        NUtil.makeResizable(labelLower+'-panel-wrapper',labelLower+'-panel',resize);
        config.Panel = NUtil.NodePanel( this, Dom.get(labelLower+'-panel') );

        d.destination = Dom.get(labelLower+'-container');
        var onPanelClick = function(obj) {
          return function(event, matchedEl, container) {
            var panel = config.Panel,
                elList = panel.elList,
                i, elList;
            config.node = [];
            for (i in elList) {
              el = elList[i];
              if ( el.checked ) { config.node.push(panel.nodes[i]); }
            }
            if ( config.node.length == 0 ) {
              PxS.notify(obj.id,'unsetValueFor',labelForm);
            } else {
              PxS.notify(obj.id,'setValueFor',labelForm);
            }
          }
        }(this);
        YAHOO.util.Event.delegate(d.destination, 'click', onPanelClick, 'input');
      },
      makeControlTextbox: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, resize, helpStr='';
        el = document.createElement('div');
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelCss+"' href='#'>[?]</a>";
        }
        el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                          "<div class='phedex-nextgen-label' id='phedex-label-"+labelCss+"'>"+label+helpStr+"</div>" +
                          "<div id='"+labelCss+"-wrapper' class='phedex-nextgen-control'>" +
                            "<div><textarea id='"+labelLower+"' name='"+labelLower+"' class='phedex-nextgen-textarea'>" + config.text + "</textarea></div>" +
                          "</div>" +
                        "</div>";
        parent.appendChild(el);
        if ( config.help_text ) {
          config.help_align = Dom.get('phedex-label-'+labelCss);
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }

        resize = config.resize || {maxWidth:745, minWidth:100};
        NUtil.makeResizable(labelCss+'-wrapper',labelLower,resize);

        d[labelForm] = Dom.get(labelLower);
        d[labelForm].onfocus = function() {
          if ( this.value == config.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
            PxS.notify(obj.id,'setValueFor',labelForm);
          }
        }
        d[labelForm].onblur=function() {
          if ( this.value == '' ) {
            this.value = config.text;
            Dom.setStyle(this,'color',null);
            PxS.notify(obj.id,'unsetValueFor',labelForm);
          } else {
            PxS.notify(obj.id,'setValueFor',labelForm);
          }
        }
      },
      makeControlRadio: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, i, radioStr='', helpStr='';
        el = document.createElement('div');
        for ( i in config.values ) {
          radioStr += "<div><input class='phedex-radio' type='radio' name='"+labelForm+"' value='"+i+"'";
          if ( config._default == i ) { radioStr += " checked"; }
          radioStr += ">"+config.values[i]+"</input></div>";
        }
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelCss+"' href='#'>[?]</a>";
        }

        el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                          "<div class='phedex-nextgen-label' id='phedex-label-"+labelCss+"'>"+label+helpStr+"</div>" +
                          "<div id='"+labelForm+"' class='phedex-nextgen-control'>" +
                            radioStr +
                         "</div>" +
                       "</div>";
        parent.appendChild(el);
        if ( config.help_text ) {
          config.help_align = Dom.get('phedex-label-'+labelCss);
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }
        config.elList = Dom.getElementsByClassName('phedex-radio','input',labelForm);
      },
      getRadioValues: function(config) {
        var elList=config.elList, map=config.map, i, value;
        for (i in elList) {
          el = elList[i];
          if ( el.checked ) {
            value = config.values[el.value];
            if ( map ) { value = map[value]; }
          }
        }
        return value;
      }
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

PHEDEX.Nextgen.Request.Xfer = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      NUtil = PHEDEX.Nextgen.Util;
  return {
    meta: {
      table: { columns: [{ key:'dataset',       label:'Dataset', className:'align-left' },
                         { key:'blocks',        label:'Blocks',  className:'align-right', parser:'number' },
                         { key:'bytes',         label:'Bytes',   className:'align-right', parser:'number', formatter:'customBytes' },
                         { key:'time_create',   label:'Creation time', formatter:'UnixEpochToUTC', parser:'number' },
                         { key:'is_open',       label:'Open', className:'align-right' }],
          nestedColumns:[{ key:'block',         label:'Block', className:'align-left' },
                         { key:'b_files',       label:'Files', className:'align-right', parser:'number' },
                         { key:'b_bytes',       label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' },
                         { key:'b_time_create', label:'Creation time', formatter:'UnixEpochToUTC', parser:'number' },
                         { key:'b_is_open',     label:'Open', className:'align-right' }]
              },
      synchronise: {
        Preview: { data_items:false },
        Accept:  { data_items:false, destination:false, user_group:false }
      }
    },
    initSub: function() {
      var d = this.dom,
          mb = d.main_block,
          hd = d.hd,
          form, elList, el, label, control, i, ctl;
      hd.innerHTML = 'Subscribe data';

      form = document.createElement('form');
      form.id   = 'subscribe_data';
      form.name = 'subscribe_data';
      mb.appendChild(form);

// Subscription level

// Data Items
      this.data_items = {
        text:'enter one or more block/data-set names, separated by white-space or commas.',
        help_text:"<p><strong>/Primary/Processed/Tier</strong> or<br/><strong>/Primary/Processed/Tier#Block</strong></p><p>Use an asterisk (*) as wildcard, and either whitespace or a comma as a separator between multiple entries</p><p>Even if wildcards are used, the dataset path separators '/' are required. E.g. to subscribe to all 'Higgs' datasets you would have to write '/Higgs/*/*', not '/Higgs*'.</p>",
        label:'Data Items'
      };
      this.makeControlTextbox(this.data_items,form);

// Preview
      this.makeControlOutputbox({label:'Preview'},form);

// DBS
      this.dbs = {
        instanceDefault:{
          prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          test:'LoadTest',
          debug:'LoadTest',
          tbedi:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          tbedii:'test',
          tony:'test'
        },
        label:'DBS'
      };
      this.makeControlDBS(this.dbs,form);

// Destination
      this.destination = {
        label:'Destination'
      };
      this.makeControlDestination(this.destination,form);

// Site Custodial
      this.site_custodial = {
        values:['yes','no'],
        _default:1,
        help_text:'<p>Whether or not the target node(s) have a custodial responsibility for the data in this request.</p><p>Only T1s and the T0 maintain custodial copies, T2s and T3s never have custodial responsibility</p>',
        label:'Site Custodial',
        map:{yes:'y', no:'n'}
      };
      this.makeControlRadio(this.site_custodial,form);

// Subscription type
      this.subscription_type = {
        values:['growing','static'],
        _default:0,
        help_text:'<p>A <strong>growing</strong> subscription downloads blocks/files added to open datasets/blocks as they become available, until the dataset/block is closed.</p><p>Also, wildcard patterns will be re-evaluated to match new datasets/blocks which become available.</p><p>A <strong>static</strong> subscription will expand datasets into block subscriptions.</p><p>Wildcard patterns will not be re-evaluated. A static subscription is a snapshot of blocks available now</p>',
        label:'Subscription Type',
        map:{'static':'y', growing:'n'}
      };
      this.makeControlRadio(this.subscription_type,form);

// Transfer type
      this.transfer_type = {
        values:['replica','move'],
        _default:0,
        help_text:'<p>A <strong>replica</strong> replicates data from the source to the destination, creating a new copy of the data.</p><p>A <strong>move</strong> replicates the data then deletes the data at the source. The deletion will be automatic if the source data is unsubscribed; if it is subscribed, the source site will be asked to approve or disapprove the deletion.</p><p>Note that moves are only used for moving data from T2s to T1s</p>',
        label:'Transfer Type',
        map:{move:'y', replica:'n'}
      };
      this.makeControlRadio(this.transfer_type,form);

// Priority
      this.priority = {
        values:['high','normal','low'],
        _default:2,
        help_text:'<p>Priority is used to determine which data items get priority when resources are limited.</p><p>Setting high priority does not mean your transfer will happen faster, only that it will be considered first if there is congestion causing a queue of data to build up.</p><p>Use <strong>low</strong> unless you have a good reason not to</p>',
        label:'Priority'
      };
      this.makeControlRadio(this.priority,form);

// User group
      this.user_group = {
        _default:'<em>Choose a group</em>',
        help_text:'<p>The group which is requesting this data. Used for accounting purposes.</p><p>This field is now mandatory, whereas previously it could be left undefined.</p>'
      };
      var user_group = this.user_group;
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-user-group'>User Group <a class='phedex-nextgen-help' id='phedex-help-user-group' href='#'>[?]</a></div>" +
                        "<div id='user_group_menu' class='phedex-nextgen-control'>" + "<em>loading list of groups...</em>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      user_group.help_align = Dom.get('phedex-label-user-group');
      Dom.get('phedex-help-user-group').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','user_group');");

      var makeGroupMenu = function(obj) {
        return function(data,context,response) {
          PHEDEX.Datasvc.throwIfError(data,response);
          var onMenuItemClick, groupMenuItems=[], groupList, group, i, gDiv;
          gDiv = Dom.get('user_group_menu');
          gDiv.innerHTML = '';
          groupList = data.group;
          if ( !groupList ) {
            gDiv.innerHTML = '&nbsp;<strong>Error</strong> loading group names, cannot continue';
            Dom.addClass(gDiv,'phedex-box-red');
            obj.Preview.set('disabled',true);
            obj.Accept.set('disabled',true);
            Dom.get('data_items').disabled = true;
            return;
          }

          onMenuItemClick = function (p_sType, p_aArgs, p_oItem) {
            var sText = p_oItem.cfg.getProperty('text');
            user_group.MenuButton.set('label', sText);
            user_group.value = sText;
            PxS.notify(obj.id,'setValueFor','user_group');
//             if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
          };
          for (i in groupList ) {
            group = groupList[i];
            if ( !group.name.match(/^deprecated-/) ) {
              groupMenuItems.push( { text:group.name, value:group.id, onclick:{ fn:onMenuItemClick } } );
            }
          }
          user_group.MenuButton = new YAHOO.widget.Button({ type: 'menu',
                                    label: user_group._default,
                                    id:   'groupMenuButton',
                                    name: 'groupMenuButton',
                                    menu:  groupMenuItems,
                                    container: 'user_group_menu' });
          user_group.MenuButton.getMenu().cfg.setProperty('scrollincrement',5);
       }
      }(this);
      PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// Time Start
      this.time_start = {
        text:'YYYY-MM-DD [hh:mm:ss]',
        help_text:'<p>This field is optional. Only data injected into PhEDEx after the specified time will be subscribed with this request. If you do not specify a time, all the data from the dataset(s) requested will be subscribed</p><p><strong>N.B.</strong> This does not affect the transfer scheduling, only the selection of a time-window of data. Data will still be transferred as soon as it can be queued to your destination.</p><p>If you do not specify a time, all the data will be subscribed.</p><p>You can enter a date & time in the box, or select a date from the calendar</p><p>The time will be rounded down to the latest block-boundary before the time you specify. I.e. you will receive whole blocks, starting from the block that contains the start-time you specify</p><p>The time is interpreted as UT, not as your local time.</p>'
      };
      var time_start = this.time_start;
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML =  "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label' id='phedex-label-time-start'>Data injected after <a class='phedex-nextgen-help' id='phedex-help-time-start' href='#'>[?]</a></div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><input type='text' id='time_start' name='time_start' class='phedex-nextgen-text' value='" + time_start.text + "' />" +
                          "<img id='phedex-nextgen-calendar-icon' width='18' height='18' src='" + PxW.BaseURL + "/images/calendar_icon.gif' style='vertical-align:middle; padding:0 0 0 2px;' />" +
                          "</div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      time_start.help_align = Dom.get('phedex-label-time-start');
      Dom.get('phedex-help-time-start').setAttribute('onclick', "PxS.notify('"+this.id+"','Help','time_start');");
      d.calendar_icon = Dom.get('phedex-nextgen-calendar-icon');

      el = document.createElement('div');
      el.id='phedex-nextgen-calendar-el';
      el.className='phedex-invisible';
      document.body.appendChild(el);
      d.calendar_el = el;

      var mySelectHandler = function(o) {
        return function(type,args,obj) {
          var selected = args[0][0];
          o.dom.time_start.value = selected[0]+'-'+selected[1]+'-'+selected[2]+' 00:00:00';
          if ( o.formFail ) { o.Accept.set('disabled',false); o.formFail=false; }
          Dom.setStyle(o.dom.time_start,'color','black');
          YuD.addClass(elCal,'phedex-invisible');
        }
      }(this);
      var cal = new YAHOO.widget.Calendar( 'cal'+PxU.Sequence(), d.calendar_el); //, {maxdate:now.month+'-'+now.day+'-'+now.year } );
          cal.cfg.setProperty('MDY_YEAR_POSITION', 1);
          cal.cfg.setProperty('MDY_MONTH_POSITION', 2);
          cal.cfg.setProperty('MDY_DAY_POSITION', 3);
          cal.selectEvent.subscribe( mySelectHandler, cal, true);
          cal.render();

      YuE.addListener(d.calendar_icon,'click',function() {
        if ( YuD.hasClass(d.calendar_el,'phedex-invisible') ) {
          var elRegion = Dom.getRegion(d.time_start);
          YuD.removeClass(d.calendar_el,'phedex-invisible');
          Dom.setX(d.calendar_el,elRegion.left);
          Dom.setY(d.calendar_el,elRegion.bottom);
        } else {
          YuD.addClass(d.calendar_el,'phedex-invisible');
        }
      }, this, true);

      d.time_start = Dom.get('time_start');
      Dom.setStyle(d.time_start,'width','170px')
      d.time_start.onfocus=function(obj) {
        return function() {
          if ( this.value == time_start.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
          }
          if ( obj.formFail ) { obj.Accept.set('disabled',false); obj.formFail=false; }
        }
      }(this);
      d.time_start.onblur=function(obj) {
        return function() {
          if ( this.value == '' ) {
            this.value = time_start.text;
            delete time_start.time_start;
            Dom.setStyle(this,'color',null)
          }
        }
      }(this);

      this.getTimeStart = function() {
        var time_start=this.time_start, el=this.dom.time_start, str=el.value, arr=[], year, day, month, hour, minute, second, now=PxU.now();
        if ( str == time_start.text ) { return; } // no date specified!
        if ( !str.match(/^(\d\d\d\d)\D+(\d\d?)\D+(\d\d?)(\D+)?(.*)$/) ) {
          this.onAcceptFail('Illegal date format. Must be YYYY-MM-DD HH:MM:SS (HH:MM:SS optional)');
          return;
        }
        year  = parseInt(RegExp.$1);
        month = parseInt(RegExp.$2);
        day   = parseInt(RegExp.$3);
        str   = RegExp.$5;
        hour = minute = second = 0;
        if ( str != '' ) {
          str.match(/^(\d\d?)(\D+(\d\d?))?(\D+(\d\d?))?$/);
          hour   = parseInt(RegExp.$1);
          minute = parseInt(RegExp.$3 || 0);
          second = parseInt(RegExp.$5 || 0);
        }
        time_start.time_start = Date.UTC(year,month-1,day,hour,minute,second)/1000; // Month counts from zero in Javascript Data object
      }

// Email
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
// TODO take away phedex-invisible if we really need this, or suppress this field entirely if we don't
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Email</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='email_selector'>" +
                            "<span id='email_value'></span>" +
                            "<span>&nbsp;</span>" +
                            "<a id='change_email' class='phedex-nextgen-form-link phedex-invisible' href='#'>change</a>" + // Do we want to change this?
                          "</div>" +
                          "<div><input type='text' id='email_input' name='email' class='phedex-nextgen-text phedex-invisible' value='' /></div>" +
                        "</div>" +
                      "</div>";

      form.appendChild(el);
      this.email = { _default:'(unknown)' };
      var email = this.email, onEmailInput, kl;
      email.selector = Dom.get('email_selector');
      email.input    = Dom.get('email_input');
      email.value    = Dom.get('email_value');
      Dom.setStyle(email.input,'width','170px')
      Dom.setStyle(email.input,'color','black');
      Dom.setStyle(email.value,'color','grey');

      onChangeEmailClick = function(obj) {
        return function() {
          Dom.addClass(   email.selector,'phedex-invisible');
          Dom.removeClass(email.input,   'phedex-invisible');
          email.input.focus();
        };
      }(this);
      Event.on(Dom.get('change_email'),'click',onChangeEmailClick);

      onEmailInput = function(obj) {
        return function() {
          Dom.removeClass(email.selector,'phedex-invisible');
          Dom.addClass(   email.input,   'phedex-invisible');
          email.value.innerHTML = email.input.value;
        }
      }(this);
      email.input.onblur = onEmailInput;

      kl = new YAHOO.util.KeyListener(email.input,
                               { keys:YAHOO.util.KeyListener.KEY.ENTER },
                               { fn:function(obj){ return function() { onEmailInput(); } }(this),
                               scope:this, correctScope:true } );
      kl.enable();

      var gotAuthData = function(obj) {
        return function(data,context,response) {
          var address = '';
          try { address = data.auth[0].email; }
          catch(ex) {
//          AUTH failed, don't know what address to put in!
            email.value.innerHTML = email._default;
          }
          if ( !address ) { return; }
          email.value.innerHTML = email.input.value = email._default = address;
        };
      }(this);
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:gotAuthData })

// Comments
      this.comments = {
        text:'enter any additional comments here',
        label:'Comments'
      };
      this.makeControlTextbox(this.comments,form);

// Results
      this.makeControlOutputbox({label:'Results', className:'phedex-invisible'},form);

// Set up the Accept and Reset handlers
      this.requestCallback = function(obj) {
        return function(data,context,response) {
          var dom = obj.dom, str, msg, rid;
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML = '';
          Dom.removeClass(dom.results,'phedex-box-yellow');
          if ( data.message ) { // indicative of failure
            str = "Error when making call '" + context.api + "':";
            msg = data.message.replace(str,'').trim();
            obj.onAcceptFail(msg);
            obj.Accept.set('disabled',false);
          }
          if ( rid = data.request_created[0].id ) {
            obj.onResetSubmit();
            var uri = location.href;
            uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
            uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
            uri = uri.replace(/\/[^/]*$/g,'/');

            dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
              "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
            Dom.addClass(dom.results,'phedex-box-green');
            Dom.removeClass(dom.results,'phedex-invisible');
            d.preview_text.innerHTML = d.preview_label.innerHTML = '';
            Dom.addClass(dom.preview,'phedex-invisible');
          }
        }
      }(this);
      this.onAcceptFail = function(obj) {
        return function(text) {
          var dom = obj.dom;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-red');
          dom.results_label.innerHTML = 'Error:';
          if ( dom.results_text.innerHTML ) {
            dom.results_text.innerHTML += '<br />';
          }
          dom.results_text.innerHTML += text;
          obj.formFail = true;
        }
      }(this);
      this.onAcceptSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              user_group = obj.user_group,
              email      = obj.email,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i, panel;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;
          this.set('disabled',true);

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// DBS - done directly in the xml

// Destination
          panel = obj.destination.Panel;
          elList = panel.elList;
          args.node = [];
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.node.push(panel.nodes[i]); }
          }
          if ( args.node.length == 0 ) {
            obj.onAcceptFail('No Destination nodes specified');
          }

// Site Custodial
          args.custodial = obj.getRadioValues(obj.site_custodial);
// Subscription Type
          args['static'] = obj.getRadioValues(obj.subscription_type);
// Transfer Type
          args.move = obj.getRadioValues(obj.transfer_type);
// Priority
          args.priority = obj.getRadioValues(obj.priority);

// User Group
          if ( ! user_group.value ) {
            obj.onAcceptFail('No User-Group specified');
          }
          args.group = user_group.value;

// Time Start
          obj.getTimeStart();
          if ( time_start.time_start ) {
            args.time_start = time_start.time_start;
          }

// Email TODO check if we need this field?
//           args.email = email.value.innerHTML;

// Comments
          if ( dom.comments.value && dom.comments.value != obj.comments.text ) { args.comments = dom.comments.value; }

// Never subscribe automatically from this form
          args.request_only = 'y';

// Do not suppress the email
          args.no_mail = 'n';

// Hardwired, for best practise!
          args.level = 'block';

// If there were errors, I can give up now!
          if ( obj.formFail ) {
            this.set('disabled',true);
            return;
          }

// Now build the XML!
          xml = '<data version="2.0"><dbs name="' + dbs.value.innerHTML + '">';
          for ( dataset in data.datasets ) {
            xml += '<dataset name="'+dataset+'" is-open="dummy">';
            for ( block in data.datasets[dataset] ) {
              xml += '<block name="'+block+'" is-open="dummy" />';
            }
            xml += '</dataset>';
          }
          xml += '</dbs></data>';
          args.data = xml;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-yellow');
          dom.results_label.innerHTML = 'Status:';
          dom.results_text.innerHTML  = NUtil.stdLoading('Submitting request (please wait)');
          PHEDEX.Datasvc.Call({
                                api:'subscribe',
                                method:'post',
                                args:args,
                                callback:function(data,context,response) { obj.requestCallback(data,context,response); }
                              });
        }
      }(this);

      this.onPreviewSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          Dom.addClass(obj.dom.results,'phedex-invisible');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// Time Start
          obj.getTimeStart();
          if ( time_start.time_start ) {
            args.create_since = time_start.time_start;
          } else {
            args.create_since = 0;
          }

// If there were errors, I can give up now!
          if ( obj.formFail ) { return; }

// Now build the args!
          if ( data.datasets ) {
            for ( dataset in data.datasets ) {
              blocks = data.datasets[dataset];
              if ( typeof(blocks) == 'number' ) {
                if ( !args.dataset ) { args.dataset = []; }
                args.dataset.push(dataset);
              } else {
                for ( block in blocks ) {
                  if ( !args.block ) { args.block = []; }
                  args.block.push(block);
                }
              }
            }
          }
          Dom.removeClass(dom.preview,'phedex-invisible');
          Dom.addClass(dom.preview,'phedex-box-yellow');
          dom.preview_label.innerHTML = 'Status:';
          dom.preview_text.innerHTML  = NUtil.stdLoading('Calculating request (please wait)');
          args.level = 'block';
//           PHEDEX.Datasvc.Call({ api:'data', args:args, callback:function(data,context,response) { obj.previewCallback(data,context,response); } });
          PHEDEX.Datasvc.Call({
                                api:'previewrequestdata',
                                args:args,
                                callback:function(data,context,response) { obj.previewCallback(data,context,response); }
                              });
        }
      }(this);
    },
    previewCallback: function(data,context,response) {
      var rid, api=context.api, Table=[], Row, Nested, unique=0, ds, block, nFiles, nBytes, tDatasets=0, tBlocks=0, tFiles=0, tBytes=0;
      switch (api) {
        case 'data': {
          var dom=this.dom, datasets=data.dbs, ds, dsName, blocks, block, i, j, n,
              t=this.meta.table, cDef;
          Dom.removeClass(dom.preview,'phedex-box-yellow');
          Dom.removeClass(dom.preview,'phedex-box-red');
          if ( !datasets ) {
            dom.preview_text.innerHTML = 'Error retrieving information from the data-service';
            Dom.addClass(dom.preview,'phedex-box-red');
            return;
          }
          if ( datasets.length == 0 ) {
            dom.preview_text.innerHTML = 'No data found matching your selection';
            if ( context.args.create_since ) {
              dom.preview_text.innerHTML += '<br/><br/>No data injected since the time you specified (' + PxUf.UnixEpochToUTC(context.args.create_since) + ')' +
                                            '<br/><br/>If you expect data to be injected later, you can continue with the request. Otherwise, please modify your selection.';
              Dom.addClass(dom.preview,'phedex-box-yellow');
            } else {
              Dom.addClass(dom.preview,'phedex-box-red');
            }
            return;
          }
          dom.preview_label.innerHTML = 'Preview:';
          dom.preview_text.innerHTML = "<div id='phedex-preview-summary'></div><div id='phedex-preview-table'></div>";
          dom.preview_summary = Dom.get('phedex-preview-summary');
          dom.preview_table   = Dom.get('phedex-preview-table');
          datasets = datasets[0].dataset;
          for (i in datasets) {
            Nested = [];
            ds = datasets[i];
            Row = { dataset:ds.name, block:0, time_create:ds.time_create, is_open:ds.is_open };
            Row.uniqueid = unique++;
            nFiles = nBytes = 0;
            for (j in ds.block ) {
              block = ds.block[j];
              nFiles += parseInt(block.files);
              nBytes += parseInt(block.bytes);
              Nested.push({ block:block.name, b_time_create:block.time_create, b_is_open:block.is_open, b_files:block.files, b_bytes:block.bytes });
            }
            if ( Nested.length > 0 ) {
              tBlocks += Nested.length;
              tFiles  += nFiles;
              tBytes  += nBytes;
              Row.blocks = Nested.length;
              Row.nesteddata = Nested;
              Row.bytes = nBytes;
            }
            Table.push(Row);
          }
          tDatasets = datasets.length;
          dom.preview_summary.innerHTML = tDatasets+' datasets, '+tBlocks+' blocks, '+tFiles+' files, '+PxUf.bytes(tBytes);
          dom.preview_summary.innerHTML = +tDatasets +' dataset' + ( tDatasets>1 ? 's' : '' ) + ', ' +
                                          tBlocks +   ' block' +   ( tBlocks>1   ? 's' : '' ) + ', ' +
                                          tFiles + ' files, ' + PxUf.bytes(tBytes);
          i = t.columns.length;
          if (!t.map) { t.map = {}; }
          while (i > 0) { //This is for main columns
            i--;
            cDef = t.columns[i];
            if (typeof cDef != 'object') { cDef = { key:cDef }; t.columns[i] = cDef; }
            if (!cDef.label)      { cDef.label      = cDef.key; }
            if (!cDef.resizeable) { cDef.resizeable = true; }
            if (!cDef.sortable)   { cDef.sortable   = true; }
            if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          }
          if ( !t.nestedColumns ) {
            t.nestedColumns = [];
          }
          i = t.nestedColumns.length;
          while (i > 0) { //This is for inner nested columns
            i--;
            cDef = t.nestedColumns[i];
            if (typeof cDef != 'object') { cDef = { key:cDef }; t.nestedColumns[i] = cDef; }
            if (!cDef.label)      { cDef.label      = cDef.key; }
            if (!cDef.resizeable) { cDef.resizeable = true; }
            if (!cDef.sortable)   { cDef.sortable   = true; }
            if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          }
          if ( this.dataSource ) {
            delete this.dataSource;
            delete this.nestedDataSource;
          }
          this.dataSource = new YAHOO.util.DataSource(Table);
          this.nestedDataSource = new YAHOO.util.DataSource();
          if ( this.dataTable  ) {
            this.dataTable.destroy();
            delete this.dataTable;
          }
          if ( t.columns[0].key == '__NESTED__' ) { t.columns.shift(); } // NestedDataTable has side-effects on its arguments, need to undo that before re-creating the table
          this.dataTable = new YAHOO.widget.NestedDataTable(this.dom.preview_table, t.columns, this.dataSource, t.nestedColumns, this.nestedDataSource,
                          {
                              initialLoad: false,
                              generateNestedRequest: this.processNestedrequest
                          });
          var oCallback = {
            success: this.dataTable.onDataReturnInitializeTable,
            failure: this.dataTable.onDataReturnInitializeTable,
            scope: this.dataTable
          };

          this.dataTable.subscribe('nestedDestroyEvent',function(obj) {
            return function(ev) {
              delete obj.nestedtables[ev.dt.getId()];
            }
          }(this));

          this.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
            var dt = oArgs.dt,
                oCallback = {
                success: dt.onDataReturnInitializeTable,
                failure: dt.onDataReturnInitializeTable,
                scope: dt
            }, ctxId;
            this.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
            if ( !dt ) { return; }
            // This is to maintain the list of created nested tables that would be used in context menu
            if ( !o.nestedtables ) {
              o.nestedtables = {};
            }
            o.nestedtables[dt.getId()] = dt;
          }, this);
          this.dataSource.sendRequest('', oCallback);

          var column = this.dataTable.getColumn('dataset');
          this.dataTable.sortColumn(column, YAHOO.widget.DataTable.CLASS_ASC);
          break;
        }
        case 'previewrequestdata': {
debugger;
          break;
        }
      }
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      NUtil = PHEDEX.Nextgen.Util;
  return {
    meta: {
      table: { columns:[ { key:'block',        label:'Block', className:'align-left' },
                         { key:'b_files',      label:'Files', className:'align-right', parser:'number' },
                         { key:'b_bytes',      label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' },
                         { key:'b_replicas',   label:'# Replicas', parser:'number'}],
          nestedColumns:[{ key:'node',         label:'Node', className:'align-left' },
                         { key:'r_complete',   label:'Complete' },
                         { key:'r_custodial',  label:'Custodial' },
                         { key:'r_group',      label:'Group' },
                         { key:'r_files',      label:'Files', className:'align-right', parser:'number' },
                         { key:'r_bytes',      label:'Bytes', className:'align-right', parser:'number', formatter:'customBytes' }]
              },
      synchronise: {
        Preview: { data_items:false, destination:false },
        Accept:  { data_items:false, destination:false }
      }
    },
    initSub: function() {
      var d = this.dom,
          mb = d.main_block,
          hd = d.hd,
          form, elList, el, label, control, i, ctl;
      hd.innerHTML = 'Delete data';

      form = document.createElement('form');
      form.id   = 'subscribe_data';
      form.name = 'subscribe_data';
      mb.appendChild(form);

// Data Items
      this.data_items = {
        text:'enter one or more block/data-set names, separated by white-space or commas.',
        help_text:"<p><strong>/Primary/Processed/Tier</strong> or<br/><strong>/Primary/Processed/Tier#Block</strong></p><p>Use an asterisk (*) as wildcard, and either whitespace or a comma as a separator between multiple entries</p><p>Even if wildcards are used, the dataset path separators '/' are required. E.g. to subscribe to all 'Higgs' datasets you would have to write '/Higgs/*/*', not '/Higgs*'.</p>",
        label:'Data Items'
      };
      this.makeControlTextbox(this.data_items,form);

// Preview
      this.makeControlOutputbox({label:'Preview'},form);

// DBS
      this.dbs = {
        instanceDefault:{
          prod:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          test:'LoadTest',
          debug:'LoadTest',
          tbedi:'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet',
          tbedii:'test',
          tony:'test'
        },
        label:'DBS'
      };
      this.makeControlDBS(this.dbs,form);

// Destination
      this.destination = {
        label:'Destination'
      };
      this.makeControlDestination(this.destination,form);

// Remove Subscriptions?
      this.remove_subscription = {
        values:['yes','no'],
        _default:0,
        label:'Remove Subscriptions'
      };
      this.makeControlRadio(this.remove_subscription,form);

// Email
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
// TODO take away phedex-invisible if we really need this, or suppress this field entirely if we don't
      el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label'>Email</div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div id='email_selector'>" +
                            "<span id='email_value'></span>" +
                            "<span>&nbsp;</span>" +
                            "<a id='change_email' class='phedex-nextgen-form-link phedex-invisible' href='#'>change</a>" +
                          "</div>" +
                          "<div><input type='text' id='email_input' name='email' class='phedex-nextgen-text phedex-invisible' value='' /></div>" +
                        "</div>" +
                      "</div>";

      form.appendChild(el);
      this.email = { _default:'(unknown)' };
      var email = this.email, onEmailInput, kl;
      email.selector = Dom.get('email_selector');
      email.input    = Dom.get('email_input');
      email.value    = Dom.get('email_value');
      Dom.setStyle(email.input,'width','170px')
      Dom.setStyle(email.input,'color','black');
      Dom.setStyle(email.value,'color','grey');

      onChangeEmailClick = function(obj) {
        return function() {
          Dom.addClass(   email.selector,'phedex-invisible');
          Dom.removeClass(email.input,   'phedex-invisible');
          email.input.focus();
        };
      }(this);
      Event.on(Dom.get('change_email'),'click',onChangeEmailClick);

      onEmailInput = function(obj) {
        return function() {
          Dom.removeClass(email.selector,'phedex-invisible');
          Dom.addClass(   email.input,   'phedex-invisible');
          email.value.innerHTML = email.input.value;
        }
      }(this);
      email.input.onblur = onEmailInput;

      kl = new YAHOO.util.KeyListener(email.input,
                               { keys:13 }, // TODO '13' is the enter key, seems there's no mnemonic for this?
                               { fn:function(obj){ return function() { onEmailInput(); } }(this),
                               scope:this, correctScope:true } );
      kl.enable();

      var gotAuthData = function(obj) {
        return function(data,context,response) {
          var address = '';
          try { address = data.auth[0].email; }
          catch(ex) {
// AUTH failed, don't know what address to put in!
            email.value.innerHTML = email._default;
          }
          if ( !address ) { return; }
          email.value.innerHTML = email.input.value = email._default = address;
        };
      }(this);
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:gotAuthData })

// Comments
      this.comments = {
        text:'enter any additional comments here',
        label:'Comments'
      };
      this.makeControlTextbox(this.comments,form);

// Results
      this.makeControlOutputbox({label:'Results', className:'phedex-invisible'},form);

      this.requestCallback = function(obj) {
        return function(data,context,response) {
          var dom = obj.dom, str, msg, rid;
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML = '';
          Dom.removeClass(dom.results,'phedex-box-yellow');
          if ( data.message ) { // indicative of failure
            str = "Error when making call '" + context.api + "':";
            msg = data.message.replace(str,'').trim();
            obj.onAcceptFail(msg);
            obj.Accept.set('disabled',false);
          }
          if ( rid = data.request_created[0].id ) {
            obj.onResetSubmit();
            var uri = location.href;
            uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
            uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
            uri = uri.replace(/\/[^/]*$/g,'/');

            dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
              "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
            Dom.addClass(dom.results,'phedex-box-green');
            Dom.removeClass(dom.results,'phedex-invisible');
          }
        }
      }(this);
      this.onAcceptFail = function(obj) {
        return function(text) {
          var dom = obj.dom;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-red');
          dom.results_label.innerHTML = 'Error:';
          if ( dom.results_text.innerHTML ) {
            dom.results_text.innerHTML += '<br />';
          }
          dom.results_text.innerHTML += text;
          obj.formFail = true;
        }
      }(this);
      this.onAcceptSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              user_group = obj.user_group,
              email      = obj.email,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i, panel;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;
          this.set('disabled',true);

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// DBS - done directly in the xml

// Destination
          panel = obj.destination.Panel;
          elList = panel.elList;
          args.node = [];
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.node.push(panel.nodes[i]); }
          }
          if ( args.node.length == 0 ) {
            obj.onAcceptFail('No Destination nodes specified');
          }

// Remove Subscriptions
          tmp = obj.remove_subscription;
          elList = tmp.elList;
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.rm_subscriptions = ( tmp.values[el.value] == 'yes' ? 'y' : 'n' ); }
          }

// Email TODO check field?
//           args.email = email.value.innerHTML;

// Comments
          if ( dom.comments.value && dom.comments.value != obj.comments.text ) { args.comments = dom.comments.value; }

          args.no_mail = 'n';

// Hardwired, for best practise!
          args.level = 'block'; // TODO is this right for deletions?

// If there were errors, I can give up now!
          if ( obj.formFail ) {
            this.set('disabled',true);
            return;
          }

// Now build the XML!
          xml = '<data version="2.0"><dbs name="' + dbs.value.innerHTML + '">';
          for ( dataset in data.datasets ) {
            xml += '<dataset name="'+dataset+'" is-open="dummy">';
            for ( block in data.datasets[dataset] ) {
              xml += '<block name="'+block+'" is-open="dummy" />';
            }
            xml += '</dataset>';
          }
          xml += '</dbs></data>';
          args.data = xml;
          Dom.removeClass(dom.results,'phedex-invisible');
          Dom.addClass(dom.results,'phedex-box-yellow');
          dom.results_label.innerHTML = 'Status:';
          dom.results_text.innerHTML  = NUtil.stdLoading('Submitting request (please wait)');
          PHEDEX.Datasvc.Call({
                                api:'delete',
                                method:'post',
                                args:args,
                                callback:function(data,context,response) { obj.requestCallback(data,context,response); }
                              });
        }
      }(this);

      this.onPreviewSubmit = function(obj) {
        return function(id,action) {
          var dbs = obj.dbs,
              dom = obj.dom,
              time_start = obj.time_start,
              data_items = dom.data_items,
              menu, menu_items,
              data={}, args={}, tmp, value, type, block, dataset, xml,
              elList, el, i, panel;

// Prepare the form for output messages, disable the button to prevent multiple clicks
          Dom.removeClass(obj.dom.results,'phedex-box-red');
          Dom.addClass(obj.dom.results,'phedex-invisible');
          dom.results_label.innerHTML = '';
          dom.results_text.innerHTML  = '';
          obj.formFail = false;

// Subscription level is hardwired for now.

// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort

          if ( !data_items.value || data_items.value == obj.data_items.text ) {
            obj.onAcceptFail('No Data-Items specified');
          }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
          if ( data_items.value != obj.data_items.text ) {
            tmp = data_items.value.split(/ |\n|,/);
            data = {blocks:{}, datasets:{} };
            for (i in tmp) {
              block = tmp[i];
              if ( block != '' ) {
                if ( block.match(/(\/[^/]*\/[^/]*\/[^/#]*)(#.*)?$/ ) ) {
                  dataset = RegExp.$1;
                  if ( dataset == block ) { data.datasets[dataset] = 1; }
                  else                    { data.blocks[block] = 1; }
                } else {
                  obj.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
                }
              }
            }
          }
// 3. Blocks which are contained within explicit datasets are suppressed
          for (block in data.blocks) {
            block.match(/^([^#]*)#/);
            dataset = RegExp.$1;
            if ( data.datasets[dataset] ) {
              delete data.blocks[block];
            }
          }
// 4. Blocks are grouped into their corresponding datasets
          for (block in data.blocks) {
            block.match(/([^#]*)#/);
            dataset = RegExp.$1;
            if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
            data.datasets[dataset][block] = 1;
          }
// 5. the block-list is now redundant, clean it up!
          delete data.blocks;

// Destination
          panel = obj.destination.Panel;
          elList = panel.elList;
          args.node = [];
          for (i in elList) {
            el = elList[i];
            if ( el.checked ) { args.node.push(panel.nodes[i]); }
          }
          if ( args.node.length == 0 ) {
            obj.onAcceptFail('No Target nodes specified');
          }

// No 'time start' for deletions, set create_since to zero
          args.create_since = 0;

// If there were errors, I can give up now!
          if ( obj.formFail ) { return; }

// Now build the args!
          if ( data.datasets ) {
            for ( dataset in data.datasets ) {
              blocks = data.datasets[dataset];
              if ( typeof(blocks) == 'number' ) {
                if ( !args.dataset ) { args.dataset = []; }
                args.dataset.push(dataset);
              } else {
                for ( block in blocks ) {
                  if ( !args.block ) { args.block = []; }
                  args.block.push(block);
                }
              }
            }
          }
          Dom.removeClass(dom.preview,'phedex-invisible');
          Dom.addClass(dom.preview,'phedex-box-yellow');
          dom.preview_label.innerHTML = 'Status:';
          dom.preview_text.innerHTML  = NUtil.stdLoading('Calculating request (please wait)');
          args.level = 'dataset';
          args.show_dataset = 'y'; // build more hierarchical utput
          PHEDEX.Datasvc.Call({
                                api:'blockreplicas',
                                args:args,
                                callback:function(data,context,response) { obj.previewCallback(data,context,response); }
                              });
        }
      }(this);
    },
    previewCallback: function(data,context,response) {
      var rid, api=context.api, Table=[], Row, Nested, unique=0, ds, block, tDatasets=0, tBlocks=0, tReplicas=0, tFiles=0, tBytes=0;
      switch (api) {
        case 'blockreplicas': {
debugger;
          var dom=this.dom, datasets=data.dataset, dataset, blocks, block, i, j, n, replicas, replica,
              t=this.meta.table, cDef;
          Dom.removeClass(dom.preview,'phedex-box-yellow');
          if ( !datasets ) {
            dom.preview_text.innerHTML = 'Error retrieving information from the data-service';
            Dom.addClass(dom.preview,'phedex-box-red');
            return;
          }
          tDatasets = datasets.length;
          if ( tDatasets == 0 ) {
            dom.preview_text.innerHTML = 'No data found matching your selection';
            Dom.addClass(dom.preview,'phedex-box-red');
            return;
          }
          Dom.removeClass(dom.preview,'phedex-box-red');
          dom.preview_label.innerHTML = 'Preview:';
          dom.preview_text.innerHTML = "<div id='phedex-preview-summary'></div><div id='phedex-preview-table'></div>";
          dom.preview_summary = Dom.get('phedex-preview-summary');
          dom.preview_table   = Dom.get('phedex-preview-table');
          for (h in datasets) {
            dataset = datasets[h];
            blocks = dataset.block;
            tBlocks += blocks.length;

            for (i in blocks) {
              Nested = [];
              block = blocks[i];
              replicas = block.replica;
              Row = { block:block.name, b_files:block.files, b_bytes:block.bytes, b_replicas:replicas.length };
              Row.uniqueid = unique++;

              if ( replicas.length > 0 ) {
                for (j in replicas ) {
                  replica = replicas[j];
                  tReplicas++;
                  tFiles += parseInt(replica.files);
                  tBytes += parseInt(replica.bytes);
                  Nested.push({ node:replica.node, r_complete:replica.complete, r_custodial:replica.custodial, r_group:replica.group, r_files:replica.files, r_bytes:replica.bytes });
                }
              }

              if ( Nested.length > 0 ) { Row.nesteddata = Nested; }
              Table.push(Row);
            }
          }
          dom.preview_summary.innerHTML = +tDatasets +' dataset' + ( tDatasets>1 ? 's' : '' ) + ', ' +
                                          tBlocks +   ' block' +   ( tBlocks>1   ? 's' : '' ) + ', ' +
                                          tReplicas + ' replicas, for a total of ' + tFiles + ' files, ' + PxUf.bytes(tBytes);
          i = t.columns.length;
          if (!t.map) { t.map = {}; }
          while (i > 0) { //This is for main columns
            i--;
            cDef = t.columns[i];
            if (typeof cDef != 'object') { cDef = { key:cDef }; t.columns[i] = cDef; }
            if (!cDef.label)      { cDef.label      = cDef.key; }
            if (!cDef.resizeable) { cDef.resizeable = true; }
            if (!cDef.sortable)   { cDef.sortable   = true; }
            if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          }
          if ( !t.nestedColumns ) {
            t.nestedColumns = [];
          }
          i = t.nestedColumns.length;
          while (i > 0) { //This is for inner nested columns
            i--;
            cDef = t.nestedColumns[i];
            if (typeof cDef != 'object') { cDef = { key:cDef }; t.nestedColumns[i] = cDef; }
            if (!cDef.label)      { cDef.label      = cDef.key; }
            if (!cDef.resizeable) { cDef.resizeable = true; }
            if (!cDef.sortable)   { cDef.sortable   = true; }
            if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
          }
          if ( this.dataSource ) {
            delete this.dataSource;
            delete this.nestedDataSource;
          }
          this.dataSource = new YAHOO.util.DataSource(Table);
          this.nestedDataSource = new YAHOO.util.DataSource();
          if ( this.dataTable  ) {
            this.dataTable.destroy();
            delete this.dataTable;
          }
          if ( t.columns[0].key == '__NESTED__' ) { t.columns.shift(); } // NestedDataTable has side-effects on its arguments, need to undo that before re-creating the table
          this.dataTable = new YAHOO.widget.NestedDataTable(this.dom.preview_table, t.columns, this.dataSource, t.nestedColumns, this.nestedDataSource,
                          {
                              initialLoad: false,
                              generateNestedRequest: this.processNestedrequest
                          });
          var oCallback = {
            success: this.dataTable.onDataReturnInitializeTable,
            failure: this.dataTable.onDataReturnInitializeTable,
            scope: this.dataTable
          };

          this.dataTable.subscribe('nestedDestroyEvent',function(obj) {
            return function(ev) {
              delete obj.nestedtables[ev.dt.getId()];
            }
          }(this));

          this.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
            var dt = oArgs.dt,
                oCallback = {
                success: dt.onDataReturnInitializeTable,
                failure: dt.onDataReturnInitializeTable,
                scope: dt
            }, ctxId;
            this.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
            if ( !dt ) { return; }
            // This is to maintain the list of created nested tables that would be used in context menu
            if ( !o.nestedtables ) {
              o.nestedtables = {};
            }
            o.nestedtables[dt.getId()] = dt;
          }, this);
          this.dataSource.sendRequest('', oCallback);

          var column = this.dataTable.getColumn('dataset');
          this.dataTable.sortColumn(column, YAHOO.widget.DataTable.CLASS_ASC);
          break;
        }
      }
debugger;
    }
//     previewCallback: function(data,context,response) {
//       var rid, api=context.api, Table=[], Row, Nested, unique=0, ds, block, tBlocks=0, tReplicas=0, tFiles=0, tBytes=0;
//       switch (api) {
//         case 'blockreplicas': {
//           var dom=this.dom, blocks=data.block, block, i, j, n, replicas, replica,
//               t=this.meta.table, cDef;
//           Dom.removeClass(dom.preview,'phedex-box-yellow');
//           if ( !blocks ) {
//             dom.preview_text.innerHTML = 'Error retrieving information from the data-service';
//             Dom.addClass(dom.preview,'phedex-box-red');
//             return;
//           }
//           tBlocks = blocks.length;
//           if ( tBlocks == 0 ) {
//             dom.preview_text.innerHTML = 'No data found matching your selection';
//             Dom.addClass(dom.preview,'phedex-box-red');
//             return;
//           }
//           Dom.removeClass(dom.preview,'phedex-box-red');
//           dom.preview_label.innerHTML = 'Preview:';
//           dom.preview_text.innerHTML = "<div id='phedex-preview-summary'></div><div id='phedex-preview-table'></div>";
//           dom.preview_summary = Dom.get('phedex-preview-summary');
//           dom.preview_table   = Dom.get('phedex-preview-table');
//           for (i in blocks) {
//             Nested = [];
//             block = blocks[i];
//             replicas = block.replica;
//             Row = { block:block.name, b_files:block.files, b_bytes:block.bytes, b_replicas:replicas.length };
//             Row.uniqueid = unique++;
// 
//             if ( replicas.length > 0 ) {
//               for (j in replicas ) {
//                 replica = replicas[j];
//                 tReplicas++;
//                 tFiles += parseInt(replica.files);
//                 tBytes += parseInt(replica.bytes);
//                 Nested.push({ node:replica.node, r_complete:replica.complete, r_custodial:replica.custodial, r_group:replica.group, r_files:replica.files, r_bytes:replica.bytes });
//               }
//             }
// 
//             if ( Nested.length > 0 ) { Row.nesteddata = Nested; }
//             Table.push(Row);
//           }
//           dom.preview_summary.innerHTML = +tBlocks+' blocks, '+tReplicas+' replicas, for a total of '+tFiles+' files, '+PxUf.bytes(tBytes);
//           i = t.columns.length;
//           if (!t.map) { t.map = {}; }
//           while (i > 0) { //This is for main columns
//             i--;
//             cDef = t.columns[i];
//             if (typeof cDef != 'object') { cDef = { key:cDef }; t.columns[i] = cDef; }
//             if (!cDef.label)      { cDef.label      = cDef.key; }
//             if (!cDef.resizeable) { cDef.resizeable = true; }
//             if (!cDef.sortable)   { cDef.sortable   = true; }
//             if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
//           }
//           if ( !t.nestedColumns ) {
//             t.nestedColumns = [];
//           }
//           i = t.nestedColumns.length;
//           while (i > 0) { //This is for inner nested columns
//             i--;
//             cDef = t.nestedColumns[i];
//             if (typeof cDef != 'object') { cDef = { key:cDef }; t.nestedColumns[i] = cDef; }
//             if (!cDef.label)      { cDef.label      = cDef.key; }
//             if (!cDef.resizeable) { cDef.resizeable = true; }
//             if (!cDef.sortable)   { cDef.sortable   = true; }
//             if (!t.map[cDef.key]) { t.map[cDef.key] = cDef.key.toLowerCase(); }
//           }
//           if ( this.dataSource ) {
//             delete this.dataSource;
//             delete this.nestedDataSource;
//           }
//           this.dataSource = new YAHOO.util.DataSource(Table);
//           this.nestedDataSource = new YAHOO.util.DataSource();
//           if ( this.dataTable  ) {
//             this.dataTable.destroy();
//             delete this.dataTable;
//           }
//           if ( t.columns[0].key == '__NESTED__' ) { t.columns.shift(); } // NestedDataTable has side-effects on its arguments, need to undo that before re-creating the table
//           this.dataTable = new YAHOO.widget.NestedDataTable(this.dom.preview_table, t.columns, this.dataSource, t.nestedColumns, this.nestedDataSource,
//                           {
//                               initialLoad: false,
//                               generateNestedRequest: this.processNestedrequest
//                           });
//           var oCallback = {
//             success: this.dataTable.onDataReturnInitializeTable,
//             failure: this.dataTable.onDataReturnInitializeTable,
//             scope: this.dataTable
//           };
// 
//           this.dataTable.subscribe('nestedDestroyEvent',function(obj) {
//             return function(ev) {
//               delete obj.nestedtables[ev.dt.getId()];
//             }
//           }(this));
// 
//           this.dataTable.subscribe('nestedCreateEvent', function (oArgs, o) {
//             var dt = oArgs.dt,
//                 oCallback = {
//                 success: dt.onDataReturnInitializeTable,
//                 failure: dt.onDataReturnInitializeTable,
//                 scope: dt
//             }, ctxId;
//             this.nestedDataSource.sendRequest('', oCallback); //This is to update the datatable on UI
//             if ( !dt ) { return; }
//             // This is to maintain the list of created nested tables that would be used in context menu
//             if ( !o.nestedtables ) {
//               o.nestedtables = {};
//             }
//             o.nestedtables[dt.getId()] = dt;
//           }, this);
//           this.dataSource.sendRequest('', oCallback);
// 
//           var column = this.dataTable.getColumn('dataset');
//           this.dataTable.sortColumn(column, YAHOO.widget.DataTable.CLASS_ASC);
//           break;
//         }
//       }
//     }
  }
}

log('loaded...','info','nextgen-request-create');
