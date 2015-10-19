package PHEDEX::Tests::File::Download::Helpers::SessionCreation;

use strict;
use warnings;

use base 'Exporter';

use IO::File;
use File::Copy qw(move);
use File::Path;
use PHEDEX::File::Download::Circuits::ResourceManager;
use POE;
use POSIX;

our @EXPORT = qw(setupSession setupResourceManager logChecking $baseLocation);
our $baseLocation = '/tmp/tests/circuit-manager';

sub setupSession {
    my ($circuitManager, $endAfter, $additionalEvents) = @_;
    my $states;

    $states->{_start} = sub {
        my ( $kernel, $session ) = @_[ KERNEL, SESSION ];
        $circuitManager->Logmsg("Starting a POE test session (id=",$session->ID,")");
        $circuitManager->_poe_init($kernel, $session);
        foreach my $event (@{$additionalEvents}) {
            # Only start the events which have a timer declared
            $kernel->delay($event->[0] => $event->[1], $circuitManager, $session) if (defined $event->[1]);
        }
        $kernel->delay(stopSession => $endAfter);
    };
    foreach my $event (@{$additionalEvents}) {
        $states->{$event->[0]} = $event->[0];
    };
    $states->{stopSession} = sub {
        my $eventCount = POE::Kernel->get_event_count();
        print "There are still $eventCount events queued\n";
        POE::Kernel->stop();
    };

    my $session = POE::Session->create(inline_states => $states);

    return $session;
}

# Sets up circuit manager and test area in order to be used for testing the 'verifyStateConsistency' event
sub setupResourceManager {
    my ($runTime, $logName, $verify, $additionalEvents, $httpControl, $backend, $backendArgs) = @_;

    # Clear the test area if there's anything there
    File::Path::rmtree("$baseLocation".'/data', 1, 1) if (-d "$baseLocation".'/data');
    File::Path::make_path("$baseLocation/data/circuits/requested", {error => \my $err});
    File::Path::make_path("$baseLocation/data/circuits/online", {error => \$err});
    File::Path::make_path("$baseLocation/data/circuits/offline", {error => \$err});
    File::Path::make_path("$baseLocation/data/bod/offline", {error => \$err});
    File::Path::make_path("$baseLocation/data/bod/online", {error => \$err});
    File::Path::make_path("$baseLocation/logs", {error => \$err});

    $backend = 'Dummy' if ! defined $backend;
    $backendArgs = {AGENT_TRANSLATION_FILE => '/data/agent_ips.txt'} if ! defined $backendArgs;

    # Create a new circuit manager and setup session
    my $circuitManager = PHEDEX::File::Download::Circuits::ResourceManager->new(BACKEND_TYPE => $backend,
                                                                                BACKEND_ARGS => $backendArgs,
                                                                                STATE_DIR => "$baseLocation".'/data',
                                                                                VERBOSE => 1,
                                                                                HTTP_CONTROL => defined $httpControl? $httpControl : 0);
    # Only start the events that we deem necesssary
    $circuitManager->{PERIOD_CONSISTENCY_CHECK} = $verify;

    # Add an appender to the logger. This will allow us to search for log messages and verify stuff is actually getting done
    my $logger = $circuitManager->get_logger("PhEDEx");
    my $appender = Log::Log4perl::Appender->new("Log::Log4perl::Appender::File", filename => "$baseLocation".'/logs/'.$logName);
    $logger->add_appender($appender);

    # Setup session
    my $session = setupSession($circuitManager, $runTime, $additionalEvents);

    return ($circuitManager, $session);
}

sub logChecking {
    my ($logName, $textToFind) = @_;
    open LOG, "</tmp/tests/circuit-manager/logs/$logName";
    my @lines = <LOG>;
    my $line;
    foreach my $line (@lines) {
        return 1 if (grep {$textToFind} $line);
    }
    close LOG;
    return 0;
}

1;