
import sys
import time
from threading import Thread
from sets import Set as set

import pydot
from matplotlib import cm
import cherrypy

pydot.EDGE_ATTRIBUTES.add("penwidth")

from graphtool.base.xml_config import XmlConfig

class GraphViz(XmlConfig):

    update_interval = 60
    conns = ['Prod/NEBRASKA', 'Debug/NEBRASKA']
 
    def __init__(self, dom):
        super(GraphViz, self).__init__(dom)
        self.lastUpdate = 0
        self.info = {}
        self.query_rates()
        self.killFlag = False
        self.c = cm.get_cmap("RdYlGn")
        self.updateThread = Thread(target=self.ruleCron)
        self.updateThread.start()

    def query_rates(self):
        results, metadata = self.globals['DataQueries'].rates_query( \
            from_node='.*', to_node='.*')
        for link in results:
            self.info[link] = results[link][None]

    def ruleCron(self):
        while self.killFlag == False:
            time.sleep(1)
            now = time.time()
            if now - self.update_interval > self.lastUpdate:
                try:
                    self.query_rates()
                except:
                    raise
                    pass
                self.lastUpdate = time.time()

    def kill(self):
        self.killFlag = True
    
    _cp_config = {}

    def t1_or_t0(self, link):
        if link.find('T2') >= 0:
            return False
        if link.find('MSS') >= 0:
            return False
        return True

    def t1(self, **kw):
        g = pydot.Dot('T1s')
        nodes = set()
        for link, info in self.info.items():
            done, gb, rate, fail = info
            perc = done / float(done + fail)
            color = [int(255*i) for i in self.c(perc)]
            color = "#%02x%02x%02x%02x" % tuple(color)
            if not self.t1_or_t0(link[0]) or not self.t1_or_t0(link[1]):
                continue
            nodes.add(link[0])
            nodes.add(link[1])
            tooltip = "%s to %s:\n%i successful files, %i failed\n" \
                "Average rate: %.1fMB/s" % (link[0], link[1], done, fail, rate)
            base = self.globals['query_xml'].metadata['base_url']
            url= base + ('/quantity_rates?to_node=%s&from_node=%s' % (link[1], \
                link[0]))
            g.add_edge(pydot.Edge(link[0], link[1], color=color, URL=url,
                label='%.1f' % rate, penwidth='3', ))
        for node in nodes:
            url = self.metadata['base_url'] + '/site/' + node + '?type=svg'
            g.add_node(pydot.Node(node, URL=url, fontsize='16',
                fillcolor='white', style='filled'))
        if 'type' in kw and kw['type'] == 'dot':
            return g.to_string()
        if 'type' in kw and kw['type'] == 'svg':
            cherrypy.response.headers['Content-Type'] = 'image/svg+xml'
            return g.create_svg()
        cherrypy.response.headers['Content-Type'] = 'image/png'
        return g.create_png()
    t1.exposed = True

    def region(self, site, **kw):
        g = pydot.Dot('%s' % site)
        nodes = set()
        for link in self.info:
            if link[0] == site or link[1] == site:
                nodes.add(link[0])
                nodes.add(link[1])
        for link, info in self.info.items():
            done, gb, rate, fail = info
            perc = done / float(done + fail)
            color = [int(255*i) for i in self.c(perc)]
            color = "#%02x%02x%02x%02x" % tuple(color)
            if link[0] not in nodes or link[1] not in nodes:
                continue
            tooltip = "%s to %s:\n%i successful files, %i failed\n" \
                "Average rate: %.1fMB/s" % (link[0], link[1], done, fail, rate)
            base = self.globals['query_xml'].metadata['base_url']
            url= base + ('/quantity_rates?to_node=%s&from_node=%s' % (link[1], \
                link[0]))
            g.add_edge(pydot.Edge(link[0], link[1], color=color, URL=url,
                label='%.1f' % rate, penwidth='3', ))
        for node in nodes:
            url = self.metadata['base_url'] + '/site/' + node + '?type=svg'
            g.add_node(pydot.Node(node, URL=url, fontsize='16',
                fillcolor='white', style='filled'))
        if 'type' in kw and kw['type'] == 'dot':
            return g.to_string()
        if 'type' in kw and kw['type'] == 'svg':
            cherrypy.response.headers['Content-Type'] = 'image/svg+xml'
            return g.create_svg()
        cherrypy.response.headers['Content-Type'] = 'image/png'
        return g.create_png()
    region.exposed = True

    def site(self, site, **kw):
        g = pydot.Dot(graph_name='%s' % site)
        nodes = set()
        for link, info in self.info.items():
            done, gb, rate, fail = info
            perc = done / float(done + fail)
            color = [int(255*i) for i in self.c(perc)]
            color = "#%02x%02x%02x%02x" % tuple(color)
            if link[0] != site and link[1] != site:
                continue
            nodes.add(link[0])
            nodes.add(link[1])
            tooltip = "%s to %s:\n%i successful files, %i failed\n" \
                "Average rate: %.1fMB/s" % (link[0], link[1], done, fail, rate)
            base = self.globals['query_xml'].metadata['base_url']
            url= base + ('/quantity_rates?to_node=%s&from_node=%s' % (link[1], \
                link[0]))
            g.add_edge(pydot.Edge(link[0], link[1], color=color, URL=url,
                label='%.1f' % rate, penwidth='3', ))
        for node in nodes:
            url = self.metadata['base_url'] + '/site/' + node + '?type=svg'
            g.add_node(pydot.Node(node, URL=url, fontsize='16', 
                fillcolor='white', style='filled'))
        if 'type' in kw and kw['type'] == 'dot':
            return g.to_string()
        if 'type' in kw and kw['type'] == 'svg':
            cherrypy.response.headers['Content-Type'] = 'image/svg+xml'
            return g.create_svg()
        cherrypy.response.headers['Content-Type'] = 'image/png'
        return g.create_png()
    site.exposed = True

    def all(self, **kw):
        g = pydot.Dot('PhEDEx')
        for link, info in self.info.items():
            done, gb, rate, fail = info
            perc = done / float(done + fail)
            color = [int(255*i) for i in self.c(perc)]
            color = "#%02x%02x%02x%02x" % tuple(color)
            g.add_edge(pydot.Edge(link[0], link[1], color=color,
                label='%.1f' % rate))
        if 'type' in kw and kw['type'] == 'svg':
            cherrypy.response.headers['Content-Type'] = 'image/svg+xml'
            return g.create_svg()
        if 'type' in kw and kw['type'] == 'dot':
            return g.to_string()
        cherrypy.response.headers['Content-Type'] = 'image/png'
        return g.create_png()
    all.exposed = True

    def default(self, **kw):
        return "GraphViz generated Graphs."
    default.exposed = True

    def getLastUpdate(self):
        return str(time.time() - self.lastUpdate)
    getLastUpdate.exposed = True

