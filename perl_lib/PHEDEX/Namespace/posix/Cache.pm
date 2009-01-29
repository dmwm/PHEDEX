package PHEDEX::Namespace::posix::Cache;

=head1 NAME

PHEDEX::Namespace::posix::Cache - implement caching of results in the
namespace framework for the direct (posix) protocol

=cut

use strict;
use warnings;
use PHEDEX::Core::Util ( qw / deep_copy / );
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $h = shift;

# Params and options are module-specific
  my %params = (
		 VERBOSE => $h->{VERBOSE} || 0,
		 DEBUG	 => $h->{DEBUG}   || 0,
		 cache	 => {},
		 stats	 => {},
              );
  my $self = \%params;
  bless($self, $class);
  return $self;
}

sub store
{
  my ($self,$attr,$args,$result) = @_;
  my $flatargs;
  if ( ref($args) eq 'ARRAY' ) { $flatargs = join(' ',@{$args}); }
  else { $flatargs = $args };
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
  $calls = $self->{stats}{miss} || 0 + $hit;
  $pct   = ( $calls ? int(100*$hit/($calls)) : 0 );
  $entries = scalar keys %{$self->{cache}};
  print "Cache statistics: $hit hits, $calls calls ($pct%), $entries entries\n";
}

1;
