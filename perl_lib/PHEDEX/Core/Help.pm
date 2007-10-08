package PHEDEX::Core::Help;

=head1 NAME

PHEDEX::Core::Help - facilitate adding help to a script

=head1 DESCRIPTION

Rather trivial really. Construct your help messages as plain text with
'##H ' at the beginning of the lines and embed them in your script. Calling
the 'usage()' function from this module will print that text and exit.

This is a direct drop-in replacement for the old Toolkit/Common/UtilsHelp.pm.

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(usage);
sub usage
{
    print STDERR @_;
    open (ME, "< $0")
        && print(STDERR map { s/^\#\#H ?//; $_ } grep (/^\#\#H/, <ME>))
	&& close(ME);
    exit(1);
}

1;
