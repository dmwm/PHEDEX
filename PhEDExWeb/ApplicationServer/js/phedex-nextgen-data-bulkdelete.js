PHEDEX.namespace('Nextgen.Data');
PHEDEX.Nextgen.Data.BulkDelete = function(sandbox) {
  var string = 'nextgen-data-bulkdelete',
      _sbx = sandbox,
      dom, obj,
      NUtil = PHEDEX.Nextgen.Util,
      Icon  = PxU.icon,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Yw = YAHOO.widget,
      Button = Yw.Button;
  Yla(this,new PHEDEX.Module(_sbx,string));
  dom = this.dom;
  obj = this;

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      nodes: {},
      nNodes: 0,
      items: {},
      nItems: 0,
      level: {},
      buttons: {},
      requests: [],
      dbs: PxU.DBSDefaults[PHEDEX.Datasvc.Instance().instance],
      useElement: function(el) {
        var form;
        dom.target = el;
        dom.container  = document.createElement('div'); dom.container.className  = 'phedex-nextgen-container'; dom.container.id = 'doc2';
        dom.hd         = document.createElement('div'); dom.hd.className         = 'phedex-nextgen-hd';        dom.hd.id = 'hd';
        dom.bd         = document.createElement('div'); dom.bd.className         = 'phedex-nextgen-bd';        dom.bd.id = 'bd';
        dom.ft         = document.createElement('div'); dom.ft.className         = 'phedex-nextgen-ft';        dom.ft.id = 'ft';
        dom.main       = document.createElement('div'); dom.main.className       = 'yui-main';
        dom.main_block = document.createElement('div'); dom.main_block.className = 'yui-b phedex-nextgen-main-block';
        dom.form       = document.createElement('div'); dom.form.id              = 'phedex-data-bulkdelete-form';

        dom.bd.appendChild(dom.main);
        dom.main.appendChild(dom.main_block);
        dom.container.appendChild(dom.hd);
        dom.container.appendChild(dom.bd);
        dom.container.appendChild(dom.ft);
        dom.container.appendChild(dom.form);
        el.innerHTML = '';
        el.appendChild(dom.container);
      },
      init: function(params) {
        if ( !params ) { params={}; }
        this.params = params;
        this.useElement(params.el);
        var selfHandler = function(obj) {
          return function(ev,arr) {
            var action=arr[0], node=arr[1], el, anim, n, i, j, requests, uri;
            switch (action) {
              case 'Request': {
                requests=obj.requests;
                requests.push(arr[2]);
                uri=location.href;
                uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/')
                         .replace(/\?.*$/g,'') // shouldn't be necessary, but we'll see...
                         .replace(/\/[^/]*$/g,'/');
                uri += 'Request::View?request=' + requests.sort().join(' ');
                dom.view_all.href=uri;
                Dom.removeClass(dom.view_all,'phedex-invisible');
                break;
              }
              case 'Submit all': {
                obj.SubmitAll();
                break;
              }
              case 'Submit': {
                obj.Submit(node);
                break;
              }
              case 'Preview': {
                obj.Preview(node);
                break;
              }
              case 'Remove this node': {
                el = dom[node].el;
                el.style.height = el.offsetHeight+'px';
                el.style.overflowY = 'hidden'; // hide child elements as the element shrinks
                anim = new YAHOO.util.Anim(el, { height: { to:0 } }, 1);
                anim.onComplete.subscribe( function() { el.parentNode.removeChild(el); } );
                anim.animate();
                n = obj.nodes[node];
                for (i in n ) {
                  j = n[i];
                  obj.items[j]--;
                  if ( ! obj.items[j] ) {
                    delete obj.items[j];
                    obj.nItems--;
                  }
                }
                delete obj.nodes[node];
                obj.nNodes--;
                obj.setSummary('OK',obj.nNodes+' nodes and '+obj.nItems+' data-items remaining');
                if ( ! obj.nNodes ) {
                  obj.buttons.submit_all.set('disabled',true);
                }
                break;
              }
              case 'gotPreviewId': {
                obj.previewId = arr[1];
                break;
              }
              default: {
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,selfHandler);
        this.initSub();
      },
      initSub: function() {
        var data=PhedexPage.postdata, form=dom.form, dn, d, i, nodes=[], node, level, items=this.items, itemLevel=this.level, item, el,
            button, buttons=this.buttons, bn, label, idRes, idPre, tmp, callback, uri,
            hr = "<hr width='95%'/>",
            clear_both = "<div style='clear:both; margin-bottom:5px'></div>";
        this.comments = {
          text:'enter any additional comments here',
          label:'Comments'
        };
        this.makeControlTextbox(this.comments,form);
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-bulkdelete-results' style='padding:5px'></div>" +
                       "<div class='phedex-nextgen-buttons-right' id='buttons-right' style='padding:5px 0 0'>" +
                          "<a id='phedex-bulkdelete-view-all' class='phedex-invisible' href='#'>view all requests</a>" +
                        "</div>" +
                        clear_both +
                       "<div style='border-bottom:1px solid silver'></div>";
        form.appendChild(el);
        dom.results  = Dom.get('phedex-bulkdelete-results');
        dom.view_all = Dom.get('phedex-bulkdelete-view-all');

        label='Submit all', id='submit_all';
        buttons[id] = button = new YAHOO.widget.Button({
                              type: 'submit',
                              label: label,
                              id: id,
                              name: id,
                              value: id,
                              container: 'buttons-right' });
        button.on('click', this.callback(label) );

        for ( i in data ) {
          d = data[i].split(':');
          node = d[0];
          level = d[1];
          item = d[2];

//        bookkeeping
          if ( !this.nodes[node] ) {
            this.nodes[node] = [];
            nodes.push(node);
            this.nNodes++;
          }
          this.nodes[node].push(item);

          if ( !items[item] ) {
            items[item] = 0;
            this.nItems++;
          }
          items[item]++;

          itemLevel[item] = level;
        }
        if ( !nodes.length ) {
          this.buttons.submit_all.set('disabled',true);
          uri = location.href;
          uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/')
                   .replace(/\?.*$/g,'') // shouldn't be necessary, but we'll see...
                   .replace(/\/[^/]*$/g,'/');
          this.setSummary('OK',"Nothing to delete! Go visit the <a href='"+uri+"Data::Subscriptions'>subscriptions</a> page, tick a few boxes, and select \"Delete this data\"...");
          return;
        }
        this.setSummary('OK','Found '+this.nNodes+' nodes and '+this.nItems+' data-items in total');
        nodes = nodes.sort();
        for (i in nodes) {
          node = nodes[i];

          buttons[node] = {};
          bn = buttons[node];
          dom[node] = {};
          dn = dom[node];

          dn.el = el = document.createElement('div');
          el.id = 'phedex-bulkdelete-'+node;
          el.style.borderBottom = '1px solid silver';
          idRes = 'phedex-nextgen-results-'+node;
          idPre = 'phedex-nextgen-preview-'+node;
          el.innerHTML = "<div class='phedex-nextgen-label'>Node:</div>" +
                         "<div class='phedex-nextgen-control'>"+node+"</div>" +
                         "<div class='phedex-nextgen-label'>Items:</div>" +
                         "<div class='phedex-nextgen-control'>"+this.nodes[node].sort().join('<br/>')+"</div>" +
// TW should do this with makeControlOutputbox if I harmonised it w.r.t. phedex-nextgen-request-create
                         "<div id='"+idRes+"' style='padding:5px' class='phedex-invisible'>" +
                           "<div class='phedex-nextgen-form-element'>" +
                             "<div class='phedex-nextgen-label' id='"+idRes+"-label'></div>" +
                             "<div class='phedex-nextgen-control'>" +
                               "<div id='"+idRes+"-text'></div>" +
                             "</div>" +
                           "</div>" +
                         "</div>"+

// TW likewise, for the preview table
                         "<div id='"+idPre+"' style='padding:5px' class='phedex-invisible'>" +
                           "<div class='phedex-nextgen-form-element'>" +
                             "<div class='phedex-nextgen-label' id='"+idPre+"-label'></div>" +
                             "<div class='phedex-nextgen-control'>" +
                               "<div id='"+idPre+"-text'></div>" +
                             "</div>" +
                           "</div>" +
                         "</div>" +

// ...back to normal adding of elements...
                         "<div id='buttons-"+node+"'>" +
                           "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-left'   id='buttons-left-"  +node+"'></div>" +
                           "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-centre' id='buttons-centre-"+node+"'></div>" +
                           "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-right'  id='buttons-right-" +node+"'></div>" +
                         "</div>" +
                         clear_both;
          form.appendChild(el);
          dn.buttons       = Dom.get('buttons-'+node);
          dn.results       = Dom.get(idRes);
          dn.results_label = Dom.get(idRes+'-label');
          dn.results_text  = Dom.get(idRes+'-text');
          dn.preview       = Dom.get(idPre);
          dn.preview_text  = Dom.get(idPre+'-text');
          dn.preview_text.innerHTML = "<div id='"+idPre+"-summary'></div><div id='"+idPre+"-table'></div>";
          dn.preview_summary = Dom.get(idPre+'-summary');
          dn.preview_table   = Dom.get(idPre+'-table');

          label='Remove this node', id='button-remove-'+node;
          bn.remove = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-left-'+node });
          button.on('click', this.callback(label,node) );

          label='Preview', id='button-preview-'+node;
          bn.preview = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right-'+node });
          button.on('click', this.callback(label,node) );

          label='Submit', id='button-submit-'+node;
          bn.submit = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right-'+node });
          button.on('click', this.callback(label,node) );
        }
      },
      onAcceptFail: function(text,node) {
        var dn=dom;
        if ( node ) { dn = dom[node]; }
        text = PxU.parseDataserviceError(text);
        Dom.addClass(dn.preview,'phedex-invisible');
        Dom.removeClass(dn.results,'phedex-invisible');
        Dom.addClass(dn.results,'phedex-box-red');
        dn.results_label.innerHTML = 'Error:';
        if ( dn.results_text.innerHTML ) {
          dn.results_text.innerHTML += '<br />';
        }
        dn.results_text.innerHTML += Icon.Error+text;
      },
      Preview: function(node) {
        var items, data, tmp, args={}, dataset, block, i, xml, dn=dom[node], level, args,
            dataset, blocks, block,
            preview_summary = dn.preview_summary,
            preview_table   = dn.preview_table,
            preview  = dn.preview,
            buttons  = this.buttons[node];

        Dom.addClass(dn.results,'phedex-invisible');
        preview_summary.innerHTML = '';
        preview_table.innerHTML  = '';
        Dom.addClass(preview,'phedex-box-yellow');
        preview_summary.innerHTML = PxU.stdLoading('Calculating request (please wait)');
        Dom.removeClass(preview,'phedex-invisible');
        buttons.preview.set('disabled',true);
        if ( this.previous_preview_node ) {
          this.buttons[this.previous_preview_node].preview.set('disabled',false);
        }
        this.previous_preview_node = node;

        _sbx.notify('SetModuleConfig','previewrequestdata', {
            parent:preview_table,
            noDecorators:true,
            noExtraDecorators:true,
            noHeader:true
          });
        delete this.previewId;
        _sbx.notify('CreateModule','previewrequestdata',{notify:{who:this.id, what:'gotPreviewId'}});

// Now build the args!
        args = { node:[node], dbs:this.dbs, type:'delete' };
        data = this.parseDatasets(node);
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
        args.level = 'block';
        PHEDEX.Datasvc.Call({
                              api:'previewrequestdata',
                              args:args,
                              callback:function(data,context,response) { obj.previewCallback(data,context,response,node); }
                            });

      },
      previewCallback: function(data,context,response,node) {
        var api=context.api, dn=dom[node], preview  = dn.preview;

        Dom.removeClass(preview,'phedex-box-yellow');
        Dom.removeClass(preview,'phedex-box-red');
        if ( response ) {
          this.setSummary('error',"Error retrieving preview data",node);
          return;
        }
        if ( !this.previewId ) {
          _sbx.delay(25,'module','*','lookingForA',{moduleClass:'previewrequestdata', callerId:this.id, callback:'gotPreviewId'});
          _sbx.delay(50, this.id, 'previewCallback',data,context,response,node);
          return;
        }
        _sbx.notify(this.previewId,'doGotData',data,context,response);
        _sbx.notify(this.previewId,'doPostGotData');
        dn.preview_summary.innerHTML = '';
        Dom.removeClass(dn.preview,'phedex-invisible');
      },
      parseDatasets: function(node) {
        var tmp = this.nodes[node],
            data = {blocks:{}, datasets:{} },
            i, block, dataset;

// 1. Each substring must match /X/Y/Z, even if wildcards are used
        for (i in tmp) {
          block = tmp[i];
          if ( block.match(/(\/[^/]+\/[^/]+\/[^/#]+)(#.*)?$/ ) ) {
            dataset = RegExp.$1;
            if ( dataset == block ) { data.datasets[dataset] = 1; }
            else                    { data.blocks[block] = 1; }
          } else {
            this.onAcceptFail('item "'+block+'" does not match /Primary/Processed/Tier(#/block)',node);
          }
        }

// 2. Blocks which are contained within explicit datasets are suppressed
        for (block in data.blocks) {
          block.match(/^([^#]*)#/);
          dataset = RegExp.$1;
          if ( data.datasets[dataset] ) {
            delete data.blocks[block];
          }
        }
// 3. Blocks are grouped into their corresponding datasets
        for (block in data.blocks) {
          block.match(/([^#]*)#/);
          dataset = RegExp.$1;
          if ( ! data.datasets[dataset] ) { data.datasets[dataset] = {}; }
          data.datasets[dataset][block] = 1;
        }
// 4. the block-list is now redundant, clean it up!
        delete data.blocks;

        return data;
      },
      SubmitAll: function() {
        var node, nodes=this.nodes;
        for (node in nodes) {
          this.Submit(node);
        }
      },
      Submit: function(node) {
        var items, data, tmp, args={}, dataset, block, i, xml, dn=dom[node], level,
            results_label = dn.results_label,
            results_text  = dn.results_text,
            results  = dn.results,
            comments = dom.comments,
            buttons  = this.buttons[node];

// Prepare the form for output results, disable the button to prevent multiple clicks
        Dom.addClass(dn.preview,'phedex-invisible');
        Dom.removeClass(results,'phedex-box-red');
        results_label.innerHTML = '';
        results_text.innerHTML  = '';
        buttons.submit.set('disabled',true);
        buttons.remove.set('disabled',true);
        buttons.preview.set('disabled',true);
        if ( this.previous_preview_node == node ) {
          delete this.previous_preview_node; // to prevent it being re-enabled!
        }

// Data Items:
        data = this.parseDatasets(node);

// Now build the XML!
        xml = '<data version="2.0"><dbs name="' + this.dbs + '">';
        for ( dataset in data.datasets ) {
          xml += '<dataset name="'+dataset+'" is-open="dummy">';
          for ( block in data.datasets[dataset] ) {
            xml += '<block name="'+block+'" is-open="dummy" />';
          }
          xml += '</dataset>';
        }
        xml += '</dbs></data>';
        args.data = xml;

        args.level = 'block';
        args.node = [ node ];

// Comments
        if ( comments.value && comments.value != this.comments.text ) { args.comments = comments.value; }

        Dom.removeClass(results,'phedex-invisible');
        Dom.addClass(results,'phedex-box-yellow');
        results_label.innerHTML = 'Status:';
        results_text.innerHTML  = PxU.stdLoading('Submitting request (please wait)');
        PHEDEX.Datasvc.Call({
                              api:'delete',
                              method:'post',
                              args:args,
                              callback:function(data,context,response) { obj.requestCallback(data,context,response,node); }
                            });
      },
      requestCallback: function(data,context,response,node) {
        var dn=this.dom[node], str, msg, rid, i, uri;
        dn.results_label.innerHTML = '';
        dn.results_text.innerHTML = '';
        Dom.removeClass(dn.results,'phedex-box-yellow');
        if ( response ) { // indicative of failure
          msg = response.responseText;
          Dom.addClass(dn.buttons,'phedex-invisible');
          this.onAcceptFail(msg,node);
          return;
        }
        if ( !(rid = data.request_created[0].id) ) {
          Dom.addClass(dn.buttons,'phedex-invisible');
          this.onAcceptFail('failed to create request. Please try again later',node);
          return;
        }
        uri = location.href;
        uri = uri.replace(/http(s):\/\/[^\/]+\//g,'/')
                 .replace(/\?.*$/g,'') // shouldn't be necessary, but we'll see...
                 .replace(/\/[^/]*$/g,'/');

        dn.results_text.innerHTML = 'Request-id = ' +rid+ ' created successfully!&nbsp;' +
          "(<a href='" + uri+'Request::View?request='+rid+"'>view this request</a>)";
        Dom.addClass(dn.results,'phedex-box-green');
        Dom.removeClass(dn.results,'phedex-invisible');
        dn.preview_summary.innerHTML = '';
        dn.preview_table.innerHTML   = '';
        Dom.addClass(dn.preview,'phedex-invisible');
        Dom.addClass(dn.buttons,'phedex-invisible');
        _sbx.notify(this.id,'Request',node,rid);
        delete this.nodes[node];
        for (i in this.nodes) { return; }
        this.buttons.submit_all.set('disabled',true);
      },
      setSummary: function(status,text) {
        var el = dom.results,
            map = {OK:'phedex-box-green', error:'phedex-box-red', warn:'phedex-box-yellow'}, i;
        el.innerHTML = text;
        for ( i in map ) {
          Dom.removeClass(el,map[i]);
        }
        if ( map[status] ) {
          Dom.addClass(el,map[status]);
        }
        if ( status == 'error' ) {
          Dom.addClass(el,'phedex-invisible');
        }
      },
      callback: function() {
        var args = Array.apply(null,arguments);
        args.unshift(obj.id);
        return function() { PxS.notify.apply(PxS,args); }
      },
      makeControlTextbox: function(config,parent) {
        var label = config.label,
            labelLower = label.toLowerCase(),
            labelCss   = labelLower.replace(/ /,'-'),
            labelForm  = labelLower.replace(/ /,'_'),
            filterTag  = config.filterTag || labelForm,
            d = this.dom, el, resize, helpStr='',
            textareaClassName = config.textareaClassName || 'phedex-nextgen-textarea';
        labelForm = labelForm.replace(/-/,'_');
        el = document.createElement('div');
        if ( config.help_text ) {
          helpStr = " <a class='phedex-nextgen-help' id='phedex-help-"+labelCss+"' href='#'>[?]</a>";
        }
        el.innerHTML = "<div>" +
                  "<div class='phedex-nextgen-label' id='phedex-label-"+labelCss+"'>"+label+helpStr+":</div>" +
                  "<div class='phedex-nextgen-filter'>" +
                    "<div id='phedex-nextgen-filter-resize-"+labelCss+"'>" +
                      "<textarea id='"+labelForm+"' name='"+labelForm+"' class='"+textareaClassName+"'>" + (config.initial_text || config.text) + "</textarea>" +
                    "</div>" +
                  "</div>" +
                "</div>";
        parent.appendChild(el);
        if ( config.help_text ) {
          config.help_align = Dom.get('phedex-label-'+labelCss);
          Dom.get('phedex-help-'+labelCss).setAttribute('onclick', "PxS.notify('"+this.id+"','Help','"+labelForm+"');");
        }

        resize = config.resize || {maxWidth:745, minWidth:100};
        NUtil.makeResizable('phedex-nextgen-filter-resize-'+labelCss,labelLower,resize);

        d[labelForm] = Dom.get(labelForm);
        d[labelForm].onfocus = function() {
          if ( this.value == config.text ) {
            this.value = '';
            Dom.setStyle(this,'color','black');
          }
        }
        d[labelForm].onblur=function() {
          if ( this.value == '' ) {
            this.value = config.text;
            Dom.setStyle(this,'color',null);
            PxS.notify(obj.id,'unsetValueFor',filterTag);
          } else {
            PxS.notify(obj.id,'setValueFor',filterTag,this.value);
          }
        }
        if ( config.initial_text ) {
          Dom.setStyle(d[labelForm],'color','black');
          PxS.notify(this.id,'setValueFor',filterTag,config.initial_text);
        }
      },
    }
  }
  Yla(this,_construct(this),true);
  PxU.protectMe(this);
  return this;
}

log('loaded...','info','nextgen-data-subscriptions');
