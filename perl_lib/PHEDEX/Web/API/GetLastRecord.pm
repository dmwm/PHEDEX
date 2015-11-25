package PHEDEX::Web::API::GetLastRecord;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Web::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::GetLastRecord 

=head1 DESCRIPTION

retrieve last space usage record for a node

=head2 Options

  node             node name (requred)

=head2 Output

  <record timestamp=[timestamp] node=[node]> 
      <dirs dir=[dir] size=[size]/>
      ...
  </record>

  Result is a record element containing a list of dirs elements. 
  record  attributes:
    node         - node name
    timestamp    - the timestamp for the record 
  dirs attributes:
    dir          - path to the directory on storage
    size         - space occupied by files and subdirectories in this path 

=cut

sub methods_allowed { return ('GET'); }
sub duration { return 0; }
sub invoke { return getlastrecord(@_); }

sub getlastrecord  {
    my ($core, %h) = @_;
    my ($method, $result, $record, $dirtemp, $data);
    my $dirstemp = [];
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
    if ($args{node}) {
	eval {
	    $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
	};
	if ( $@ ) {
	    die PHEDEX::Web::Util::http_error(400,$@);
	}
	foreach $data (@{$result}) {
	    $dirtemp = {
		DIR => $data->{DIR},
		SIZE => $data->{SPACE},
	    };
	    push @$dirstemp, $dirtemp;
	}
	$record = {
	    timestamp => $$result[0]->{TIMESTAMP},
	    node => $$result[0]->{NAME},
	    dirs => $dirstemp,
	};	
    }
    return { record => $record };
}
1;
