from graphtool.base import GraphToolInfo

class NodeInfo( GraphToolInfo ):
  
  def __init__( self, *args, **kw ):
    super( NodeInfo, self ).__init__( *args, **kw )
    self.consume_keyword( 'node' )

class LinkInfo( GraphToolInfo ):
  
  def __init__( self, *args, **kw ):
    super( LinkInfo, self ).__init__( *args, **kw )
    self.consume_keyword( 'to_node' ) 
    self.consume_keyword( 'from_node' )

class DPSInfo( GraphToolInfo ):
  
  def __init__( self, *args, **kw ): 
    super( DPSInfo, self ).__init__( *args, **kw )
    self.consume_keyword( 'lfn' ) 
    self.consume_keyword( 'block' ) 
    self.consume_keyword( 'dataset' )

