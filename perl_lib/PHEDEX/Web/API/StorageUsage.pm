package PHEDEX::Web::API::StorageUsage;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Web::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::StorageUsage - Query storage info 

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
sub invoke { return storageusage(@_); }

sub storageusage  {
  my ($core, %h) = @_;
  my ($method,$inputnode,$result,@inputnodes,@records, $last, $data);
  my ($dirtemp,$dirstemp,$node);
  $method = $core->{REQUEST_METHOD};
  my %args;
  # validate input parameters and set defaults: 
  eval {
        %args = &validate_params(\%h,
                allow => [ qw ( node level rootdir time_since time_until ) ],
                required => [ qw ( node ) ],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    level => { using => 'pos_int' },
                    rootdir => { using => 'dataitem_*' },
                    time_since => { using => 'time' },
                    time_until => { using => 'time' }
                });
        };
  if ( $@ ) {
        return PHEDEX::Web::Util::http_error(400, $@);
  }

  foreach ( keys %args ) {
     $args{lc($_)} = delete $args{$_};
  }

  # TODO: replace this with a smart check based on the topdir (/store/). 
  if ($args{level}) {
     if ($args{level} > 12) {
        die PHEDEX::Web::Util::http_error(400,"the level required is too deep");
     }
  }
  else {
     $args{level} = 4;
  }

  if (!$args{rootdir}) {
    $args{rootdir} = "/";
  } 
  if ( $args{time_since} ) {
    $args{time_since} = PHEDEX::Core::Timing::str2time($args{time_since});
  }
  if ( $args{time_until} ) {
    $args{time_until} = PHEDEX::Core::Timing::str2time($args{time_until});
  }
  my $root=$args{rootdir};
  my $level=$args{level};

  # Query the database: 
  eval {
      $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
  };
  # NR: This is some check, leaving it in:
  if ( $@ ) {
      die PHEDEX::Web::Util::http_error(400,$@);
  }
  # Find all node names in the returned query results:
  my $node_names = {};
  foreach my $data (@{$result}) {
      $node_names->{$data->{NAME}}=1;
  };
  # Processing all nodes:
  foreach my $nodename (keys %$node_names) { 
      print "*** Processing node:  $nodename\n"; 
      my $node_element = {};
      $node_element->{'NODE'} = $nodename;
      $node_element->{'SUBDIR'} = $root;
      # Find all timestamps for this node:
      my $timestamps = {};
      foreach my $data (@{$result}) {
	  $timestamps->{$data->{TIMESTAMP}}=1;
      };
      my @timebins; # Array for node aggregated data per timestamp
      foreach my $timestamp (keys %$timestamps) { 
	  my $timebin_element = {timestamp => $timestamp};
	  # Pre-initialize data for all levels:
	  my @levelsarray;
	  for (my $i = 1; $i<= $level; $i++) {
	      push @levelsarray, {DATA => [], LEVEL => $i};
	  };
	  # Filter out all data for a given node and timestamp from SQL output:
	  my @currentdata = grep {
	      ($_->{NAME} eq $nodename ) and ( $_->{TIMESTAMP} eq $timestamp )
	  } @{$result};
	  my ($cur, $reldepth);
	  while (@currentdata) {
	      $cur = shift @currentdata;
	      print "dir: " . $cur->{DIR} . "\n";
	      $reldepth = checklevel($root, $cur->{DIR});
	      print "Relative depth to rootdir $root = $reldepth\n";
	      # Aggregate by levels: 
	      for ( my $i = 1; $i <= $level; $i++ ) 
	      {
		  if ( $reldepth <= $i ) {
		      push @{$levelsarray[$i-1]->{DATA}},{
			  SIZE=>$cur->{SPACE}, 
			  DIR=>$cur->{DIR}
		      };
		  };
	      };
	  };
	  $timebin_element->{LEVELS} = \@levelsarray;
	  push @timebins, $timebin_element;
      };
      $node_element->{'TIMEBINS'} = \@timebins;
      push @records, $node_element;
  };
  return { nodes => \@records };
}

sub checklevel {
# Takes two paths as two arguments, checks if the second arg is a subdirectory 
# of the first arg and returns the number of how many additional directory
# levels it contains. Otherwise returns -1.
    my ($rootdir,$path)=@_;
    my @p = split "/", $path;
    my @r = split "/", $rootdir;
    return -1 if (@p < @r);
    my $result=1;
    for (my $i=1; $i < @p; $i += 1) {
	if ( ! $r[$i]){
	    $result += 1;
	    next;
	}
	if ( ($p[$i] ne $r[$i] )){
	    return -1;
	} 	
    }
    ( $rootdir eq "/" ) && ($result-=1);
    return $result;
}

1;
