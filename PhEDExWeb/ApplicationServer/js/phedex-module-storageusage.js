PHEDEX.namespace('Module');
PHEDEX.Module.StorageUsage = function(sandbox, string) {
  Yla(this,new PHEDEX.Protovis(sandbox,string));

  var _sbx = sandbox, collName, level=3;
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
        if ( collName ) { return true; }
        return false;
      },
      getState: function() { return {collName:collName}; },
      initData: function() {
        this.dom.title.innerHTML = 'Waiting for parameters to be set...';
        if ( collName ) {
          _sbx.notify( this.id, 'initData' );
          return;
        }
        _sbx.notify( 'module', 'needArguments', this.id );
      },
     setArgs: function(arr) {
        if ( !arr )          { return; }
        if ( !arr.collName ) { return; }
        if ( arr.collName == collName ) { return; }
        collName = arr.collName;
        this.dom.title.innerHTML = 'setting parameters...';
        _sbx.notify(this.id,'setArgs');
      },

      getData: function() {
// customisable stuff starts here. Check that the 'collName' is defined. If not, go ask for a value. If yes, get the data
        if ( !collName ) {
          this.initData();
          return;
        }
        this.dom.title.innerHTML = 'fetching data...';
        log('Fetching data','info',this.me);
        _sbx.notify( this.id, 'getData', { api:'storageusage', args:{collName:collName,level:level} } );
      },
     gotData: function(data,context,response) {
        var max=0, tmp={}, tree={}, i, j, k, _level, item, node, timebins, timebin, total=0, path;
        PHEDEX.Datasvc.throwIfError(data,response);
        log('Got new data','info',this.me);
        this.dom.title.innerHTML = 'Parsing data';

        if ( !data.nodes ) {
          throw new Error('data incomplete for '+context.api);
        }

// parse the data into the pvData structure.
        for ( i in data.nodes ) {
          node = data.nodes[i];
          timebin = node.timebins[0];
          this.dom.title.innerHTML = 'Node: '+collName+' Root: "'+node.subdir+'" Time: '+PxUf.UnixEpochToUTC(timebin.timestamp);
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
        if ( j ) { tree['other'] = j; } // yes, 'tree', not 'tmp'!
        for ( i in tmp ) {
          path = i.split('/');
          path.shift();
          k = tree;
          for ( j in path ) {
            if ( parseInt(j)+1 == path.length ) {
              k[i] = tmp[i];
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
            .canvas(this.dom.body)
            .width(w)
            .height(h)
            .bottom(20)
            .left(20)
            .right(10)
            .top(5);

        function title(d) {
  var v;
  if ( d.parentNode ) {
    v = title(d.parentNode) + '/' + d.nodeName;
  } else {
    v = '';
  }
  return v; }
// return d.parentNode ? (title(d.parentNode) + "/" + d.nodeName) : d.nodeName; }

        var re = "",
            color = pv.Colors.category19().by(function(d) { d.parentNode.nodeName; })
            nodes = pv.dom(tree).root("tree").nodes();

        var treemap = vis.add(pv.Layout.Treemap)
            .nodes(nodes)
            .round(true);

        treemap.leaf.add(pv.Panel)
            .fillStyle(function(d) color(d).alpha(title(d).match(re) ? 1 : .2))
            .strokeStyle("#fff")
            .lineWidth(1)
            .antialias(false);

        treemap.label.add(pv.Label)
            .textStyle(function(d) pv.rgb(0, 0, 0, title(d).match(re) ? 1 : .2));

        vis.render();
      }
    };
  };
  Yla(this,_construct(this),true);
  return this;
};
log('loaded...','info','storageusage');
