package PHEDEX::Error::Constants;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw( PHEDEX_RC_SUCCESS   PHEDEX_XC_SUCCESS   PHEDEX_VC_SUCCESS
		  PHEDEX_RC_EXPIRED   PHEDEX_XC_EXPIRED   PHEDEX_RC_LOST_TASK PHEDEX_XC_NOXFER 
                  PHEDEX_RC_LOST_FILE PHEDEX_XC_LOST_FILE PHEDEX_VC_LOST_FILE
		  PHEDEX_VC_VETO );

# Error code definitions for PhEDEx errors
# RC : report code, reported to the phedex database
# XC : transfer code, returned from a transfer tool
# VC : validation code, returned from a validation script
use constant {
    # these are a bit obvious, but anyway
    PHEDEX_RC_SUCCESS   =>  0,  # the task succeeded
    PHEDEX_XC_SUCCESS   =>  0,  # the transfer succeeded
    PHEDEX_VC_SUCCESS   =>  0,  # the validation succeeded

    PHEDEX_RC_EXPIRED   => -1,  # the task expired
    PHEDEX_XC_EXPIRED   => -1,  # the transfer expired
    PHEDEX_RC_LOST_TASK => -2,  # the task was lost
    PHEDEX_XC_NOXFER    => -2,  # no transfer was attempted
    PHEDEX_RC_LOST_FILE => -3,  # a critical state file was lost
    PHEDEX_XC_LOST_FILE => -3,  # a critical state file was lost
    PHEDEX_VC_LOST_FILE => -3,  # a critical state file was lost
    PHEDEX_VC_VETO      => 86   # the transfer task was vetoed
};

1;
