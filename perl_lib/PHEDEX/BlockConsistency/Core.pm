package PHEDEX::BlockConsistency::Core;

=head1 NAME

PHEDEX::BlockConsistency::Core - business logic for the Block Consistency
Checking agent.

=head1 SYNOPSIS

Implements the checking logic for the Block Consistency Check agent.

=head1 DESCRIPTION

See L<https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjConsistency> for more
information.

=cut

use strict;
use warnings;
use base 'PHEDEX::BlockConsistency::SQL';

use PHEDEX::Core::DB;
use PHEDEX::Core::Catalogue;
use Carp;

our @EXPORT = qw( );
our (%h,%check,%params);

%check = (
		'SIZE'		=> 0,
 		'MIGRATION'	=> 0,
 		'CKSUM'		=> 0,
 		'DBS'		=> 0,
	 );

%params = (
		DBH		=> undef,
		BLOCK		=> undef,
		DATASET		=> undef,
		LFN		=> undef,
		BUFFER		=> undef,
		CHECK		=> \%check,
		AUTOBLOCK	=> 0,

		VERBOSE		=> 0,
		DEBUG		=> 0,
		TERSE		=> 1,
	  );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(@_);
    
  my %args = (@_);
  map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
  bless $self, $class;

  $self->_init();

  return $self;
}

sub _init
{
  my $self = shift;
  $self->{VERBOSE} = 3;
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

sub InjectTest
{
  my ($self,%h,@fields,$sql,$id,%p,$q,$r);

  $self = shift;
  %h = @_;
  @fields = qw / block node test n_files time_expire priority use_srm /;

  foreach ( @fields )
  {
    defined($h{$_}) or die "'$_' missing in " . __PACKAGE__ . "::InjectTest!\n";
  }
  $r = getQueued ($self,
			 block   => $h{block},
			 test    => $h{test},
			 node    => $h{node},
			 n_files => $h{n_files}
			);

  if ( scalar(@{$r}) )
  {
#  Silently report (one of) the test(s) that already exists...
    return $r->[0]->{ID};
  }

  $sql = 'insert into t_dvs_block (id,' . join(',', @fields) . ') ' .
         'values (seq_dvs_block.nextval, ' .
          join(', ', map { ':' . $_ } @fields) .
          ') returning id into :id';

  map { $p{':' . $_} = $h{$_} } keys %h;
  $p{':id'} = \$id;
  $q = execute_sql( $self, $sql, %p );
  $id or return undef;

# Insert an entry into the status table...
  $sql = qq{ insert into t_status_block_verify
        (id,block,node,test,n_files,n_tested,n_ok,time_reported,status)
        values (:id,:block,:node,:test,:n_files,0,0,:time,0) };
  foreach ( qw / :time_expire :priority :use_srm / ) { delete $p{$_}; }
  $p{':id'} = $id;
  $p{':time'} = time();
  $q = execute_sql( $self, $sql, %p );

# Now populate the t_dvs_file table.
  $sql = qq{ insert into t_dvs_file (id,request,fileid,time_queued)
        select seq_dvs_file.nextval, :request, id, :time from t_dps_file
        where inblock = :block};
  %p = ( ':request' => $id, ':block' => $h{block}, ':time' => time() );
  $q = execute_sql( $self, $sql, %p );

  return $id;
}

#-------------------------------------------------------------------------------
sub Checks
{
  my ($self,@checks) = @_;
  if ( ! @checks ) { @checks = $self->{CHECKS}; }

# Which integrity checks are we going to run?
  foreach ( split m|[,\s*]|, "@checks" )
  {
    my $v = 1;
    if ( s%^no%% ) { $v = 0; }
    my $k = uc($_);

    if ( !defined($check{$k}) )
    {
      print "Unknown check \"$_\" requested. Known checks are: ",
	  join(', ',
		  map { "\"$_\"(" . $check{$_} . ")" } sort keys %check),
	  "\n";
      exit 1;
    }
    $self->{CHECKS}{$k} = $v;
  }

  my $nchecks=0;
  $self->{VERBOSE} >= 2 && print "Perform the following checks:\n";
  foreach ( sort keys %{$self->{CHECKS}} )
  {
    $self->{VERBOSE} >= 2 && printf " %10s : %3s\n", $_,
		 ($self->{CHECKS}{$_} ? 'yes' : 'no');
    $nchecks += $self->{CHECKS}{$_};
  }

  return $nchecks;
}

#-------------------------------------------------------------------------------
sub Buffers
{
  my ($self,@buffer) = @_;
  @buffer = @{$self->{BUFFER}} unless @buffer;

  @buffer = split m|[,\s*]|, "@buffer";
  foreach my $buffer ( @buffer )
  {
    $self->{DEBUG} && print "Getting buffers with names like '$buffer'\n";
    my $tmp = $self->getBufferFromWildCard($buffer);
    map { $self->{result}{Buffers}{ID}{$_} = $tmp->{$_} } keys %$tmp;
  }
  $self->{DEBUG} && exists($self->{result}{Buffers}{ID}) && print "done getting buffers!\n";
  ( @{$self->{bufferIDs}} ) = sort keys %{$self->{result}{Buffers}{ID}}
             or die "No buffers found matching \"@buffer\", typo perhaps?\n";

# Check the technologies!
  my %t;
  map { $t{$self->{result}{Buffers}{ID}{$_}{TECHNOLOGY}}++ }
	 @{$self->{bufferIDs}};
  croak "Woah, too many technologies! (",join(',', keys %t),")\n" if ( scalar keys %t > 1 );
  return ( (keys %t)[0] );
}

#-------------------------------------------------------------------------------
sub Datasets
{
  my ($self,@dataset) = @_;
# Here I cheat. Dataset names are simply short forms of block names, so I
# add a wildcard to the dataset name and call it a block!
#
# Cunning, eh?
  croak "Untested, maybe unwanted...?\n";
  @dataset = @{$self->{DATASET}} unless @dataset;
  @dataset = split m|[,\s*]|, "@dataset";
  my @block = map { $_ . '%' } @dataset;
  $self->Blocks(@block);
}

#-------------------------------------------------------------------------------
sub Blocks
{
  my ($self,@block) = @_;
  croak "Untested, maybe unwanted...?\n";
  @block = @{$self->{BLOCK}} unless @block;
  push @block, split m|[,\s*]|, "@block";
  if ( @block )
  {
#   Find those I want and mark them, then GC the rest...
    my %g;
    foreach my $block ( @block )
    {
      $self->{DEBUG} && print "Getting blocks with names like '$block'\n";
      my $tmp = $self->getBlocksOnBufferFromWildCard ($block);
      map { $g{$_}++ } @$tmp;
      map { $self->{result}{Blocks}{$_} = {} } @$tmp;
    }
    foreach my $block ( keys %{$self->{result}{Blocks}} )
    {
      if ( ! defined($g{$block}) )
      {
        my $data = $self->{result}{Blocks}{$block}{Dataset};
        delete $self->{result}{Datasets}{$data}{Blocks}{$block};
        delete $self->{result}{Blocks}{$block};
      }
    }
  }
}

#-------------------------------------------------------------------------------
sub LFN
{
  my ($self,@lfn) = @_;
  croak "Untested, maybe unwanted...?\n";
  @lfn = @{$self->{LFN}} unless @lfn;
  push @lfn, split m|[,\s*]|, "@lfn";

  @lfn = split m|[,\s*]|, "@lfn";
  foreach my $lfn ( @lfn )
  {
    $self->{VERBOSE} >= 3 && print "Getting lfns with names like '$lfn'\n";
    my $tmp = $self->getLFNsFromWildCard($lfn);
    map { $h{LFNs}{$_} = {} } @$tmp;
  }

  foreach my $lfn ( keys %{$h{LFNs}} )
  {
    next if exists($h{LFNs}{$lfn}{Block});
    my $tmp = $self->getBlocksFromLFN($lfn);
    map { $h{LFNs}{$lfn}{Block} = $_   } @$tmp;
    map { $h{Blocks}{$_}{LFNs}{$lfn}++ } @$tmp;
  }
  $self->{DEBUG} && defined($h{LFNs}) && print "done getting LFNs!\n";
}

#-------------------------------------------------------------------------------
sub getQueued
{
  my ($self,%h) = @_;
  my ($sql,$q,%p,@r);
  
  $sql = qq{ select b.id, block, node, test, n_files, time_expire, priority,
             use_srm, name
             from t_dvs_block b join t_dvs_test t on b.test = t.id
             where 1 = 1
           };

# Build on numerical matches
  foreach ( qw /block node use_srm test/ )
  {
    if ( defined($h{$_}) )
    {
      $sql .= " and $_ = :$_";
      $p{':' . $_} = $h{$_};
    }
  }

# Build on numerical inequalities
  foreach ( qw /n_files time_expire/ )
  {
    if ( defined($h{$_}) )
    {
      $sql .= " and $_ >= :$_";
      $p{':' . $_} = $h{$_};
    }
  }

# Build on string matches
  foreach ( qw /name/ )
  {
    if ( defined($h{$_}) )
    {
      $sql .= " and $_ like :$_";
      $p{':' . $_} = $h{$_};
    }
  }

  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

1;
