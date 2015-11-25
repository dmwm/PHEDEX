package PHEDEX;

use strict;
use warnings;

use PHEDEX::File::Download::CircuitAgent;
use PHEDEX::Core::Help;

use POE;

my %args = (
    LABEL =>            'download-fdt',
    DBCONFIG =>         '/data/TESTBED_ROOT/DBParam:CircuitTestbed',   
    NODES =>            ['T2_ANSE_CERN_Dev'],
    ACCEPT_NODES =>     [],
    VALIDATE_COMMAND => ['/data/TESTBED_ROOT_Config/Site/fdt-validate.pl'],
    DELETE_COMMAND =>   ['/data/TESTBED_ROOT_Config/Site/fdt-delete.pl'],
    BACKEND_TYPE =>     'FDT',
    PROTOCOLS =>        'fdt',
    NJOBS =>            1,
    BATCH_FILES =>      15,
    LINK_PEND =>        30,
    COMMAND  =>         '/usr/bin/fdtcp,--debug=DEBUG',
    DROPDIR =>          '/data/TESTBED_ROOT/CircuitTestbed_T2_ANSE_CERN_Dev/state/download-fdt',    
    WORKDIR =>          '/data/TESTBED_ROOT/CircuitTestbed_T2_ANSE_CERN_Dev/state/download-fdt/workdir',    
    TASKDIR  =>         '/data/TESTBED_ROOT/CircuitTestbed_T2_ANSE_CERN_Dev/state/download-fdt/task',
    ARCHIVEDIR =>       '/data/TESTBED_ROOT/CircuitTestbed_T2_ANSE_CERN_Dev/state/download-fdt/archive',
);

my @backArgs = ['-protocols', 'fdt', '-command', '/usr/bin/fdtcp,--debug=DEBUG', '-batch-files', '15', '-link-pending-files', '30', '-jobs', '1'];

my $agent = PHEDEX::File::Download::CircuitAgent->new(%args, BACKEND_ARGS => @backArgs);
POE::Kernel->run();
print "POE kernel has ended, now I shoot myself\n";

exit 0;
