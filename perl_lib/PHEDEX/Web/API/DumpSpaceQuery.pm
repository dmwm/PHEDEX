package PHEDEX::Web::API::DumpSpaceQuery;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Web::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::DumpSpaceQuery - useful for debugging only

=head1 DESCRIPTION

returns unprocessed result of  PHEDEX::Web::SQLSpace::querySpace
on DMWMMON database using input parameters 

=head2 Options

 required inputs: node 
 optional inputs: (as filters) level, rootdir, time_since, time_until 

  node             node name, could be multiple, all(T*). 
  level            the depth of directories, should be less than or equal to 6 (<=6), the default is 4
  rootdir          the path to be queried
  time_since       former time range, since this time, if not specified, time_since=0
  time_until       later time range, until this time, if not specified, time_until=10000000000
                   if both time_since and time_until are not specified, the latest record will be selected

=head2 Output

  <nodes>
    <timebins>
      <levels>
        <data/>
      </levels>
       ....
    </timebins>
    ....
  </nodes>
  ....

=head3 <nodes> elements

  subdir             the path searched
  node               node name

=head3 <timebins> elements

  timestamp          time for the directory info

=head3 <levels> elements

  level              the directory depth

=head3 <data> elements

  size               the size of the directory
  dir                the directory name

=cut

sub methods_allowed { return ('GET'); }
sub duration { return 0; }
sub invoke { return dumpspacequery(@_); }

sub dumpspacequery  {
  my ($core,%h) = @_;
  my $result = PHEDEX::Web::SQLSpace::querySpace($core, %h);
  return { querySpace => $result };
}

1;
