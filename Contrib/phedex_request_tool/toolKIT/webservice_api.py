# Helper to access CMS webservices (SiteDB, Phedex)
# by Fred Stober (stober@cern.ch) - copied from grid-control

import logging, os
log = logging.getLogger('webservice')

def user_agent(value):
	user_agent.value = value
user_agent.value = 'toolKIT/0.1'

def removeUnicode(obj):
	if type(obj) in (list, tuple, set):
		(obj, oldType) = (list(obj), type(obj))
		for i, v in enumerate(obj):
			obj[i] = removeUnicode(v)
		obj = oldType(obj)
	elif isinstance(obj, dict):
		result = {}
		for k, v in obj.iteritems():
			result[removeUnicode(k)] = removeUnicode(v)
		return result
	elif isinstance(obj, unicode):
		return str(obj)
	return obj

def readURL(url, params = None, headers = {}, cert = None):
	headers.setdefault('User-Agent', user_agent.value)

	import urllib, urllib2, httplib
	class HTTPSClientAuthHandler(urllib2.HTTPSHandler):
		def __init__(self, key, cert):
			urllib2.HTTPSHandler.__init__(self)
			(self.key, self.cert) = (key, cert)
		def https_open(self, req):
			return self.do_open(self.getConnection, req)
		def getConnection(self, host, timeout = None):
			return httplib.HTTPSConnection(host, key_file=self.key, cert_file=self.cert)

	if cert:
		cert_handler = HTTPSClientAuthHandler(cert, cert)
		opener = urllib2.build_opener(cert_handler)
		urllib2.install_opener(opener)

	url_arg = urllib.urlencode(params, doseq=True)
	log.info('Starting http query: %r %r' % (url, url_arg))
	log.debug('Connecting with header: %r' % headers)
	return urllib2.urlopen(urllib2.Request(url, url_arg, headers)).read()

def parseJSON(data):
	import json
	return removeUnicode(json.loads(data))

def readJSON(url, params = None, headers = {}, cert = None):
	return parseJSON(readURL(url, params, headers, cert))
