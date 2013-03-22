# data management python tools
# by Fred Stober (stober@cern.ch)

import os, logging, lfntools

log = logging.getLogger('data_management')

# Calculate needed space to store x bytes in some tape family
def get_needed_space(bytes, tape_family):
	if tape_family == 'CMS-replica-1':
		return 10 * bytes # 9 times replicated
	return bytes

# Get possible non-custodial tape families for some dataset
def get_noncustodial_tape_families():
	return ['CMS-test-1', 'CMS-test-2', 'CMS-test-3']

# Get possible custodial tape families for some dataset
def get_custodial_tape_families(datatier, datatype):
	if datatype == 'data':
		# python lists are not allowed as dict keys!
		tf2tier = {
			'CMS-data-1,CMS-data-4,CMS-data-7': ['RAW'],
			'CMS-data-2,CMS-data-5,CMS-data-8': ['RECO', 'RAW-RECO', 'ALCARECO'],
			'CMS-data-3,CMS-data-6,CMS-data-9': ['AOD', 'DQM', 'FEVTDEBUGHLT', 'USER'],
		}
	elif datatype == 'mc':
		tf2tier = {
			'CMS-mc-1,CMS-mc-4': ['GEN-SIM', 'GEN-SIM-RAW', 'GEN-RAW', 'GEN-SIM-DIGI-RAW', 'GEN-SIM-RAWDEBUG'],
			'CMS-mc-2,CMS-mc-5': ['GEN-SIM-RAW-RECO', 'GEN-SIM-DIGI-RECO', 'GEN-SIM-RAW-HLTDEBUG-RECO', 'GEN-SIM-RECO', 'GEN-SIM-RECODEBUG', 'RAWRECOSIMHLT'],
			'CMS-mc-3': ['DQM', 'AODSIM', 'FEVTDEBUGHLT', 'USER'],
			'CMS-mc-6': ['GEN'],
		}
	else:
		raise Exception('Unknown data type: %s' % datatype)
	# reverse mapping and split comma-separated tape family list into python list
	tier2tf = {}
	for (tf_str, tier_list) in tf2tier.items():
		tier2tf.update(dict(map(lambda tier: (tier, tf_str.split(',')), tier_list)))
	return tier2tf[datatier]

# get correct tape family for dataset
def get_allowed_tape_families(dataset, interface, custodial):
	log.info('Determine correct tape family for %s (custodial=%r)' % (dataset, custodial))

	# generator files are replicated for more performance
	common_lfn = lfntools.get_common_directory(interface.get_files(dataset)) + '/'
	if common_lfn.startswith('/store/generator/'):
		return ['CMS-replica-1']

	if not custodial:
		return get_noncustodial_tape_families()

	ds_info = interface.get_dataset_info(dataset)
	if not ds_info:
		raise Exception('Dataset %s not found!' % dataset)
	else:
		datatype = ds_info['datatype'].lower()

	datatier = dataset.split('/')[-1]
	return get_custodial_tape_families(datatier, datatype)
