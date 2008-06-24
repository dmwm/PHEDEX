#!/usr/bin/env python

from graphtool.base.xml_config import XmlConfig
import cherrypy

if __name__ == '__main__':
  xc = XmlConfig( file='$GRAPHTOOL_CONFIG_ROOT/website_dev.xml' ) 
  cherrypy.server.quickstart()
  cherrypy.engine.start() 
  xc.globals['web'].kill()

