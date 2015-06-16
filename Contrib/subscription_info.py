#!/bin/env python

# by Derek Feichtinger

import os, sys
import xml.dom.minidom
from xml.dom.minidom import Node
import datetime
from optparse import OptionParser

def formatDate(timestamp):
    #return datetime.datetime.fromtimestamp(int(timestamp)).strftime('%Y-%m-%d %H:%M:%S')
    return datetime.datetime.fromtimestamp(float(timestamp)).strftime('%Y-%m-%d %H:%M:%S')
    

##################
### Options
usage = "This tool queries the PhEDEx data service and creates a table containing "
usage +="information on subscriptions to a site. Group selection is also possible.\n\n"
usage +="Usage example: python "+sys.argv[0]+" --site T2_CH_CSCS --group local"

parser = OptionParser(usage = usage)
parser.add_option("--site",
                  action="store", dest="Site", default="",
                  help="Site selection, e.g. T2_CH_CSCS")
parser.add_option("--group",
                  action="store", dest="Group", default="",
                  help="PhEDEx group selection")
(options, args) = parser.parse_args()


#################
### Options check
SITE= options.Site
GROUP= options.Group
CREATED_SINCE="0"

if SITE=="":
    print "[ERROR] Please select a site using the --site option"
    sys.exit(1)


################
### Getting the XML file from PhEDEx data service
xmlFilename = "data.xml"
command = "wget --no-check-certificate -O "+xmlFilename+" 'https://cmsweb.cern.ch/phedex/datasvc/xml/prod/Subscriptions?node="+SITE+"&create_since="+CREATED_SINCE+"&group="+GROUP+"' &> /dev/null"
#print command
print "Getting the data from the data service..."
os.system(command)

###############
### Opening the XML file
xmlFile = open(xmlFilename)
doc = xml.dom.minidom.parse(xmlFile)

#key is the subscription ID, each subscription is a dict, too
subscriptionList = {}

################
### Looping on datasets, using the Subscriptions data
for node in doc.getElementsByTagName("dataset"):
    size = 0
    group = ""
    reqID = 0
    dataset =  node.attributes['name'].value
    totalSize = node.attributes['bytes'].value
    reqTime = ""
    for subscr in node.getElementsByTagName("subscription"):
        reqID = int(subscr.attributes['request'].value)
        group =  subscr.attributes['group'].value
        reqTime = formatDate(subscr.attributes['time_create'].value)
        if subscr.attributes['node_bytes'].value != "":
            size += float(subscr.attributes['node_bytes'].value)

    #Filling a dict
    sub = {'group':group,
           'size':(size)/(1024*1024*1024), 'totalSize':totalSize,
           'dataset':dataset,
           'created':reqTime,
           'comments':'',
           'comments2':'',
           'name':'',
           'email':''}
    subscriptionList[reqID] = sub

requests = subscriptionList.keys()
requests.sort()


####################
### Getting extra info for subscriptions (requestor, etc)
### One call for each dataset, sigh...
for i in requests:
    command = "wget --no-check-certificate -O req.xml 'https://cmsweb.cern.ch/phedex/datasvc/xml/prod/TransferRequests?node="+SITE+"&request="+str(i)+"' &> /dev/null"
    os.system(command)
    xmlReqFile = open("req.xml")
    docReq = xml.dom.minidom.parse(xmlReqFile)
    name = ""
    email = ""
    comment = ""
    for subscr in docReq.getElementsByTagName("request"):
        for rb in subscr.getElementsByTagName("requested_by"):
            name = rb.attributes['name'].value
            email = rb.attributes['email'].value
            if len(rb.firstChild.childNodes)!=0:
                comment =  rb.firstChild.firstChild.data.replace("\n"," ")
    subscriptionList[i]['name'] = name
    subscriptionList[i]['email']= email
    subscriptionList[i]['comments']= comment
    myI = 0
    for cmt in docReq.getElementsByTagName("comments"):
        if len(cmt.childNodes)!=0:
            if myI==0: subscriptionList[i]['comments'] = cmt.firstChild.data.replace("\n"," ")
            else: subscriptionList[i]['comments2'] = cmt.firstChild.data.replace("\n"," ")
        myI+=1
    os.system("rm req.xml")
    

################
### Finally, printing the result
print     "\n|%10s|%10s|%10s|%10s|%10s|%10s|%10s|%10s|%10s|" %("*keep?*","*ID*","*Dataset*","*Size(GB)*","*Group*","*Requested on*","*Requested by*","*Comments*","*Comments2*")
for i in requests:
    r = subscriptionList[i]
    print "|%10s|%10s|%10s|%2.1f|%10s|%10s|%10s|%10s|%10s|" %("",str(i),r["dataset"], r["size"],r["group"],r["created"],r["name"],r["comments"],r['comments2'])

os.system("rm "+xmlFilename)
