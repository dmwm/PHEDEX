# phedex python tools
# by Fred Stober (stober@cern.ch)

import logging

log = logging.getLogger('phedex')

# perform queries against the json dataservice of phedex
def query_phedex(api, params, instance = 'prod', cert = None):
	log.info('Starting phedex query %s with %r' % (api, params))
	import webservice_api
	url = 'https://cmsweb.cern.ch/phedex/datasvc/json/%s/%s' % (instance, api)
	result = webservice_api.readJSON(url, params, cert = cert)
	if 'phedex' not in result:
		raise Exception('Unexpected phedex result: %r' % result)
	return result['phedex']
