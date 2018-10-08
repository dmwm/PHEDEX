package PHEDEX::Web::API::GetLastRecord;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Web::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::GetRecords - Query storage info 

=head1 DESCRIPTION

Query storage info with options from oracle backend

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
sub invoke { return getrecords(@_); }

sub getlastrecord  {
    my ($core, %h) = @_;
    my ($method, $result, $record, $last, $data);
    my ($dirtemp,$dirstemp);
    $method = $core->{REQUEST_METHOD};
    my %args;
    eval {
        %args = &validate_params(\%h,
				 allow => [ qw ( node ) ],
				 required => [ qw ( node ) ],
				 spec =>
				 {
				     node => { using => 'node', multiple => 0 },
				 });
    };
    if ( $@ ) {
        return PHEDEX::Web::Util::http_error(400, $@);
    } 
    # Convert all arguments to lowcase:
    foreach ( keys %args ) {
	$args{lc($_)} = delete $args{$_};
    }

    # Check node name syntax (X-names are discarded here)
    if ($args{node} =~ m/^T\*$/) {
	eval {
	    $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
	};
	if ( $@ ) {
	    die PHEDEX::Web::Util::http_error(400,$@);
	}
	$record = {
	    node => $results[0]->{NAME};
	    timestamp => $result[0]->{TIMESTAMP}
	};	
	foreach $data (@{$result}) {
	    $dirtemp->{DIR} = $data->{DIR};
	    $dirtemp->{SPACE} = $data->{SPACE};
	    push @$dirstemp, $dirtemp;
	}
    }
    return { record => $record };
}
1;
