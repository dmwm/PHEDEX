package PHEDEX::Web::API::StorageUsage;
use warnings;
use strict;
use MongoDB;
use MongoDB::OID;
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
  my ($method,$site,@records);

  $method = $core->{REQUEST_METHOD};

  if ($args{level} > 6) {
    die PHEDEX::Web::Util::http_error(400,"the level required is too deep");
  }

  if (!$args{collName}) {
    die PHEDEX::Web::Util::http_error(400,"no nodes are specified");
  }
  if (!$args{rootdir}) {
    $args{rootdir} = "/";
  }
  foreach $site (@{$args{collName}}) {
     my $node = {};
     $args{site} = $site;
     $node->{node} = $site;
     $node->{subdir} = $args{rootdir};
     $node->{timebins} = &getNodeInfo(%args);
     warn "dumping node ",Data::Dumper->Dump([ $node ]);
     push @records, $node;
  }
  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { storageusage => \@records };

}

sub getNodeInfo
{
  my (%args) = @_;
  warn "dumping arguments for getNodeInfo",Data::Dumper->Dump([ \%args ]);
  my ($conn,$db,$table,$data,$cursor);
  my ($level,$rootdir,%dir, $dirs);
  my ($dirarray, $dirhash, $levelarray, $levelhash, $timebin, $timebins);
  $conn = MongoDB::Connection->new(host => 'localhost', port => 8230);
  $db = $conn->SiteSpace;
  $site = $args{site};
  $table = $db->$site();

  my %temp;
  $level = 4;
  if (exists $args{level}) {
     $level = $args{level};
  }
  $rootdir = $args{rootdir};

  if(!(exists $args{time_since}) && !(exists $args{time_until})) {
    # return latest one
    $cursor = $table->find()->skip($table->find()->count()-1);
  }
  else {
    if (!$args{time_since}) {
      $temp{'$lt'} = $args{time_until} + 0.0;
    }
    elsif (!$args{time_until}) {
      $temp{'$gt'} = $args{time_since} + 0.0;
    }
    else {
      $temp{'$gt'} = $args{time_since} + 0.0;
      $temp{'$gt'} = $args{time_since} + 0.0;
      $temp{'$lt'} = $args{time_until} + 0.0;
    }
    $dir{_id} = \%temp;
    warn "dumping converted arguments ",Data::Dumper->Dump([ \%dir ]);
    $cursor = $table->find(\%dir);
    #$cursor = $table->find({_id =>{'$gt' => 0,'$lt' => 11}});
  }
  $timebins = ();
  while ($data = $cursor->next) {
    warn "dumping data from db ", Data::Dumper->Dump([ $data ]);
    $timebin = {};
    $timebin->{timestamp} = $data->{_id};
    #@dirarray = ();
    $levelarray = ();
    for (my $i = 1; $i<= $level; $i++) {
       $dirhash = {};
       $dirarray = ();
       $levelhash = {};
       foreach $dirs ( @{$data->{dir}} ) {
         if (!$rootdir || (index($dirs->{name},$rootdir) != -1)) {
            #if (!dirlevel($dirs->{name}, $i)) {
            #   $dirhash->{dirlevel($dirs->{name}, $i)} += $dirs->{size};
            #}
            $dirhash->{&dirlevel($dirs->{name}, $i)} += $dirs->{size};
         }
       }
       push @$dirarray, $dirhash;
       warn "dump dirarray ", Data::Dumper->Dump([ $dirarray ]);
       $levelhash->{level} = $i;
       $levelhash->{data} = $dirarray;
       warn "dump levelhash ", Data::Dumper->Dump([ $levelhash ]);
       push @$levelarray, $levelhash;
    }

    warn "dump levelarray ", Data::Dumper->Dump([ $levelarray ]);
    $timebin->{levels} = $levelarray;
    warn "dump timebin ", Data::Dumper->Dump([ $timebin ]);
    push @$timebins, $timebin;
  }

  warn "dumping timebins ",Data::Dumper->Dump([ $timebins ]);
  return $timebins;
}

sub dirlevel {
  my $path=shift;
  my $depth=shift;
  my @tmp=();
  if  ( not $path =~ /^\//){ die "ERROR: path does not start with a slash:  \"$path\"";}
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
