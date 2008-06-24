#!/usr/bin/env python

import os
import urllib2
from xml.dom.minidom import parse

import pydot
from matplotlib import cm

url = "http://t2.unl.edu/phedex/xml/rates_query?from_node=.*&to_node=.*"
dom = parse(urllib2.urlopen(url))
c = cm.get_cmap("RdYlGn")
done_dict = {}
fail_dict = {}
g = pydot.Dot() #graph_name="PhEDEx Transfer Quality")
for pivot_dom in dom.getElementsByTagName("pivot"):
    pivot_name = pivot_dom.getAttribute("name")
    from_node, to_node = eval(pivot_name, {})
    data = pivot_dom.getElementsByTagName("d")
    done = float(data[0].firstChild.data)
    fail = float(data[3].firstChild.data)
    done_dict[(from_node, to_node)] = done
    fail_dict[(from_node, to_node)] = fail
max_done = max(done_dict.values())
for link in done_dict:
    done = done_dict[link]
    fail = fail_dict[link]
    perc = done / float(done+fail)
    color = [int(255*i) for i in c(perc)]
    color = "#%02x%02x%02x%02x" % tuple(color)
    width = max(5*done/float(max_done),.5)
    g.add_edge(pydot.Edge(link[0], link[1], penwidth=str(width), color=color))
    
g.write_png(os.path.expandvars("$HOME/tmp/phedex_topo.png"))

