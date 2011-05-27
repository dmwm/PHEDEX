PHEDEX.namespace('Nextgen.Request');
PHEDEX.Nextgen.Request.View = function(sandbox) {
  var string = 'nextgen-request-view',
      _sbx = sandbox,
      Dom = YAHOO.util.Dom,
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
      waitToEnableAccept:2,
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
//        var item      = this[arg],
//            help_text = item.help_text,
//            elSrc     = item.help_align,
//            elContent = this.dom.floating_help,
//            elRegion  = Dom.getRegion(elSrc);
//        if ( this.help_item != arg ) {
//          Dom.removeClass(elContent,'phedex-invisible');
//          Dom.setX(elContent,elRegion.left);
//          Dom.setY(elContent,elRegion.bottom);
//          elContent.innerHTML = help_text;
//          this.help_item = arg;
//        } else {
//          Dom.addClass(elContent,'phedex-invisible');
//          delete this.help_item;
//        }
      },
      init: function(params) {
        var elList, elMain, el, i, id;
        if ( !params ) { params={}; }
        this.params = params;
        elMain = params.el
        elMain.innerHTML='';
        elList = Dom.getElementsByClassName('Request::View::Id','div');
        for ( i in elList ) {
          el = elList[i];
          id = el.id;
          id = id.replace(/^Request::View::Id::/,'');
        }
      },
    }
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','nextgen-request-view');

