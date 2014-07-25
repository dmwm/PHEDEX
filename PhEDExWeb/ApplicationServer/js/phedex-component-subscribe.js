PHEDEX.namespace('Component');
PHEDEX.Component.Subscribe = function(sandbox,args) {
  var _me = 'component-subscribe',
      _sbx = sandbox,
      payload, opts, obj,
      ttIds = [], ttHelp = {},
      groupComplete =
        {
          name:'autocomp-groups',
          source:'component-autocomplete',
          payload:{
            el:      '',
            dataKey: 'group',
            api:     'groups',
            argKey:  'group',
            handler: 'groupSelected'
          }
        },
      dbsComplete =
        {
          name:'autocomp-dbs',
          source:'component-autocomplete',
          payload:{
            el:      '',
            dataKey: 'dbs',
            api:     'dbs',
            argKey:  'dbs',
            handler: 'dbsSelected'
          }
        },
      defaultDBS = 'https://cmsweb.cern.ch/dbs/prod/global/DBSReader',
      _fieldSize = 60;

  if ( !args ) { args={}; }
  opts = {
    text: 'Make a subscription',
    payload:{
      control:{
        parent:'control',
        payload:{
          text:  'Subscribe data',
          title: 'Make a request to transfer data',
          animate:  false,
          disabled: false, //true,
        },
        el:'content'
      },
      buttons: [ 'Apply', 'Reset', 'Dismiss' ],
      buttonMap: {
                   Apply:{title:'Subscribe this data', action:'Validate'}
                 },
      panel: {
        'Datasets/Blocks':{
          fields:{
//             expand:       {type:'checkbox', text:'Expand wildcards before submitting request?',
//                            tip:'Expand wildcards now to find all matching blocks/datasets, or submit the request with wildcards for future re-evaluation', attributes:{checked:true} },
            level:        {type:'radio', fields:['dataset','block'], text:'Subscription level',
                           tip:'A block-level subscription allows you to subscribe individual blocks', _default:'dataset' },
            dataset0: {type:'regex', text:'Enter a dataset name and hit Return', tip:'enter a valid dataset name', negatable:false, value:'', focus:true, size:_fieldSize },
            dataset:  {type:'text', dynamic:true },
          }
        },
        Parameters:{
          fields:{
// need to extract the list of DBS's from somewhere...
            dbs:          {type:'regex', text:'Enter a DBS name and hit Return', negatable:false, value:defaultDBS, title:defaultDBS, autoComplete:dbsComplete, size:_fieldSize },

// node can be multiple
            node:         {type:'regex', text:'Destination node', tip:'enter a valid node name', negatable:false, value:'', size:_fieldSize },
            _static:       {type:'radio', fields:['growing','static'], text:'Subscription type',
                           tip:'A static subscription is a snapshot of the data as it is now. A growing subscription will add new blocks as they become available', _default:'growing' },
            move:         {type:'radio', fields:['replica','move'], text:'Transfer type',
                           tip:'Replicate (copy) or move the data. A "move" will delete the data from the source after it has been transferred', _default:'replica' },
            priority:     {type:'radio', fields:['low','normal','high'],  byName:true, text:'Priority', _default:'low' },

            custodial:    {type:'checkbox', text:'Make custodial request?', tip:'Check this box to make the request custodial', attributes:{checked:false} },
            group:        {type:'regex',    text:'User-group', tip:'The group which is requesting the data. May be left undefined, used only for accounting purposes', negatable:false, autoComplete:groupComplete },

            time_start:   {type:'regex',    text:'Start-time for subscription',    tip:'Valid for datasets only. Format is "YYYY-MM-DD hh:mm:ss", where the hh:mm:ss may be omitted. Only dates in the past are allowed, you may not subscribe data from the future.', negatable:false },
            request_only: {type:'checkbox', text:'Request only, do not subscribe', tip:'Make the request without making a subscription',   attributes:{checked:true} },
            no_mail:      {type:'checkbox', text:'Suppress email notification?',   tip:'Check this box to not send an email',              attributes:{checked:true} },
            comments:     {type:'textarea', text:'Enter your comments here', className:'phedex-inner-textarea' },
          }
        }
      }
    }
  }
  Yla(args, opts);
  Yla(args.payload, opts.payload);
  payload = args.payload;
  obj = payload.obj;
  if ( !obj ) {
    obj = new PHEDEX.Base.Object();
    obj.dom['content'] = document.getElementById('phedex-main');
    obj.dom['control'] = document.getElementById('phedex-navbar');
    payload.obj = obj;
  }

//   this.id = _me+'_'+PxU.Sequence(); // don't set my own ID, inherit the one I get from the panel!
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));
  YuD.addClass(this.dom.panel,'phedex-panel-wide')
  this.dataLookup = false;

  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action=arr[0], args=arr[1], ctl=o.ctl.panel;
      switch (action) {
        case 'add': {
// TODO is_open when blocks are typed in...?
          var c, cart=o.cart, cd=cart.data, type, item, blocks, el, icon;
          type = 'dataset';
          item = args.dataset;
          if ( args.block ) {
// if ( typeof args.ds_is_open == 'undefined'  ) { debugger; }
            if ( !cd[item] ) { cd[item] = { dataset:item, is_open:args.ds_is_open, blocks:{} }; }
            blocks = cd[item].blocks;
            type = 'block';
            item = args.block;
            if ( blocks[item] ) { return; }
            blocks[item] = { block:item, is_open:args.is_open };
// if ( typeof args.is_open == 'undefined' ) { debugger; }
          } else {
            if ( cd[item] ) { return; }
            cd[item] = { dataset:item, is_open:args.ds_is_open, blocks:{} };
          }
          c = o.meta._panel.fields[type];
          el = o.AddFieldsetElement(c,item,item);
          cart.elements[item] = {type:type, el:el};
          cart.elements[item] = {type:type, el:el};
          if ( ctl ) { ctl.Enable(); }
          else       { YuD.removeClass(o.overlay.element,'phedex-invisible'); }
          o.ctl.Apply.set('disabled',false);
          break;
        }
      }
    }
  }(this);
  _sbx.listen('buildRequest',this.cartHandler);

/**
 * construct a PHEDEX.Component.Subscribe object. Used internally only.
 * @method _contruct
 * @private
 */
  _construct = function() {
    return {
      me: _me,
      cart: {},
       init: function() {}, // stub to keep the core happy TODO do I need a phedex-component.js for this, like I have a phedex-module?
      _init: function(args) {
        this.resetCart();
        this.selfHandler = function(o) {
          return function(ev,arr) {
            var action    = arr[0], subAction, value,
                cart=o.cart, elements=cart.elements, _panel=o.meta._panel, _fieldsets=_panel.fieldsets;
            switch (action) {
              case 'Panel': {
                subAction = arr[1];
                value     = arr[2];
                switch (subAction) {
                  case 'Reset': {
                    var i, item, _cart, _fieldset;
                    for (i in elements) {
                      item = elements[i];
                      _fieldset = _fieldsets[item.type].fieldset;
                      _fieldset.removeChild(item.el);
                    }
                    o.resetCart();
                    o.dom.result.innerHTML = '';
                    YuD.addClass(o.dom.resultFieldset,'phedex-invisible');
                    YuD.addClass(o.dom.datasetIcon,   'phedex-invisible');
//                     o.ctl.Apply.set('disabled',true);
                    break;
                  }
                  case 'Apply': {
                    var args={}, i, val, cart=o.cart, iCart, item, dbs, dataset, ds, block, xml, vName, vValue,
                        m=o.meta, _p=m._panel, _f=_p.fields, nodes, result=o.dom.result, dataset0, block0,
                        needInfo=false, _getInfo={dataset:{}, block:{}};
//                     o.ctl.Apply.set('disabled',true);
                    YuD.removeClass(o.dom.resultFieldset,'phedex-invisible');
                    if ( m.node ) { nodes = m.node.selected; }
                    if ( ! (nodes && nodes.length) ) {
                      result.innerHTML = 'No destination nodes set';
                      banner('No destination nodes set','error');
                      _f.node.inner.childNodes[0].focus();
                      return;
                    }
                    i=0;
                    for (item in cart.data) { i++; }
                    if ( !i ) {
                      result.innerHTML = 'No datasets or blocks selected!';
                      dataset0 = _f.dataset0.inner.childNodes[0];
                      dataset0.focus();
                      if ( dataset0.value ) {
                        result.innerHTML += '<br/>(did you forget to press "Enter" in the dataset field?)';
                      }
                      banner('No datasets or blocks selected','error');
                      return;
                    }
                    result.innerHTML = '';
                    for ( i in value ) {
                      val = value[i];
                      vName = val.name;
                      vValue = val.values.value;
//                       if ( vName == 'dataset' || vName == 'block' ) { level = vName; }
                      if      ( vName == 'dbs'  ) { dbs         = vValue; }
                      else if ( vName != 'node' ) { args[vName] = vValue; }
                    }
                    args.level        = (args.level   == '1') ? 'block' : 'dataset';
                    args.move         = (args.move    == '1') ? 'y' : 'n';
                    args._static      = (args._static == '1') ? 'y' : 'n';
                    args.no_mail      =  args.no_mail         ? 'y' : 'n';
                    args.request_only =  args.request_only    ? 'y' : 'n';
//                     args.request_only =  'y';
                    args.custodial    =  args.custodial       ? 'y' : 'n';
                    args.node         =  nodes;
                    if ( m.time_start ) { args.time_start = m.time_start; }

                    xml = '<data version="2.0"><dbs name="'+dbs+'">';
                    iCart=cart.data;
                    for ( dataset in iCart ) {
                      ds=iCart[dataset];
                      xml += '<dataset name="'+dataset+'" is-open="'+ds.is_open+'">';
                      for ( block in ds.blocks ) {
                        xml += '<block name="'+block+'" is-open="'+ds.blocks[block].is_open+'" />';
                      }
                      xml += '</dataset>';
                    }
                    xml += '</dbs></data>';
                    args.data = xml;
                    result.innerHTML = 'Submitting request, please wait...';
                    _sbx.notify( o.id, 'getData', { api:'subscribe', args:args, method:'post' } );
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
              case 'datasvcFailure': {
                var api = arr[1][1].api,
                    msg = arr[1][0].message;
                    str = "Error when making call '"+api+"':";
                msg = msg.replace(str,'').trim();
                banner('Error subscribing data','error');
                o.dom.result.innerHTML = 'Error subscribing data:<br />'+msg;
                YuD.removeClass(o.dom.resultFieldset,'phedex-invisible');
                break;
              }
              case 'authData': {
                o.gotAuth = true;
                o.buildNodeSelector(arr[1].node);
                break;
              }
              case 'node_Apply': {
                var metaNode=o.meta.node, cBoxes=metaNode.cBoxes, node, cBox;
                YuD.addClass(metaNode.panel,'phedex-invisible');
                metaNode.selected=[];
                for (node in cBoxes) {
                  cBox = cBoxes[node];
                  if ( cBox.checked ) { metaNode.selected.push(node); }
                }
                metaNode.Ctl.value = metaNode.Ctl.title = metaNode.selected.sort().join(' ');
                break;
              }
              case 'node_Dismiss': {
                var metaNode=o.meta.node, cBoxes=metaNode.cBoxes, node, cBox;
                YuD.addClass(metaNode.panel,'phedex-invisible');
                for (node in cBoxes) {
                  cBox = cBoxes[node];
                  cBox.checked = false;
                }
                for (node in metaNode.selected) {
                  cBox = cBoxes[metaNode.selected[node]];
                  cBox.checked = true;
                }
                break;
              }
              case 'node_Reset': {
                var metaNode=o.meta.node, cBoxes=metaNode.cBoxes, node, cBox;
                for (node in cBoxes) {
                  cBox = cBoxes[node];
                  cBox.checked=false;
                }
                break;
              }
              case 'dbsSelected': {
                o.meta._panel.fields.dbs.inner.title = arr[1];
                break;
              }
              case 'authTimeout': {
                _sbx.notify(o.id,'getData',{api:'nodes'} );
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);
        _sbx.notify('ComponentExists',this); // borrow the Core machinery for getting data!

        this.reAuth = function(o) {
          return function(ev,arr) {
            var authData = arr[0];
            o.buildNodeSelector(authData.node);
          }
        }(this);
        _sbx.listen('authData',this.reAuth);
        _sbx.notify('login','getAuth',this.id);
        _sbx.delay(3000,this.id,'authTimeout');

        var fieldset = document.createElement('fieldset'),
            legend = document.createElement('legend'),
            el = document.createElement('div');
        fieldset.id = 'fieldset_'+PxU.Sequence();
        fieldset.className = 'phedex-invisible';
        legend.appendChild(document.createTextNode('Results'));
        fieldset.appendChild(legend);
        this.dom.panel.appendChild(fieldset);

        el.className = 'phedex-panel-status';
        fieldset.appendChild(el);
        this.dom.result = el;
        this.dom.resultFieldset = fieldset;

        var startInner = this.meta._panel.fields.time_start.inner,
            startCtl = startInner.childNodes[1];
        this.buildCalendarSelector(startInner,startCtl);

//         this.ctl.Apply.set('disabled',true);

        var _fields = this.meta._panel.fields,
            datasetInner = _fields.dataset0.inner,
            datasetCtl = datasetInner.childNodes[0],
            _fDataset = _fields.dataset,
            icon,
            k1 = new Yu.KeyListener(
              datasetCtl,
              { keys: Yu.KeyListener.KEY['ENTER'] },
              { fn:function(){
                  var value = datasetCtl.value, cart=this.cart, cd=cart.data, icon;
                  if ( cd[value] ) { return; }
                  if ( this.datasetLookup ) {
                    icon = this.dom.datasetIcon;
                    YuD.removeClass(icon,'phedex-invisible');
                    icon.src = PxW.WebAppURL+'/images/progress.gif';
                    _sbx.notify( this.id, 'getData', { api:'data', args:{dataset:value, level:'block'} } );
                  } else {
                    if ( cd[value] ) { return; }
                    cd[value] = { dataset:value, blocks:{}, is_open:'n' };
                    el = this.AddFieldsetElement(_fDataset,value,value);
                    cart.elements[value] = {type:'dataset', el:el };
                  }
                  return false;
              }, scope:this, correctScope:true }
            );
        icon = document.createElement('img');
        icon.style.cssFloat = 'left';
        icon.className = 'phedex-invisible';
        datasetInner.appendChild(icon);
        this.dom.datasetIcon = icon;
        k1.enable();
      },
      resetCart: function() {
        this.cart = { data:{}, elements:{} }
      },
      buildCalendarSelector: function(el,ctl) {
        var elCal = document.createElement('div'), cal, thisYear, thisMonth, thisDay, thisHour, thisMinute, thisSecond, now, elInput = el.childNodes[0];
        elCal.className = 'phedex-panel-calendar-select phedex-invisible';
        el.appendChild(elCal);

        now = PxU.now();
        var mySelectHandler = function(o) {
          return function(type,args,obj) {
            var selected = args[0][0];
            elInput.value = selected[0]+'-'+selected[1]+'-'+selected[2]+' 00:00:00';
            o.meta.time_start = new Date(selected[0],selected[1],selected[2],0,0,0).getTime()/1000;
            YuD.addClass(elCal,'phedex-invisible');
          }
        }(this);

        ctl.type='button';
        ctl.id = 'calendar_'+PxU.Sequence();
        ctl.title = 'Show calendar for date-selection';
        var img = document.createElement('img');
        img.src = PxW.WebAppURL+'/images/calendar_icon.gif';
        img.width = img.height = 18;
        img.style.verticalAlign = 'text-bottom';
        ctl.appendChild(img);

        cal = new YAHOO.widget.Calendar( 'cal'+PxU.Sequence(), elCal, {maxdate:now.month+'/'+now.day+'/'+now.year } );
        cal.cfg.setProperty('MDY_YEAR_POSITION', 1);
        cal.cfg.setProperty('MDY_MONTH_POSITION', 2);
        cal.cfg.setProperty('MDY_DAY_POSITION', 3);
        cal.selectEvent.subscribe( mySelectHandler, cal, true);
        cal.render();

        YuE.addListener(ctl,'click',function() {
            if ( YuD.hasClass(elCal,'phedex-invisible') ) {
              YuD.removeClass(elCal,'phedex-invisible');
              elCal.style.left = ctl.offsetLeft - elCal.clientWidth;
            } else {
              YuD.addClass(elCal,'phedex-invisible');
            }
          }, this, true);

        this.updateCal = function() {
          var str=elInput.value, arr=[], year, day, month, hour, minute, second, now=PxU.now(), _e=el, _eI=elInput,
              anim, attributes = {
                backgroundColor: { to:'#fff' },
                duration: 2
              };
          anim = new YAHOO.util.ColorAnim(elInput, attributes);
          if ( str == '' || !str ) {
            delete this.meta.time_start;
            YuD.addClass(elCal,'phedex-invisible');
            return;
          }
          if ( !str.match(/^(\d\d\d\d)\D?(\d\d?)\D?(\d\d?)\D?(.*)$/) ) {
            banner('Illegal date format. Must be YYYY-MM-DD HH:MM:SS (HH:MM:SS optional)','error');
            delete this.meta.time_start;
            YuD.addClass(elCal,'phedex-invisible');
            elInput.style.backgroundColor = '#f66';
            anim.animate();
            return;
          }
          year  = parseInt(RegExp.$1);
          month = parseInt(RegExp.$2);
          day   = parseInt(RegExp.$3);
          str   = RegExp.$4;
          hour = minute = second = 0;
          if ( str != '' ) {
            str.match(/^(\d\d?)(\D?(\d\d?))?(\D?(\d\d?))?$/);
            hour   = parseInt(RegExp.$1);
            minute = parseInt(RegExp.$3 || 0);
            second = parseInt(RegExp.$5 || 0);
          }
//        Make sure the date is not in the future.
          if ( year  > now.year  || ( year  == now.year  && (
                 month > now.month || ( month == now.month && (
                   day   > now.day   || ( day   == now.day   && (
                     hour  > now.hour  || ( hour  == now.hour  && (
                       minute > now.minute || ( minute == now.minute && second > now.second )
                     ) )
                   ) )
                 ) )
                ) )
              )
          {
            banner('You may not set a start-date in the future','error');
            year   = now.year;
            month  = now.month;
            day    = now.day;
            hour   = now.hour;
            minute = now.minute;
            second = 0; // don't fuss with individual seconds, reset to the minute
            elInput.style.backgroundColor = '#f66';
            anim.animate();
          } else {
            YuD.addClass(elCal,'phedex-invisible'); // a valid date was typed in, so accept it and move on
          }

          if ( month  < 10 ) { month  = '0' + month; }
          if ( day    < 10 ) { day    = '0' + day; }
          if ( hour   < 10 ) { hour   = '0' + hour; }
          if ( minute < 10 ) { minute = '0' + minute; }
          if ( second < 10 ) { second = '0' + second; }
          this.meta.time_start = new Date(year,month,day,hour,minute,second).getTime()/1000;
          cal.select(year+'/'+month+'/'+day);
          ctl.value = year+'-'+month+'-'+day+' '+hour+':'+minute+':'+second;
          cal.cfg.setProperty('pagedate', month+'/'+year);
          cal.render();
        }
        var k1 = new Yu.KeyListener(
          elInput,
          { keys: Yu.KeyListener.KEY['ENTER'] },
          { fn:function(){
              this.updateCal();
              return false;
          }, scope:this, correctScope:true }
        );
        k1.enable();

        return cal;
      },

      buildNodeSelector: function(nodeList) {
        var nodes=[], nNames=[], i, p, q, nBuffer=0, nMSS=0, node, name, nNodes=nodeList.length, _buffer=[], _mss=[], tmp=[], selected=[],
            _defaultBuffer=false, _defaultMSS=false, nodeInner, nodeCtl, nRows, nCols, nodePanel, container, el, cBox, label, metaNode;

        for (i in nodeList) {
          name = nodeList[i].name;
          node = {name:name, isBuffer:false, isMSS:false, checked:false};
          if ( nNodes == 1 ) { node.checked = true; }
          if ( name.match(/_Buffer$/) ) { nBuffer++; _buffer[name]=1; node.isBuffer = true; }
          if ( name.match(/_MSS$/) )    { nMSS++;    _mss[name]=1;    node.isMSS = true; }
          nodes[name] = node;
          nNames.push(name);
        }

//      Now the logic to build the selector. If only one node is allowed, select it and lock it in
        nodeInner = this.meta._panel.fields.node.inner;
        nodeCtl = nodeInner.childNodes[0];
        if ( nNodes == 1 ) {
          nodeCtl.value = nodeList[0].name;
          nodeCtl.disabled = true;
          return;
        }

//      Now, if there is one Buffer node and no MSS nodes, select that by default
        if ( nBuffer == 1 && nMSS == 0 ) { _defaultBuffer = true; }
//      if there's only one MSS node, select that by default
        if ( nMSS == 1 ) { _defaultMSS = true; }
//      if any node-types are selected by default, set that default in the nodes array
        if ( nNodes > 1 && ( _defaultBuffer || _defaultMSS ) ) {
          if ( _defaultBuffer ) {
            for (name in _buffer) {
              nodes[name].checked = true;
              selected.push(name);
            }
          }
          if ( _defaultMSS ) {
            for (name in _mss) {
              nodes[name].checked = true;
              selected.push(name);
            }
          }
        }
        nodeCtl.value = nodeCtl.title = selected.sort().join(' ') || '';

//      sort the names into the right order
        nNames.sort();
        nRows = Math.round(Math.sqrt(nNodes));
        nCols = Math.round(nNodes/nRows);
        if ( nCols > 8 ) { nCols = 6; }
        while ( nRows*nCols < nNodes ) { nRows++; }
        for (p=0; p<nRows; p++) {
          tmp[p] = [];
          for (q=0; q<nCols; q++) {
            i = p+q*nRows;
            if ( i >= nNodes ) { continue; }
            tmp[p][q] = nodes[nNames[i]];
          }
        }
        nodes = tmp;

//      now build the panel to show the nodes
        nodePanel = this.dom.nodePanel;
        if ( nodePanel ) { nodePanel.destroy(); }
        nodePanel = document.createElement('div');
        nodePanel.className = 'phedex-panel-node-select phedex-invisible';
        container = document.createElement('div');

        var meta = this.buildCBoxPanel('nodePanel','node',nodes);
        nodeInner.appendChild(meta.panel);
        meta.Ctl = nodeCtl;
        meta.selected = selected;
        this.meta.node = meta;

        nodeCtl.onfocus = function(o) {
          return function() {
            var colWidth, metaNode=o.meta.node, panel=metaNode.panel;
            YuD.removeClass(panel,'phedex-invisible');
            if ( metaNode.marker ) {
              colWidth = metaNode.marker.offsetWidth;
              panel.style.width = nCols * colWidth;
              delete metaNode.marker;
            }
            metaNode.focus.focus();
          }
        }(this);
      },
      buildCBoxPanel: function(elName, id, items, buttons) {
        var panel = this.dom[elName],
            container, nRows, nCols, p, q, item, name, el, cBox, cBoxes=[], label, focus, marker;
        if ( panel ) { panel.destroy(); }
        panel = document.createElement('div');
        panel.className = 'phedex-panel-'+id+'-select phedex-invisible';
        container = document.createElement('div');

        nRows = items.length;
        nCols = items[0].length;
        for (p=0; p<nRows; p++) {
          for (q=0; q<nCols; q++) {
            item = items[p][q];
            if ( !item ) {
              panel.appendChild(container);
              container = document.createElement('div');
              continue;
            }
            name = item.name;
            el = document.createElement('div');
            el.className = 'phedex-panel-select';
            cBox = document.createElement('input');
            cBox.type = 'checkbox';
            cBox.className = 'phedex-panel-checkbox';
            cBox.id = 'cbox_' + PxU.Sequence();
            cBox.checked = item.checked;
            cBoxes[name] = cBox;
            el.appendChild(cBox);
            label = document.createElement('div');
            label.className = 'phedex-inline';
            label.innerHTML = name;
            el.appendChild(label);
            container.appendChild(el);
            if ( !focus )  { focus = cBox; }
            if ( !marker ) { marker = el; }
          }
          if ( container.childNodes.length > 0 ) {
            panel.appendChild(container);
            container = document.createElement('div');
          }
        }
        var b, bName, _buttons=document.createElement('div');
        if ( !buttons ) { buttons = {Apply:'Select the checked '+id+'s', Reset:'un-select all '+id+'s', Dismiss:'dismiss the panel, with no changes'}; }
        _buttons.className = 'align-right';
        panel.appendChild(_buttons);
        for (name in buttons) {
          bName = id+'_' + name;
          this.ctl[bName] = b = new Yw.Button({ label:name, title:buttons[name], container:_buttons });
          b.on ('click', function(id,_action) {
            return function() { _sbx.notify(id,_action); }
          }(this.id,bName) );
        }
        return { panel:panel, cBoxes:cBoxes, focus:focus, marker:marker };
      },
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        var rid, api=context.api;
        switch (api) {
          case 'subscribe': {
            rid = data.request_created[0].id;
            log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
            banner('Subscription succeeded!');
            this.dom.result.innerHTML = 'Subscription succeeded:<br/>request-ID = '+rid+'<br/>';
            YuD.removeClass(this.dom.resultFieldset,'phedex-invisible');
//             this.ctl.Apply.set('disabled',true);
            break;
          }
          case 'nodes': {
            if ( !this.gotAuth ) {
              this.buildNodeSelector(data.node);
            }
            break;
          }
          case 'data': {
            var datasets=data.dbs, ds, dsName, blocks, block, i, j, n, item, cart=this.cart, cData=cart.data, icon,
                _fields = this.meta._panel.fields,
                datasetInner = _fields.dataset0.inner,
                datasetCtl = datasetInner.childNodes[0],
                _fDataset = _fields.dataset;
            icon = this.dom.datasetIcon;
            try {
              if ( datasets.length == 0 ) {
                item = context.args.dataset || context.args.block;
                YuD.removeClass(icon,'phedex-invisible');
                icon.src = PxW.WebAppURL + '/images/close-red-16x16.gif';
                return;
              }
              datasets = datasets[0].dataset;
              for (i in datasets) {
                ds = datasets[i];
                dsName = ds.name;
                if ( cData[dsName] ) { continue; }
                cData[dsName] = { dataset:dsName, blocks:{}, is_open:ds.is_open };
                n = ds.block.length;
                for (j in ds.block ) {
                  block = ds.block[j];
                  cData[dsName].blocks[block.name] = block;
                }
                el = this.AddFieldsetElement(_fDataset,dsName+' ('+n+' blocks)',dsName);
                cart.elements[dsName] = {type:'dataset', el:el };
              }
              YuD.removeClass(icon,'phedex-invisible');
              icon.src = PxW.WebAppURL + '/images/check-green-16x16.gif';
            } catch(ex) {
              var _x = ex;
            }
            break;
          }
        }
      },
      getDataFail: function(api,message) {
        var str = "Error when making call '"+api+"':";
        var x = message.replace(str,'').trim();
        banner(message.replace(str,'').trim(),'error');
      }
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-subscribe');
