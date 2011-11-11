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
      buttons: {},
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
            var action=arr[0], node=arr[1], el, anim, n, i, j;
            switch (action) {
              case 'Submit all': {
                break;
              }
              case 'Submit': {
                break;
              }
              case 'Preview': {
                break;
              }
              case 'Remove this item': {
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
                obj.setSummary('','OK',obj.nNodes+' nodes and '+obj.nItems+' items remaining');
                if ( ! obj.nNodes ) {
                  obj.buttons['button-submit-all'].set('disabled',true);
                }
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
        var data=PhedexPage.postdata, form=dom.form, dn, d, i, nodes=[], node, level, items=this.items, item, el,
            button, label, id, callback, hr="<hr width='95%'/>", clear_both="<div style='clear:both; margin-bottom:5px'></div>";
        this.comments = {
          text:'enter any additional comments here',
          label:'Comments'
        };
        this.makeControlTextbox(this.comments,form);
        el = document.createElement('div');
        el.innerHTML = "<div id='phedex-bulkdelete-messages' style='padding:5px'></div>" +
                       "<div class='phedex-buttons-right' id='buttons-right' style='float:right'></div>" +
                        clear_both +
                       "<div style='border-bottom:1px solid silver'></div>";
        form.appendChild(el);
        dom.messages = Dom.get('phedex-bulkdelete-messages');

        label='Submit all', id='button-submit-all';
        this.buttons[id] = button = new YAHOO.widget.Button({
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
        }
        if ( !nodes.length ) {
          this.buttons['button-submit-all'].set('disabled',true);
          this.setSummary('','OK','Nothing to delete! Go visit the subscriptions page, and tick a few boxes...');
          return;
        }
        this.setSummary('','OK','Found '+this.nNodes+' nodes and '+this.nItems+' items in total');
        nodes = nodes.sort();
        for (i in nodes) {
          node = nodes[i];
          dom[node] = {};
          dn = dom[node];
          node = nodes[i];
          dn.el = el = document.createElement('div');
          el.id = 'phedex-bulkdelete-'+node;
          el.style.borderBottom = '1px solid silver';
          el.innerHTML = "<div class='phedex-nextgen-label'>Node:</div>" +
                         "<div class='phedex-nextgen-control'>"+node+"</div>" +
                         "<div class='phedex-nextgen-label'>Items:</div>" +
                         "<div class='phedex-nextgen-control'>"+this.nodes[node].sort().join(' ')+"</div>" +
                         "<div id='phedex-bulkdelete-messages-"+node+"' style='padding:5px'></div>" +
                         "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-left'   id='buttons-left-"  +node+"'></div>" +
                         "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-centre' id='buttons-centre-"+node+"'></div>" +
                         "<div class='phedex-nextgen-buttons phedex-nextgen-buttons-right'  id='buttons-right-" +node+"'></div>" +
                         clear_both;
          form.appendChild(el);
          dom['messages-'+node] = Dom.get('phedex-bulkdelete-messages-'+node);

          label='Remove this item', id='button-remove-'+node;
          this.buttons[id] = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-left-'+node });
          button.on('click', this.callback(label,node) );

          label='Preview', id='button-preview-'+node;
          this.buttons[id] = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right-'+node });
          button.on('click', this.callback(label,node) );

          label='Submit', id='button-submit-'+node;
          this.buttons[id] = button = new YAHOO.widget.Button({
                                type: 'submit',
                                label: label,
                                id: id,
                                name: id,
                                value: id,
                                container: 'buttons-right-'+node });
          button.on('click', this.callback(label,node) );
        }
      },
      setSummary: function(id,status,text) {
        if ( !id ) { id = 'messages' }
        else       { id = 'messages-'+id; }
        var el = dom[id],
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
