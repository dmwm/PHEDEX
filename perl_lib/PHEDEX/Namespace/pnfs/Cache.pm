package PHEDEX::Namespace::pnfs::Cache;
# Implement caching of results in the namespace framework for pnfsdump file
# It just records all results in a hash, and never expires them.
use strict;
use warnings;
use PHEDEX::Core::Util ( qw / deep_copy / );
use Data::Dumper;
use PHEDEX::Namespace::pnfs::stat ( qw / parse_pnfsdump / );
our $cache_initialised;
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $h = shift;

# Params and options are module-specific
  my %params = (
                 VERBOSE => $h->{VERBOSE} || 0,
                 DEBUG   => $h->{DEBUG}   || 0,
                 cache   => {},
                 stats   => {},
              );
  my $self = \%params;
  if  ($h->{INPUT_FILE}) {
    my $dumpfile = $h->{INPUT_FILE};
    print "Populating cache from ". $dumpfile. "\n" if $self->{VERBOSE};
    open(DUMP, "<$dumpfile") or die  "Could not open file ".$dumpfile. " for reading";
    my $file;
    my $stat;
    my ($access, $uid, $gid, $size, $mtime);
    while (<DUMP>){
      chomp;
      ($file, $stat) = split /,/, $_,2;
      ($access, $uid, $gid, $size, $mtime) = split /,/,$stat,5;
      my %hash;
      $hash{STDOUT} = $stat;
      $hash{access}=$access;
      $hash{uid}=$uid;
      $hash{gid}=$gid;
      $hash{size}=$size;
      $hash{mtime}=$mtime;
      $self->{cache}{$file}{'stat'} = \%hash;
    }
  }
  bless($self, $class);
  return $self;
}

sub store
{
  my ($self,$attr,$args,$result) = @_;
# $attr is the method that was requested. 'size', 'checksum_type' etc...
# $args is the file (or files) that the attribute was requested for
# $flatargs takes account of the case where $args is an array. In practise
# this is unlikely to happen, I'm not even sure if it makes sense if it does
  my $flatargs;
  if ( ref($args) eq 'ARRAY' ) { $flatargs = join(' ',@{$args}); }
  else { $flatargs = $args };

# use 'deep_copy' from the Util package to make sure we have immutable results
  return $self->{cache}{$flatargs}{$attr} = deep_copy($result);
}

sub fetch
{
  my ($self,$attr,$args) = @_;
  my $flatargs;

  if ( ref($args) eq 'ARRAY' ) { $flatargs = join(' ',@{$args}); }
  else { $flatargs = $args };
  if ( exists($self->{cache}{$flatargs}) &&
       exists($self->{cache}{$flatargs}{$attr}) )
  {
    $self->{stats}{hit}++;
    return deep_copy($self->{cache}{$flatargs}{$attr});
  }
  $self->{stats}{miss}++;
  return undef;
}

sub DESTROY
{
  my $self = shift;
  return unless $self->{VERBOSE};
  my ($hit,$calls,$pct,$entries);
  $hit   = $self->{stats}{hit} || 0;
  $calls = ($self->{stats}{miss} || 0) + $hit;
  $pct   = ( $calls ? int(100*$hit/($calls)) : 0 );
  $entries = scalar keys %{$self->{cache}};
  print "Cache statistics: $hit hits, $calls calls ($pct%), $entries entries\n";
}

1;
