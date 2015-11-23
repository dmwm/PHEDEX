package PHEDEX::Web::API::GetRecords;
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
sub invoke { return getrecords(@_); }

sub nrdebug {
    my $message = shift;
    open(my $fh, '>>', '/tmp/nrdebug_report.txt');
    print $fh $message . "\n";
    close $fh;
}
sub getrecords  {
  my ($core, %h) = @_;
  my ($method,$inputnode,$result,@inputnodes,@records, $last, $data);
  my ($dirtemp,$dirstemp,$node);
  $method = $core->{REQUEST_METHOD};
  my %args;
  &nrdebug ('trace0 in storageusage');
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

  if ($args{node} =~ m/^T\*$/) {
     eval {
        $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
     };
     if ( $@ ) {
       die PHEDEX::Web::Util::http_error(400,$@);
     }
     $last = @{$result}[0]->{NAME};
     $dirstemp = ();
     foreach $data (@{$result}) {
       $dirtemp = {};
       $dirtemp->{DIR} = $data->{DIR};
       $dirtemp->{SPACE} = $data->{SPACE};
       $dirtemp->{TIMESTAMP} = $data->{TIMESTAMP};
       $dirtemp->{NAME} = $data->{NAME};
       push @$dirstemp, $dirtemp;
       if ($last !~ m/$data->{NAME}/) {
          $node = {};
          $node->{subdir} = $args{rootdir};
          $node->{node} = $last;
          $node->{timebins} = getNodeInfo($core, $dirstemp, %args);
          push @records, $node;
          $dirstemp = ();
          $last = $data->{NAME};
       }
    }
    if ($last =~ m/@{$result}[0]->{NAME}/) {
       $node = {};
       $node->{subdir} = $args{rootdir};
       $node->{node} = $last;
       $node->{timebins} = getNodeInfo($core, $dirstemp, %args);
       push @records, $node;
    }
  } 
  else {
     if (ref $args{node} eq 'ARRAY') {
        @inputnodes = @{$args{node}};
     }
     else {
        @inputnodes = $args{node};
     }
     foreach $inputnode (@inputnodes) {
        my $node = {};
        $args{node} = $inputnode;
        $node->{subdir} = $args{rootdir};
        eval {
          $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
        };
        if ( $@ ) {
          die PHEDEX::Web::Util::http_error(400,$@);
        }
        $node->{node} = @{$result}[0]->{NAME};
        $node->{timebins} = getNodeInfo($core, $result, %args); 
        push @records, $node;
     }
  }

  return { nodes => \@records };
}

sub getNodeInfo {
  my ($core, $result, %args) = @_;
  my ($level,$rootdir,%dir, $dirs, $data);
  my ($dirtemp, $timetemp, $dirstemp, $last, $time);
  my ($dirarray, $dirhash, $dirhashSep, $levelarray, $levelhash, $timebin, $timebins);
  my %temp;
  # New vars: 
  my ($reldepth, $levelshash, $dirsize, $depth);
  my @datalist = ();
  $timebins = ();
  $rootdir = $args{rootdir};
  $level = $args{level};

  # classify data by timestamp
  $timetemp = {};
  my $current = undef;
  $dirstemp = ();
  foreach $data (@{$result}) {
      if (!$current || ( $data->{TIMESTAMP} != $current ) ) {
	  if ( $dirstemp ) {
	      $timetemp->{$current} = $dirstemp;
	      $dirstemp = ();
	  }
	  $current = $data->{TIMESTAMP};
      }
    $dirtemp = {};
    $dirtemp->{dir} = $data->{DIR};
    $dirtemp->{space} = $data->{SPACE};
    push @$dirstemp, $dirtemp;
  }
  if ( $dirstemp ) {
      $timetemp->{$current} = $dirstemp;
  }
  return $timetemp;
}

sub checklevel {
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
