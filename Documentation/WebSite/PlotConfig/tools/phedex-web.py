#!/usr/bin/env python
from graphtool.base.xml_config import XmlConfig
import sys, cherrypy
xc = XmlConfig(file=sys.argv[1])
cherrypy.quickstart()
cherrypy.engine.start()
xc.globals['web'].kill()
