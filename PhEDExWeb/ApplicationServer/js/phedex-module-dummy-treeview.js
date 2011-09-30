/**
 * This is a dummy module, with no DOM or data-service interaction. It provides only the basic interaction needed for the core to be able to control it, for debugging or stress-testing the core and sandbox.
 * @namespace PHEDEX.Module.Dumy
 * @class TreeView
 * @constructor
 * @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
 * @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
 */
PHEDEX.namespace('Module.Dummy');
PHEDEX.Module.Dummy.TreeView = function(sandbox, string) {
  Yla(this,new PHEDEX.TreeView(sandbox,string));
  var _sbx = sandbox;
  _construct = function(obj) {
    return {
      decorators: [
        {
          name: 'Headers',
          source:'component-control',
          parent: 'control',
          payload:{
            target: 'extra',
            animate:false,
          }
        },
        {
          name: 'ContextMenu',
          source:'component-contextmenu',
        },
        {
          name: 'cMenuButton',
          source:'component-splitbutton',
          payload:{
            name:'Show all fields',
            map: {
              hideColumn:'addMenuItem',
            },
            container: 'buttons',
          },
        },
      ],
      meta: {
        tree: [
          {
            width:1200,
            name:'Block',
            format: [
              {width:300,text:'Field-1', className:'phedex-tree-block-field1', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'], spanWrap:true },
              {width:300,text:'Field-2', className:'phedex-tree-block-field2', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'] },
//               {width:60,text:'Field-3', className:'phedex-tree-block-field3', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'] },
//               {width:60,text:'Field-4', className:'phedex-tree-block-field4', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'] },
//               {width:60,text:'Field-5', className:'phedex-tree-block-field5', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'] },
//               {width:60,text:'Field-6', className:'phedex-tree-block-field6', otherClasses:'align-left',  ctxArgs:['block','sort-alpha'] },
            ]
          },
        ],
// Filter-structure mimics the branch-structure. Use the same classnames as keys.
        filter: {
          'Block-level attributes':{
            map:{from:'phedex-tree-block-', to:'B'},
            fields:{
              'phedex-tree-block-field1' :{type:'regex', text:'Field 1', tip:'javascript regular expression' },
              'phedex-tree-block-field2' :{type:'regex', text:'Field 2', tip:'javascript regular expression' },
//               'phedex-tree-block-field3' :{type:'regex', text:'Field 3', tip:'javascript regular expression' },
//               'phedex-tree-block-field4' :{type:'regex', text:'Field 4', tip:'javascript regular expression' },
//               'phedex-tree-block-field5' :{type:'regex', text:'Field 5', tip:'javascript regular expression' },
//               'phedex-tree-block-field6' :{type:'regex', text:'Field 6', tip:'javascript regular expression' },
            }
          },
        },
      },

      fillExtra: function() {},
      hideFields: function() {},
      addMenuItem: function() {},
//       init: function(opts) {
//         this._init(opts);
//         _sbx.notify( this.id, 'init' );
//       },
      initData: function() {
        _sbx.notify( this.id, 'initData' );
      },
      getData: function() {
        var tNode, i, j, row;
        for (i=0; i<3; i++) {
          row = [];
          for (j=0; j<2; j++) {
            row.push('this-is-the-value-for-field-'+i+'-'+j);
          }
          tNode = this.addNode(
            { format:this.meta.tree[0].format },
            row
          );
        }
        this.tree.render();
      },
    };
  };
  Yla(this,_construct(this),true);
  return this;
};

log('loaded...','info','dummy-treeview');
