#!/usr/bin/env python
import traceback, getopt, sys
import json, copy

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

payloads=[]
for i in [ 1000, 2000, 3000 ]:
  p = copy.deepcopy(payload)
  p['workflow']['Intervals']['counter'] = 2 * i / 1000
  p['workflow']['counter'] = i
  print "fork_counter: create new workflow with counter=",i
  payloads.append(p)

f = open(_out,'w')
f.write(json.dumps(payloads))
