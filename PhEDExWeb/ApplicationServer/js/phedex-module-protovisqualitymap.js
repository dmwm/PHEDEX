/**
 * This is the base class for all PhEDEx Protovis-related modules. It provides the basic interaction needed for the core to be able to control it.
 * @namespace PHEDEX.Module
 * @class ProtovisQualityMap
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module');
PHEDEX.Module.ProtovisQualityMap = function(sandbox, string) {
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
        height:800,
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
//       setArgs: function(arr) {
//         if ( !arr )      { return; }
//         if ( !arr.node ) { return; }
//         if ( arr.node == node ) { return; }
//         node = arr.node;
//         this.dom.title.innerHTML = 'setting parameters...';
//         _sbx.notify(this.id,'setArgs');
//       },

      getData: function() {
        log('Fetching data','info',this.me);
        this.dom.title.innerHTML = this.me+': fetching data...';
        var args = {}, magic = PxU.Sequence(); // stub the magic for now
        if ( this._magic == magic ) {
          log('Already asked for this magic data: magic="'+magic+'"','warn',this.me);
          return;
        }
        this._magic = magic;
        args.to = 'T*';
        args.binwidth = 96*3600;
        this.data = {};
       _sbx.notify( this.id, 'getData', { api:'TransferHistory', args:args, magic:magic } );
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

        if ( !data.link ) {
          throw new Error('data incomplete for '+context.api);
        }

// parse the data into the pvData structure.
// Correctly, for the 'agents' API, I should loop over data.node as an array. 
        var jLinks, jLink, iLink, nLinks, to, from, quality, i, j, k, nodes=[], n2=[], map=[], map2=[], row=[];
        this.data = jLinks = data.link;
        nLinks    = jLinks.length;
        this.dom.title.innerHTML = this.data.length + " links";

        i = 0;
        for (iLink = 0; iLink < nLinks; iLink++) {
          jLink = jLinks[iLink];
            to = jLink.to;
            if ( to.match(/MSS$/) ) { continue; }
            from = jLink.from;
            if ( from.match(/MSS$/) ) { continue; }
            if ( to.match(/^T3/) || from.match(/^T3/) ) { continue; }
            quality = (jLink.transfer[0].quality || 0) * 100;
            i++;
            nodes[to] = 1;
            if ( !map[to] )   { map[to] = []; }
            if ( !map[from] ) { map[from] = []; }
            map[to][from] = map[from][to] = quality.toFixed(2);
        }
        row.push('node');
        for (to in nodes) { n2.push(to); }
        nodes = n2.sort();
        for (to in nodes) { row.push(nodes[to]); }
        map2.push(row);
        for (i in nodes) {
          to = nodes[i];
          row=[];
          row.push(to);
          for (j in nodes) {
            from = nodes[j];
            quality = map[to][from] || -1;
            row.push(quality);
          }
          map2.push(row);
        }

        this.dom.title.innerHTML = i + ' nodes (excluding MSS)';

        var cols = map2.shift();
        map2 = map2.map(function(d) { pv.dict(cols, function() { d[this.index] }) });
        cols.shift();

/* The color scale ranges from 0 to 100. */
        var fill = pv.dict(cols, function(f){pv.Scale.linear()}
                .domain(     0,  0.01,  10.0,       80.0,    100.0)
                .range('white', 'red', 'orange', 'yellow', 'green'));

/* The cell dimensions. */
        var w = 24, h = 13;

        var vis = new pv.Panel()
            .width(cols.length * w)
            .height(map2.length * h)
            .top(130)
            .left(130);

        vis.add(pv.Panel)
            .data(cols)
            .left(function(){this.index * w})
            .width(w)
          .add(pv.Panel)
            .data(map2)
            .top(function(){this.index * h})
            .height(h)
            .fillStyle(function(d, f){fill[f](d[f])})
            .strokeStyle('white')
            .lineWidth(1)
            .antialias(false)
            .title(function(d, f) { var str = d.node+' to '+f+': '; return d[f] >= 0 ? str + d[f] : str + 'no transfers'; } )
            .event('mouseover',function(d,node) {
              var str;
              if ( d.node == node ) { str = ''; }
              else {
                str = 'From '+d.node+' to '+node+': ';
                if ( d[node] < 0 ) { str += 'no transfers'; }
                else { str += d[node]+'%'; }
              }
              banner(str);
            })
            .event('mousedown',function(d,node) {
              alert('I could show link-details from '+d.node+' to '+node+', or anything!');
            });

        vis.add(pv.Label)
            .data(cols)
            .left(function(){this.index * w + w / 2})
            .textAngle(-Math.PI / 2)
            .textBaseline('middle');

        vis.add(pv.Label)
            .data(map2)
            .top(function(){this.index * h + h / 2})
            .textAlign("right")
            .textBaseline('middle')
            .text(function(d){d.node});

        vis.render();
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','protovisqualitymap');
