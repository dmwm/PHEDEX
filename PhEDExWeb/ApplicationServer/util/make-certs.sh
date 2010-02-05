#!/bin/bash
mkdir /tmp/$USER >/dev/null
cd /tmp/$USER || exit 0
if [ ! -d certs ]; then
  mkdir certs
fi
if [ ! -d certs ]; then
  echo "Cannot make `pwd`/certs"
  exit 0
fi

echo "CH"			| tee    response.txt
echo "Geneva"			| tee -a response.txt
echo "Meyrin"			| tee -a response.txt
echo "CERN"			| tee -a response.txt
echo "CMS"			| tee -a response.txt
echo "localhost"		| tee -a response.txt
echo "tony.wildish@cern.ch"	| tee -a response.txt

cat response.txt | \
openssl req -new -x509 -nodes \
	-out certs/server-cert.pem \
	-keyout certs/server-key.pem

echo "

Now run the https proxy. Something like...

phedex-https-proxy.pl --listen 20000 --redirect_to https://cmsweb.cern.ch:443/ --verbose --debug --nocert --map yui=/$HOME/public/yui

"
