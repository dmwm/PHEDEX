#!/usr/bin/env python

import os
import urllib2
from xml.dom.minidom import parse

import pydot
from matplotlib import cm

sites = {}
sites['T1_ASGC_Buffer'] = ['India', 'KNU', 'Taiwan', 'NCP', 'ASGC_MSS']
sites['T1_CNAF_Buffer'] = ['Bari', 'Legnaro', 'Pisa', 'Rome', 'CNAF_MSS']
sites['T1_FNAL_Buffer'] = ['Caltech', 'Florida', 'MIT', 'Nebraska', 'Purdue', 
                 'UERJ', 'UCSD', 'Wisconsin', 'FNAL_MSS', 'SPRACE', 'TTU']
sites['T1_FZK_Buffer']  = ['RWTH', 'DESY', 'CSCS', 'Warsaw', 'FZK_MSS']
sites['T1_IN2P3_Buffer']= ['GRIF', 'Beijing', 'Belgium', 'PKU', 'IN2P3_MSS']
sites['T1_PIC_Buffer']  = ['CIEMAT', 'IFCA', 'LIP_Coimbra', 'LIP_Lisbon', 
                           'PIC_MSS']
sites['T1_RAL_Buffer']  = ['Bristol', 'Estonia', 'Helsinki', 'London', 
                           'Rutherford', 'RAL_MSS']
sites['T1_CERN_Buffer'] = ['CH_CAF', 'CERN_MSS', 'ITEP', 'HIP', 'IRES']

url = "http://t2.unl.edu/phedex/xml/rates_query?from_node=.*&to_node=.*&" \
      "conn=Debug/NEBRASKA"

def is_non_t1(site, t2s):
    if (site.startswith("T2_") or site.startswith("T3_") or \
            site.find("MSS") >= 0) and site not in t2s:
        t2s.append(site)

def is_t1(site, t1s):
    if site.startswith("T1_") and site not in t1s:
        t1s.append(site)

dom = parse(urllib2.urlopen(url))
c = cm.get_cmap("RdYlGn")
done_dict = {}
fail_dict = {}
rate_dict = {}
t2s = []
t1s = []
g = pydot.Dot(ratio="fill", center="1")
for pivot_dom in dom.getElementsByTagName("pivot"):
    pivot_name = pivot_dom.getAttribute("name")
    from_node, to_node = eval(pivot_name, {})
    data = pivot_dom.getElementsByTagName("d")
    done = float(data[0].firstChild.data)
    fail = float(data[3].firstChild.data)
    rate = float(data[2].firstChild.data)
    done_dict[(from_node, to_node)] = done
    fail_dict[(from_node, to_node)] = fail
    rate_dict[(from_node, to_node)] = rate
    is_non_t1(from_node, t2s)
    is_non_t1(to_node, t2s)
    is_t1(from_node, t1s)
    is_t1(to_node, t1s)
    
max_done = max(done_dict.values())

for t1 in sites:
    t1_name = None
    for t1n in t1s:
        if t1n.find(t1) >= 0 and t1n.find("MSS") < 0:
            t1_name = t1n
            break
    if not t1_name:
        continue
    clust = pydot.Cluster(graph_name=t1_name, suppress_disconnected=False,
                          color='blue')
    clust.add_node(pydot.Node(t1, fillcolor="pink"))
    nodes = [t1_name]
    for t2 in sites[t1]:
        for t2_name in t2s:
            if t2_name.find(t2) >= 0:
                clust.add_node(pydot.Node(t2_name))
                nodes.append(t2_name)
    remaining_dict = {}
    for link in done_dict:
        from_node, to_node = link
        if from_node in nodes and to_node in nodes:
            done = done_dict[link]
            fail = fail_dict[link]
            perc = done / float(done+fail)
            color = [int(255*i) for i in c(perc)]
            color = "#%02x%02x%02x%02x" % tuple(color)
            width = max(5*done/float(max_done),.5)
            clust.add_edge(pydot.Edge(from_node, to_node, setlinewidth=str(width), label="%.1f" % rate_dict[link],
                       color=color, penwidth=str(width)))
        else:
            remaining_dict[link] = done_dict[link]
    done_dict = remaining_dict    
    g.add_subgraph(clust)

for link in done_dict:
    done = done_dict[link]
    fail = fail_dict[link]
    perc = done / float(done+fail)
    color = [int(255*i) for i in c(perc)]
    color = "#%02x%02x%02x%02x" % tuple(color)
    width = max(5*done/float(max_done),.5)
    g.add_edge(pydot.Edge(link[0], link[1], setlinewidth=str(width), color=color, penwidth=str(width), )) # label="%.1f" % rate_dict[link]))
    
g.write_png(os.path.expandvars("$HOME/tmp/phedex_topo2.png"))

