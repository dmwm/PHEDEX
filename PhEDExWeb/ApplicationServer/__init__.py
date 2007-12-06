"PhEDEx pages"
from Framework.PluginManager import DeclarePlugin
from Framework import Controller, StaticController, templatepage
from Tools.Functors import AlwaysFalse

from Tools.SiteDBCore import SiteDBApi, SiteResources, SiteSurvey, SAM

from Tools.SecurityModuleCore.SecurityDBApi import SecurityDBApi
from Tools.SecurityModuleCore import SecurityToken, RedirectToLocalPage, RedirectAway, RedirectorToLogin
from Tools.SecurityModuleCore import Group, Role, NotAuthenticated, FetchFromArgs
from Tools.SecurityModuleCore import is_authorized, is_authenticated, has_site

import urllib
import ConfigParser

import sys
import os
import time, calendar, datetime
from os import getcwd, listdir
from os.path import join, exists
from os import getenv

from cherrypy import expose, HTTPRedirect, request

def phedexNotAuthenticated (*args, **kw):
    args[0].context.Logger().message("Unauthenticated access atempted")
    page = args[0].context.CmdLineArgs().opts.baseUrl + request.request_line.split()[1]
    return args[0].templatePage ("SiteDBNotAuthenticated",{"page":page})

def return_type (returnType):
        def decorator (func):
            import cherrypy
            def wrapper (*args, **kwds):
                    cherrypy.response.headers['Content-Type'] = returnType
                    return func (*args, **kwds)
            wrapper.__name__ = func.__name__
            wrapper.__doc__ = func.__doc__
            return wrapper
        return decorator
#TODO: Set global flag if import of security stuff fails to import
#TODO: Get software list via ajax callback
#TODO: XML output
class Page(Controller):
    database = ''
    dbtype = ''
    title = 'Untitled Page'
    basepath = ''
    db = ''
    baseurl = ''

    @templatepage  
    def request(self):
        return {}
DeclarePlugin ("/Controllers/PhEDEx/Root", Page, options={"baseUrl": "/phedex"})