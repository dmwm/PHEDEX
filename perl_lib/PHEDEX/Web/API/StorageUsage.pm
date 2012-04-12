package PHEDEX::Web::API::StorageUsage;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Core::Inject;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::StorageUsage - simple interface to query 

=head2 DESCRIPTION

GET data from storage usage db

=cut

sub methods_allowed { return ('GET'); }
sub duration { return 0; }
sub invoke { return storageusage(@_); }

sub storageusage 
{
  my ($core, %args) = @_;
  warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);
  my ($method,$site,$result,@inputSitelist,@records);

  $method = $core->{REQUEST_METHOD};

  foreach ( keys %args ) {
     $args{lc($_)} = $args{$_};
  }
 
  if ($args{level}) {
     if ($args{level} > 6) {
        die PHEDEX::Web::Util::http_error(400,"the level required is too deep");
     }
  }
  else {
     $args{level} = 4;
  }

  if (!$args{site}) {
    die PHEDEX::Web::Util::http_error(400,"no nodes are specified");
  }

  if (!$args{rootdir}) {
    $args{rootdir} = "/";
  } 
  
  if ($args{site} =~ m/^\*$/) {
     push @inputSitelist, "*";
  } 
  else {
     @inputSitelist = split(",", $args{site});
  }

  foreach $site (@inputSitelist) {
     my $node = {};
     $args{site} = $site;
     $node->{subdir} = $args{rootdir};
     $result = PHEDEX::Web::SQLSpace::querySpace($core, %args);
     $node->{node} = @{$result}[0]->{SITENAME};
     $node->{timebins} = getNodeInfo($core, $result, %args); 
     warn "dumping node ",Data::Dumper->Dump([ $node ]);
     push @records, $node;
  }
  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { nodes => \@records };
  #return { storageusage => @records };

}

sub getNodeInfo 
{
  my ($core, $result, %args) = @_;
  warn "dumping arguments for getNodeInfo",Data::Dumper->Dump([ \%args ]);
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
  warn "dumping last ",Data::Dumper->Dump([ $last ]);
  $dirtemp = ();
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
       $levelhash->{level} = $i;
       $levelhash->{data} = $dirarray;
       #warn "dump levelhash ", Data::Dumper->Dump([ $levelhash ]);
       push @$levelarray, $levelhash;
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
  if  ( not $path =~ /^\//){ die "ERROR: path does not start with a slash:  \"$path\"";}
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
