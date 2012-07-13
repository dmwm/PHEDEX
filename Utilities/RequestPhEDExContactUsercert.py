#!/usr/bin/env python2.4

import os
import StringIO
import pycurl
import simplejson
import re

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

c = pycurl.Curl()
c.setopt(pycurl.CAPATH,os.getenv('X509_CERT_DIR'))
c.setopt(pycurl.SSLKEY,os.getenv('X509_USER_PROXY'))
c.setopt(pycurl.SSLCERT,os.getenv('X509_USER_PROXY'))

jr = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/site-responsibilities')
jn = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/site-names')
jp = fetchSiteDBData(c,'https://cmsweb.cern.ch/sitedb/data/prod/people')

asso={}

for i in jn['result']:
    if i[jn['desc']['columns'].index('type')]=='phedex':
        phedexname=i[jn['desc']['columns'].index('alias')]
        phedexname=re.sub('_(Export|Buffer|Disk|MSS|Stage)$','',phedexname)
        sitedbname=i[jn['desc']['columns'].index('site_name')]
        asso[phedexname]=[]
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

#print asso

os.mkdir('Output')

for site in asso.keys():
    if len(asso[site])==0:
        print "WARNING: No PhEDEx Contact found for site "+site
    else:
        for admin in asso[site]:
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

            fm2=open('Output/'+site+':'+admin,'w')
            fm2.write(msg.as_string())
            fm2.close()

            s = smtplib.SMTP('localhost')
            s.sendmail(msg['From'], [msg['To']], msg.as_string())
            s.quit()
