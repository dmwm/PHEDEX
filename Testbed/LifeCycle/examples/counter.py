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

try:
  payload['workflow']['counter'] += 1
except KeyError:
  payload['workflow']['counter'] = 1

print "Counter: count=",payload['workflow']['counter']

f = open(_out,'w')
f.write(json.dumps(payload))
