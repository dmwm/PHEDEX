# dCache python tools
# by Fred Stober (stober@cern.ch)

import os, logging

log = logging.getLogger('dCache')

dCacheInfo = type('dCacheInfo', (),
	dict(map(lambda (idx, name): (name, idx), enumerate(
		['pfn', 'dcache_id', 'adler32', 'size', 'storage_group', 'location']))))

# Get free space in storage group set for this directory
def dcache_free_space(path):
	log.info('Getting free space on path %s' % path)
	s = os.statvfs(path)
	return s.f_frsize * s.f_bavail

# Get storage group of directory
def get_tape_family(path, no_raise = False):
	log.info('Getting tape family for path %s' % path)
	if not os.path.exists(path):
		log.debug('Directory %s does not exist!' % path)
		if no_raise:
			return
		raise Exception('Path %s does not exist!' % path)
	tf = open(os.path.join(path, ".(tag)(sGroup)")).read().strip()
	log.debug('Tape family of path %s: %s' % (path, tf))
	return tf

# Get storage group of directory (or parents)
def get_tape_family_parents(path):
	log.info('Getting tape family for path %s or parents of this path' % path)
	while path and not os.path.exists(path):
		path = os.path.dirname(path)
	return get_tape_family(path)
