#!/bin/sh

# Build DBD against Oracle Instant Client SDK

# Building on ScientificLinux3, perl 5.8.0 (basically RHE3).

# Need OIC version 10.1.0.3. Download the basic, sqlplus and devel zips. 
# You need to rejiggle the files (not many) to form a reasonable directory 
# structure. Assume $BASE holds your top level directory for installation, then:

if [ "$BASE" = '' ]; then
echo "You need to set \$BASE to your top level directory for installation"
exit
fi

#cd $BASE
# download instantclient-basic-linux32-10.1.0.3.zip
# download instantclient-sqlplus-linux32-10.1.0.3.zip
# download instantclient-sdk-linux32-10.1.0.3.zip
#if [ ! -e instantclient-basic-linux32-10.1.0.3.zip ]; then
#echo "Please download the Oracle Instant Client install zips and place them in $BASE"
#exit
#fi
#unzip *.zip # creates dir instantclient10_1
#export ORACLE_HOME=${BASE}/instantclient10_1
#cd $ORACLE_HOME
#ln -s libclntsh.so.10.1 libclntsh.so
#mkdir lib
#mkdir bin
#mkdir java
#mv lib* lib
#mv sqlplus bin
#mv glogin.sql bin
#mv *jar java
#mv sdk/demo .
#mv sdk/include .
#rm -fr sdk
#export PATH=$ORACLE_HOME/bin:$PATH
#export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
#export SQLPATH=$ORACLE_HOME/bin
#cd ..
mkdir perl-modules
cd perl-modules
wget http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBD-Oracle-1.16.tar.gz
tar zxvf DBD-Oracle-1.16.tar.gz

cd DBD-Oracle-1.16
echo "diff Makefile.PL.orig Makefile.PL
1122a1123,1126
>     # Tim Barrass: hacked for Oracle Instant Client
>     if ( \$OH =~ /instantclient/ ) {
>         \$linkvia = \"\$ENV{ORACLE_HOME}/lib/libclntsh.so\";
>     }
1254a1259
>        \"$OH/include\", # Tim Barrass, hacked for OIC install from zips" > Makefile.PL.patch
patch Makefile.PL Makefile.PL.patch
#perl Makefile.PL prefix=$BASE/perl-modules -m $ORACLE_HOME/demo/demo.mk

#echo "If you see WARNING: I could not determine Oracle client version ..."
#echo "remove the trailing slash from ORACLE_HOME"

#make
#make install

# Create and environment script
echo 'Writing local-oci-env.sh: please take a look and edit'
echo "export BASE=$BASE
export ORACLE_HOME=${BASE}/instantclient10_1
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:${LD_LIBRARY_PATH}
export PATH=${ORACLE_HOME}/bin:${PATH}
export SQLPATH=${ORACLE_HOME}/bin
# Note the trailing end of perl5lib might vary with architecture-
# look out for where your DBD-Oracle actually gets installed
export PERL5LIB=${ORACLE_HOME}/perl-modules/lib/<your path to dbd-oracle>
export TNS_ADMIN=<path to your tnsnames.ora file>" > local-oci-env.sh

# test at will ...
