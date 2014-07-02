PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.Create = function(sandbox) {
  var string = 'nextgen-request-create',
      _sbx  = sandbox, dom,
      Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      NUtil = PHEDEX.Nextgen.Util,
      Icon  = PHEDEX.Util.icon;
  Yla(this,new PHEDEX.Module(_sbx,string));
  dom = this.dom;

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      options: { },
      type:null,
      useElement: function(el) {
        dom.target = el;
        dom.container  = document.createElement('div'); dom.container.className  = 'phedex-nextgen-container'; dom.container.id = 'doc2';
        dom.hd         = document.createElement('div'); dom.hd.className         = 'phedex-nextgen-hd phedex-silver-border'; dom.hd.id = 'hd';
        dom.bd         = document.createElement('div'); dom.bd.className         = 'phedex-nextgen-bd phedex-silver-border'; dom.bd.id = 'bd';
        dom.ft         = document.createElement('div'); dom.ft.className         = 'phedex-nextgen-ft phedex-silver-border'; dom.ft.id = 'ft';
        dom.main       = document.createElement('div'); dom.main.className       = 'yui-main';
        dom.main_block = document.createElement('div'); dom.main_block.className = 'yui-b phedex-nextgen-main-block';

        dom.bd.appendChild(dom.main);
        dom.main.appendChild(dom.main_block);
        dom.container.appendChild(dom.hd);
        dom.container.appendChild(dom.bd);
        dom.container.appendChild(dom.ft);
        el.innerHTML = '';
        el.appendChild(dom.container);

        dom.floating_help = document.createElement('div'); dom.floating_help.className = 'phedex-nextgen-floating-help phedex-invisible';
        document.body.appendChild(dom.floating_help);
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
        var el;
        if ( params.type == 'xfer' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Xfer(_sbx,params), true);
        } else if ( params.type == 'delete' ) {
          Yla(this,new PHEDEX.Nextgen.Request.Delete(_sbx,params), true);
        } else if ( params.type == 'fileinvalidate' ) {
          Yla(this,new PHEDEX.Nextgen.Request.FileInvalidate(_sbx,params), true);
        } else if ( !this.type ) {
          var l = location, href = location.href;
          var e = document.createElement('div');
          var e_html = '<h1>Choose a request type</h1>' +
                     '<ul>' +
                       "<li><a href='" + location.pathname + "?type=xfer'>Transfer Request</a></li>" +
                       "<li><a href='" + location.pathname + "?type=delete'>Deletion Request</a></li>";
          if ( PhedexPage.TestingMode ) {
            e_html += "<li><a href='" + location.pathname + "?type=fileinvalidate'>File Invalidation Request</a></li>";
          }
          e_html += "<li>If you want to transfer private data, you need to <a  href='https://twiki.cern.ch/twiki/bin/view/CMSPublic/WorkBookGroupActivities'>use the StoreResults service</a> to promote your data to the global DBS, then come back here</li>" +
                      '</ul>';
          e.innerHTML = e_html;
          params.el.innerHTML='';
          params.el.appendChild(e);
          return;
        } else {
          throw new Error('type is defined but unknown: '+this.type);
        }
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0],
                arr1 = arr.slice();
            if ( obj[action] && typeof(obj[action]) == 'function' ) {
              arr1.shift();
              obj[action].apply(obj,arr1);
              return;
            }
          }
        }(this);
        _sbx.listen(this.id, selfHandler);
        this.initSub();
        this.initButtons();
        _sbx.notify('SetModuleConfig','previewrequestdata', { parent:this.dom.preview_table,  autoDestruct:false, noDecorators:true, noExtraDecorators:true, noHeader:true });
        _sbx.notify('CreateModule','previewrequestdata',{notify:{who:this.id, what:'gotPreviewId'}});
      },
      initButtons: function() {
        var ft=this.dom.ft, Reset,
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
        this.Reset = new YAHOO.widget.Button({
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
        this.Preview.on('click', this.onPreviewSubmit,this,true);
        label='Accept', id='button'+label;
        this.Accept = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right' });
        this.Accept.set('disabled',true);
        this.Accept.on('click', this.onAcceptSubmit,this,true);
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
              _sbx.notify(this.id,'synchronise',i,'allSet');
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
              _sbx.notify(this.id,'synchronise',i,'notAllSet');
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
        labelForm = labelForm.replace(/-/,'_');
        config._default = this.params.dbs || config.instanceDefault[instance.instance] || '(not defined)';

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
            config.MenuButton = new YAHOO.widget.Button({ type: 'menu',
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
            d = this.dom, el, className='', helpStr='';
        labelForm = labelForm.replace(/-/,'_');
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelLower+"' href='#'>[?]</a>";
        }
        if ( config.className ) { className = "class='"+config.className+"'"; }
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-nextgen-"+labelLower+"'"+className+"'>" +
                         "<div class='phedex-nextgen-form-element'>" +
                           "<div class='phedex-nextgen-label' id='phedex-nextgen-"+labelLower+"-label'>"+label+helpStr+"</div>" +
                           "<div class='phedex-nextgen-control'>" +
                              "<div id='phedex-nextgen-"+labelLower+"-text'></div>" +
                            "</div>" +
                          "</div>" +
                        "</div>";
        parent.appendChild(el);
        d[labelLower] = Dom.get('phedex-nextgen-'+labelLower);
        d[labelLower+'_label'] = Dom.get('phedex-nextgen-'+labelLower+'-label');
        d[labelLower+'_text']  = Dom.get('phedex-nextgen-'+labelLower+'-text');
        if ( config.help_text ) {
          config.help_align = d[labelLower+'_label'];
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }
      },
      makeControlDestination: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d=this.dom, el, resize, className, default_nodes=this.params.node;
        labelForm = labelForm.replace(/-/,'_');
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
        if ( typeof(default_nodes) == 'string' ) { default_nodes = [ default_nodes ]; }
        config.Panel = NUtil.NodePanel( this, Dom.get(labelLower+'-panel'), default_nodes );

        d.destination = Dom.get(labelLower+'-container');
        this.onPanelClick = function(obj) {
          return function(event, matchedEl, container) { /* None of these arguments are used! They are declared only for completion... */
            var panel = config.Panel,
                elList = panel.elList,
                i, elList;
            config.node = [];
            for (i in elList) {
              el = elList[i];
              if ( el.checked ) { config.node.push(panel.nodes[i]); }
            }
            if ( config.node.length == 0 ) {
              _sbx.notify(obj.id,'unsetValueFor',labelForm);
            } else {
              _sbx.notify(obj.id,'setValueFor',labelForm);
            }
            return config.node.length;
          }
        }(this);
        YAHOO.util.Event.delegate(d.destination, 'click', this.onPanelClick, 'input');
        if ( default_nodes ) { _sbx.notify(obj.id,'setValueFor',labelForm); }
      },
      makeControlTextbox: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, resize, helpStr='';
        labelForm = labelForm.replace(/-/,'_');
        el = document.createElement('div');
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelCss+"' href='#'>[?]</a>";
        }
        el.innerHTML = "<div class='phedex-nextgen-form-element'>" +
                          "<div class='phedex-nextgen-label' id='phedex-label-"+labelCss+"'>"+label+helpStr+"</div>" +
                          "<div id='"+labelCss+"-wrapper' class='phedex-nextgen-control'>" +
                            "<div><textarea id='"+labelForm+"' name='"+labelForm+"' class='phedex-nextgen-textarea'>" + (config.initial_text || config.text) + "</textarea></div>" +
                          "</div>" +
                        "</div>";
        parent.appendChild(el);
        if ( config.help_text ) {
          config.help_align = Dom.get('phedex-label-'+labelCss);
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }

        resize = config.resize || {maxWidth:745, minWidth:100};
        NUtil.makeResizable(labelCss+'-wrapper',labelLower,resize);

        d[labelForm] = Dom.get(labelForm);
        d[labelForm].onfocus = function() {
          if ( this.value == config.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
            _sbx.notify(obj.id,'setValueFor',labelForm);
          }
        }
        d[labelForm].onblur=function() {
          if ( this.value == '' ) {
            this.value = config.text;
            Dom.setStyle(this,'color',null);
            _sbx.notify(obj.id,'unsetValueFor',labelForm);
          } else {
            _sbx.notify(obj.id,'setValueFor',labelForm);
          }
        }
        if ( config.initial_text ) {
          Dom.setStyle(d[labelForm],'color','black');
          _sbx.notify(this.id,'setValueFor',labelForm);
        }
      },
      makeControlRadio: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            d = this.dom, el, i, radioStr='', helpStr='';
        labelForm = labelForm.replace(/-/,'_');
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
      makeControlPreview: function(parent) {
        this.preview = {
          label:'Preview',
          className:'phedex-invisible',
          help_text:"<p>This panel shows a preview of the data that matches your request.</p><p>The global summary lists the amount of data found, and flags any errors or warnings with a red or yellow bullet.</p><p>Warnings are given for things like data which is already subscribed to the nodes you are requesting. This is perfectly legitimate if you are overriding a previous request, to change the start-time or user-group, for example.</p><p>The data-table shows information about the known replicas. For each node where the data is supposed to reside, the replica is complete unless indicated otherwise ('empty' or 'incomplete'), and the data is subscribed to that node unless indicated otherwise.</p><p>Nodes that form part of your request are colour-coded yellow or green to indicate that there is or is not a pre-existing subscription for the same data.</p><p>Click on the '+' icon in the left-hand column of a row a summary of information about the subscriptions to each node.</p><p>Note that a replica may be shown as complete in this table, but if more data is injected into the block/dataset later on, it may not become incomplete.</p><p>For more complete information about the data at a node, see the Data::Replicas or Data::Subscriptions pages</p>"
        }

        var d = this.dom;
        this.makeControlOutputbox(this.preview,parent);
        d.preview_text.innerHTML = "<div id='phedex-preview-summary'></div><div id='phedex-preview-table'></div>";
        d.preview_summary = Dom.get('phedex-preview-summary');
        d.preview_table   = Dom.get('phedex-preview-table');
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
      },
      gotAuthData: function(data,context,response) {
        var auth, i, roles, role, address='', canWildcard=false, canTimeStart=false, time_start=obj.time_start, email=obj.email, d=obj.dom;
        try {
          auth = data.auth[0];
          _sbx.notify(obj.id,'setValueFor','auth');
          address = auth.email;
          email.value.innerHTML = email.input.value = email._default = address;
// TW hardwired for now. Inspect the roles if I need to allow TimeStart or WildCard only for certain roles.
          canTimeStart = canWildCard = true;
//           roles = auth.role;
//           for (i in roles) {
//             role = roles[i];
//             if ( role.group == 'phedex' ) {
//               if ( role.name == 'Admin' ) {
//                 canWildcard = true;
//                 canTimeStart = true;
//               }
//             }
//           }
        }
        catch(ex) {
//        AUTH failed, don't know what address to put in!
          email.value.innerHTML = email._default;
          if ( obj.type == 'xfer' ) {
            time_start.help_text = '<p>This field is disabled because there was an error checking your access rights. If you believe you have the necessary rights, please reload the page and try again.</p><p>If the problem persists, contact the PhEDEx developers</p>';
          }
          d.results_text.innerHTML = '<p>An error occurred while checking your access-rights.<p/><p>Some features may not work correctly, or may be disabled. Try reloading the page to see if that fixes the problem, and contact the PhEDEx developers if the error persists</p>';            Dom.addClass(obj.dom.results,'phedex-box-red');
          Dom.removeClass(d.results,'phedex-invisible');
        }
        if ( canTimeStart && obj.type == 'xfer' ) {
          time_start.input.disabled = false;
          Dom.addClass(time_start.label,'phedex-nextgen-label');
          Dom.removeClass(time_start.label,'phedex-nextgen-label-disabled');
          time_start.help_text = time_start.help_text_enabled;
        }
      },
      previewCallback: function(data,context,response) {
        var dom=this.dom, api=context.api, msg;

        this.data = data;
        this.context = context;

        Dom.removeClass(dom.preview,'phedex-box-yellow');
        Dom.removeClass(dom.preview,'phedex-box-red');
        if ( response ) {
          msg = 'Error retrieving preview data';
          if ( response.statusText == 'transaction aborted' && context.call_time > context.timeout ) {
            msg = "There was a timeout fetching the preview<br/>You can try again, or you can still make the request if you think it is correct";
          }
          this.setSummary('error',msg);
          return;
        }
        if ( !this.previewId ) {
          _sbx.delay(25,'module','*','lookingForA',{moduleClass:'previewrequestdata', callerId:this.id, callback:'gotPreviewId'});
          _sbx.delay(50, this.id, 'previewCallback',data,context,response);
          return;
        }
        _sbx.notify(this.previewId,'doGotData',data,context,response);
        _sbx.notify(this.previewId,'doPostGotData');
        dom.preview_summary.innerHTML = '';
        Dom.removeClass(dom.preview,'phedex-invisible');
      },
      suppressExcessNodes: function(excessNodes) {
        var elList, el, i, j, nodes, node;
        nodes = excessNodes.split(' ');
        elList = this.destination.Panel.elList;
        for (i in nodes) {
          node = nodes[i];
          for (j in elList) {
            el = elList[j];
            if ( el.name == node ) {
              el.checked = false;
              break;
            }
          }
        }
        if ( this.onPanelClick() ) {
          _sbx.notify(this.id,'onPreviewSubmit'); // still some nodes left, so re-generate the preview
        } else {
          Dom.addClass(dom.preview,'phedex-invisible'); // no nodes left, hide the preview
        }
      },
      setDBS: function(dbs) {
        this.dbs.value.innerHTML = dbs;
        _sbx.notify(this.id,'onPreviewSubmit');
      },
      requestCallback: function(data,context,response) {
        var dom = this.dom, str, msg, rid;
        dom.results_label.innerHTML = '';
        dom.results_text.innerHTML = '';
        Dom.removeClass(dom.results,'phedex-box-yellow');
        if ( PhedexPage.TestingMode ) {
          alert("Datasvc call returned:\n"+YAHOO.lang.dump(data));
        }
        if ( response ) { // indicative of failure
          msg = response.responseText;
          this.onAcceptFail(msg);
          this.Accept.set('disabled',false);
          return;
        }
        if ( rid = data.request_created[0].id ) {
          this.onResetSubmit();
          var uri = location.href;
          uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/');
          uri = uri.replace(/\?.*$/g,'');      // shouldn't be necessary, but we'll see...
          uri = uri.replace(/\/[^/]*$/g,'/');

          dom.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
            "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
          Dom.addClass(dom.results,'phedex-box-green');
          Dom.removeClass(dom.results,'phedex-invisible');
          d.preview_summary.innerHTML = '';
          d.preview_table.innerHTML = '';
          Dom.addClass(dom.preview,'phedex-invisible');
        }
      },
      onAcceptFail: function(text) {
        text = PxU.parseDataserviceError(text);
        var dom = this.dom;
        Dom.addClass(dom.preview,'phedex-invisible');
        Dom.removeClass(dom.results,'phedex-invisible');
        Dom.addClass(dom.results,'phedex-box-red');
        dom.results_label.innerHTML = 'Error:';
        if ( dom.results_text.innerHTML ) {
          dom.results_text.innerHTML += '<br />';
        }
        dom.results_text.innerHTML += Icon.Error+text;
        this.formFail = true;
      },
      checkRequestParameters: function() {
        var dbs = this.dbs,
            dom = this.dom,
            user_group = this.user_group,
            email      = this.email,
            time_start = this.time_start,
            data_items = dom.data_items,
            comments   = dom.comments,
            site_custodial       = this.site_custodial,
            subscription_type    = this.subscription_type,
            re_evaluate_request  = this.re_evaluate_request,
            transfer_type        = this.transfer_type,
            priority             = this.priority,
            remove_subscriptions = this.remove_subscriptions,
            menu, menu_items,
            data={}, args={}, tmp, value, block, dataset,
            elList, el, i, panel, api;
       
        this.formFail = false;
// Data Items: Several layers of checks:
// 1. If the string is empty, or matches the inline help, abort
        if ( !data_items.value || data_items.value == this.data_items.text ) {
          this.onAcceptFail('No Data-Items specified');
        }
// 2. Each non-empty substring must match /X/Y/Z, even if wildcards are used
        if ( data_items.value != this.data_items.text ) {
          tmp = data_items.value.split(/ |\n|,/);
          data = {blocks:{}, datasets:{} };
          for (i in tmp) {
            block = tmp[i];
            if ( block != '' ) {
              if ( block.match(/(\/[^/]+\/[^/]+\/[^/#]+)(#.*)?$/ ) ) {
                dataset = RegExp.$1;
                if ( dataset == block ) { data.datasets[dataset] = 1; }
                else                    { data.blocks[block] = 1; }
              } else {
                this.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)');
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

// 6. Stash the structure to be able to return it
        args.data = data;

// Destination
        panel = this.destination.Panel;
        elList = panel.elList;
        args.node = [];
        for (i in elList) {
          el = elList[i];
          if ( el.checked ) { args.node.push(panel.nodes[i]); }
        }

// DBS - done directly in the xml
// Site Custodial
        if ( site_custodial ) { args.custodial = this.getRadioValues(site_custodial); }
// Subscription Type
        if ( subscription_type ) { args['static'] = this.getRadioValues(subscription_type); }
// Re-evaluate
        if ( re_evaluate_request ) { args['re-evaluate'] = this.getRadioValues(re_evaluate_request); }
        if ( args['re-evaluate'] == 'y' && args['static'] == 'y' ) {
          this.onAcceptFail('A static, re-evaluated request makes no sense!');
        }
// Transfer Type
        if ( transfer_type ) { args.move = this.getRadioValues(transfer_type); }
// Priority
        if ( priority ) { args.priority = this.getRadioValues(priority); }
// User Group
        if ( user_group ) { args.group = user_group.value; }
// Remove Subscriptions
        if ( remove_subscriptions ) { args.rm_subscriptions = this.getRadioValues(remove_subscriptions); }

// Time Start
        if ( time_start ) {
          this.getTimeStart();
          if ( time_start.time_start ) {
            args.time_start = time_start.time_start;
          }
        }

// Email TODO check if we need this field?
//         args.email = email.value.innerHTML;

// Comments
        if ( comments.value && comments.value != this.comments.text ) { args.comments = comments.value; }

// Never subscribe automatically from this form
        if ( this.type == 'xfer' ) {
          args.request_only = 'y';
// Do not suppress the email
          args.no_mail = 'n';
        }

// Hardwired, for best practise!
        args.level = 'block';

        return args;
      },
      onAcceptSubmit: function(id,action) {
        var dbs = this.dbs,
            email      = this.email,
            time_start = this.time_start,
            data_items = dom.data_items,
            menu, menu_items,
            data={}, args={}, tmp, value, block, dataset, xml,
            elList, el, i, panel, api;

// Prepare the form for output messages, disable the button to prevent multiple clicks
        Dom.removeClass(dom.results,'phedex-box-red');
        dom.results_label.innerHTML = '';
        dom.results_text.innerHTML  = '';
        this.Accept.set('disabled',true);

// Subscription level is hardwired for now.
        args = this.checkRequestParameters();     
        if ( args.node.length == 0 ) {
          this.onAcceptFail('No Destination nodes specified');
        }
        if ( this.user_group && !args.group ) {
          this.onAcceptFail('No User-Group specified');
        }
// If there were errors, I can give up now!
        if ( this.formFail ) {
          this.set('disabled',true);
          return;
        }
// Now build the XML!
        data = args.data;
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
        dom.results_text.innerHTML  = PxU.stdLoading('Submitting request (please wait)');
        if ( this.type == 'xfer'   ) { api = 'subscribe'; }
        if ( this.type == 'delete' ) { api = 'delete'; }
        if ( this.type == 'fileinvalidate' ) { alert ('Performing fileinvalidation request with:\n '+YAHOO.lang.dump(args)); api = 'bounce'; }
        PHEDEX.Datasvc.Call({
                              api:api,
                              method:'post',
                              args:args,
                              callback:function(data,context,response) { obj.requestCallback(data,context,response); }
                            });
      },

      gotPreviewId: function(arg) {
        this.previewId = arg.moduleId;
        var previewHandler = function(obj) {
          return function(ev,arr) {
            var action = arr[0], arr1;
            switch (action) {
              case 'setSummary': {
                arr1 = arr.slice();
                arr1.shift();
                obj.setSummary.apply(obj,arr1);
                break;
              }
              case 'suppressExcessNodes': {
                obj.suppressExcessNodes(arr[1]);
                break;
              }
              case 'setDBS': {
                obj.setDBS(arr[1]);
                break;
              }
              case 'destroy': {
                delete this.previewId;
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.previewId,previewHandler);
      },

      setSummary: function(status,text) {
        var map = {error:'phedex-box-red', warn:'phedex-box-yellow'}, i;
        dom.preview_summary.innerHTML = text;
        for ( i in map ) {
          Dom.removeClass(dom.preview,map[i]);
        }
        if ( map[status] ) {
          Dom.addClass(dom.preview,map[status]);
        }
        if ( status == 'error' ) {
          Dom.addClass(dom.preview_table,'phedex-invisible');
        }
      },
      onPreviewSubmit: function(id,action) {
        var dbs = this.dbs,
            time_start = this.time_start,
            data_items = dom.data_items,
            menu, menu_items,
            data={}, args={}, tmp, value, block, blocks, dataset, xml,
            panel, elList, el, i;

        if ( !this.previewId ) {
          _sbx.notify('module','*','lookingForA',{moduleClass:'previewrequestdata', callerId:this.id, callback:'gotPreviewId'});
        }

// Prepare the form for output messages, disable the button to prevent multiple clicks
        Dom.removeClass(dom.results,'phedex-box-red');
        Dom.addClass(dom.results,'phedex-invisible');
        Dom.removeClass(dom.preview,'phedex-invisible');
        Dom.removeClass(dom.preview_table,'phedex-invisible');
        dom.preview_summary.innerHTML = dom.results_text.innerHTML  = '';

// Now build the args!
        args = this.checkRequestParameters();
        if ( this.formFail ) { return; }
        data = args.data;
        args.data = [];
        if ( data.datasets ) {
          for ( dataset in data.datasets ) {
            blocks = data.datasets[dataset];
            if ( typeof(blocks) == 'number' ) {
              args.data.push(dataset);
            } else {
              for ( block in blocks ) {
                args.data.push(block);
              }
            }
          }
        }
        Dom.removeClass(dom.preview,'phedex-invisible');
        Dom.addClass(dom.preview,'phedex-box-yellow');
        dom.preview_summary.innerHTML = PxU.stdLoading('Calculating request (please wait)');
        args.level = 'block';

        args.type = this.type;
        args.dbs = dbs.value.innerHTML;
        PHEDEX.Datasvc.Call({
                              api:'previewrequestdata',
                              args:args,
                              callback:function(data,context,response) { obj.previewCallback(data,context,response); },
                              timeout:120*1000
                            });
      },

      onResetSubmit: function(id,action) {
        var dbs = this.dbs,
            user_group  = this.user_group,
            email       = this.email,
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
        elList = this.destination.Panel.elList;
        for (i in elList) {
          elList[i].checked = false;
        }

// Remove Subscription
        if ( tmp = this.remove_subscriptions ) {
          elList = tmp.elList;
          _default = tmp._default;
          for (i in elList) {
            el = elList[i];
            if ( el.value == _default ) { el.checked = true; }
            else                        { el.checked = false; }
          }
        }

// Site Custodial
        if ( tmp = this.site_custodial ) {
          elList = tmp.elList;
          _default = tmp._default;
          for (i in elList) {
            el = elList[i];
            if ( el.value == _default ) { el.checked = true; }
            else                        { el.checked = false; }
          }
        }

// Subscription Type
        if ( tmp = this.subscription_type ) {
          elList = tmp.elList;
          _default = tmp._default;
          for (i in elList) {
            el = elList[i];
            if ( el.value == _default ) { el.checked = true; }
            else                        { el.checked = false; }
          }
        }

// Transfer Type
        if ( tmp = this.transfer_type ) {
          elList = tmp.elList;
          _default = tmp._default;
          for (i in elList) {
            el = elList[i];
            if ( el.value == _default ) { el.checked = true; }
            else                        { el.checked = false; }
          }
        }

// Priority
        if ( tmp = this.priority ) {
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

        this.Accept.set('disabled',false);
        dom.preview_summary.innerHTML = '';
        dom.preview_table.innerHTML = '';
        Dom.addClass(dom.preview,'phedex-invisible');
        Dom.addClass(dom.results,'phedex-invisible');
      }

    }
  };
  Yla(this,_construct(this),true);
  return this;
};

PHEDEX.Nextgen.Request.Xfer = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
  return {
    type: 'xfer',
    initSub: function() {
      var d   = this.dom,
          mb = d.main_block,
          hd = d.hd,
          params = this.params,
          form, el;
      hd.innerHTML = 'Subscribe data';
      this.meta.synchronise = {
        Preview: { data_items:false },
        Accept:  { data_items:false, destination:false, user_group:false, auth:false }
      };

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
      if ( params.data ) {
        if ( typeof(params.data) == 'string' ) { this.data_items.initial_text = params.data; }
        else                                   { this.data_items.initial_text = params.data.join("\n"); }
      }
      this.makeControlTextbox(this.data_items,form);

// DBS
      this.dbs = {
        instanceDefault:PxU.DBSDefaults,
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
      if ( this.params.custodial == 'y' ) { this.site_custodial._default = 0; }
      this.makeControlRadio(this.site_custodial,form);

// Subscription type
      this.subscription_type = {
        values:['growing','static'],
        _default:0,
        help_text:'<p>A <strong>growing</strong> subscription downloads blocks/files added to open datasets/blocks as they become available, until the dataset/block is closed.</p><p>Also, wildcard patterns will be re-evaluated to match new datasets/blocks which become available.</p><p>A <strong>static</strong> subscription will expand datasets into block subscriptions.</p><p>Wildcard patterns will not be re-evaluated. A static subscription is a snapshot of blocks available now</p>',
        label:'Subscription Type',
        map:{'static':'y', growing:'n'}
      };
// 'subscription_type' is not something we can expect the user to put into a URL. So allow the field-value names instead, asserted
// to be true ('y') or false ('n'). Here we only examine the cases that cause the default to change. All illegal values are ignored
      if ( this.params['static'] == 'y' ) { this.subscription_type._default = 1; }
      if ( this.params.growing   == 'n' ) { this.subscription_type._default = 1; }
      this.makeControlRadio(this.subscription_type,form);

// Re-evaluate
      this.re_evaluate_request = {
        values:['yes','no'],
        _default:1,
        help_text:"<p>A <strong>re-evaluated</strong> request will be re-examined periodically to see if new datasets or blocks match the request. The opposite is a <strong>snapshot</strong> request, which is for data that exists in TMDB at the time of the request. Most requests should be snapshots, so do not alter this option unless you understand it.</p><p>This applies to block and dataset <em>names</em>, not to the files within them. It allows you to subscribe existing or future datasets, and is, in effect, orthogonal to the <strong>subscription type</strong>, which allows you to choose between existing or future blocks within a dataset.</p><p>This is useful for requests with wildcards in them, such as <strong>/*/*/*Higgs*</strong>. New Higgs datasets may appear at any time, so that string may match more datasets tomorrow than it matches today.</p><p>A <strong>snapshot</strong> of that request will match all datasets currently in TMDB, but if a new dataset is injected later with a name that matches that string, it will <em>not</em> be subscribed. A <strong>re-evaluated</strong> request for that same string will also be matched against any new datasets that are created later on, so can add new datasets to this same subscription.</p><p><strong>N.B.</strong> Not all combinations of options make sense, e.g. a <strong>static</strong> request is also a <strong>snapshot</strong>, by definition. A <strong>re-evaluated</strong> request only makes sense for a <strong>growing</strong> request where the requested data includes wildcards in the name, or where some of the data-items do not yet exist.</p>",
        label:'Re-evaluate request',
        map:{yes:'y', no:'n' },
      };
      this.makeControlRadio(this.re_evaluate_request,form);
// TW Hide this control until the data-service supports it's use
      d.re_evaluate_request = Dom.get('phedex-label-re-evaluate-request');
      d.re_evaluate_request.parentNode.className = 'phedex-invisible';

// Transfer type
      this.transfer_type = {
        values:['replica','move'],
        _default:0,
        help_text:'<p>A <strong>replica</strong> replicates data from the source to the destination, creating a new copy of the data.</p><p>A <strong>move</strong> replicates the data then deletes the data at the source. The deletion will be automatic if the source data is unsubscribed; if it is subscribed, the source site will be asked to approve or disapprove the deletion.</p><p>Note that moves are only used for moving data from T2s to T1s</p>',
        label:'Transfer Type',
        map:{move:'y', replica:'n'}
      };
// See subscription_type for the logic behind this
      if ( this.params.move    == 'y' ) { this.transfer_type._default = 1; }
      if ( this.params.replica == 'n' ) { this.transfer_type._default = 1; }
      this.makeControlRadio(this.transfer_type,form);

// Priority
      this.priority = {
        values:['high','normal','low'],
        _default: this.params.priority || 2,
        help_text:'<p>Priority is used to determine which data items get priority when resources are limited.</p><p>Setting high priority does not mean your transfer will happen faster, only that it will be considered first if there is congestion causing a queue of data to build up.</p><p>Use <strong>low</strong> unless you have a good reason not to</p>',
        label:'Priority'
      };
      if ( this.params.priority ) {
        switch (this.params.priority) {
          case 0: case 'high':   { this.priority._default = 0; break; }
          case 1: case 'normal': { this.priority._default = 1; break; }
          case 2: case 'low':    { this.priority._default = 2; break; }
        }
      }
      this.makeControlRadio(this.priority,form);

// User group
      this.user_group = {
        _default:'<em>Choose a group</em>',
        help_text:'<p>The group which is requesting this data. Used for accounting purposes.</p><p>This field is now mandatory, whereas previously it could be left undefined.</p>'
      };
// use 'initial', not '_default', so I can tell this is not the real default
      if ( this.params.group ) { this.user_group.initial = this.params.group; }
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
            _sbx.notify(obj.id,'setValueFor','user_group');
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
          if ( user_group.initial ) {
            user_group.MenuButton.set('label', user_group.initial);
            user_group.value = user_group.initial;
            _sbx.notify(obj.id,'setValueFor','user_group');
          }
       }
      }(this);
      PHEDEX.Datasvc.Call({ api:'groups', callback:makeGroupMenu });

// Time Start
      this.time_start = {
        text:'YYYY-MM-DD [hh:mm:ss]',
        help_text_enabled:'<p>This field is optional. Only data injected into PhEDEx after the specified time will be subscribed with this request. If you do not specify a time, all the data from the dataset(s) requested will be subscribed</p><p><strong>N.B.</strong> This does not affect the transfer scheduling, only the selection of a time-window of data. Data will still be transferred as soon as it can be queued to your destination.</p><p>If you do not specify a time, all the data will be subscribed.</p><p>You can enter a date & time in the box, or select a date from the calendar</p><p>The correct format is <strong>YYYY-MM-DD HH:MM:SS</strong>, or just <strong>YYYY-MM-DD</strong>.</p><p>The time is interpreted as UT, not as your local time.</p>',
        help_text: '<p>This field is disabled because you do not have the right to use it.</p><p>If you believe you should be allowed to use it, please contact data-operations management to request access.</b>'
      };

      var time_start = this.time_start;
      el = document.createElement('div');
      Dom.addClass(el,'phedex-nextgen-form');
      el.innerHTML =  "<div class='phedex-nextgen-form-element'>" +
                        "<div class='phedex-nextgen-label-disabled' id='phedex-label-time-start'>Data injected after <a class='phedex-nextgen-help' id='phedex-help-time-start' href='#'>[?]</a></div>" +
                        "<div class='phedex-nextgen-control'>" +
                          "<div><input type='text' id='time_start' name='time_start' class='phedex-nextgen-text' value='" + time_start.text + "' />" +
                          "<img id='phedex-nextgen-calendar-icon' width='18' height='18' src='" + PxW.WebAppURL + "/images/calendar_icon.gif' style='vertical-align:middle; padding:0 0 0 2px;' />" +
                          "</div>" +
                        "</div>" +
                      "</div>";
      form.appendChild(el);
      time_start.label = time_start.help_align = Dom.get('phedex-label-time-start');
      time_start.input = Dom.get('time_start');
      time_start.input.disabled = true;
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
          YuD.addClass(o.dom.calendar_el,'phedex-invisible');
        }
      }(this);
      var cal = new YAHOO.widget.Calendar( 'cal'+PxU.Sequence(), d.calendar_el); //, {maxdate:now.month+'-'+now.day+'-'+now.year } );
          cal.cfg.setProperty('MDY_YEAR_POSITION', 1);
          cal.cfg.setProperty('MDY_MONTH_POSITION', 2);
          cal.cfg.setProperty('MDY_DAY_POSITION', 3);
          cal.selectEvent.subscribe( mySelectHandler, cal, true);
          cal.render();

      YuE.addListener(d.calendar_icon,'click',function() {
        if ( this.time_start.input.disabled ) { return; }
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
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })

// Comments
      this.comments = {
        text:'enter any additional comments here',
        label:'Comments',
        initial_text:params.comment
      };
      this.makeControlTextbox(this.comments,form);

// Preview
      this.makeControlPreview(form);

// Results
      this.makeControlOutputbox({label:'Results', className:'phedex-invisible'},form);
    }
  }
}

PHEDEX.Nextgen.Request.Delete = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
  return {
    type:'delete',
    initSub: function() {
      var d  = this.dom,
          mb = d.main_block,
          hd = d.hd,
          params = this.params,
          form, elList, el;
      hd.innerHTML = 'Delete data';
      this.meta.synchronise = {
        Preview: { data_items:false, destination:false },
        Accept:  { data_items:false, destination:false, auth:false }
      };

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
      if ( params.data ) {
        if ( typeof(params.data) == 'string' ) { this.data_items.initial_text = params.data; }
        else                                   { this.data_items.initial_text = params.data.join("\n"); }
      }
      this.makeControlTextbox(this.data_items,form);

// DBS
      this.dbs = {
        instanceDefault: PHEDEX.Util.DBSDefaults,
//        instanceDefault:{
//          prod:'https://cmsweb.cern.ch/dbs/prod/global/DBSReader',
//          test:'LoadTest',
//          debug:'LoadTest',
//          tbedi:'https://cmsweb.cern.ch/dbs/prod/global/DBSReader',
//          tbedii:'test',
//          tony:'test'
//        },
        label:'DBS'
      };
      this.makeControlDBS(this.dbs,form);

// Destination
      this.destination = {
        label:'Destination'
      };
      this.makeControlDestination(this.destination,form);

// Remove Subscriptions?
      this.remove_subscriptions = {
        values:['yes','no'],
        _default:0,
        label:'Remove Subscriptions',
        map:{yes:'y', no:'n'},
        help_text:"<p>Whether or not the subscriptions for the data in this request should be removed.</p><p>If subscriptions are removed (default), the data will not be retransferred after the deletion. Use this to permanently delete the data from your site.</p><p>If subscriptions are <em>not</em> removed, the data will automatically be queued for retransfer after the deletion is completed. Use this to re-transfer a fresh copy of the data after files have been lost (e.g. through hardware failure).</p>"
      };
      this.makeControlRadio(this.remove_subscriptions,form);

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
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })

// Comments
      this.comments = {
        text:'enter any additional comments here',
        label:'Comments',
        initial_text:params.comment
      };
      this.makeControlTextbox(this.comments,form);

// Preview
      this.makeControlPreview(form);

// Results
      this.makeControlOutputbox({label:'Results', className:'phedex-invisible'},form);
    }
  }
}


PHEDEX.Nextgen.Request.FileInvalidate = function(_sbx,args) {
  var Dom   = YAHOO.util.Dom,
      Event = YAHOO.util.Event;
  return {
    type:'fileinvalidate',
    initSub: function() {
      var d  = this.dom,
          mb = d.main_block,
          hd = d.hd,
          params = this.params,
          form, elList, el;
      hd.innerHTML = 'Invalidate Files';

      this.meta.synchronise = {
      	Preview: { data_items:false, destination:false},
      	Accept:  { data_items:false, destination:false, auth:false }
      };

      form = document.createElement('form');
      form.id   = 'invalidate_files';
      form.name = 'invalidate_files';
      mb.appendChild(form);

// Data Items
      this.data_items = {
        text:'enter one or more file names, separated by white-space or commas.',
        help_text:"Probably for this test we need blocks and/or data-set",
        label:'Data Items'
      };
      if ( params.data ) {
        if ( typeof(params.data) == 'string' ) { this.data_items.initial_text = params.data; }
        else                                   { this.data_items.initial_text = params.data.join("\n"); }
      }
      this.makeControlTextbox(this.data_items,form);

// DBS
      this.dbs = {
        instanceDefault:{
         prod:'none',
         test:'none',
        debug:'none',
         },
         label:'DBS'
      };
      this.makeControlDBS(this.dbs,form);  

// Destination
      this.destination = {
        label:'Destination'
      };
      this.makeControlDestination(this.destination,form);      
      
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
      PHEDEX.Datasvc.Call({ method:'post', api:'auth', callback:this.gotAuthData })     
      
// Comments
      this.comments = {
        text:'enter any additional comments here',
        label:'Comments',
        initial_text:params.comments
      };
      this.makeControlTextbox(this.comments,form);

// Preview
      this.makeControlPreview(form);
      
// Results
      this.makeControlOutputbox({label:'Results', className:'phedex-invisible'},form);
    }
  }
}

log('loaded...','info','nextgen-request-create');
