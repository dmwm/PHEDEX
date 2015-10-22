package PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsLSM;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(
                STATE_CREATED STATE_FAILED STATE_EXPIRED STATE_TERMINATING STATE_TERMINATED
                MSG_FORCE_END MSG_TERMINATE_REQUEST MSG_TERMINATE_CONFIRMED MSG_EXPIRED
                LSM_TRANSITIONS
                );

# State machine states and messages                
use constant {
    # States
    STATE_CREATED           =>  "Created",
    STATE_FAILED            =>  "Failed",
    STATE_EXPIRED           =>  "Passed end time",
    STATE_TERMINATING       =>  "Terminating",
    STATE_TERMINATED        =>  "Terminated",
        
    # Messages
    MSG_FORCE_END           =>  "forceEnd",
    MSG_TERMINATE_REQUEST   =>  "term.rq",
    MSG_TERMINATE_CONFIRMED =>  "term.cf",
    MSG_EXPIRED             =>  "endTime",  
};

# State machine transitions
use constant { 
    LSM_TRANSITIONS => {
        STATE_CREATED()                 => {
            MSG_FORCE_END()             => STATE_FAILED,
            MSG_TERMINATE_REQUEST()     => STATE_TERMINATING,
            MSG_EXPIRED()               => STATE_EXPIRED,
        },    
        
        STATE_FAILED()                  => {
            MSG_TERMINATE_REQUEST()     => STATE_TERMINATING,
        },
        
        STATE_EXPIRED()                 => {
            MSG_TERMINATE_REQUEST()     => STATE_TERMINATING,
        },
        
        STATE_TERMINATING()             => {
            MSG_TERMINATE_CONFIRMED()   => STATE_TERMINATED,
        }
    }
};

1;