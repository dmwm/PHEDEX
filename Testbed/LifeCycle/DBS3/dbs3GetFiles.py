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
initial = payload['workflow']['block_name']
print "Block name: "+initial

## last step (list all files in DBS3 below the 'initial' root)
files = api.listFiles(block_name=initial)
print "Found",len(files),"files"
payloads=[]
for file in files:
  p = copy.deepcopy(payload)
  p['workflow']['file'] = file['logical_file_name']
  payloads.append(p)

f = open(_out,'w')
f.write(json.dumps(payloads))
