#! /usr/bin/python
#Script for extracting a list of files from DPM database
#Inspired from original script by Erming Pei, 2009/11/13
#A. Sartirana 2012/02/16, sartiran@llr.in2p3.fr


import sys,os
import datetime, time
import MySQLdb

usage= ''

helpmsg= """
Script for getting a a filelist in xml format in dpm

Usage: dpmdump.py [-dbcfg FILE] [-rootdir <DIR>] [-dirlist <COMMA SEPARATED DIRLIST>] [-delay <SECS>] [-out <FILE>] [-only_csum] [-nocsum_file <FILE>] [-help]

OPTIONS AND AGRUMENTS

-dbcfg   <FILE>      : configuration file for db access with the line <user>/<password>@<host>. Defaults are: /opt/lcg/etc/DPMCONFIG and /opt/lcg/etc/NSCONFIG

-rootdir <DIR>       : base directory from which start the list of files. Default value is '/dpm'
                       WARNING: you should not put final '/'.

-dirlist <LIST>      : comma separated list of subdirectory to scan. Default is '/' (i.e. all the root directory).

-delay   <SECS>      : only lists files older than SECS seconds. Default is 0.

-out     <FILE>      : output file. Default is 'dump.xml'.

-only_csum           : only the files with a checksum entry get into the file list. Others are printed in a different list.

-nocsum_file <FILE>  : the file where the list of files with no checksum entry are printed. Default is nocsum.xml

-help                : print this help

"""

#arguments defaults
#by default it looks for all files and dump in dump.xml
rootdir='/dpm'
xmlfile="dump.xml"
startdate=time.time()
dirlist=['/'] 
only_csum=0
nocsum_file='nocsum.xml'
cfgfile=''

i=1
while(i<len(sys.argv)):
    if(sys.argv[i]=='-rootdir'):
        rootdir=sys.argv[i+1]
        i=i+2
    elif(sys.argv[i]=='-dbcfg'):
        cfgfile=sys.argv[i+1].split(',')
        i=i+2
    elif(sys.argv[i]=='-dirlist'):
        dirlist=sys.argv[i+1].split(',')
        i=i+2
    elif(sys.argv[i]=='-delay'):
        startdate=startdate - int(sys.argv[i+1])
        i=i+2
    elif(sys.argv[i]=='-out'):
        xmlfile=sys.argv[i+1]
        i=i+2
    elif(sys.argv[i]=='-only_csum'):
        only_csum=1
        i=i+1
    elif(sys.argv[i]=='-nocsum_file'):
        nocsum_file=sys.argv[i+1]
        i=i+2        
    elif(sys.argv[i]=='-help'):
        print  helpmsg
        sys.exit(0)
        i=i+1
    else:
        print 'Unrecognized option'
        print usage
        sys.exit(1)
        


if(cfgfile == ''):
    if os.path.exists('/opt/lcg/etc/DPMCONFIG'):
        cfgfile='/opt/lcg/etc/DPMCONFIG'
    else:
        cfgfile='/opt/lcg/etc/NSCONFIG'

try:
    f=open(cfgfile,'r')
    dpmconfstr=f.readline()
    User=dpmconfstr.split('/')[0]
    Passwd=dpmconfstr.split('/')[1].split('@')[0]
    Host=dpmconfstr.split('/')[1].split('@')[1]
    f.close()
except:
    print "Cannot open DPM config file: " + cfgfile
    sys.exit()

conn=MySQLdb.connect(host=Host,user=User,passwd=Passwd,db="cns_db") 
sql="select fileid, parent_fileid,name,filesize,filemode,ctime,csumtype,csumvalue from Cns_file_metadata order by parent_fileid"
cursor=conn.cursor()
cursor.execute(sql)

#curtime=time.strftime("%Y.%m.%d %H:%M:%S",time.localtime())
curtime=datetime.datetime.isoformat(datetime.datetime.now())


f=open(xmlfile,'w')
header="<?xml version="+'"'+"1.0"+'"'+" encoding="+'"'+"iso-8859-1"+'"'+"?>"
header=header+"<dump recorded=" + '"' + curtime + '"' + "><for>vo:cms</for>"+"\n"+"<entry-set>"+"\n" 
f.write(header)	

if only_csum == 1:
    g=open(nocsum_file,'w')
    header="<?xml version="+'"'+"1.0"+'"'+" encoding="+'"'+"iso-8859-1"+'"'+"?>"
    header=header+"<nocsum recorded=" + '"' + curtime + '"' + "><for>vo:cms</for>"+"\n"+"<entry-set>"+"\n" 
    g.write(header)	

fileids={}

for row in cursor.fetchall():
#    print row
    fileid=str(row[0])
    parentid=str(row[1])
    name=str(row[2])
    size=str(row[3])
    filemode=str(row[4])
    ctime=int(row[5])
    csum=str(row[6])+':'+str(row[7])
    
    if parentid=='' or fileid=='':
        continue   

    if parentid=='0':
        fileids[fileid]=''
    else:
        try:
            fileids[fileid]=fileids[parentid]+'/'+name 
        except KeyError:
            print "The file's parent does not exist."
            continue

        except:
            print 'Unkown error occurred in one line.'
            continue

        if int(filemode)>30000:      # To select files
            #Check that the file is older than the delar
            if(ctime<startdate):
                if(fileids[fileid].find(rootdir) != -1):
                    for dir in dirlist:
                        if(fileids[fileid].find(rootdir+dir) != -1):
                            if((csum != ':') or (only_csum==0)):
                                content="<entry name=" + '"' + fileids[fileid] + '"' + "><size>" + size + "</size><ctime>" + str(ctime) +"</ctime><checksum>"+csum+"</checksum></entry>"+"\n"
                                f.write(content)
                            else:
                                content="<entry name=" + '"' + fileids[fileid] + '"' + "><size>" + size + "</size><ctime>" + str(ctime) +"</ctime>"+"\n"
                                g.write(content)
f.write("</entry-set></dump>\n")
f.close()

if only_csum==1 :
    g.write("</entry-set></nocsum>\n")
    g.close()

