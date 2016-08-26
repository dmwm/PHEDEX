from __future__ import print_function
import cgi, cgitb, warnings
cgitb.enable()


from graphtool.base.xml_config import XmlConfig
from graphtool.graphs.graph import draw_empty
try:
    import cStringIO as StringIO
except ImportError: # python3
    import io as StringIO
except:
    import StringIO

warnings.filterwarnings('ignore', 'integer argument expected, got float')

if __name__ == '__main__':
  xc = XmlConfig( file="$GRAPHTOOL_CONFIG_ROOT/phedex_graphs.xml" )
  classes = xc.find_classes()
  phedex_grapher = classes['phedex_grapher']
  form = cgi.FieldStorage()
  my_input = {}
  for key in form.keys():
    my_input[key] = form.getfirst( key )
  query_name = form.getfirst("graph")
  try:
    image = phedex_grapher.run_query( query_name, **my_input )
  except Exception as e:
    image = StringIO.StringIO()
    draw_empty( "Error drawing graph:\n%s" % str(e), image, my_input )
    image = image.getvalue()
  print("Content-Type: image/png")
  print()
  print(image)
