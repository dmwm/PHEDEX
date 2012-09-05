package PHEDEX::Web::API::TransferHistory;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferHistory - history of completed transfer attempts

=head1 DESCRIPTION

Serves historical statistics about completed transfer attempts.

Note: PhEDEx monitoring is not "real time", which means that statistics
for past events are added to the history as they are received. For
example, if you are interested in the transfers for the last day, you
are advised to make the call to the data service at least 3 hours
after that day ends, to give PhEDEx time to add the statistics to the
DB tables.  Even waiting this amount of time does not guaruntee that
more statistics will be added to the day later, but in most cases it
is sufficient.

=head2 Options

 required inputs: none (default to be the last hour)
 optional inputs: from, to, timebin, timewidth

  from            name of the source node, could be multiple
  to              name of the destination node, could be multiple
  starttime       start time
  endtime         end time
  binwidth        width of each timebin in seconds
  (ctime)         set output of time in YYYY-MM-DD hh:mm:ss format
                  otherwise, output of time is in UNIX time format

  default values:
  endtime = now
  binwidth = 3600
  starttime = endtime - binwidth

=head3 format of time

  starttime and endtime could in one of the following format
  [1] <UNIX time>            (integer)
  [2] "YYYY-MM-DD"           (assuming 00:00:00 UTC)
  [3] "YYYY-MM-DD hh:mm:ss"  (UTC)

=head2 Output

  <link>
    <transfer/>
    ...
  </link>
  ...

=head3 <link> elements

  from            name of the source node
  to              name of the destinatio node

=head3 <transfer> elements

  timebin         the end point of each timebin, aligned with binwidth
                  * when binwidth == endtime - starttime, timebin = starttime
  binwidth        width of each timebin (from the input)
  done_files      number of files in successful transfers
  done_bytes      number of bytes in successful transfers
  fail_files      number of files in failed transfers
  fail_bytes      number of bytes in failed transfers
  expire_files    number of files expired in this timebin, binwidth
  expire_bytes    number of bytes expired in this timebin, binwidth
  try_files       number of files tried
  try_bytes       number of bytes tried
  rate            sum(done_bytes)/binwidth
  quality         done_files / (done_files + fail_files)

=head3 Relation with time

  starttime <= timebin < endtime
  number of bins = (endtime - starttime)/binwidth

=cut 

use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return transferhistory(@_); }

my $map = {
    _KEY => 'FROM+TO',
    from => 'FROM',
    to => 'TO',
    transfer => {
        _KEY => 'TIMEBIN',
        timebin => 'TIMEBIN',
        binwidth => 'BINWIDTH',
        done_files => 'DONE_FILES',
        done_bytes => 'DONE_BYTES',
        expire_files => 'EXPIRE_FILES',
        expire_bytes => 'EXPIRE_BYTES',
        fail_files => 'FAIL_FILES',
        fail_bytes => 'FAIL_BYTES',
        try_files => 'TRY_FILES',
        try_bytes => 'TRY_BYTES',
        rate => 'RATE',
        quality => 'QUALITY'
    }
};

#sub transferhistory
#{
#    my ($core, %h) = @_;
#
#    # convert parameter keys to upper case
#    foreach ( qw / from to starttime endtime binwidth ctime / )
#    {
#        $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    my $r = PHEDEX::Web::SQL::getTransferHistory($core, %h);
#
#    foreach (@$r)
#    {
#        $_ -> {'QUALITY'} = &Quality ($_);
#    }
#
#    return { link => PHEDEX::Core::Util::flat2tree($map, $r) };
#}

sub Quality
{
  my $h = shift;
  my $sum = $h->{DONE_FILES} + $h->{FAIL_FILES};

  if ($sum == 0)    # no transfer at all
  {
      return undef;
  }

  return sprintf('%.4f', $h->{DONE_FILES} / $sum);
}

my $sth;
our $limit = 1000;
my @keys = ('FROM', 'TO');
my %p;

sub spool
{
    my ($core, %h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [ qw / from to starttime endtime binwidth ctime / ],
                    spec =>
                    {
                        from => { using => 'node', multiple => 1 },
                        to   => { using => 'node', multiple => 1 },
                        starttime => { using => 'time' },
                        endtime => { using => 'time' },
                        binwidth => { using => 'pos_int' },
                        ctime => { using => 'yesno' }
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }

        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getTransferHistory($core, %p), $limit, @keys);
    }

    my $r;
    $r = $sth->spool();

    if ($r)
    {
        foreach (@$r)
        {
            $_ -> {'QUALITY'} = &Quality ($_);
        }

        return { link => PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}

1;
