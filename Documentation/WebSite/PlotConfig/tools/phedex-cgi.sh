#!/bin/sh

# Users edit these variables
export CMS_ROOT=/opt/test-aptinstaller-slc4
export GRAPHTOOL_ROOT=/opt/test-aptinstaller-slc4/GraphTool
export GRAPHTOOL_USER_ROOT=$CMS_ROOT/graphusers/phedex
export GRAPHTOOL_CONFIG_ROOT=$GRAPHTOOL_USER_ROOT/config

# Don't edit the below ones unless you know what you're doing

export PYTHONPATH=$GRAPHTOOL_USER_ROOT/src:$GRAPHTOOL_ROOT/src

export PATH=$GRAPHTOOL_ROOT/tools:$PATH

export TTFPATH=$CMS_ROOT/slc4_ia32_gcc345/external/py2-matplotlib/0.87.7/lib/python2.4/site-packages/matplotlib/mpl-data

export MATPLOTLIBDATA=$GRAPHTOOL_ROOT/config

export HOME=$GRAPHTOOL_ROOT

if [ -f $CMS_ROOT/slc4_ia32_gcc345/.aptinstaller/cmspath ]; then

source $CMS_ROOT/slc4_ia32_gcc345/external/oracle/10.2.0.2/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/libpng/1.2.10/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/python/2.4.3/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/py2-cx-oracle/4.2/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/py2-matplotlib/0.87.7/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/py2-numpy/1.0.1/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/libjpg/6b/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/libtiff/3.8.2/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/external/py2-pil/1.1.6/etc/profile.d/init.sh
source $CMS_ROOT/slc4_ia32_gcc345/cms/oracle-env/1.2/etc/profile.d/init.sh

fi

python $GRAPHTOOL_USER_ROOT/tools/phedex-cgi.py

