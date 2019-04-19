## PHEDEX agents installation on SLC6  
##

FROM cern/slc6-base

# work dir must be accessible both by root and phedex user
WORKDIR /tmp

# Make sure all comp platform dependencies are available
# List taken from http://cmsrep.cern.ch/cmssw/comp/slc6_amd64_gcc493-driver.txt
#

RUN yum install -y glibc coreutils bash tcsh zsh perl tcl tk readline openssl \
  ncurses e2fsprogs krb5-libs freetype compat-readline5 ncurses-libs perl-libs \
  perl-ExtUtils-Embed  fontconfig compat-libstdc++-33 libidn libX11 libXmu \
  libSM libICE libXcursor libXext libXrandr libXft mesa-libGLU mesa-libGL \
  e2fsprogs-libs libXi libXinerama libXft libXrender libXpm libcom_err

# Packages needed for deployment scripts and database connections
RUN yum install -y wget rsync libaio

# Install convenience system packages:
RUN yum install -y which nano mlocate less

# SW install by root is considered insecure, continue as a regular user:
RUN adduser phedex
USER phedex 

ADD pre-install.sh /home/phedex
RUN source /home/phedex/pre-install.sh

# Start phedex bash session and keep it open without doing anything:
ENTRYPOINT ["/bin/bash", "-c", "sleep infinity"]
