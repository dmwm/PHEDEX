package PHEDEX::Testbed::Lifecycle::FakeData;

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use Time::HiRes;
use POE;
use Carp;
use Data::Dumper;

our %params = (
	  Verbose	=> undef,
	  Debug		=> undef,
        );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { parent => shift };
  my $workflow = shift;

  my $package;
  $self->{ME} = $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;

  my $p = $workflow->{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};

  $self->{Verbose} = $self->{parent}->{Verbose};
  $self->{Debug}   = $self->{parent}->{Debug};
  bless $self, $class;
  return $self;
}

sub MakeBlock
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($h,$blockid,$now,$workflow);
  $workflow = $payload->{workflow};

# do I need a new block, or can I re-use the one I have?
  if ( $h = $workflow->{_block} )
  {
    $h->{_injections_left}--;
    # close the block on the last injection
    if ( $h->{_injections_left} == 1 )
    {
      $h->{BlockIsOpen} = 'n';
    }
    if ($h->{_injections_left} > 0) {
      $blockid = $h->{blockid};
    } else {
      undef $h;
    }
  }

  $now = time;
  if ( !$blockid )
  {
    $h->{blockid}	= $blockid = sprintf("%08x",$now - 1330556400);
    $h->{dbs}		= $workflow->{DBS} || "test";
    $h->{dls}		= $workflow->{DLS} || "lfc:unknown";
    $h->{created}	= $now;
    $h->{DsetIsOpen}	= $workflow->{IsOpen};
    $h->{BlockIsOpen}	= $workflow->{IsOpen};
    $h->{IsTransient}	= $workflow->{IsTransient};
    $h->{dataset}	= $workflow->{Dataset};
    $h->{block}		= $workflow->{Dataset} . "#$blockid";
    $h->{_injections_left} = $workflow->{InjectionsPerBlock};
    if ( $h->{_injections_left} == 1 ) { $h->{BlockIsOpen} = 'n'; }
  }

  my $n = 0;
  $n = scalar @{$h->{files}} if $h->{files};
  for my $n_file (($n+1)..($n+$workflow->{NFiles}))
  {
    my $file_ref = $self->getNextLFN($workflow,$blockid,$n_file);
    push @{$h->{files}}, $file_ref;
  };
  $workflow->{_block} = $h;
  $kernel->yield('nextEvent',$payload);
}

my $_file_number=0;
sub getNextLFN
{
  my ($self,$ds,$blockid,$n_file) = @_;
  my ($file,$lfn,$size,$mean,$sdev,$cksum,$RN,$suffix,$lfnList);
  if ( ! ($lfnList = $self->{parent}{LFNList}) )
  {
$suffix = "";
    if ( defined($ds->{StuckFileFraction}) && $ds->{StuckFileFraction} > 0)
    {
       $RN = rand 100;
      ($RN < $ds->{StuckFileFraction}) && ($suffix = "-stuckfile");
    }
    $lfn  = $ds->{Dataset} . "/${blockid}/${n_file}" . $suffix;
    $mean = defined( $ds->{FileSizeMean} )   ? $ds->{FileSizeMean}   : 2.0;
    $sdev = defined( $ds->{FileSizeStdDev} ) ? $ds->{FileSizeStdDev} : 0.2;
    $size = int(gaussian_rand($mean, $sdev) * (1000**3)); 
    $cksum = 'cksum:'. int(rand() * (10**10));
    $self->Dbgmsg("lfn => $lfn, size => $size, cksum => $cksum");
    return { lfn => $lfn, size => $size, cksum => $cksum};
  }

  if ( !$self->{lfns} )
  {
    open LFNs, "<$lfnList}" or $self->Fatal("Cannot open $lfnList: $!");
    while ( $_ = <LFNs> )
    {
      next if m%^#%;
      ($lfn,$size,$cksum) = split(' ',$_);
      $size = int(gaussian_rand($mean, $sdev) * (1000**3)) unless $size;


      $cksum = 'cksum:'. int(rand() * (10**10)) unless $cksum;
      push @{$self->{lfns}}, { lfn => $lfn, size => $size, cksum => $cksum};
    }
    close LFNs;
  }
  my $i = ($_file_number++) % scalar @{$self->{lfns}};
  return $self->{lfns}[$i];
}

sub makeXML
{
  my ($self,$h,$xmlfile) = @_;

  my ($dbs,$dls,$dataset,$block,$files,$disopen,$bisopen,$istransient);
  $dbs = $h->{dbs};
  $dls = $h->{dls};
  $dataset     = $h->{dataset};
  $block       = $h->{block};
  $disopen     = $h->{DsetIsOpen};
  $bisopen     = $h->{BlockIsOpen};
  $istransient = $h->{IsTransient};
  if ( ! defined($xmlfile) )
  {
    $xmlfile = $dataset;
    $xmlfile =~ s:^/::;  $xmlfile =~ s:/:-:g; $xmlfile .= '.xml';
  }

  open XML, '>', $xmlfile or $self->Fatal("open: $xmlfile: $!");
  print XML qq{<data version="2.0">};
  print XML qq{<dbs name="$dbs"  dls="$dls">\n};
  print XML qq{\t<dataset name="$dataset" is-open="$disopen">\n};
  print XML qq{\t\t<block name="$block" is-open="$bisopen">\n};
  for my $file ( @{$h->{files}} )
  {
    my $lfn = $file->{lfn} || $self->Fatal("lfn not defined");
    my $size = $file->{size} || $self->Fatal("filesize not defined");
    my $cksum = $file->{cksum} || $self->Fatal("cksum not defined");
    print XML qq{\t\t\t<file name="$lfn" bytes="$size" checksum="$cksum"/>\n};
  }
  print XML qq{\t\t</block>\n};
  print XML qq{\t</dataset>\n};
  print XML qq{</dbs>\n};
  print XML qq{</data>};
  close XML;

  $self->Logmsg("Wrote injection file to $xmlfile") if $self->{Debug};
}

sub gaussian_rand {
    my ($mean, $sdev) = @_;
    $mean ||= 0;  $sdev ||= 1;
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;

    $g1 = $g1 * $sdev + $mean;
    $g2 = $g2 * $sdev + $mean;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}

sub dump_ref
{
  my $ref = shift;
  return unless ( ref($ref) eq 'HASH' );
  foreach ( keys %{$ref} ) { print "$_ : ", $ref->{$_}, "\n"; }
}


# If supplied argument is a scalar, returns it without change;
# Otherwise expects reference to a hash, which will be processed by
# a subroutine called algoALGO, where ALGO is the value of 'algo' key in the 
# argument hash. 
sub evaluate
{
    my $arg = shift || croak "Missing argument for \"evaluate\"\n";
    my $argtype = ref (\$arg);
    if ( $argtype eq "SCALAR")
    {
        return $arg;
    }
    $arg -> {algo} || croak "No algorithm specified in evaluate (algo)\n";
    my $algo = "algo" . $arg -> {algo};
    {
	no strict 'refs';
	return &$algo($arg);
    }
}

sub algotable
{
    my ($size,$min,$max,$step);
    my $arg = shift;
    print "In algotable: \n";
    return profile_table($arg -> {min},$arg -> {max},$arg -> {step}, $arg -> {table});
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

  $min   = shift ; defined $min || croak "Missing argument for \"min\"\n";
  $max   = shift ; defined $max || croak "Missing argument for \"max\"\n";
  $step  = shift || croak "Missing argument for \"step\"\n";
  $table = shift || croak "Missing argument for \"table\"\n";

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

1;
