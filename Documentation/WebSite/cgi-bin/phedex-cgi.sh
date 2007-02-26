#!/bin/sh

export CMS_ROOT=/opt/aptinstaller
export GRAPH_ROOT=/opt/aptinstaller/BrianPlot
export GRAPH_CONFIG_ROOT=../PlotConfig
export MATPLOTLIBDATA=$GRAPH_ROOT/config # ??? Does not exist!  But it works...

export PYTHONPATH=$GRAPH_ROOT/src

export PATH=$GRAPH_ROOT/tools:$PATH

export TTFPATH=$CMS_ROOT/slc4_ia32_gcc345/external/py2-matplotlib/0.87.7/lib/python2.4/site-packages/matplotlib/mpl-data

export HOME=/tmp

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

python $GRAPH_ROOT/tools/phedex-2.5-cgi.py

