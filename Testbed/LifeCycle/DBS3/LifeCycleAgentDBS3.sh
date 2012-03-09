#!/bin/bash
##
## DBS 3 Life Cycle Agent Test
## (Automated installation, configuration and example queries for Life Cycle Agent)
##

WORKINGDIR=/tmp/$USER/DBS3_Life_Cycle_Agent_Test
SCRAM_ARCH=slc5_amd64_gcc461
APT_VER=429-comp
SWAREA=$WORKINGDIR/sw
REPO=comp.pre

GRIDENVSCRIPT=/afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh

DBS3CLIENTVERSION=3.0.12
DBS3CLIENT=cms+dbs3-client+$DBS3CLIENTVERSION
DBS3CLIENTDOC=cms+dbs3-client-webdoc+$DBS3CLIENTVERSION

check_success() 
{
  if [ $# -eq 3 ]; then
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

check_x509_proxy()
{
  if [ -e $GRIDENVSCRIPT ]; then
    source $GRIDENVSCRIPT
    voms-proxy-info --exists &> /dev/null
    
    if [ $? -ne 0 ]; then
      echo "No valid x509 proxy found! Please, create one ..."
      voms-proxy-init --voms cms
      check_success "Creating x509 proxy" $?
    fi

  else
    echo "Grid environment cannot be set-up. $GRIDENVSCRIPT is missing."
    exit 2

  fi
}

cleanup_workingdir()
{
  ## Clean up pre-exists workdir
  if [ -d $WORKINGDIR ]; then
    echo "$WORKINGDIR already exists. Cleaning up ..."
    rm -rf $WORKINGDIR
    check_success "CleanUp" $?
  fi
}

prepare_bootstrap()
{
  ## pre-pare bootstrapping
  mkdir -p $SWAREA
  wget -O $SWAREA/bootstrap.sh http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
  check_success "Pre-pare bootstrapping" $?
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
  cleanup_workingdir
  prepare_bootstrap
  bootstrapping

  ## software installation 
  source $SWAREA/$SCRAM_ARCH/external/apt/$APT_VER/etc/profile.d/init.sh
  apt-get update -y
  apt-get install $DBS3CLIENT $DBS3CLIENTDOC -y
  check_success "Install $DBS3CLIENT and $DBS3CLIENTDOC" $?
}

setup_dbs_client()
{
  if [ ! -d $SWAREA ]; then
    echo "Software area not found in $SWAREA. Installing software ..."
    install_software
  fi

  ## setup dbs_client
  source $SWAREA/$SCRAM_ARCH/cms/dbs3-client/$DBS3CLIENTVERSION/etc/profile.d/init.sh
  export DBS_READER_URL=https://dbs3-dastestbed.cern.ch/dbs/prod/global/DBSReader
  export DBS_WRITER_URL=https://dbs3-dastestbed.cern.ch/dbs/prod/global/DBSWriter
}

run_example()
{
  ## Check for a valid x509proxy
  check_x509_proxy

  ## set-up dbs client
  setup_dbs_client

  ## run example queries
  python LifeCycleAgentDBS3.py
}

printhelp()
{
  echo -e "\nDBS 3 Life Cycle Agent Test"
  echo "(Automated installation, configuration and example queries for Life Cycle Agent)"
  echo "LifeCycleAgentDBS3.sh <options>"
  echo "Options are:"
  echo "============"
  echo "-cleanup: Cleaning up previous deployment"
  echo "-install: (re-)install DBS3 Client"
  echo "-run_example: Run DBS3 example"
  echo "-all: cleanup install run_example"
}

if [ $# -ge 1 ]; then
  case $1 in
    -cleanup ) cleanup_workingdir;;
    -all ) install_software; run_example;;
    -install ) install_software;;
    -run_example ) run_example;; 
    -h ) printhelp ;;
    -* ) echo "$0: unrecognised option $1, use -h for help" 1>&2; exit 1 ;;
    *  ) break ;;
  esac
else
  printhelp
fi
