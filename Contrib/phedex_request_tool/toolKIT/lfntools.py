# LFN python tools
# by Fred Stober (stober@cern.ch)

import os, logging

log = logging.getLogger('data_management')

# get common directory for list of paths
def get_common_directory(paths):
	log.info('Determining common directory of %d paths' % len(paths))
	commonpath = paths[0]
	for path in paths:
		while (commonpath != '') and (commonpath not in path):
			commonpath = os.path.dirname(commonpath)
	log.debug('Common directory is %s' % commonpath)
	return commonpath

# get tag directory for dataset
def get_tag_directory(dataset, lfn_list):
	log.info('Determine tag directory for dataset %s' % dataset)
	tagdir = set()
	for lfn in lfn_list:
		tagdir.add(str.join('/', lfn.split('/')[:6])) # use the first 5 directories
	if len(tagdir) != 1:
		raise Exception('No unique tag directory found! %r' % tagdir)
	result = tagdir.pop()
	log.debug('Tag directory is %s' % result)
	return result

# Translate lfn to physical path
def lfn2pfn(lfn):
	mount = os.path.realpath(os.path.expanduser('/home/cmssgm/storage_dcache'))
	return os.path.join(mount, lfn.lstrip('/'))
