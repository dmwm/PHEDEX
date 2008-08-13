package PHEDEX::Web::Cache;

=pod
=head1 NAME

PHEDEX::Web::Cache - implement caching strategies for the PHEDEX::Web modules

=head1 DESCRIPTION

=cut

use warnings;
use strict;

# If you're thinking of these, I've already tried them and decided against.
#use Cache::FileCache;
#use Cache::MemoryCache;
#use XML::XML2JSON;
#use XML::Writer;

our (%params);
%params = ( VERSION => undef,
	    DEBUG => 0,
	    STRATEGY	=> 'nocache',
	    MODULE	=> 'null',
	    );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    bless $self, $class;

#    $self->{CACHE} = new Cache::FileCache({cache_root => '/tmp/phedex-cache'});
#    $self->{CACHE} = new Cache::MemoryCache;
#    $self->{CACHE} = PHEDEX::Web::Cache->new( $self->{CACHE_CONFIG});

    # on initialization fill the caches
#    foreach my $call (grep $cacheable{$_} > 0, keys %cacheable) {
#	$self->refreshCache($call);
#    }

    return $self;
}

sub AUTOLOAD
{
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    if ( exists($params{$attr}) )
    {
	$self->{$attr} = shift if @_;
	return $self->{$attr};
    }
    my $parent = "SUPER::" . $attr;
    $self->$parent(@_);
}

sub DESTROY { }

sub set
{
  my ($self,$call,$args,$obj,$duration) = @_;
  return undef if $self->{STRATEGY} eq 'nocache';
  return undef if $self->{MODULE}   eq 'null';
  return undef if $args->{nocache};

# Have jumped through the hoops, now cache the data
  return undef;
}

sub get
{
  my ($self,$call,$args) = @_;
  return undef if $self->{STRATEGY} eq 'nocache';
  return undef if $self->{MODULE}   eq 'null';
  return undef if $args->{nocache};

# Now get the data from the cache
  return undef;
}

1;
