#!/usr/bin/python

'''
StorageDump v2.0
author: Iban Cabrillo
'''

import os
import sys
#import urllib
#import urllib2
import datetime
import subprocess
#from xml.dom import minidom


def get_local_cksum(surl):
    '''
    Get the cksum store at local file level. If the file has no cksum value we should calc it.
    '''

    #l = []
    adler_path = 'adler32/calc_adler32.py'

    #surl = localpath+lfn.rstrip('\n')

    #Look for the adler32 value 
    output, error = subprocess.Popen(['getfattr', '--only-values', '--absolute-names', '-n', 'user.storm.checksum.adler32', surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
    #print 'output:[',output,']'
    #print 'error:[',error,']'

    if len(output) == 0:

       print "No checksum value found for file %s. Processing..." % surl.replace('/gpfs/gaes/cms','')

       #Calc de adler32 value
       adler32, error = subprocess.Popen([adler_path, surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()

       # Delete de \n on the rigth and the 0's on the left to be the same adler32 format that storaged at phedex api and set the adler32 value for the file.
       setadler32, error = subprocess.Popen(['setfattr', '-n', 'user.storm.checksum.adler32', '-v', adler32.rstrip('\n').lstrip('0'), surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
       
       return adler32.rstrip('\n').lstrip('0')
     
    else:
        
       return output.rstrip('\n')


def get_local_timestamp(surl):
    '''
    Get the mtime store for local file as extra attribute. If the file has no this 
    value stored we calc it.
    '''

    #surl = localpath+lfn.rstrip('\n')

    #Look for the adler32 value
    output, error = subprocess.Popen(['getfattr', '--only-values', '--absolute-names', '-n', 'user.timestamp', surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
    #print 'output:[',output,']'
    #print 'error:[',error,']'
    
    if len(output) == 0:

       print "No timestamp value found for file %s. Processing..." % surl.replace('/gpfs/gaes/cms','')

       #Calc de timestamp value
       timestamp = str(os.stat(surl).st_ctime).rstrip('\n')

       # Set the timstamp value for the file.
       settimestamp, error = subprocess.Popen(['setfattr', '-n', 'user.timestamp', '-v', timestamp, surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
         
       return timestamp

    else:

       return output.rstrip('\n')


def get_local_size(surl):
    '''
    Get the size store for local file as extra attribute. If the file has no this 
    value stored we calc it.
    '''

    #surl = localpath+lfn.rstrip('\n')

    #Look for the adler32 value
    output, error = subprocess.Popen(['getfattr', '--only-values', '--absolute-names', '-n', 'user.size', surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
    #print 'output:[',output,']'
    #print 'error:[',error,']'
    
    if len(output) == 0:

       print "No size value found as extra attribute for file %s. Processing..." % surl.replace('/gpfs/gaes/cms','')

       #Calc de timestamp value
       size = str(os.stat(surl).st_size).rstrip('\n')

       # Set the timstamp value for the file.
       setsize, error = subprocess.Popen(['setfattr', '-n', 'user.size', '-v', size, surl], stderr=subprocess.PIPE, stdout=subprocess.PIPE).communicate()
       return size

    else:

       return output.rstrip('\n')


def print_storage_dump(lfn, size, ctime, cksum):
    '''
    Create a file with keys: lfn, size, timestamp, cksum
    '''

    f = open(DumpFile, 'a')
    f.write(lfn)
    f.write('|')
    f.write(size)
    f.write('|')
    f.write(ctime)
    f.write('|')
    f.write(cksum)
    f.write('\n')


def getopts():
    '''
    Get the command line arguments
    '''
          
    from optparse import OptionParser
                    
    parser = OptionParser()
    parser.add_option('--localpath', '-p', action='store', type='string', dest='localpath', default ='/gpfs/csic_projects/cms/', help='Local prefix to your file system to complete de plfn ')

    (opt, arg) = parser.parse_args()
    #check inputs
    #if not opt.lfn:
    #   if not opt.lfns and not opt.block and not opt.dataset:
    #      print ""
    #      raise KeyError
    #   else:
    #      return opt
    #else:
    #   print ""
    #   return opt
    return opt
 
if __name__ == '__main__':
   

###########################Globals################################
    #Path to file whhere will be written the bad lfns
    DumpFile = '/tmp/DumpFile.log.%s' % datetime.date.today()
##################################################################

    try:
        myargs = getopts()
        localpath = myargs.localpath

    except KeyError: 
        print "missing some mandatory parameters, please run <check_cks.py -h >"
        sys.exit()

    try:
         
	for tupla in os.walk(localpath):
	   if tupla[2]:
              for file in tupla[2]:
		         surl = tupla[0]+'/'+file
		         try:
                    if "csic_projects" in localpath:
                       print_storage_dump(surl.replace('/gpfs/csic_projects/cms','/store/user'), get_local_size(surl), get_local_timestamp(surl), 'N/A')
                    else:
                       if "/store/user" in tupla[0]:
                          print_storage_dump(surl.replace('/gpfs/gaes/cms',''), get_local_size(surl), get_local_timestamp(surl), 'N/A')
                       else:
    		          #print surl.replace('/gpfs/gaes/cms',''), get_local_size(surl), get_local_timestamp(surl), get_local_cksum(surl)
                          print_storage_dump(surl.replace('/gpfs/gaes/cms',''), get_local_size(surl), get_local_timestamp(surl), get_local_cksum(surl))                        
                 except OSError:
                    pass
 
    except IndexError:
        print "The file doesn't exits"
        pass
