package PHEDEX::Core::Logging;

=head1 NAME

PHEDEX::Core::Logging - a drop-in replacement for Toolkit/UtilsLogging

Although this module will be replaced by the Log4Perl module at some point,
it's still included here for completeness.

The logmsg() function has been changed to call 'warn()' directly, rather than
simply print to STDERR, while the note() function prints to STDERR, but does
not do it via the logmsg function anymore. The practical result of this is
that if you are using the PHEDEX::Debug module to debug your script, any call
to the logmsg(), warn() or alert() functions in this package will cause the
program to abort.

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(logmsg alert warn dbgmsg note);
use POSIX;

# Produce an alert message
sub logmsg
{
    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
    my $me = $0; $me =~ s|.*/||;
    warn         "$date: ${me}\[$$]: ", @_, "\n";
}

sub alert
{
    &logmsg ("alert: ", @_);
}

sub warn
{
    &logmsg ("warning: ", @_);
}

sub dbgmsg
{
    &logmsg ("debug:  ", @_);
}

sub note
{
    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
    my $me = $0; $me =~ s|.*/||;
    print STDERR "$date: ${me}\[$$]: note: ", @_, "\n";
}

1;
