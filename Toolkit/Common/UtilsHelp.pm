package UtilsHelp; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(usage);
sub usage
{
    print STDERR @_;
    open (ME, "< $0")
        && print(STDERR map { s/^\#\#H ?//; $_ } grep (/^\#\#H/, <ME>))
	&& close(ME);
    exit(1);
}

print STDERR "WARNING:  use of Common/UtilsHelp.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
