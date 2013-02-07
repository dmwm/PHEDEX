package PHEDEX::Web::API::TransferHistorySummary;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferHistorySummary - Summary of history of completed transfer attempts

=head1 DESCRIPTION

Summary of historical statistics about completed transfer attempts.

Note: PhEDEx monitoring is not "real time", which means that statistics
for past events are added to the history as they are received. For
example, if you are interested in the transfers for the last day, you
are advised to make the call to the data service at least 3 hours
after that day ends, to give PhEDEx time to add the statistics to the
DB tables.  Even waiting this amount of time does not guaruntee that
more statistics will be added to the day later, but in most cases it
is sufficient.

=head2 Options

  no options

=head2 Output

  <transfer>
   timebin
   sum_done_bytes 
  </transfer>

=head3 <transfer> elements

  timebin             the end point of each timebin, aligned with binwidth
  sum_done_bytes      number of bytes in successful transfers

=cut 

use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return transferhistory(@_); }

my $map = {
   _KEY => 'TIMEBIN+SUM_DONE_BYTES',
   timebin => 'TIMEBIN',
   done_bytes => 'SUM_DONE_BYTES',
};
my $sth;
my %p;

sub spool
{
    my ($core, %h) = @_;

    if (!$sth)
    {
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }

        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getTransferHistorySummary($core, %p));
    }

    my $r;
    $r = $sth->spool();

    #return { transfer => PHEDEX::Core::Util::flat2tree($map, $r) };
    #return {transfer => $r}; to be fixed
    return $r;
}

1;
