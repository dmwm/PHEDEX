package PHEDEX::Namespace::srmv2::stat;
# Implements the 'stat' function for srmv2 access
use strict;
use warnings;
use base 'PHEDEX::Namespace::srmv2::Common';
use Time::Local;

# @fields defines the actual set of attributes to be returned
our @fields = qw / access uid gid size mtime checksum_type checksum_value lifetime_left locality space_token retention_policy_info type /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
# This shows the use of an external command to stat the file. It would be
# possible to do this with Perl inbuilt 'stat' function, of course, but this
# is just an example.
  my $self = {
	       cmd	=> 'srmls',
	       opts	=> ['-l'],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'stat'); }

sub parse
{
# Parse the stat output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  
  foreach ( @{$r->{STDOUT}} )
  {
    my (@t,%h,$M,$d,$y,$h,$m,$s);
    chomp;
    if ( m%^\s*(\d+)\s+(\S+)\s*$% )
    {
      my $size = $1;
      my $surl = $2;
      $r->{size} = $size if $dir =~ m%$surl%;
      next;
    }
    if ( m%space token\(s\) :(.+)\s*$% )
    {
      my $token = $1;
      $token = '' if $token eq 'none found';
      $r->{space_token} = $token;
      next;
    }
    if ( m%^\s*\-\s+Checksum\s+(\S+):\s+(\S+)\s*$% )
    {
      $r->{'checksum_' . $1} = $2;
      next;
    }
    if ( m%^\s*UserPermission:\s+uid=(\S+)\s+Permissions(\S+)\s*$% )
    {
      $r->{uid} = (getpwnam($1))[2];
      my $perm = $2;
      if    ( $perm eq   '' ) { $r->{access} = '---'; }
      elsif ( $perm eq  'R' ) { $r->{access} = 'r--'; }
      elsif ( $perm eq 'RW' ) { $r->{access} = 'rw-'; }
      else { die "Don't understand user-permission $perm\n"; }
      next;
    }
    if ( m%^\s*GroupPermission:\s+gid=(\S+)\s+Permissions(\S+)\s*$% )
    {
      $r->{gid} = (getgrnam($1))[2];
      my $perm = $2;
      if    ( $perm eq   '' ) { $r->{access} .= '---'; }
      elsif ( $perm eq  'R' ) { $r->{access} .= 'r--'; }
      elsif ( $perm eq 'RW' ) { $r->{access} .= 'rw-'; }
      else { die "Don't understand group-permission $perm\n"; }
      next;
    }
    if ( m%^\s*WorldPermission:\s+(\S+)\s*$% )
    {
      my $perm = $1;
      if    ( $perm eq   '' ) { $r->{access} .= '---'; }
      elsif ( $perm eq  'R' ) { $r->{access} .= 'r--'; }
      elsif ( $perm eq 'RW' ) { $r->{access} .= 'rw-'; }
      else { die "Don't understand world-permission $perm\n"; }
      next;
    }
    if ( m%^\s*modified\s+at:(\d+)/(\d+)/(\d+)\s+(\d+):(\d+):(\d+)\s*$% )
    {
      %h = ( Jan => 0, Feb => 1, Mar => 2, Apr => 3, May =>  4, Jun =>  5,
             Jul => 6, Aug => 7, Sep => 8, Oct => 9, Nov => 10, Dec => 11 );
      $y = $1;
      $M = $2-1;
      $d = $3;
      $h = $4;
      $m = $5;
      $s = $6;
      @t = ( $s, $m, $h, $d, $M, $y );
      $r->{mtime} = timelocal(@t);
      next;
    }
    if ( m%^\s*-\s+Lifetime left \(in seconds\):\s+(\S+)\s*$% )
    {
      $r->{lifetime_left} = $1;
      next;
    }
    if ( m%^\s*locality:(\S+)\s*$% )
    {
      $r->{locality} = $1;
      next;
    }
    if ( m%^\s*retentionpolicyinfo\s*:\s*(\S+)\s*$% )
    {
      $r->{retention_policy_info} = $1;
      next;
    }
    if ( m%^\s*type\s*:\s*(\S+)\s*$% )
    {
      $r->{type} = $1;
      next;
    }
  }
  return $r;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
