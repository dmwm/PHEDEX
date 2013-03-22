# CMS database interfaces python tools
# by Fred Stober (stober@cern.ch)

import das, phedex

# Classes for uniform access to CMS databases - use caching when possible

class DAS_Interface:
	def __init__(self):
		self.cache_dataset_info = {}

	def get_dataset_info(self, dataset):
		if dataset not in self.cache_dataset_info:
			self.cache_dataset_info[dataset] = das.get_das_dataset_info(dataset)
		return self.cache_dataset_info[dataset]

class Phedex_Interface:
	def __init__(self):
		self.cache_files = {}

	def get_files(self, dataset):
		if dataset not in self.cache_files:
			self.cache_files[dataset] = []
			for file_info in phedex.get_phedex_files(dataset):
				self.cache_files[dataset].append(file_info['lfn'])
		return self.cache_files[dataset]

class CMS_Interface:
	def __init__(self):
		self.phedex = Phedex_Interface()
		self.das = DAS_Interface()

	def get_dataset_info(self, dataset):
		return self.das.get_dataset_info(dataset)

	def get_files(self, dataset):
		return self.phedex.get_files(dataset)
