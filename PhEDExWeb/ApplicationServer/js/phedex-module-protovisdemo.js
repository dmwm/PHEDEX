/**
 * This is the base class for all PhEDEx Protovis-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class ProtovisDemo
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module');
PHEDEX.Module.ProtovisDemo = function(sandbox, string) {
  Yla(this,new PHEDEX.Protovis(sandbox,string));

  var _sbx = sandbox, node;
  log('Module: creating a genuine "'+string+'"','info',string);

   _construct = function(obj) {
    return {
      decorators: [
      ],

// these define the canvas size, and are used elsewhere too
      options: {
        width:800,
        height:400,
        minwidth:600,
        minheight:50
      },

// most of this is boilerplate, only 'getData' and 'gotData' need customising.
      meta: {
      },

      isValid: function() {
        if ( node ) { return true; }
        return false;
      },
      getState: function() { return {node:node}; },

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed. If the module does not have enough parameters defined, it can notify the sandbox with <strong>needArguments</strong>, and someone out there (e.g. the global filter or the navigator history) can attempt to supply them
 * @method initData
 */
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( node ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
/** Call this to set the parameters of this module and cause it to fetch new data from the data-service.
 * @method setArgs
 * @param arr {array} object containing arguments for this module. Highly module-specific! For the <strong>Agents</strong> module, only <strong>arr.node</strong> is required. <strong>arr</strong> may be null, in which case no data will be fetched.
 */
      setArgs: function(arr) {
        if ( !arr )      { return; }
        if ( !arr.node ) { return; }
        if ( arr.node == node ) { return; }
        node = arr.node;
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
      },

      getData: function() {
// customisable stuff starts here. Check that the 'node' is defined. If not, go ask for a value. If yes, get the data
        if ( !node ) {
          this.initData();
          return;
        }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
// tell the core to get the 'agents' data for the appropriate node
        _sbx.notify( this.id, 'getData', { api:'agents', args:{node:node} } );
      },
/*
 * This is where the meat of the application resides. The gotData function receives two arguments, 'data' and 'context'. 'data contains the
 * data returned by the API call, see the phedex dataservice API documentation for details. This data is then massaged into a suitable form
 * for protovis to digest, and used in whatever representation you like.
 */
      gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';

        if ( !data.node ) {
          throw new Error('data incomplete for '+context.api);
        }

// parse the data into the pvData structure.
// Correctly, for the 'agents' API, I should loop over data.node as an array. 
        var jAgents, nAgents, iAgent, jProcs, pvData={ agents:[], times:[] }, value, max=0, now = new Date().getTime()/1000;
        this.data = jAgents = data.node;
        nAgents=jAgents.length;
        this.dom.title.innerHTML = node + ': ' + this.data.length + " agents";

        for (iAgent = 0; iAgent < nAgents; iAgent++) {
          jProcs = jAgents[iAgent].agent;
          for (iProc in jProcs) {
            value = now - jProcs[iProc]['time_update'];
            if ( value > max ) { max = value; }

//          store the update-times in one array-oject, and the labels in another
            pvData['times'].push(value);
            pvData['agents'].push(jProcs[iProc]['label']);
          }
        }

        this.dom.body.style.border = '1px solid red';

//      base options for the canvas. Take some from the module definition, others from the data, etc.
        max = max * 1.5;
        var w = this.options.width,
            h = this.options.height,
            x = pv.Scale.linear(0, max).range(0, w),
            y = pv.Scale.ordinal(pv.range(pvData['agents'].length)).splitBanded(0, h, 4/5);

/* The root panel. */
        var vis = new pv.Panel()
            .canvas(this.dom.body)
            .width(w)
            .height(h)
            .bottom(20)
            .left(20)
            .right(10)
            .top(5);

/* The bars. */
        var bar = vis.add(pv.Bar)
            .data(pvData['times'])
            .top(function() { return y(this.index); })
            .height(y.range().band)
            .left(0)
            .width(x)
            .textStyle("white")
            .fillStyle(pv.Scale.linear(0, 1800, 3600, 7200).range('green', 'green', 'yellow', 'red'));

/* The value label. */
        bar.anchor("right").add(pv.Label)
            .text(function(d) { if ( d>1800 ) { return d.toFixed(1); } return '';} );

/* The variable label. */
        bar.anchor("left").add(pv.Label)
            .textMargin(5)
            .text(function() { return pvData['agents'][this.index]; });

/* X-axis ticks. */
        vis.add(pv.Rule)
            .data(x.ticks(5))
            .left(x)
            .strokeStyle(function(d) { return d ? "rgba(255,255,255,.3)" : "#000";} )
          .add(pv.Rule)
            .bottom(0)
            .height(5)
            .strokeStyle("#000")
          .anchor("bottom").add(pv.Label)
            .text(x.tickFormat);

          vis.render();
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','protovisdemo');
