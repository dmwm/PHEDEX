# DAS python tools
# by Fred Stober (stober@cern.ch)

import logging, time

log = logging.getLogger('data_aggregation_system')

# Perform DAS query
def query_das(query):
	log.info('Starting DAS query %r' % query)
	import webservice_api
	(start, sleep) = (time.time(), 0.4)
	url = 'https://cmsweb.cern.ch/das/cache'
	while time.time() - start < 60:
		tmp = webservice_api.readURL(url, {"input": query}, {"Accept": "application/json"})
		if len(tmp) != 32:
			return webservice_api.parseJSON(tmp)['data']
		log.debug('Waiting %.1f sec for DAS query' % sleep)
		time.sleep(sleep)
		sleep += 0.4

# Get general dataset information from DAS
def get_das_dataset_info(dataset):
	log.info('Query dataset information about %s' % dataset)
	result = {}
	for x1 in query_das('dataset dataset=%s status=*' % dataset):
		for x2 in x1['dataset']:
			result.update(x2)
	return result
