package PHEDEX::Web::API::TransferHistory;
# use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferHistory - show quality of the links

=head2 transferhistory

Return

 <link/>
 <link/>
 ...

=head3 options

 required inputs: none (default to be the last hour)
 optional inputs: from_node, to_node, timebin, timewidth

  from_node       name of the from node
  to_node         name of the to_node
  timebin         end point of the time window
  timewidth       length of the window before timebin in seconds

  default values: timebin = now, timewidth = 3600

=head3 output

 <link/>
 ......

=head3 <link> elements:

  from_node
  to_node
  done_files
  done_bytes
  fail_files
  fail_bytes
  expire_files
  expire_bytes
  rate
  quality

=head3 definition of quality

  $q = done_files / (done_files + fail_files)
  quality = 3 if $q > .66
  quality = 2 if .66 >= $q > .33
  quality = 1 if .33 >= $q > 0
  quality = 0, otherwise 

=cut 

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return transferhistory(@_); }

sub transferhistory
{
    my ($core, %h) = @_;

    if (! exists $h{timebin})
    {
        # now
        $h{timebin} = time();
    }

    if (! exists $h{timewidth})
    {
        # one hour
        $h{timewidth} = 3600;
    }

    my $r = PHEDEX::Web::SQL::getTransferHistory($core, %h);

    foreach (@$r)
    {
        $_ -> {'QUALITY'} = &Quality ($_);
    }

    return { link => $r };
}

sub Quality
{
  my $h = shift;
  my $sum = $h->{DONE_FILES} + $h->{FAIL_FILES};

  if ($sum == 0)
  {
      return 0;
  }

  my $x = $h->{DONE_FILES} / $sum;
  return 3 if $x > 0.66;
  return 2 if $x > 0.33;
  return 1 if $x > 0;
  return 0;
}

1;
