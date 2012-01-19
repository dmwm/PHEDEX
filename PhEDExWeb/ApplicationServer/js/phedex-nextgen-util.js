PHEDEX.namespace('Nextgen');
PHEDEX.Nextgen.Util = function() {
  var Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      _sbx = new PHEDEX.Sandbox();

  return {
    NodePanel: function(obj,parent,default_nodes) {
      var nodePanel, seq=PxU.Sequence(),
          selfHandler = function(o) {
        return function(ev,arr) {
          var action = arr[0],
              value  = arr[1], i;
          switch (action) {
            case 'SelectAllNodes': {
              for ( i in nodePanel.elList ) { nodePanel.elList[i].checked = true; }
              break;
            }
            case 'DeselectAllNodes': {
              for ( i in nodePanel.elList ) { nodePanel.elList[i].checked = false; }
              break;
            }
          }
        }
      }(obj);
      _sbx.listen(obj.id, selfHandler);

      nodePanel = { nodes:[], selected:[], map:{ byName:{}, byId:{} } };
      if ( typeof(parent) != 'object' ) { parent = Dom.get(parent); }
      nodePanel.dom = { parent:parent };
      var makeNodePanel = function(o) {
        return function(data,context,response) {
          var nodes=[], node, i, j, k, l, checked,
            instance=PHEDEX.Datasvc.Instance();

          if ( !data.node ) {
            parent.innerHTML = '&nbsp;<strong>Error</strong> loading node names, cannot continue';
            Dom.addClass(parent,'phedex-box-red');
            _sbx.notify(o.id,'NodeListLoadFailed');
            return;
          }
          _sbx.notify(o.id,'NodeListLoaded');
          for ( i in data.node ) {
            node = data.node[i];
            if ( instance.instance != 'prod' ) { nodes.push(node); }
            else {
              if ( node.name.match(/^T(0|1|2|3)_/) && !node.name.match(/^T[01]_.*_(Buffer|Export)$/) ) { nodes.push(node); }
            }
          }
          nodes = nodes.sort( function(a,b) { return YAHOO.util.Sort.compare(a.name,b.name); } );
          parent.innerHTML = '';
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            nodePanel.map.byName[node.name] = node.id;
            nodePanel.map.byId[node.id]     = node.name;
            node.name.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              parent.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            checked = null;
            for ( l in default_nodes ) {
              if ( default_nodes[l] == node.id || default_nodes[l] == node.name ) {
                checked = 'checked';
              }
            }
            parent.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'>" +
                                  "<input class='phedex-checkbox' type='checkbox' name='"+node.name+"' "+checked+"/>"+node.name +
                                "</div>";
            nodePanel.nodes.push(node.name);
          }
          nodePanel.elList = Dom.getElementsByClassName('phedex-checkbox','input',parent);
          var onSelectClick =function(event, matchedEl, container) {
            if (Dom.hasClass(matchedEl, 'phedex-checkbox')) {
              _sbx.notify(o.id,'NodeSelected', matchedEl.name, matchedEl.checked);
            }
          };
          YAHOO.util.Event.delegate(parent, 'click', onSelectClick, 'input');
        }
      }(obj);
      PHEDEX.Datasvc.Call({ api:'nodes', callback:makeNodePanel });
      return nodePanel;
    },
    CBoxPanel: function(obj,parent, config) {
      var el, panel, seq=PxU.Sequence(), name=config.name, items=config.items,
          elList, item,
          selfHandler = function(o) {
        return function(ev,arr) {
          var action=arr[0], elList=panel.elList, el, label, i;
          switch (action) {
            case 'SelectAll-'+name: {
              for ( i in elList ) { elList[i].checked = true; }
              _sbx.notify(obj.id,'DoneSelectAll-'+name);
              break;
            }
            case 'DeselectAll-'+name: {
              for ( i in elList ) { elList[i].checked = false; }
              _sbx.notify(obj.id,'DoneDeselectAll-'+name);
              break;
            }
            case 'Reset-'+name: {
              for ( i in elList ) { elList[i].checked = panel.items[i]._default; }
              _sbx.notify(obj.id,'DoneReset-'+name);
              break;
            }
            case 'CBox-set-'+name: {
              label = arr[1];
              for ( i in elList ) {
                el = elList[i];
                if ( el.name == label ) {
                  el.checked = arr[2];
                  break;
                }
              }
              break;
            }
            default: {
              break;
            }
          }
        }
      }(obj);
      _sbx.listen(obj.id, selfHandler);

      panel = { items:items };
      el = document.createElement('div');
      if ( typeof(parent) != 'object' ) { parent = Dom.get(parent); }
      panel.dom = { parent:parent };
      var item, i;
      parent.innerHTML = '';
      for ( i in items ) {
        item = items[i];
        parent.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input class='phedex-checkbox' type='checkbox' name='"+item.label+"' />"+item.label+"</div>";
      }
      elList = panel.elList = Dom.getElementsByClassName('phedex-checkbox','input',parent);
      for ( i in elList ) {
        item = items[i];
        elList[i].checked = item._default;
      }
      var onSelectClick =function(event, matchedEl, container) {
        if (Dom.hasClass(matchedEl, 'phedex-checkbox')) {
          _sbx.notify(obj.id,'CBoxPanel-selected', matchedEl.name, matchedEl.checked);
        }
      };
      YAHOO.util.Event.delegate(parent, 'click', onSelectClick, 'input');

      return panel;
    },
    makeResizable: function(wrapper,el,cfg) {
      var resize = new YAHOO.util.Resize(wrapper,cfg);
      resize.on('resize', function(_el) {
        return function(e) {
          Dom.setStyle(_el, 'width',  (e.width  - 7) + 'px');
          Dom.setStyle(_el, 'height', (e.height - 7) + 'px');
        }}(el), resize, true);
    },
    authHelpMessage: function() {
      var str = '', i, j, k, text, roles, role, arg, auth,
          args = Array.apply(null,arguments),
          auths = {
                    'cert':'grid certificate authentication',
                    'any': 'to log in via grid certificate or password'
                  };
      for ( i in args ) {
        arg = args[i];
        auth = arg.need;
        text = arg.to;
        roles = arg.role;

        str += '<p>You need <strong>'+auths[auth]+'</strong> and to be a ';
        j = roles.length;
        for ( k=0; k<j; k++ ) {
          role = roles[k];
          str += "<strong>'"+role+"'</strong>";
          if ( j>1 ) {
            if ( j == k+2 ) { str += ' or '; }
            else            { str += ', '; }
          }
        }
        str += ' in order to '+text+'</p>';
      }
      str += "<hr class='phedex-nextgen-hr'>" +
             "<p>Passwords are managed via "+
             "<a href='/sitedb/sitedb/sitelist/'>SiteDB</a> and are synced with the CMS hypernews passwords.</p>" +
             "<p>See the <a href='http://lcg.web.cern.ch/lcg/registration.htm'>LCG registration page</a> to find help on obtaining a grid certificate.</p>" +
             "<p>Authorization roles are handled by <a href='/sitedb/sitedb/sitelist/'>SiteDB.</a> If you're logged in, you can click on your name (top-right of this page) to see which PhEDEx roles you have</p>" +
             "<p>If you think you have the necessary rights in SiteDB and are logged in " +
             "with your certificate or password but you are still having problems with this page you may " +
             "<a href='mailto:cms-phedex-admins@cern.ch'>contact the PhEDEx developers</a>.</p>";
      return str;
    },
    parseBlockName: function(string) {
      if ( string.match(/(\/[^/]+\/[^/]+\/[^/#]+)(#.*)?$/ ) ) {
        if ( RegExp.$2 ) {
          return 'BLOCK';
        }
        return 'DATASET';
      }
      return null;
    }
  }
}();
