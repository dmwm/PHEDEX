package PHEDEX::Namespace::dpm::checksum;
# Implements the 'checksum' function for dpm access
use strict;
use warnings;
use base 'PHEDEX::Namespace::dpm::Common';
use PHEDEX::Core::Catalogue;
use File::Basename;
use Data::Dumper;

our @fields = qw / tape_name checksum_type checksum_value is_migrated /;
sub new
{
    my ($proto,$h) = @_;
    my $class = ref($proto) || $proto;
    my $self = {
	cmd=> 'lcg-get-checksum',
	opts=> []
	};
    bless($self, $class);
    $self->{ENV} = $h->{ENV} || '';
    map { $self->{MAP}{$_}++ } @fields;
    return $self;
}

sub Protocol { return 'srmv2'; }

sub execute
{
  my ($self,$ns,$file) = @_;

  #there is no CACHE mode for dpm checksum. 
  return $ns->Command('checksum',$file);
}


sub parse
{
# Parse the checksum output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!

    my ($self,$ns,$r,$dir) = @_;
    my $result = {
	checksum_type=> 'adler32',
	checksum_value=> undef,
	is_migrated=> 0,
    };

    my @a= split(' ',@{$r->{STDOUT}}[0]);

    $a[0] =~ /^\s*(\S+)\s*/;

    $result->{checksum_value}= lc($1);

    $ns->{CACHE}->store('checksum',"$dir",$result);
    return $result;
}

sub Help
{
    print 'Return (',join(',',@fields),")\n";
}

1;
