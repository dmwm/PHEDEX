
from graphtool.graphs.graph import DBGraph, TimeGraph
from graphtool.graphs.common_graphs import StackedBarGraph, BarGraph, CumulativeGraph, PieGraph, QualityMap, QualityBarGraph, HorizontalBarGraph
import types

class PhedexGraph( DBGraph ):

  hex_colors = [ "#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                 "#baceac", "#00ccff", "#ccffff", "#ff99cc", "#cc99ff", "#ffcc99",
                 "#3366ff", "#33cccc" ]

  # This is now defined in Graph
  #def preset_colors( self, labels ):
  #  size_labels = len( labels )
  #  hex_colors = self.hex_colors
  #  size_colors = len( hex_colors )
  #  return [ hex_colors[ i % size_colors ] for i in range( size_labels ) ]

  def make_labels_common( self, results ):
    # Figure out the labels: 
    labels = []
    is_link = self.metadata['given_kw']['link'].lower() == 'link'
    keys = self.sort_keys( results )
    for link in keys:
      if is_link and type(link) == types.TupleType:
      #if type(link) == types.TupleType:
        labels.append(str(link[0]) + ' to ' + str(link[1]))
      else:
        labels.append( str(link) )
    labels.reverse()
    return labels

  def setup( self ):

    super( PhedexGraph, self ).setup()

    kw = dict(self.kw)
    results = self.results
    try:
      self.kind = kw['link']
    except:
      self.kind = 'Node'
    #self.labels = self.make_labels_common( results )
    #self.colors = self.preset_colors( self.labels )

    self.columns = self.prefs['columns']
    if self.kind.lower() == 'link':
      self.columns = kw.pop( 'columns', 3 )

class PhedexStackedBar( PhedexGraph, TimeGraph, StackedBarGraph ):

  pass

class PhedexBar( PhedexGraph, TimeGraph, BarGraph ):

  pass

class PhedexCumulative( PhedexGraph, CumulativeGraph ):

  pass

class PhedexPie( PhedexGraph, TimeGraph, PieGraph ):

  pass

class PhedexQualityMap( PhedexGraph, QualityMap ):

  pass

class PhedexQualityBar( PhedexGraph, QualityBarGraph ):

    pass


