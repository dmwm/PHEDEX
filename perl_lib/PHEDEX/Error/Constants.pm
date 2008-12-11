package PHEDEX::Error::Constants;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw( CONST_RC_EXPIRED   CONST_XC_EXPIRED   CONST_RC_LOST_TASK CONST_XC_NOXFER 
                  CONST_RC_LOST_FILE CONST_XC_LOST_FILE CONST_RC_VETO );

# Error code definitions for PhEDEx errors
# RC : report code
# XC : transfer code
use constant {
    CONST_RC_EXPIRED   => -1;  # the task expired
    CONST_XC_EXPIRED   => -1;  # the transfer expired
    CONST_RC_LOST_TASK => -2;  # the task was lost
    CONST_XC_NOXFER    => -2;  # no transfer was attempted
    CONST_RC_LOST_FILE => -3;  # a critical state file was lost
    CONST_XC_LOST_FILE => -3;  # a critical state file was lost
    CONST_RC_VETO      => -86; # the transfer task was vetoed
};

1;
