#!/usr/bin/env python2.4

import os
import string
import StringIO
import pycurl
import simplejson
import re
import subprocess

from optparse import OptionParser


def fetchSiteDBData(curl,url):
    curl.setopt(pycurl.URL, url)
    fr=StringIO.StringIO()
    curl.setopt(pycurl.WRITEFUNCTION,fr.write)
    curl.perform()
    jr = simplejson.loads(fr.getvalue())
    fr.close()
    return jr

parser = OptionParser()
parser.add_option("-o","--outdir", default="Input",
                  help="Output role directory, default is Input")
parser.add_option("-c","--certdir", default="Keys",
                  help="Directory containing the Usercerts for the sites that already answered, default is Keys")
parser.add_option("-s", "--site", default=None,
                  help="site that will receive notification (default is None for all sites)")

(options, args) = parser.parse_args()

certlist={}

for role in os.listdir(options.outdir):
    site=role.split(':')[0]
    contact=role.split(':')[1]
    cert=options.certdir+'/'+contact
    if not os.path.isfile(cert):
        print cert+" KEY NOT FOUND!!!!"
    else:
        u=open('/tmp/aaaaa','w')
        subprocess.call(['grid-cert-info','-subject','-f',cert],stdout=u)
        u.close()
        gu=open('/tmp/aaaaa')
        certlist[site]=gu.read().strip()
        gu.close()

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
        phedexname='phedex_'+(re.sub('_','',string.lower(re.sub('_(Export|Buffer|Disk|MSS|Stage)$','',phedexname))))[0:17]+'_prod'
        sitedbname=i[jn['desc']['columns'].index('site_name')]
        if (options.site and options.site!=phedexname):
            continue
        asso[phedexname]=[]
        for k in jr['result']:
            if k[jr['desc']['columns'].index('role')]=='PhEDEx Contact':
                if k[jr['desc']['columns'].index('site_name')]==sitedbname:
                    contactname=k[jr['desc']['columns'].index('username')]
                    #print contactname
                    for z in jp['result']:
                        if z[jp['desc']['columns'].index('username')]==contactname:
                            email=z[jp['desc']['columns'].index('dn')]
                            #print email
                            asso[phedexname].append(email)

for site in certlist.keys():
    if site!='phedex_cern_prod' and site!='phedex_central_prod':
        if certlist[site] in asso[site]:
            print certlist[site]+" is a recognized PhEDEx Contact for site "+site
        else:
            print certlist[site]+" IS NOT a recognized PhEDEx Contact for site "+site
    else:
        if certlist[site] in asso['phedex_t0chcern_prod']:
            print certlist[site]+" is a recognized PhEDEx Contact for site "+site
        else:
            print certlist[site]+" IS NOT a recognized PhEDEx Contact for site "+site

                            

