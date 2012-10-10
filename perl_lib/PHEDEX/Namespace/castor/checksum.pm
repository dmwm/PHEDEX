package PHEDEX::Namespace::castor::checksum;
# Implements the 'checksum' function for castor access
use strict;
use warnings;
use base 'PHEDEX::Namespace::castor::Common';
use File::Basename;

our @fields = qw / checksum_type checksum_value /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'nsls',
	       opts	=> ['-l','--checksum']
	     };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'checksum'); }

sub parse
{
# Parse the checksum output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!

  my ($self,$ns,$r,$dir) = @_;
  my $result = {
                 checksum_type     => undef,
		 checksum_value    => undef,
	       };      
  foreach ( @{$r->{STDOUT}} )
  {
    my (@a,$x,$file);
    chomp;
    @a = split(' ',$_);
    
    # Skip directories
    next if $a[0] =~ m/^d/;
    
    # Check if nsls -l output has checksum field
    if (scalar(@a) == 11) {

	$x->{checksum_type}  = $a[8];
	if ($x->{checksum_type} eq 'AD') {
	    $x->{checksum_type} = 'adler32';
	}
	$x->{checksum_value} = $a[9];
	$file = $a[10];

	$ns->{CACHE}->store('checksum',"$dir/$file",$x);
	
	$result = $x;
    }
    # Invoke tapechecksum instead
    elsif (scalar(@a) == 9) {
	
	$file = $a[8];
	# filename in nsls output already contains full path if argument is a single file 
	my $fullname;
	if ( $file eq basename $file ) {
	    $fullname = "$dir/$file";
	}
	elsif ( $file eq $dir ) {
	    $fullname = $dir;
	}
	else {
	    die "Cannot determine path for $file in $dir\n";
	}
	# Try to extract tapechecksum from cache
	my $tapestats = $ns->{CACHE}->fetch('tapechecksum',$fullname);
	# Execute command if tapechecksum is not in cache
	if ( not defined $tapestats ) {
	    $tapestats = $self->SUPER::execute($ns,$fullname,'tapechecksum');
	}
	$x->{checksum_type} = $tapestats->{'tape_checksum_type'};
	$x->{checksum_value} = $tapestats->{'tape_checksum_value'};
	
	$ns->{CACHE}->store('checksum',$fullname,$x);
	
	$result = $x;
    }
  }
  
  return $result;
  
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
