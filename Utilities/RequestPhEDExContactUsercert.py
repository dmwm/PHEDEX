#!/usr/bin/env python2.4

import os
import StringIO
import pycurl
import simplejson
import re

from optparse import OptionParser

# Import smtplib for the actual sending function
import smtplib

# Import the email modules we'll need
from email.MIMEText import MIMEText

def fetchSiteDBData(curl,url):
    curl.setopt(pycurl.URL, url)
    fr=StringIO.StringIO()
    curl.setopt(pycurl.WRITEFUNCTION,fr.write)
    curl.perform()
    jr = simplejson.loads(fr.getvalue())
    fr.close()
    return jr

parser = OptionParser()
parser.add_option("-o","--outdir", default="TestOut",
                  help="Output mail directory, default is TestOut")
parser.add_option("-c","--certdir", default="Usercerts",
                  help="Directory containing the Usercerts for the sites that already answered, default is Usercerts")
parser.add_option("-s", "--site", default=None,
                  help="site that will receive notification (default is None for all sites)")
parser.add_option("-m", "--mail",
                  action="store_true", default=False,
                  help="send mail, default is False")

(options, args) = parser.parse_args()

certlist={}

for i in os.listdir(options.certdir):
    site=i.split(':')[0]
    contact=i.split(':')[1]
    certlist[site]=contact

c = pycurl.Curl()
c.setopt(pycurl.CAPATH,os.getenv('X509_CERT_DIR'))
c.setopt(pycurl.SSLKEY,os.getenv('X509_USER_PROXY'))
c.setopt(pycurl.SSLCERT,os.getenv('X509_USER_PROXY'))

jr = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/site-responsibilities')
jn = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/site-names')
jp = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/people')

asso={}
execlist={}

for i in jn['result']:
    if i[jn['desc']['columns'].index('type')]=='phedex':
        phedexname=i[jn['desc']['columns'].index('alias')]
        phedexname=re.sub('_(Export|Buffer|Disk|MSS|Stage)$','',phedexname)
        sitedbname=i[jn['desc']['columns'].index('site_name')]
        if (options.site and options.site!=phedexname):
            continue
        asso[phedexname]=[]
        execlist[phedexname]=[]
        #print phedexname
        for k in jr['result']:
            if k[jr['desc']['columns'].index('role')]=='PhEDEx Contact':
                if k[jr['desc']['columns'].index('site_name')]==sitedbname:
                    contactname=k[jr['desc']['columns'].index('username')]
                    #print contactname
                    for z in jp['result']:
                        if z[jp['desc']['columns'].index('username')]==contactname:
                            email=z[jp['desc']['columns'].index('email')]
                            #print email
                            asso[phedexname].append(email)
            elif k[jr['desc']['columns'].index('role')]=='Site Executive':
                if k[jr['desc']['columns'].index('site_name')]==sitedbname:
                    contactname=k[jr['desc']['columns'].index('username')]
                    #print contactname
                    for z in jp['result']:
                        if z[jp['desc']['columns'].index('username')]==contactname:
                            email=z[jp['desc']['columns'].index('email')]
                            #print email
                            execlist[phedexname].append(email)
                            
#print asso

if not os.path.isdir(options.outdir):
    os.mkdir(options.outdir)

for site in asso.keys():
    if len(asso[site])==0:
        print "WARNING: No PhEDEx Contact found for site "+site+", contact Site Executives: "+(", ".join(execlist[site]))
    if site in certlist.keys():
        print "INFO: "+certlist[site]+" already replied for site "+site+", skipping email"
    else:
        for admin in asso[site]:

            if os.path.isfile(options.outdir+'/'+site+':'+admin):
                print "WARNING: skipping mail already sent to "+options.outdir+'/'+site+':'+admin
                continue
            
            f=StringIO.StringIO()

            f.write("Hello "+admin+"\n\n")
            f.write("In order to renew your PhEDEx authentication role,\n")
            f.write("we need the public key of your certificate, typically found\n")
            f.write("in ~/.globus/usercert.pem.\n")
            f.write("Please reply to this mail with your usercert.pem in attachment\n")
            f.write("(NOT your userkey.pem!!!) and you will soon receive your new\n")
            f.write("authentication information by encrypted mail\n\n")
            f.write("Yours truly,\n")
            f.write("  PhEDEx administrators\n")
            f.write("  (cms-phedex-admins@cern.ch)\n")

            msg = MIMEText(f.getvalue())
            f.close()
        
            msg['Subject'] = "Requesting usercert.pem of PhEDEx Contact for "+site+" for authentication role renewal"
            msg['From'] = "cms-phedex-admins@cern.ch"
            msg['Cc'] = "cms-phedex-admins@cern.ch"
            msg['To'] = admin

            fm2=open(options.outdir+'/'+site+':'+admin,'w')
            fm2.write(msg.as_string())
            fm2.close()

            if options.mail:
                s = smtplib.SMTP('localhost')
                s.sendmail(msg['From'], [msg['To'],msg['Cc']], msg.as_string())
                s.quit()
