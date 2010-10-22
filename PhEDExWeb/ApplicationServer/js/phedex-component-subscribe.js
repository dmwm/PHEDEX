PHEDEX.namespace('Component');
PHEDEX.Component.Subscribe = function(sandbox,args) {
  var _me = 'component-subscribe',
      _sbx = sandbox,
      payload, opts, obj,
      ttIds = [], ttHelp = {};

  var groupComplete =
        {
          name:'autocomp-groups',
          source:'component-autocomplete',
          payload:{
            el:      '',
            dataKey: 'group',
            api:     'groups',
            argKey:  'group',
            handler: 'buildGroupsSelector'
          }
        };

  if ( !args ) { args={}; }
  opts = {
    text: 'Make a subscription',
    payload:{
      control:{
        parent:'control',
        payload:{
          text:'Subscribe',
          animate:  false,
          disabled: false, //true,
        },
        el:'content'
      },
      buttons: [ 'Dismiss', 'Apply', 'Reset' ],
      buttonMap: {
                   Apply:{title:'Subscribe this data', action:'Validate'}
                 },
      panel: {
        Datasets:{
          fields:{
            dataset:{type:'text', dynamic:true },
          }
        },
        Blocks:{
          fields:{
            block:{type:'text', dynamic:true },
          }
        },
        Parameters:{
          fields:{
// need to extract the list of DBS's from somewhere...
            dbs:          {type:'regex', text:'Name your DBS', negatable:false, value:'test' /*http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query'*/ },

// node can be multiple
            node:         {type:'regex', text:'Destination node', tip:'enter a valid node name', negatable:false, value:'' },
            move:         {type:'radio', fields:['replica','move'], text:'Transfer type',
                           tip:'Replicate (copy) or move the data. A "move" will delete the data from the source after it has been transferred', default:'replica' },
            static:       {type:'radio', fields:['growing','static'], text:'Subscription type',
                           tip:'A static subscription is a snapshot of the data as it is now. A growing subscription will add new blocks as they become available', default:'growing' },
            priority:     {type:'radio', fields:['low','normal','high'],  byName:true, text:'Priority', default:'low' },

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

//   this.id = _me+'_'+PxU.Sequence(); // don't set my own ID, inherit the one I get from the panel!
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));

  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action=arr[0], args=arr[1], ctl=o.ctl['panel'];
      switch (action) {
        case 'add': {
          var c, cart=o.cart, cd=cart.data, type, item, blocks, _a=o;
          type = 'dataset';
          item = args.dataset;
          if ( !cart[item] ) {
            cd[item] = { dataset:item, is_open:args.ds_is_open, blocks:{} };
          }
          blocks = cd[item].blocks;
          if ( args.block ) {
            type = 'block';
            item = args.block;
            if ( blocks[item] ) {
              return;
            }
          }
          blocks[item] = { block:item, is_open:args.is_open };
          c = o.meta._panel.fields[type];
          cart.elements.push({type:type, el:o.AddFieldsetElement(c,item)});
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
      cart:{ data:{}, elements:[] },
      _init: function(args) {
        this.selfHandler = function(o) {
          return function(ev,arr) {
            var action    = arr[0], subAction, value,
                cart = o.cart, _panel = o.meta._panel, _fieldsets = _panel.fieldsets;
            switch (action) {
              case 'Panel': {
                subAction = arr[1];
                value     = arr[2];
                switch (subAction) {
                  case 'Reset': {
                    var item, _cart, _fieldset;
                    while (item = cart.elements.shift()) {
                      _fieldset = _fieldsets[item.type].fieldset;
                      _fieldset.removeChild(item.el);
                    }
                    cart = { data:{}, elements:[] };
//                     o.ctl.Apply.set('disabled',true);
                    break;
                  }
                  case 'Apply': {
                    var args={}, i, val, cart=o.cart, iCart, item, dbs, dataset, ds, block, xml, vName, vValue;
//                     o.ctl.Apply.set('disabled',true);
                    o.dom.result.innerHTML = '';
                    for ( i in value ) {
                      val = value[i];
                      vName = val.name;
                      vValue = val.values.value;
                      if ( vName == 'dataset' || vName == 'block' ) { level = vName; }
                      else if ( vName == 'dbs' ) { dbs         = vValue; }
                      else                       { args[vName] = vValue; }
                    }
                    args.move         = (args.move   == '1') ? 'y' : 'n';
                    args.static       = (args.static == '1') ? 'y' : 'n';
                    args.no_mail      =  args.no_mail        ? 'y' : 'n';
                    args.request_only =  args.request_only   ? 'y' : 'n';
                    args.custodial    =  args.custodial      ? 'y' : 'n';

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
                    o.dom.result.innerHTML = 'Submitting request, please wait...';
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
                o.buildNodeSelector(arr[1].node);
                break;
              }
              case 'node_Apply': {
                var metaNode=o.meta['node'], cBoxes=metaNode.cBoxes, node, cBox;
                YuD.addClass(metaNode.panel,'phedex-invisible');
                metaNode.selected=[];
                for (node in cBoxes) {
                  cBox = cBoxes[node];
                  if ( cBox.checked ) { metaNode.selected.push(node); }
                }
                metaNode.Ctl.value = metaNode.Ctl.title = metaNode.selected.sort().join(' ');
                break;
              }
              case 'node_Reset': {
                var metaNode=o.meta['node'], cBoxes=metaNode.cBoxes, node, cBox;
                for (node in cBoxes) {
                  cBox = cBoxes[node];
                  cBox.checked=false;
                }
                break;
              }
//               case 'start_time_Select': {
// debugger;
//                 break;
//               }
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

        var startInner = this.meta._panel.fields['time_start'].inner;
        var startCtl = startInner.childNodes[0];
        this.buildCalendarSelector(startInner,startCtl);

//         this.ctl.Apply.set('disabled',true);
      },
      buildCalendarSelector: function(el,ctl) {
        var elCal = document.createElement('div'), cal, thisYear, thisMonth, thisDay, thisHour, thisMinute, today=new Date();
        elCal.className = 'phedex-panel-calendar-select phedex-invisible';
        el.appendChild(elCal);

        thisYear   = today.getFullYear();
        thisMonth  = today.getMonth()+1;
        thisDay    = today.getDate();
        thisHour   = today.getHours();
        thisMinute = today.getMinutes();

        var mySelectHandler = function(o) {
          return function(type,args,obj) {
            var selected = args[0][0];
            ctl.value = selected[0]+'-'+selected[1]+'-'+selected[2]+' 00:00:00';
            YuD.addClass(elCal,'phedex-invisible');
          }
        }(this);

        cal = new YAHOO.widget.Calendar( 'cal'+PxU.Sequence(), elCal, {close:true, maxdate:thisMonth+'/'+thisDay+'/'+thisYear } );
        cal.cfg.setProperty('MDY_YEAR_POSITION', 1);
        cal.cfg.setProperty('MDY_MONTH_POSITION', 2);
        cal.cfg.setProperty('MDY_DAY_POSITION', 3);
        cal.selectEvent.subscribe( mySelectHandler, cal, true);
        cal.render();

        ctl.onfocus = function(o) {
          return function() {
            YuD.removeClass(elCal,'phedex-invisible');
            var elLeft = ctl.offsetLeft;
            elCal.style.left = elLeft - 12; // empirical. Distance between phedex-inner and phedex-outer. TODO find better way to set this
          }
        }(this);

        var updateCal = function() {
          var str=ctl.value, arr=[], year, day, month, hour, minute, second;
          str.match(/^(\d\d\d\d)\D?(\d\d?)\D?(\d\d?)\D?(.*)$/);
          year  = RegExp.$1;
          month = RegExp.$2;
          day   = RegExp.$3;
          str   = RegExp.$4;
          str.match(/^(\d\d?)(\D?(\d\d?))?(\D?(\d\d?))?$/);
          hour   = RegExp.$1 || 0;
          minute = RegExp.$3 || 0;
          second = RegExp.$5 || 0;
alert('hand-setting date does not always work properly to update the calendar. Setting 2-digits for months less than 10 etc, forcing calendar to sync with typed values...');
// make sure the date is not in the future. The logic required is as listed here, but a faster form of it is used.
//           if ( ( year >= thisYear && month >= thisMonth && day >= thisDay && hour >= thisHour && minute > thisMinute ) ||
//                ( year >= thisYear && month >= thisMonth && day >= thisDay && hour >  thisHour ) ||
//                ( year >= thisYear && month >= thisMonth && day >  thisDay ) ||
//                ( year >= thisYear && month >  thisMonth ) ||
//                  year >  thisYear ) {
          if ( year  > thisYear  || ( year  == thisYear  && (
                 month > thisMonth || ( month == thisMonth && (
                   day   > thisDay   || ( day   == thisDay   && (
                     hour  > thisHour  || ( hour  == thisHour  && (
                       minute > thisMinute || ( minute == thisMinute && second > thisSecond )
                     ) )
                   ) )
                 ) )
                ) )
              )
          {
            banner('You may not select a date in the future','error');
            year   = thisYear;
            month  =  thisMonth;
            day    = thisDay;
            hour   = thisHour;
            minute = thisMinute;
            second = 0; // don't fuss with individual seconds, reset to the minute
          } else {
            YuD.addClass(elCal,'phedex-invisible'); // a valid date was typed in, so accept it and move on
          }

          ctl.value = year+'-'+month+'-'+day+' '+hour+':'+minute+':'+second;
          cal.cfg.setProperty('pagedate', month+'/'+year);
          cal.render();
//           if (day != '') {
//             cal.select(year+'/'+month+'/'+day);
// //             cal.select(month+'/'+day+'/'+year);
//             var selectedDates = cal.getSelectedDates();
//             if (selectedDates.length > 0) {
//               var firstDate = selectedDates[0];
//               cal.cfg.setProperty('pagedate', (firstDate.getMonth()+1) + "/" + firstDate.getFullYear());
//               cal.render();
//             } else {
//               banner('You may not select a date in the future','error');
//             }
//           }
        }
        var k1 = new Yu.KeyListener(
          ctl,
          { keys: Yu.KeyListener.KEY['ENTER'] },
          { fn:function(){
//           { fn:function(o){
//             return function() {
              updateCal();
              return false;
//             }
//           }(this), scope:this, correctScope:true }
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
        nodeInner = this.meta._panel.fields['node'].inner;
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
        nodeCtl.value = nodeCtl.title = selected.sort().join(' ');

//      sort the names into the right order
        nNames.sort();
        nRows = Math.round(Math.sqrt(nNodes));
        nCols = Math.round(nNodes/nRows);
        if ( nRows*nCols < nNodes ) { nRows++; }
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
        this.meta['node'] = meta;

        nodeCtl.onfocus = function(o) {
          return function() {
            var colWidth, metaNode=o.meta['node'], panel=metaNode.panel;
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
        if ( !buttons ) { buttons = {Apply:'Select the checked '+id+'s', Reset:'un-select all '+id+'s'}; }
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
      gotData: function(data,context) {
        var rid = data.request_created[0].id;
        log('Got new data: api='+context.api+', id='+context.poll_id+', magic:'+context.magic,'info',this.me);
        banner('Subscription succeeded!');
        this.dom.result.innerHTML = 'Subscription succeeded:<br/>request-ID = '+rid+'<br/>';
        YuD.removeClass(this.dom.resultFieldset,'phedex-invisible');
//         this.ctl.Apply.set('disabled',true);
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