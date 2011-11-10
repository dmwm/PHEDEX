PHEDEX.namespace('Nextgen.Data');
PHEDEX.Nextgen.Data.BulkDelete = function(sandbox) {
  var string = 'nextgen-data-bulkdelete',
      _sbx = sandbox, dom,
      NUtil = PHEDEX.Nextgen.Util,
      Icon  = PxU.icon,
      Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      Yw = YAHOO.widget,
      Button = Yw.Button;
  Yla(this,new PHEDEX.Module(_sbx,string));
  dom = this.dom;

  log('Nextgen: creating a genuine "'+string+'"','info',string);

  _construct = function(obj) {
    return {
      nodes: {},
      useElement: function(el) {
        var form;
        dom.target = el;
        dom.container  = document.createElement('div'); dom.container.className  = 'phedex-nextgen-container'; dom.container.id = 'doc3';
        dom.hd         = document.createElement('div'); dom.hd.className         = 'phedex-nextgen-hd';        dom.hd.id = 'hd';
        dom.bd         = document.createElement('div'); dom.bd.className         = 'phedex-nextgen-bd';        dom.bd.id = 'bd';
        dom.ft         = document.createElement('div'); dom.ft.className         = 'phedex-nextgen-ft';        dom.ft.id = 'ft';
        dom.main       = document.createElement('div'); dom.main.className       = 'yui-main';
        dom.main_block = document.createElement('div'); dom.main_block.className = 'yui-b phedex-nextgen-main-block';
        dom.dataform   = document.createElement('div'); dom.dataform.id          = 'phedex-data-subscriptions-dataform';
        dom.messages   = document.createElement('div'); dom.messages.id          = 'phedex-data-subscriptions-messages';
        dom.messages.style.padding = '5px';

        dom.bd.appendChild(dom.main);
        dom.main.appendChild(dom.main_block);
        dom.container.appendChild(dom.hd);
        dom.container.appendChild(dom.bd);
        dom.container.appendChild(dom.ft);
        dom.container.appendChild(dom.dataform);
        dom.dataform.appendChild(dom.messages);
        el.innerHTML = '';
        el.appendChild(dom.container);
      },
      init: function(params) {
        if ( !params ) { params={}; }
        this.params = params;
        this.useElement(params.el);
        this.initSub();
      },
      initSub: function() {
        var data = PhedexPage.postdata, d, i, node, level, item;
        for ( i in data ) {
          d = data[i].split(':');
          node = d[0];
          level = d[1];
          item = d[2];
          dom.dataform.innerHTML += "<div>Node: "+node+", level:"+level+", item:"+item+"</div>";
          if ( !this.nodes[node] ) { this.nodes[node] = []; }
          this.nodes[node].push(item);
        }
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
