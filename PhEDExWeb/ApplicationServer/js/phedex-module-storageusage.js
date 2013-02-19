PHEDEX.namespace('Module');
PHEDEX.Module.StorageUsage = function(sandbox, string) {
  Yla(this,new PHEDEX.Protovis(sandbox,string));

  var _sbx = sandbox, se, level=3, time_since=1, rootdir='/', other='other';
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
      isValid: function() {
        if ( se ) { return true; }
        return false;
      },
      initMe: function() {
        var el = document.createElement('div');
        this.dom.content.appendChild(el);
        this.dom.treemap = el;
        el = document.createElement('div');
        el.style.clear = 'both';
        this.dom.content.appendChild(el);
        el = document.createElement('div');
        this.dom.content.appendChild(el);
        this.dom.stackedChart = el;

        this.selfHandler = function(o) {
          return function(ev,arr) {
            var action = arr[0],
                value = arr[1];
            switch (action) {
              case 'mouseover': {
                break;
              }
              case 'mouseout': {
                break;
              }
              case 'click': {
                if ( level == 6 ) { return; }
                var _rootdir = arr[1].split(' ')[0];
                if ( _rootdir == other ) { return; }
                rootdir = _rootdir;
                level = level+2;
                if ( level > 6 ) { level = 6; }
                _sbx.notify(obj.id,'doGetData');
                break;
              }
              default: {
                break;
              }
            }
          }
        }(this);
        _sbx.listen(this.id,this.selfHandler);
      },
      getState: function() { return {se:se}; },
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( se ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
     setArgs: function(arr) {
        if ( !arr )    { return; }
        if ( !arr.se ) { return; }
        if ( arr.se == se ) { return; }
        se = arr.se;
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
      },
      getData: function() {
// customisable stuff starts here. Check that the 'se' is defined. If not, go ask for a value. If yes, get the data
        if ( !se ) {
          this.initData();
          return;
        }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'storageusage', args:{se:se,level:level,time_since:time_since,rootdir:rootdir} } );
      },
     gotData: function(data,context,response) {
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';

        if ( !data.nodes ) {
          throw new Error('data incomplete for '+context.api);
        }
        
        this.makeStackChart(data);
        this.makeTreemap(data);
      },

      makeStackChart: function(data) {

        var w = 400,
            h = 200,
            x = pv.Scale.linear(0, 30).range(0, w),
            y = pv.Scale.linear(0, 3).range(0, h);
        var n = 10, a, l;
        var total;
        var tmp={},i, j, k, _level, item, node, timebins, timebin, timestamp, path, size;
        var timestamp=2, _timestamp=2;

        for ( i in data.nodes[0].timebins ) {
          timebin = data.nodes[0].timebins[i];
          _level = timebin.levels[1];
          timestamp = Math.round((timebin.timestamp)/(3600*12));
          if(!tmp[timestamp]) {
             tmp[timestamp] = {};
          }
          l = 0;
          total=0;
          for ( k in _level.data ) {
            item = _level.data[k];
            tmp[timestamp][l] = item;
            total += item.size;
            l=l+1;
          }
        }

       // coalesce tiny entries
        var littles;

        for ( i in tmp ) {
          littles = 0;
          a = tmp[i];
          for (j in tmp[i]) {
            item = tmp[i][j];
            if ( (item.size)/total < 0.3 ) {
              littles += item.size;
              //delete tmp[i][j];
            }
          }
          if ( littles ) { 
             item.dir = 'other';
             item.size = littles*100;
             tmp[i][j]= item;
          }
        } 

      data = layers(n);
      function layers(n) {
        return pv.range(n).map(function(j) {
          return pv.range(0, 60, 1).map(function(x) {
              var size;
              timestamp = Math.round(1316228745/(3600*12) +x);
              item = tmp[timestamp][j];
              size = (item.size)/(1000*1000*1000*1000*1000);
              return {x: x, y: size};
            });
        });
      }


/* The root panel. */
        var vis = new pv.Panel()
            .canvas(this.dom.stackedChart)
            .width(w)
            .height(h)
            .bottom(20)
            .left(20)
            .right(10)
            .top(5);
           

       vis.add(pv.Label)
            .left(70)
            .top(6)
            .height(h+5)
            .textAlign("center")
            .text("storage size(PB) vs. date(day)");


/* X-axis and ticks. */
        vis.add(pv.Rule)
            .data(x.ticks(30))
            .visible(function(d) { return d;})
            .left(x)
            .bottom(-5)
            .height(5)
          .anchor('bottom').add(pv.Label)
            .text(x.tickFormat);

/* The stack layout. */
        vis.add(pv.Layout.Stack)
            .layers(data)
            .x(function(d) { return x(d.x); })
            .y(function(d) { return y(d.y); })
          .layer.add(pv.Area);

/* Y-axis and ticks. */
        vis.add(pv.Rule)
            .data(y.ticks(10))
            .bottom(y)
            .strokeStyle(function(d) { return d ? 'rgba(128,128,128,.2)' : '#000'; })
          .anchor('left').add(pv.Label)
            .text(y.tickFormat);

        vis.render();
      },
      makeTreemap: function(data) {
        var max=0, tmp={}, tree={}, i, j, k, _level, item, node, timebins, timebin, total=0, path;

        for ( i in data.nodes ) {
          node = data.nodes[i];
          timebin = node.timebins[0];
          this.dom.title.innerHTML = 'Node: '+se+' Root: "'+node.subdir+'" level:'+level+' Time: '+PxUf.UnixEpochToUTC(timebin.timestamp);
          for ( j in timebin.levels ) {
            _level = timebin.levels[j];
            if ( _level.level == level ) {
              for ( k in _level.data ) {
                item = _level.data[k];
                tmp[item.dir] = item.size;
                total += item.size
              }
            }
          }
        }

// coalesce tiny entries
        j = 0;
        for ( i in tmp ) {
          if ( tmp[i]/total < 0.01 ) {
            j += tmp[i];
            delete tmp[i];
          }
        }
        if ( j ) { tree[other] = j; } // yes, 'tree', not 'tmp'!
        for ( i in tmp ) {
          path = i.split('/');
          path.shift();
          k = tree;
          for ( j in path ) {
            if ( parseInt(j)+1 == path.length ) {
              k[path[j]] = tmp[i];
            } else {
              if ( !k[path[j]] ) { k[path[j]] = {}; }
              k = k[path[j]];
            }
          }
        }

//      base options for the canvas. Take some from the module definition, others from the data, etc.
        max = max * 1.5;
        var w = this.options.width,
            h = this.options.height;

/* The root panel. */
        var vis = new pv.Panel()
            .canvas(this.dom.treemap)
            .width(w)
            .height(h)
            .bottom(20)
            .left(20)
            .right(10)
            .top(5);

        function pathName(d) {
          var path = d.parentNode ? pathName(d.parentNode) + '/' + d.nodeName : '';
          if ( path == '/'+other ) { return other; }
          return path;
        }
        function tooltip(d)  { return pathName(d) + ' ' + PxUf.bytes(d.nodeValue); }

        var re = '',
            color = pv.Colors.category20().by(function(d) { return pathName(d.parentNode); }),
            nodes = pv.dom(tree).root('tree').nodes();

        var treemap = vis.add(pv.Layout.Treemap)
            .nodes(nodes)
            .round(true)
            .def('active',-1);

        treemap.leaf.add(pv.Panel)
            .def('i',-1)
            .fillStyle(function(d) { return treemap.active() == this.index ? 'lightyellow' : color(d).alpha(pathName(d).match(re) ? 1 : .2); } )
            .strokeStyle('#fff')
            .lineWidth(1)
            .antialias(false)
            .title(function(d) { return tooltip(d); })
            .event('mouseover',function() { return treemap.active(this.index); } )
            .event('mouseout', function() { return treemap.active(-1); } )
            .event('click', function() { _sbx.notify(obj.id,'click',this.title()); });

        treemap.label.add(pv.Label)
            .textStyle(function(d) { return pv.rgb(0, 0, 0, pathName(d).match(re) ? 1 : .2); } );

        vis.render();
        this.visTreemap = vis;
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','storageusage');
