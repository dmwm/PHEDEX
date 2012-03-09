#!/usr/bin/env python
import traceback, getopt, sys
import json, copy
from pprint import pprint

from dbs.apis.dbsClient import *

url=os.environ['DBS_READER_URL'] 
api = DbsApi(url=url)

try:
  opts, args = getopt.getopt(sys.argv[1:], "io", ["in=", "out="])
except getopt.GetoptError, err:
  print "Error parsing arguments"
  sys.exit(2)
_out = 'none'
_in  = 'none'
for o, a in opts:
  if o == "--out":
    _out = a
  elif o == "--in":
    _in = a
  else:
    assert False, "unhandled option"

f = open(_in,'r')
payload = json.loads(f.read())
initial = payload['workflow']['InitialRequest']
print "Initial request string: "+initial

## first step (list all datasets in DBS3 below the 'initial' root)
datasets = api.listDatasets(dataset=initial)
print "Found",len(datasets),"datasets"
payloads=[]
for dataset in datasets:
  p = copy.deepcopy(payload)
  p['workflow']['dataset'] = dataset['dataset']
  payloads.append(p)

f = open(_out,'w')
f.write(json.dumps(payloads))
