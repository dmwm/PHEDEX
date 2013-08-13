#!/bin/bash

source ./setup_env.sh

check_success() 
{
  if [ $# -ne 2 ]; then
    echo "check_success expects exact two parameters."
    exit 1
  fi

  local step=$1
  local exit_code=$2

  if [ $exit_code -ne 0 ]; then
    echo "$step was not successful"
    exit $exit_code
  fi
}

cleanup_swdir()
{
  rm -rf $SWAREA
  check_success "Cleaning up $SWAREA" $?
}

prepare_bootstrap()
{
  ## prepare bootstrapping
  mkdir -p $SWAREA
  wget -O $SWAREA/bootstrap.sh http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
  check_success "Preparing bootstrapping" $?
}

bootstrapping()
{
  ## bootstrapping
  chmod +x $SWAREA/bootstrap.sh
  sh -x $SWAREA/bootstrap.sh setup -repository $REPO -path $SWAREA -arch $SCRAM_ARCH >& $SWAREA/bootstrap_$SCRAM_ARCH.log
  check_success "Bootstrapping" $?
}

install_software()
{
  cleanup_swdir
  prepare_bootstrap
  bootstrapping

  ## software installation 
  source $SWAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh
  apt-get update -y
  apt-get install $DBS3CLIENT $DBS3CLIENTDOC $DATAPROVIDER $LIFECYCLEAGENT $DBS3LIFECYCLE -y
  check_success "Install $DBS3CLIENT, $DBS3CLIENTDOC, $DATAPROVIDER, $LIFECYCLEAGENT and $DBS3LIFECYCLE" $?
}

### run software installation
install_software
