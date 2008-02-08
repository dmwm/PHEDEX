package UtilsLogging; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(logmsg alert warn note);
use POSIX;

# Produce an alert message
sub logmsg
{
    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
    my $me = $0; $me =~ s|.*/||;
    print STDERR "$date: ${me}\[$$]: ", @_, "\n";
}

sub alert
{
    &logmsg ("alert: ", @_);
}

sub warn
{
    &logmsg ("warning: ", @_);
}

sub note
{
    &logmsg ("note: ", @_);
}

print STDERR "WARNING:  use of Common/UtilsLogging.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
