#!/usr/bin/env python

from twisted.web.resource import Resource
import os
from twisted.application import service, internet
from twisted.web import static, server

import cx_Oracle

from graphtool.base.xml_config import XmlConfig
conf = XmlConfig(file='config.xml')
mapper = conf.globals['mapper']

class HelloResource(Resource):

    isLeaf = True

    def render_GET(self, request):
        info = request.path.split('/')[1:]
        args = self.parse_args(request.args)
        if info[0] == 'xml' and len(info) == 1:
            request.setHeader('Content-Type', 'text/xml')
            request.write(mapper.xml())
        elif info[0] == 'xml' and len(info) == 2:
            request.setHeader('Content-Type', 'text/xml')
            request.write(mapper.xml(info[1]))
        elif info[0] == 'map' and len(info) == 2:
            request.write(mapper.map(info[1], **args))
        elif info[0] == 'map_se' and len(info) == 2:
            request.write(mapper.map_se(info[1], **args))
        else:
            raise Exception("Unknown command: %s" % request.path)
        request.finish()
        return server.NOT_DONE_YET

    def parse_args(self, args):
        ret_args = {}
        for key, val in args.items():
            if len(val) == 1:
                ret_args[key] = val[0]
            else:
                ret_args[key] = val
        return ret_args

def makeWebService():
    my_server = server.Site(HelloResource())
    return internet.TCPServer(8079, my_server)

application = service.Application("Demo application")

service = makeWebService()
service.setServiceParent(application)

