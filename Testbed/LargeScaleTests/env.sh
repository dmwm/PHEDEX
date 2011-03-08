# Do whatever you need to pick up a basic working PhEDEx environment here. The easy way is to install
# a PhEDEx version from somewhere, and then source its environment. That way, you get all the external
# dependencies resolved for you. You can override some of these later.
#. /data/wildish/testbed/sw/slc5_amd64_gcc434/cms/PHEDEX/PHEDEX_3_3_2/etc/profile.d/init.sh

# TESTBED_ROOT is a where state and log files will go
export TESTBED_ROOT=/data/wildish/testbed

# PHEDEX_ROOT is where you have installed the version of PHEDEX that you intent to run.
# Your Config files will make extensive use of PHEDEX_ROOT.
export PHEDEX_ROOT=$HOME/public/COMP/PHEDEX_CVS

# Pre-pend your PERL5LIB environment variable with the T0 libraries and the libraries from
# the PhEDEx version you are going to run
export PERL5LIB=$TESTBED_ROOT/T0/perl_lib:$PERL5LIB
export PERL5LIB=$PHEDEX_ROOT/perl_lib:$PERL5LIB

# Take great care with this. Get it wrong and you could cause serious trouble
export PHEDEX_INSTANCE=PrivateTestbed2
export PHEDEX_DBPARAM=$HOME/private/DBParam.11gr2:$PHEDEX_INSTANCE

# This is where you are, now, under the PHEDEX directory hierarchy
export LOCAL_ROOT=Testbed/LargeScaleTests

# Set this if you need to use a special TNSNAMES.ORA, such as for testing on special hardware
export TNS_ADMIN=$PHEDEX_ROOT/$LOCAL_ROOT
