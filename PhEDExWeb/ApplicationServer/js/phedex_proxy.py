#!/usr/bin/env python

import cherrypy
import urllib,urllib2

class PhEDExProxy:
    def readfile(self,name):
    	return open(name,'r').read()
    readfile.exposed=True
    def phedex(self,*args,**kwargs):
    	#cherrypy.response.headers['Content-Type'] = 'application/json'
    	return urllib2.urlopen('http://lxbuild061.cern.ch:7001/phedex/%s'%('/'.join(args)+'?'+urllib.urlencode(kwargs))).read()
    phedex.exposed=True

cherrypy.config.update({"server.socket_port": 30001})		
cherrypy.quickstart(PhEDExProxy())
