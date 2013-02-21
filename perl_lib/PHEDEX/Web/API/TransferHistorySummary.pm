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
  sum_gigabytes       number of GB (1000**4 bytes) in successful transfers

=cut 

use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return transferhistorysummary(@_); }
sub transferhistorysummary {
  my ($core, %h) = @_;
  return {transferhistorysummary => PHEDEX::Web::SQL::getTransferHistorySummary($core) }
}

1;
