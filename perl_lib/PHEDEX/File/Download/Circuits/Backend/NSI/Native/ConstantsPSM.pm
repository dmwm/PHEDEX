package PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsPSM;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(
                STATE_PROVISIONING STATE_PROVISIONED STATE_RELEASING STATE_RELEASED
                MSG_PROVISION MSG_PROVISION_CONFIRMED MSG_RELEASE MSG_RELEASE_CONFIRMED
                PSM_TRANSITIONS
                );

# State machine states and messages                
use constant {
    STATE_PROVISIONING        =>  "Provisioning",
    STATE_PROVISIONED         =>  "Provisioning confirmed",
    STATE_RELEASING           =>  "Releasing",
    STATE_RELEASED            =>  "Release confirmed",
        
    # PSM messages
    MSG_PROVISION                   =>  "prov.rq",
    MSG_PROVISION_CONFIRMED         =>  "prov.cf",
    MSG_RELEASE                     =>  "release.rq",
    MSG_RELEASE_CONFIRMED           =>  "release.cf",  
};

# State machine transitions
use constant { 
    PSM_TRANSITIONS => {
        STATE_RELEASED()                => {
            MSG_PROVISION()             => STATE_PROVISIONING,       
        },    
        
        STATE_PROVISIONING()            => {
            MSG_PROVISION_CONFIRMED()   => STATE_PROVISIONED,
        },
        
        STATE_PROVISIONED()             => {
            MSG_RELEASE()               => STATE_RELEASING,
        },
        
        STATE_RELEASING()               => {
            MSG_RELEASE_CONFIRMED()     => STATE_RELEASED,
        }
    }
};
                
1;