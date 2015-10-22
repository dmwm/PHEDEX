package PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsRSM;

use strict;
use warnings;

use base 'Exporter';

use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsLSM;

our @EXPORT = qw(
                STATE_RESERVE_START STATE_RESERVE_CHECKING STATE_RESERVE_HELD STATE_RESERVE_COMMITING STATE_RESERVE_FAILED STATE_RESERVE_TIMEOUT STATE_RESERVE_ABORTING STATE_RESERVED
                MSG_RESERVE MSG_RESERVE_COMMIT MSG_RESERVE_ABORT MSG_RESERVE_CONFIRMED MSG_RESERVE_FAILED MSG_RESERVE_COMMIT_CONFIRMED MSG_RESERVE_COMMIT_FAILED MSG_RESERVE_ABORT_CONFIRMED MSG_RESERVE_TIMEOUT
                RSM_TRANSITIONS
                );

# State machine states and messages                
use constant {
    STATE_RESERVE_START         =>  "Reserve start",
    STATE_RESERVE_CHECKING      =>  "Reserve checking",
    STATE_RESERVE_HELD          =>  "Reserve held",
    STATE_RESERVE_COMMITING     =>  "Reserve commiting",
    STATE_RESERVE_FAILED        =>  "Reserve failed",
    STATE_RESERVE_TIMEOUT       =>  "Reserve timeout",
    STATE_RESERVE_ABORTING      =>  "Reserve aborting",
    STATE_RESERVED              =>  "Reserved", # This isn't in the specifications
        
    MSG_RESERVE                     =>  "rsv.rq",
    MSG_RESERVE_COMMIT              =>  "rsvcommit.rq",
    MSG_RESERVE_ABORT               =>  "rsvabort.rq",
    MSG_RESERVE_CONFIRMED           =>  "rsv.cf",
    MSG_RESERVE_FAILED              =>  "rsv.fl",
    MSG_RESERVE_COMMIT_CONFIRMED    =>  "rsvcommit.cf",
    MSG_RESERVE_COMMIT_FAILED       =>  "rsvcommit.fl",
    MSG_RESERVE_ABORT_CONFIRMED     =>  "rsvabort.cf",
    MSG_RESERVE_TIMEOUT             =>  "rsvTimeout.nt",
};

# State machine transitions
use constant { 
    RSM_TRANSITIONS => {
        STATE_RESERVE_START()               => {
            MSG_RESERVE()                   =>  STATE_RESERVE_CHECKING
        },
            
        STATE_RESERVE_CHECKING()            => {
            MSG_RESERVE_FAILED()            =>  STATE_RESERVE_FAILED,
            MSG_RESERVE_CONFIRMED()         =>  STATE_RESERVE_HELD,
        },
        
        STATE_RESERVE_HELD()                => {
            MSG_RESERVE_COMMIT()            => STATE_RESERVE_COMMITING,
            MSG_RESERVE_ABORT()             => STATE_RESERVE_ABORTING,
            MSG_RESERVE_TIMEOUT()           => STATE_RESERVE_TIMEOUT
        },
        
        STATE_RESERVE_COMMITING()           => {
            MSG_RESERVE_COMMIT_CONFIRMED()  => STATE_RESERVED,
            MSG_RESERVE_COMMIT_FAILED()     => STATE_RESERVE_START,
        },
        
        STATE_RESERVE_FAILED()              => {
            MSG_RESERVE_ABORT()             => STATE_RESERVE_ABORTING,            
        },
        
        STATE_RESERVE_ABORTING()            => {
            MSG_RESERVE_ABORT_CONFIRMED()   => STATE_RESERVE_START,
        },
        
        STATE_RESERVE_TIMEOUT()             => {
            MSG_RESERVE_ABORT()             => STATE_RESERVE_ABORTING, 
            MSG_RESERVE_COMMIT()            => STATE_RESERVE_START,
        },
        
        # This state transition is also an addition
        STATE_RESERVED()                    => {
            MSG_TERMINATE_CONFIRMED()       => STATE_RESERVE_START
        }
    },
};
                
1;