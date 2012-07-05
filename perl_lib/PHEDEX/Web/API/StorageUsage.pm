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

sub storageusage 
{
  my ($core, %h) = @_;
  #warn "dumping arguments ",Data::Dumper->Dump([ \%h ]);
  my ($method,$inputnode,$result,@inputnodes,@records, $last, $data);
  my ($dirtemp,$dirstemp,$node);

  $method = $core->{REQUEST_METHOD};
  my %args;
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
  if ( $@ )
  {
        return PHEDEX::Web::Util::http_error(400, $@);
  } 


  #warn "dumping arguments after validate ",Data::Dumper->Dump([ \%args ]);
  foreach ( keys %args ) {
     $args{lc($_)} = delete $args{$_};
  }
 
  if ($args{level}) {
     if ($args{level} > 6) {
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
     $last = @{$result}[0]->{SITENAME};
     $dirstemp = ();
     foreach $data (@{$result}) {
       $dirtemp = {};
       $dirtemp->{DIR} = $data->{DIR};
       $dirtemp->{SPACE} = $data->{SPACE};
       $dirtemp->{TIMESTAMP} = $data->{TIMESTAMP};
       $dirtemp->{SITENAME} = $data->{SITENAME};
       push @$dirstemp, $dirtemp;
       #warn "dumping dirtemp ",Data::Dumper->Dump([ $dirtemp ]);
       if ($last !~ m/$data->{SITENAME}/) {
          $node = {};
          $node->{subdir} = $args{rootdir};
          $node->{node} = $last;
          #warn "dumping node1 ",Data::Dumper->Dump([ $node ]);
          $node->{timebins} = getNodeInfo($core, $dirstemp, %args);
          push @records, $node;
          $dirstemp = ();
          $last = $data->{SITENAME};
       }
    }
    if ($last =~ m/@{$result}[0]->{SITENAME}/) {
       $node = {};
       $node->{subdir} = $args{rootdir};
       $node->{node} = $last;
       #warn "dumping node1 ",Data::Dumper->Dump([ $node ]);
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
        #warn "dumping node ",Data::Dumper->Dump([ $node ]);
        push @records, $node;
     }
  }
  #warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { nodes => \@records };
  #return { storageusage => @records };
}

sub getNodeInfo 
{
  my ($core, $result, %args) = @_;
  #warn "dumping arguments for getNodeInfo",Data::Dumper->Dump([ \%args ]);
  my ($level,$rootdir,%dir, $dirs, $data);
  my ($dirtemp, $timetemp, $dirstemp, $last, $time);
  my ($dirarray, $dirhash, $dirhashSep, $levelarray, $levelhash, $timebin, $timebins);
  my %temp;

  $timebins = ();
  $rootdir = $args{rootdir};
  $level = $args{level};

  # classify data by timestamp
  $timetemp = {};
  $last = @{$result}[0]->{TIMESTAMP};
  #warn "dumping last ",Data::Dumper->Dump([ $last ]);
  $dirstemp = ();
  foreach $data (@{$result}) {
    #warn "dumping data from db ", Data::Dumper->Dump([ \$data ]);
    $dirtemp = {};
    $dirtemp->{dir} = $data->{DIR};
    $dirtemp->{space} = $data->{SPACE};
    push @$dirstemp, $dirtemp;
    $timetemp->{$data->{TIMESTAMP}} = $dirstemp;
    if ($last != $data->{TIMESTAMP}) {
       $dirstemp = ();
       $last = $data->{TIMESTAMP};
    }
  }
  #warn "dumping timetemp ",Data::Dumper->Dump([ $timetemp ]);

  foreach $time ( keys %{$timetemp} ) {
    $timebin = {};
    $timebin->{timestamp} = $time;
    $levelarray = ();
    for (my $i = 1; $i<= $level; $i++) {
       $dirhash = {};
       $dirarray = ();
       $levelhash = {};
       foreach $dirs ( @{$timetemp->{$time}} ) {
         if (!$rootdir || (index($dirs->{dir},dirlevel($rootdir,$i)) == 0)) {
            $dirhash->{dirlevel($dirs->{dir}, $i)} += $dirs->{space};
         }
       }
       my $count = 0;
       foreach ( keys %{$dirhash} ) {
         $dirhashSep = {};
         $dirhashSep->{dir} = $_;
         $dirhashSep->{size} = $dirhash->{$_};
         push @$dirarray, $dirhashSep;
         $count = $count + 1;
       }

       if ($count==0) { $level = $i; }

       #warn "dump dirarray ", Data::Dumper->Dump([ $dirarray ]);
       if ($dirarray) {
          $levelhash->{level} = $i;
          $levelhash->{data} = $dirarray;
          #warn "dump levelhash ", Data::Dumper->Dump([ $levelhash ]);
          push @$levelarray, $levelhash;
       }
    }
    #warn "dump levelarray ", Data::Dumper->Dump([ $levelarray ]);
    $timebin->{levels} = $levelarray;
    #warn "dump timebin ", Data::Dumper->Dump([ $timebin ]);
    push @$timebins, $timebin;
  }
    
  #warn "dumping timebins ",Data::Dumper->Dump([ $timebins ]);
  return $timebins;
}

sub dirlevel {
  my $path=shift;
  my $depth=shift;
  my @tmp=();
  if  ( not $path =~ /^\//){ die "ERROR: path does not start with a slash";}
  $path = $path."/";
  @tmp = split ('/', $path, $depth+2);
  pop @tmp;
  if (scalar(@tmp) >= 2) {
     return join ("/", @tmp);
  }
  else {
     return $path;
  }
}

1;
