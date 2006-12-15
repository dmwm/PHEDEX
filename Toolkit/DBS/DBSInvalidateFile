#!/usr/bin/env python
"""
_DBSInjectReport_
                                                                                
Command line tool to inject a "JobSuccess" event into DBS reading a FrameworkJobReport file.

"""
import dbsCgiApi
from dbsException import DbsException

import string,sys,os,getopt,time


usage="\n Usage: python DBSInvalidateFile.py <options> \n Options: \n --DBSAddress=<MCLocal/Writer> \t\t DBS database instance \n --DBSURL=<URL> \t\t DBS URL \n --lfn=<LFN> \t\t LFN \n --lfnFileList=<filewithLFNlist> \t\t File with the list of LFNs \n [ valid \t\t option to set files to valid instead of invalid]"
valid = ['DBSAddress=','DBSURL=','lfn=','lfnFileList=','valid']
try:
    opts, args = getopt.getopt(sys.argv[1:], "", valid)
except getopt.GetoptError, ex:
    print usage
    print str(ex)
    sys.exit(1)

url = "http://cmsdoc.cern.ch/cms/test/aprom/DBS/CGIServer/prodquery"
dbinstance = None
lfn = None
lfnFileList = None
valid = False

for opt, arg in opts:
    if opt == "--lfn":
        lfn = arg
    if opt == "--lfnFileList":
        lfnFileList = arg
    if opt == "--DBSAddress":
        dbinstance = arg
    if opt == "--DBSURL":
        url = arg
    if opt == "--valid":
        valid = True

if dbinstance == None:
    print "--DBSAddress option not provided. For example : --DBSAddress MCLocal/Writer"
    print usage
    sys.exit(1)

if (lfn == None) and (lfnFileList == None) :
    print "\n either --lfn or --lfnFileList option has to be provided"
    print usage
    sys.exit(1)
if (lfn != None) and (lfnFileList != None) :
    print "\n options --lfn or --lfnFileList are mutually exclusive"
    print usage
    sys.exit(1)

print ">>>>> DBS URL : %s DBS Address : %s"%(url,dbinstance)
#  //
# // Get API to DBS
#//
## database instance
args = {'instance' : dbinstance}
dbsapi = dbsCgiApi.DbsCgiApi(url, args)

#  //
# // Invalidate LFNs
#//
def setLFNstatus(alfn, valid):

  if valid:
    print "Validating LFN %s"%alfn
    dbsapi.setFileStatus (alfn,"valid")
  else:
    print "Invalidating LFN %s"%alfn
    dbsapi.setFileStatus (alfn,"invalid") 


if (lfn != None):
  setLFNstatus(lfn,valid)

if (lfnFileList != None) :
 expand_lfnFileList=os.path.expandvars(os.path.expanduser(lfnFileList))
 if not os.path.exists(expand_lfnFileList):
    print "File not found: %s" % expand_lfnFileList
    sys.exit(1)

 lfnlist_file = open(expand_lfnFileList,'r')
 for line in lfnlist_file.readlines():
   lfn=line.strip()
   setLFNstatus(lfn,valid) 
 lfnlist_file.close()



