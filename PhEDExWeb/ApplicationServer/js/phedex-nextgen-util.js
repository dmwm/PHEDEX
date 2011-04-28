PHEDEX.namespace('Nextgen');
PHEDEX.Nextgen.Util = function() {
  var Dom = YAHOO.util.Dom,
      Event = YAHOO.util.Event,
      _sbx = new PHEDEX.Sandbox();

  return {
    NodePanel: function(obj,parent) {
      var el, nodePanel, seq=PxU.Sequence(),
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
            default: {
              break;
            }
          }
        }
      }(obj);
      _sbx.listen(obj.id, selfHandler);

      nodePanel = { nodes:[], selected:[] };
      el = document.createElement('div');
      if ( typeof(parent) != 'object' ) { parent = Dom.get(parent); }
      nodePanel.dom = { parent:parent };
      var makeNodePanel = function(o) {
        return function(data,context) {
try { // TW take out the try-catch
          var nodes=[], node, i, j, k,
            instance=PHEDEX.Datasvc.Instance();

          if ( !data.node ) {
            parent.innerHTML = '&nbsp;<strong>Error</strong> loading node names, cannot continue';
            Dom.addClass(parent,'phedex-box-red');
            _sbx.notify(o.id,'NodeListLoadFailed');
            return;
          }
          _sbx.notify(o.id,'NodeListLoaded');
          for ( i in data.node ) {
            node = data.node[i].name;
            if ( instance.instance != 'prod' ) { nodes.push(node ); }
            else {
              if ( node.match(/^T(0|1|2|3)_/) && !node.match(/^T[01]_.*_(Buffer|Export)$/) ) { nodes.push(node ); }
            }
          }
          nodes = nodes.sort();
          parent.innerHTML = '';
          k = '1';
          for ( i in nodes ) {
            node = nodes[i];
            node.match(/^T(0|1|2|3)_/);
            j = RegExp.$1;
            if ( j > k ) {
              parent.innerHTML += "<hr class='phedex-nextgen-hr'>";
              k = j;
            }
            parent.innerHTML += "<div class='phedex-nextgen-nodepanel-elem'><input class='phedex-checkbox' type='checkbox' name='"+node+"' />"+node+"</div>";
            nodePanel.nodes.push(node);
          }
          nodePanel.elList = Dom.getElementsByClassName('phedex-checkbox','input',parent);
          var onSelectClick =function(event, matchedEl, container) {
            if (Dom.hasClass(matchedEl, 'phedex-checkbox')) {
              _sbx.notify(o.id,'NodeSelected', matchedEl.name, matchedEl.checked);
            }
          };
          YAHOO.util.Event.delegate(parent, 'click', onSelectClick, 'input');
} catch(ex) {
var _ex = ex;
debugger;
}
        }
      }(obj);
      PHEDEX.Datasvc.Call({ api:'nodes', callback:makeNodePanel });
      return nodePanel;
    }
  };
}();