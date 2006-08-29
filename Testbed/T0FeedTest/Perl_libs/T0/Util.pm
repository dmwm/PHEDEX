use strict;
package T0::Util;
use Sys::Hostname;
use POE;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;
@EXPORT = qw/ Print dump_ref profile_flat profile_table bin_table uuid
	      reroute_event check_host SelectTarget /;

my ($debug,$quiet,$verbose,$i,@queue);

our $hdr = __PACKAGE__ . ":: ";
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }

sub Print
{
  my $time = time;
  print scalar localtime($time),': ',@_;
}
sub Verbose { my $verbose = shift; $verbose && Print @_; }
sub Debug   { my $debug   = shift; $debug   && Print @_; }
sub Quiet   { my $quiet   = shift; $quiet   || Print @_; }

sub check_host
{
  my $required = shift;
  return unless $required;
  return if $required =~ m%localhost%i;

  my $host = hostname;
  if ( $host ne $required )
  {
    Croak "Wrong machine (" . $host . " != " . $required . ")\n";
  }
}

sub reroute_event
{
  $_ = shift;
  my ( $kernel, $session ) = @_[ KERNEL, SESSION ];
  s%^.*::_%%;
  $kernel->yield($_, @_[ARG0 .. $#_]);
# $kernel->call( $session->ID, $_, @_[ARG0 .. $#_] );
}

sub dump_ref
{
  my $ref = shift;
  return unless ( ref($ref) eq 'HASH' );
  foreach ( keys %{$ref} ) { print "$_ : ", $ref->{$_}, "\n"; }
}

sub bin_table
{
  my ($i,@s,$sum,$bin,$table);
  $table = shift || croak "Missing argument for \"table\"\n";;

  foreach ( @{$table} )
  {
    $sum+= $_;
    push @s, $sum;
  }
  $i = int rand($sum);

  $bin = 0;
  foreach ( @s )
  {
    last if ( $_ > $i );
    $bin++;
  }
  return $bin;
}

sub profile_table
{
  my ($size,$min,$max,$step);
  my ($minp,$maxp,$table,$i,$j,$n,@s,$sum);

  $min   = shift || croak "Missing argument for \"min\"\n";;
  $max   = shift || croak "Missing argument for \"max\"\n";;
  $step  = shift || croak "Missing argument for \"step\"\n";;
  $table = shift || croak "Missing argument for \"table\"\n";;

  if ( !defined($table) ) { return profile_flat($min,$max,$step); }

  $j = bin_table($table);
  $n = scalar @{$table};
  $maxp = (1+$j)*($max-$min)/$n + $min;
  $minp =    $j *($max-$min)/$n + $min;

  $size = int(rand($maxp-$minp))+$minp;
  $size = $step * int($size/$step);
  return $size;
}

sub profile_flat
{
  my ($size,$min,$max,$step);
  $min  = shift || croak "Missing argument for \"min\"\n";;
  $max  = shift || croak "Missing argument for \"max\"\n";;
  $step = shift || croak "Missing argument for \"step\"\n";;

  $size = int(rand($max-$min))+$min;
  $size = $step * int($size/$step);
  return $size;
}

sub uuid
{
  my $uuid;
  open UUID, "uuidgen -r |" or croak "uuidgen: $!\n";
  while ( <UUID> )
  {
    chomp;
    if ( m%-% ) { s%-%%g; $uuid = $_; }
  }
  close UUID;# or croak "uuidgen: close: $!\n";
  return $uuid;
}

sub SelectTarget
{
  my ($ref,$targets,$mode,$target,$i);
  $ref = shift;
  $targets = $ref->{TargetDirs} or die "'TargetDirs' not in $ref\n";
  $mode    = $ref->{TargetMode} or die "'TargetMode' not in $ref\n";

  if ( $mode =~ m%^RoundRobin$% )
  {
    $target = shift @{$targets};
    push @{$targets}, $target;
    return $target;
  }

  croak "Don't know what target to take for TargetMode = \"$mode\"...\n";
}

sub ReadConfig
{
  my ($this, $hash, $file) = @_;

  $file = $this->{Config} unless $file;
  defined($file) && -f $file or return;
  do "$file" or Croak "$file: problem...? $!\n";

  no strict 'refs';
  if ( ! $hash ) { ( $hash = $this->{Name} ) =~ s%^T0::%%; }
  map { $this->{$_} = $hash->{$_} } keys %$hash;

  foreach $hash ( keys %{$this->{Partners}} )
  {
    map { $this->{$hash}->{$_} = $this->{Partners}->{$hash}->{$_} }
			  keys %{$this->{Partners}->{$hash}};
  }

  $this->{ConfigRefresh} = 10 unless $this->{ConfigRefresh};
}

sub timestamp
{
  my ($year,$month,$day,$hour,$minute,$seconds) = @_;

  my @n = localtime;

  defined($year)    or $year    = $n[5] + 1900;
  defined($month)   or $month   = $n[4] + 1;
  defined($day)     or $day     = $n[3];
  defined($hour)    or $hour    = $n[2];
  defined($minute)  or $minute  = $n[1];
  defined($seconds) or $seconds = $n[0];

  sprintf("%04d%02d%02d%02d%02d%02d",
                  $year,$month,$day,$hour,$minute,$seconds);
}

1;
