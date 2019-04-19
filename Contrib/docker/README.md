To build phedex docker image : 

    docker build -t phedex-agents ./

To run phedex server in a container : 

    nohup docker run --name phedex-server phedex-agents &

To login to the server (wait a few secs until server starts):
    sleep 10
    docker exec -it phedex-server /bin/bash

To set environment inside a container: 

    source ~/sw/slc6_amd64_gcc493/cms/PHEDEX/4.2.1/etc/profile.d/init.sh

To stop server container:

    docker stop phedex-server

For manual installation instructions see:
 https://twiki.cern.ch/twiki/bin/view/CMSPublic/PhedexAdminDocsInstallation
