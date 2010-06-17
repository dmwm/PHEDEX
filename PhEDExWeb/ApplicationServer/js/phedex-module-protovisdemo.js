/**
 * This is the base class for all PhEDEx data-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class Agents
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

      options: {
        width:800,
        height:400,
        minwidth:600,
        minheight:50
      },

      meta: {
      },

/** final preparations for receiving data. This is the last thing to happen before the module gets data, and it should notify the sandbox that it has done its stuff. Otherwise the core will not tell the module to actually ask for the data it wants. Modules may override this if they want to sanity-check their parameters first, e.g. the <strong>Agents</strong> module might want to check that the <strong>node</strong> is set before allowing the cycle to proceed. If the module does not have enough parameters defined, it can notify the sandbox with <strong>needArguments</strong>, and someone out there (e.g. the global filter or the navigator history) can attempt to supply them
 * @method initData
 */
      initData: function() {
        node = 'T0_CH_CERN_Export';
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

        if ( !node ) {
          this.initData();
          return;
        }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'agents', args:{node:node} } );
      },
      gotData: function(data,context) {
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';

//           var data = 
// {"node":[{"agent":[{"time_update":"1276696583.94697","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"10552","version":"PHEDEX_3_3_1","label":"exp-pfn-local"}],"name":"FileExport","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276697851.88557","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"10516","version":"PHEDEX_3_3_1","label":"exp-pfn"}],"name":"FileExport","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699510.4564","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"25776","version":"PHEDEX_3_3_1","label":"mgmt-blockmon"}],"name":"BlockMonitor","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699538.78552","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"25164","version":"PHEDEX_3_3_1","label":"blockverify"}],"name":"BlockDownloadVerify","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699535.77539","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"27824","version":"PHEDEX_3_3_1","label":"mgmt-pump"}],"name":"FilePump","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699280.83667","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"10657","version":"PHEDEX_3_3_1","label":"download-remove"}],"name":"FileRemove","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699565.30076","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"26833","version":"PHEDEX_3_3_1","label":"info-invariant"}],"name":"InvariantMonitor","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276698998.37744","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"25881","version":"PHEDEX_3_3_1","label":"info-fs"}],"name":"InfoFileSize","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699090.30835","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"10476","version":"PHEDEX_3_3_1","label":"exp-stager-caf"}],"name":"FileStager","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699291.24255","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"25938","version":"PHEDEX_3_3_1","label":"mgmt-blockactiv"}],"name":"BlockActivate","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276697507.72133","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"26265","version":"PHEDEX_3_3_1","label":"mgmt-blockverifyinjector"}],"name":"BlockDownloadVerifyInjector","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699593.68942","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"25870","version":"PHEDEX_3_3_1","label":"mgmt-reqalloc"}],"name":"RequestAllocator","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699507.34888","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"27073","version":"PHEDEX_3_3_1","label":"info-tc"}],"name":"InfoStatesClean","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699027.33946","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"26020","version":"PHEDEX_3_3_1","label":"mgmt-blockdeact"}],"name":"BlockDeactivate","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699488.46464","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"10963","version":"PHEDEX_3_3_1","label":"mgmt-router"}],"name":"FileRouter","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699256.21639","state_dir":"/data/ProdNodes/Prod_T0_CH_CERN_Export/state","pid":"10439","version":"PHEDEX_3_3_1","label":"exp-stager-others"}],"name":"FileStager","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699559.35547","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"26080","version":"PHEDEX_3_3_1","label":"mgmt-blockdelete"}],"name":"BlockDelete","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699553.72433","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"3292","version":"PHEDEX_3_3_1","label":"info-pm"}],"name":"PerfMonitor","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"},{"agent":[{"time_update":"1276699486.4837","state_dir":"/data/ProdNodes/Prod_Mgmt/state","pid":"26571","version":"PHEDEX_3_3_1","label":"mgmt-blockalloc"}],"name":"BlockAllocator","node":"T0_CH_CERN_Export","host":"vocms02.cern.ch"}]};

        if ( !data.node ) {
          throw new Error('data incomplete for '+context.api);
        }
        var jAgents, nAgents, iAgent, jProcs, pvData={ agents:[], times:[] }, value, max=0;
        this.data = jAgents = data.node;
        nAgents=jAgents.length;
        this.dom.title.innerHTML = node + ': ' + this.data.length + " agents";
            var now = new Date().getTime()/1000;

        for (iAgent = 0; iAgent < nAgents; iAgent++) {
          jProcs = jAgents[iAgent].agent;
          for (iProc in jProcs) {
            value = now - jProcs[iProc]['time_update'];
            if ( value > max ) { max = value; }
            pvData['times'].push(value);
            pvData['agents'].push(jProcs[iProc]['label']);
          }
        }

        this.dom.body.style.border = '1px solid red';

        max = max * 1.5;
        var w = this.options.width,
            h = this.options.height,
            x = pv.Scale.linear(0, max).range(0, w),
            y = pv.Scale.ordinal(pv.range(pvData['agents'].length)).splitBanded(0, h, 4/5);
//         var data = pv.range(10).map(function(d) { return Math.random() + .1; });

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
            .top(function() y(this.index))
            .height(y.range().band)
            .left(0)
            .width(x)
            .fillStyle(pv.Scale.linear(1800, 3600, 7200).range('green', 'yellow', 'red'));

/* The value label. */
        bar.anchor("right").add(pv.Label)
            .textStyle("white")
            .text(function(d) d.toFixed(1));

/* The variable label. */
        bar.anchor("left").add(pv.Label)
            .textMargin(5)
//             .textAlign("right")
            .text(function() pvData['agents'][this.index]);

/* X-axis ticks. */
        vis.add(pv.Rule)
            .data(x.ticks(5))
            .left(x)
            .strokeStyle(function(d) d ? "rgba(255,255,255,.3)" : "#000")
          .add(pv.Rule)
            .bottom(0)
            .height(5)
            .strokeStyle("#000")
          .anchor("bottom").add(pv.Label)
            .text(x.tickFormat);

vis.render();

//         new pv.Panel()
//             .width(this.options.width)
//             .height(this.options.height)
//             .canvas(this.dom.body)
//           .anchor("center").add(pv.Label)
//             .text("Hello, world!")
//           .root.render();

        _sbx.notify( this.id, 'gotData' );
      },
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','agents');