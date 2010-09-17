PHEDEX.namespace('Component');
PHEDEX.Component.Subscribe = function(sandbox,args) {
  var _me = 'component-subscribe',
      _sbx = sandbox,
      payload = args.payload,
      obj = payload.obj,
      partner = args.partner,
      ttIds = [], ttHelp = {};

  if ( !payload.panel ) {
    payload.panel =
    {
      Datasets:{
        fields:{
          dataset:{type:'text', tip:'Dataset name, with or without wildcards', dynamic:true },
        }
      },
      Blocks:{
        fields:{
          block:{type:'text', tip:'Block name, with or without wildcards', dynamic:true },
        }
      },
      Parameters:{
        fields:{
// need to extract the list of DBS's from somewhere...
          dbs:          {type:'text', text:'Choose your DBS', value:'http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query' },

// node can be multiple
          node:         {type:'regex', text:'Destination node', tip:'enter a valid node name', negatable:false },
          move:         {type:'radio', fields:['replica','move'], text:'Transfer type',
                         tip:'Replicate (copy) or move the data. A "move" will delete the data from the source after it has been transferred', default:'replica' },
          static:       {type:'radio', fields:['growing','static'], text:'Subscription type',
                         tip:'A static subscription is a snapshot of the data as it is now. A growing subscription will add new blocks as they become available', default:'growing' },
          priority:     {type:'radio', fields:['low','normal','high'],  byName:true, text:'Priority', default:'low' },

          custodial:    {type:'checkbox', text:'Make custodial request?', tip:'Check this box to make the request custodial', attributes:{checked:false} },
          group:        {type:'regex',    text:'User-group', tip:'The group which is requesting the data. May be left undefined, used only for accounting purposes', negatable:false },

          time_start:   {type:'regex',    text:'Start-time for subscription',    tip:'This is valid for datasets only. Unix epoch-time', negatable:false },
          request_only: {type:'checkbox', text:'Request only, do not subscribe', tip:'Make the request without making a subscription',   attributes:{checked:true} },
          no_mail:      {type:'checkbox', text:'Suppress email notification?',   tip:'Check this box to not send an email',              attributes:{checked:true} },
          comments:     {type:'textarea', text:'Enter your comments here', className:'phedex-inner-textarea' }
        }
      }
    }
  }
//   this.id = _me+'_'+PxU.Sequence(); // don't set my own ID, inherit the one I get from the panel!
  Yla(this, new PHEDEX.Component.Panel(sandbox,args));

  this.cartHandler = function(o) {
    return function(ev,arr) {
      var action = arr[0], field=arr[1], overlay=o.overlay, ctl=o.ctl['panel'];
      switch (action) {
        case 'add': {
          var _x=o, c, cart=o.cart, type, item, _panel=o.meta._panel;
          for (type in field) {
            item = field[type];
            if ( cart[type][item] ) { return; }
            cart[type][item] = 1;
            c = _panel.fields[type];
            o.AddFieldsetElement(c,item);
          }
          if ( ctl ) { ctl.Enable(); }
          else       { YuD.removeClass(overlay.element,'phedex-invisible'); }
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
      cart:{ dataset:{}, block:{} },
      _init: function(args) {
        this.selfHandler = function(o) {
          return function(ev,arr) {
            var action    = arr[0],
                subAction = arr[1],
                value     = arr[2];
            switch (action) {
              case 'Panel': {
                switch (subAction) {
                  case 'Reset': {
                    break;
                  }
                  case 'Apply': {
                    var args={}, call={api:'bounce'}, i, val, cart=o.cart, iCart, item, level;
                    for ( i in value ) {
                      val = value[i];
                      args[val.name] = val.values.value;
                    }
                    args.move         = (args.move   == '1') ? 'y': 'n';
                    args.static       = (args.static == '1') ? 'y': 'n';
                    args.no_mail      =  args.no_mail        ? 'y' : 'n';
                    args.request_only =  args.request_only   ? 'y' : 'n';

                    for ( level in cart ) {
                      iCart=cart[level];
//                       args.data='<dbs name="'+value[dbs].values.value+'>';
                      for ( item in iCart ) {
                      args.level = level;
                      }
                    }
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
      },
    };
  };
  Yla(this,_construct(this),true);
  this._init(args);
  return this;
}

log('loaded...','info','component-subscribe');

//   <dbs name="http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query">
//     <dataset name="/sample/dataset">
//       <block name="/sample/dataset#1" />
//       <block name="/sample/dataset#2" />
//     </dataset>
//     <dataset name="/sample/dataset2">
//       <block name="/sample/dataset2#1" />
//       <block name="/sample/dataset2#2" />
//     </dataset>
//   </dbs> 

//    <dbs name="http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query">
//      <dataset name="/sample/dataset" is-open="y" is-transient="n">
//        <block name="/sample/dataset#1" is-open="y">
//          <file lfn="file1" size="10" checksum="cksum:1234"/>
//          <file lfn="file2" size="22" checksum="cksum:456"/>
//        </block>
//        <block name="/sample/dataset#2" is-open="y">
//          <file lfn="file3" size="1" checksum="cksum:2"/>
//        </block>
//      </dataset>
//      <dataset name="/sample/dataset2" is-open="n" is-transient="n">
//        <block name="/sample/dataset2#1" is-open="n"/>
//        <block name="/sample/dataset2#2" is-open="n"/>
//      </dataset>
//    </dbs>