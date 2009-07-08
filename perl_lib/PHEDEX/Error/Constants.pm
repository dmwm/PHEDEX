package PHEDEX::Error::Constants;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw( PHEDEX_RC_SUCCESS   PHEDEX_XC_SUCCESS   PHEDEX_VC_SUCCESS
		  PHEDEX_RC_EXPIRED   PHEDEX_XC_EXPIRED   PHEDEX_RC_LOST_TASK PHEDEX_XC_NOXFER 
                  PHEDEX_RC_LOST_FILE PHEDEX_XC_LOST_FILE PHEDEX_VC_LOST_FILE
		  PHEDEX_VC_VETO      PHEDEX_RC_VETO
		  PHEDEX_XC_KILLED    PHEDEX_XC_TIMEOUT   PHEDEX_XC_AGENTKILLED
		  );

# Error code definitions for PhEDEx errors
# RC : report code, reported to the phedex database
# XC : transfer code, returned from a transfer tool
# VC : validation code, returned from a validation script

# Notes on error codes:
#   (-inf,-512] are reserved for future use
#   [-511,-256] are reserved for PhEDEx-ignored exit codes (= -255 - $exitcode)
#   [-255,-1]   are reserved for PhEDEx-generated error codes
#   [1,127]     are exit codes returned by transfer/validation commands
#   [128,255]   are signalled exit codes by transfer/validation commands (= 127 + $signal)
#   [256,+inf)  are reserved for future use
use constant {
    # these are a bit obvious, but anyway
    PHEDEX_RC_SUCCESS     =>  0,   # the task succeeded
    PHEDEX_XC_SUCCESS     =>  0,   # the transfer succeeded
    PHEDEX_VC_SUCCESS     =>  0,   # the validation succeeded

    PHEDEX_RC_EXPIRED     => -1,   # the task expired
    PHEDEX_XC_EXPIRED     => -1,   # the transfer expired
    PHEDEX_RC_LOST_TASK   => -2,   # the task was lost
    PHEDEX_XC_NOXFER      => -2,   # no transfer was attempted
    PHEDEX_RC_LOST_FILE   => -3,   # a critical state file was lost
    PHEDEX_XC_LOST_FILE   => -3,   # a critical state file was lost
    PHEDEX_VC_LOST_FILE   => -3,   # a critical state file was lost
    PHEDEX_VC_VETO        => 86,   # the transfer task was vetoed
    PHEDEX_RC_VETO        => -86,  # the transfer task was vetoed

    PHEDEX_XC_KILLED      => -4,   # the transfer was killed (externally)
    PHEDEX_XC_TIMEOUT     => -5,   # the transfer was timed out (by PhEDEx)
    PHEDEX_XC_AGENTKILLED => -6,   # the agent/wrapper managing the transfer was killed
};

1;
