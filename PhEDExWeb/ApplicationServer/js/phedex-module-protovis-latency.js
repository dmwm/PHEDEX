PHEDEX.namespace('Module.Protovis');
PHEDEX.Module.Protovis.Latency = function(sandbox, string) {
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
        return true;
      },

      initData: function() {
        _sbx.notify(this.id,'initData');
},
      getData: function() {
// customisable stuff starts here. Check that the 'node' is defined. If not, go ask for a value. If yes, get the data
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
// tell the core to get the 'agents' data for the appropriate node
        PHEDEX.Datasvc.Instance('tbedi');
        _sbx.notify( this.id, 'getData', { api:'blocklatency', args:{block:'/lifecycle/latency/*'} } );
      },
      gotData: function(data,context,response) {
        var i, j, k, l, dst, ltn, d1, result=[], tmp, dom=this.dom, order, max, min, value, newResult=[], maxInterval, now,
             vis, width = 900, height = 400;
        order=[
//           'block_create', 'block_close',
//           'time_create', 'time_subscription', 'time_update',
//           'first_request', 'first_replica', 'latest_replica', 'last_replica',
            {key:'first_request',     value:0},
            {key:'percent25_replica', value:25},
            {key:'percent50_replica', value:50},
            {key:'percent75_replica', value:75},
            {key:'percent95_replica', value:95},
            {key:'last_replica',      value:100}
          ];
        for ( i in data.block ) {
          tmp={};
          d1 = data.block[i];
          tmp.time_create = d1.time_create;
          tmp.time_update = d1.time_update;
          tmp.name = d1.name;
          for ( j in d1.destination ) {
            dst = d1.destination[j];
            tmp.node = dst.name;
            for ( k in dst.latency ) {
              ltn = dst.latency[k];
              for ( l in ltn ) {
                tmp[l] = ltn[l];
              }
              result.push( tmp );
            }
          }
        }

        log('Got new data','info',this.me);
        dom.title.innerHTML = 'Parsing data';
        dom.body.style.border='1px solid red';

        vis = new pv.Panel()
                    .canvas(dom.body)
                    .width(width)
                    .height(height)
                    .margin(20)
                    .bottom(20);

        maxInterval = 0;
        now = new Date().getTime()/1000;
        for ( i in result ) {
          max = 0;
          min = now;
          d = result[i];
          tmp=[];
          for (j in order) {
            value = d[order[j].key];
            if ( value ) {
              tmp.push([order[j].value,value]);
              if ( value > max ) { max = value; }
              if ( value < min ) { min = value; }
            }
          }
          if ( max > min ) { // only consider complete entries
            if ( max - min > maxInterval ) { maxInterval = max - min; }
            newResult.push(tmp);
          }
        }

        for ( i in newResult ) {
          tmp = newResult[i];
          min = tmp[0][1];
          for ( j in tmp ) {
            if ( tmp[j][1] ) { tmp[j][1] = (tmp[j][1]-min)/(maxInterval); }
          }

          vis.add(pv.Line)
             .data(tmp)
             .left(function(t) {   return width  * t[0] / 100;} )
             .bottom(function(t) { return height * t[1]; })
             .strokeStyle("rgba(0, 0, 0, .5)")
             .lineWidth(1);
        }

        var percentiles, times, step, y;
        y = pv.Scale.linear(0, maxInterval).range(0,height);
        step = 3600, range=pv.range(0, Math.ceil(maxInterval/step)*step, step);
        times = vis.add(pv.Rule)
                   .data(function() { return range; })
                   .bottom(y)
                   .strokeStyle("#eee");
        times.anchor('left').add(pv.Label)
             .textStyle('#000')
             .text(function(s) { return Math.round(s/step); });

        percentiles = vis.add(pv.Rule)
                         .data(order)
                         .left(function(s) { return width * s.value/100; } )
                         .strokeStyle( '#eee' );
        percentiles.anchor('bottom').add(pv.Label)
                   .textStyle('#000')
                   .text(function(s) { return s.value+'%'; });

        dom.title.innerHTML = 'Found '+newResult.length+' completed blocks out of '+result.length+' candidates';
        vis.render();
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','protovisdemo');
