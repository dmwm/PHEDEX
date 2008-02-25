package PHEDEX::Namespace::Namespace;

=head1 NAME

PHEDEX::Namespace - implement namespace (size, migration...) checks on SEs

=head1 SYNOPSIS

This wraps the 'stat' commands of different MSS/storage namespaces in a
uniform interface. Adding a new technology should be easy, the intention 
is that people who know the technologies can contribute the specific code 
here and everyone can benefit from it.

=head1 DESCRIPTION

PHEDEX::Namespace knows about the protocol and technology used at an SE 
and allows you to run simple namespace checks (file-size, 
migration-status) in a technology-independant manner. For example:

Known protocols are 'rfio', 'srm', and 'unix' (posix-style). Known 
technologies are 'Castor', 'dCache', 'Disk', and 'DPM'. Specifying the 
technology implicitly defines the protocol, the only sensible override to 
this is to specify protocol 'srm'.

The technology and protocol between them specify the PFN to/from LFN
mappings to extract from the TFC. The protocol also specifies which 
specific function is called to satisfy a given lookup. For example, 
calling C<< $ns->statsize(...) >> when the protocol is rfio will result in 
calling C<rfstat>, when the protocol is srm it will call C<srmstat>, etc. 
The raw output of the protocol-specific command is cached, and the 
relevant information extracted and returned to the calling function. 

Clear? I thought not...

=head1 METHODS

=over

=item protocol( $protocol )

Set the protocol to one of the allowed values. Dies if an invalid protocol 
is given. You would not normally call this except to switch to using srm, 
for whatever insane reasons you might have.

=item technology( $technology )

Set the technology to one of the allowed values. Dies if an invalid
technology is given. Also sets the protocol to the appropriate value for 
the given technology.

=item lfn2pfn( $lfn )

Returns the pfn of the input lfn, given the technology and trivial file 
catalogue in use. Uses pfnLookup from 
L<PHEDEX::Core::Catalogue|PHEDEX::Core::Catalogue> to manage the 
conversion.

=item statmode( $pfn )

Returns the migration status of the given C< $pfn >. Currently only 
implemented for Castor, pending some protocol-specific contributions for 
other systems (feel free to volunteer!).

The result is cached, so that repeated calls do not saturate the disk
server. This may not be ideal, and may need revision in future. You can
always cheat by deleting the contents of C< %PHEDEX::Namespace::stat > to 
force all lookups to be repeated (or just C< 
$PHEDEX::Namespace::stat{$pfn} >, to delete information about a single 
file. The cache is also flushed in the constructor, so simply creating and
throwing away a Namespace object is enough to clear the cache.

=item statsize( $pfn )

Returns the size, in bytes, of the given C< $pfn >. Caches the result, so 
that repeated calls do not saturate the disk server.

=back

=head1 EXAMPLES

   # Create a Namespace object. Needs a DB filehandle and a TFC
   $ns = PHEDEX::Namespace->new
                (
                        DBH             => $dbh,
                        STORAGEMAP      => $path_to_TFC,
                );
  # Declare the technology to be RFIO
  $ns->technology( 'Castor' );

  # Get the PFN from an LFN
  $pfn = $ns->lfn2pfn( $lfn );

  # Get the filesize of a given file
  $size = $ns->statsize( $pfn );

  # Get the tape-migration status of the file
  $ns->statmode( $pfn );

=cut

use strict;
use warnings;

use PHEDEX::Core::Catalogue;
use File::Basename;
use Data::Dumper;
use base 'Exporter';
our @EXPORT = qw();


our %pmap = ( rfio => 'rf',
	      srm  => 'srm',
	      disk => 'unix',
	      dcap => 'dcap',
	    );
our %tmap = ( Castor => 'rfio',
	      dCache => 'dcap',
	      Disk   => 'disk',
	      DPM    => 'dpns',
	    );
our %stat = ();


our (%params,%ro_params, %static_var_refs);

%params = (
                STORAGEMAP      => undef,
                TFCPROTOCOL     => 'direct',
                MSSPROTOCOL     => '',
                DESTINATION     => 'any',
		RFIO_USES_RFDIR => 0,
		VERBOSE		=> 0,
		DEBUG		=> 0,
	  );
%ro_params = ( );

%static_var_refs = (pmap=>\%pmap, tmap=>\%tmap, stat=>\%stat);


sub _init
{
  my $self = shift;
  my %h = @_;

#  if ( $h{protocol} ) { $self->protocol( delete $h{protocol} ); }
  map { $self->{$_} = $params{$_} } keys %params; #load hardcoded params
  map { $self->{$_} = $h{$_} } keys %h; #override some with supplied
  map { $self->{$_} = $ro_params{$_} } keys %ro_params;
  map { $self->{$_} = $static_var_refs{$_} } keys %static_var_refs;

}

sub protocol
{
  my ($self,$protocol) = @_;

  if ( $protocol )
  {
    die "protocol '$protocol' not known. Only know about '" . join("', '", keys %pmap) . "'\n" unless defined $pmap{$protocol};
    $self->{prefix}   = $pmap{$protocol};
    $self->{protocol} = $protocol;
    print "Using TFC protocol $protocol\n";
  }

  return $self->{protocol};
}

sub technology
{
  my ($self,$technology) = @_;
  return $self->protocol() unless defined $technology;
  die "technology '$technology' not known. Only know about '" . join("', '", keys %tmap) . "'\n" unless defined $tmap{$technology};
  print "Using MSS technology $technology\n";
  return $self->protocol($tmap{$technology});
}

sub lfn2pfn
{ 
  my $self = shift;
  my $cmdref = shift;

  my @pfns = ();

    my $proto = $cmdref->{tfcproto} || 
	$self->{COMMANDS}->{"default"}->{"tfcproto"} || 
	$self->{TFCPROTOCOL};

  my @lfns = ref($_[0])? @{$_[0]} : @_;
#  print "Converting @lfns\n";

  foreach my $lfn ( ref($_[0])? @{$_[0]} : @_) {

      my ($pfn) = &pfnLookup( $lfn,
			    $proto,
			    $self->{DESTINATION},
			    $self->{STORAGEMAP}
			    );
      
      if ($pfn) { push @pfns, $pfn; } 
      else { print "Can not convert LFN $lfn into PFN for node $self->{DESTINATION} and tfc proto $proto\n";}
  }
  
  return @pfns;
}

sub pfn2lfn {
    my $self = shift;
    my $cmdref = shift;

    my @lfns = ();

    my $proto = $cmdref->{tfcproto} || 
	$self->{COMMANDS}->{"default"}->{"tfcproto"} || 
	$self->{TFCPROTOCOL};
    
    foreach my $pfn ( ref($_[0])? @{$_[0]} : @_) {
#	print "Converting PFN $pfn\n";
	my $lfn = &lfnLookup( $pfn,
			      $proto,
			      $self->{DESTINATION},
			      $self->{STORAGEMAP}
			      );
	
	if ($lfn) { push @lfns, $lfn; }
	else { print "Can not convert PFN $pfn into LFN for node $self->{DESTINATION} and tfc proto $proto\n";}
    }
    
      return @lfns;


}


sub Raw
{
  my $self = shift;
  my $pfn  = shift;
  return $stat{$pfn}{RAW};
}

sub cache {
    my $self = shift;
    my $checksref = shift;
    my $lfnsref = shift;

    my $cmdref = $self->{COMMANDS}->{"stat"};

    print "Cacheall: checks:", @$checksref," lfns: ",map {"    $_ \n"} @$lfnsref,"\n";
    
    my @raw = ();
    
    $self->runCommand($cmdref,\@raw, $lfnsref);
    
    my %r = $self->parseRawStat($cmdref, \@raw, $lfnsref);
    
    my $stat = $self->{stat};
    map { $stat->{$_} = $r{$_} } keys %r;
    
}

sub runCommand {
    my $self = shift;
    my $cmdref = shift;
    my $rawref = shift;
    my $lfnsref = shift;

    my @pfns = $self->lfn2pfn($cmdref,$lfnsref);

    my $cmd = $cmdref->{cmd};
    my $opts = join " ", @{$cmdref->{opts}};

    my $cmdline = "$cmd $opts";

    my $n = $cmdref->{"n"} || $self->{COMMANDS}->{"default"}->{"n"} || 1;

    while (@pfns) {
        my @somepfns = splice(@pfns,0,$n);
        print "ns::runCommand: Running stat for ", scalar(@somepfns), "\n";

	print "ns::_runCommand: Calling $cmdline @_\n";
	open CMD, "$cmdline @somepfns 2>&1 |" or die "$cmdline @somepfns: $!\n";
	push @$rawref, (<CMD>);
	close CMD; # or die "close $cmdline @somepfns: $!\n";
    }

}

#stat first checks whether there is a cached copy
sub stat{
    my $self = shift;
    my (%q,%r);

    my $stat = $self->{stat};

    print "ns::stat for @_\n";

    my @tostat = ();

    foreach (@_) {
        if (exists $stat->{$_}) {
            $q{$_} = $stat->{$_} ;
            print "Got from cache $_\n";
        }
        else{
            push @tostat, $_;
            print "Not in cache, will stat again $_\n";
        }
    }


    my $cmdref = $self->{COMMANDS}->{"stat"};

    my @raw= ();

    if (@tostat) {
	$self->runCommand($cmdref,\@raw, \@tostat);

	%r = $self->parseRawStat($cmdref,\@raw, \@tostat);

	map { $stat->{$_} = $r{$_} } keys %r;
    }

    map { $q{$_} = $r{$_} } keys %r;

    return %q;
}

sub stat_key
{
  my $self = shift;
  my $key  = shift;
  my %q;
  my %r = $self->stat(@_);

  if ( scalar @_ == 1 ) { return $r{$_[0]}{$key}; }

  map { $q{$_} = $r{$_}{$key} } keys %r;
  return \%q;
}

sub statsize
{
  my $self = shift;
  return $self->stat_key('Size',@_);
}

sub statmode
{
  my $self = shift;
  return $self->stat_key('Migrated',@_);
}

sub statondisk
{
  my $self = shift;
  return $self->stat_key('OnDisk',@_);
}


sub delete {
    my $self = shift;
    my $lfnsref = shift;

    my $cmdref = $self->{COMMANDS}->{"delete"};

    my @raw = ();

    $self->runCommand($cmdref,\@raw, $lfnsref);

#    my $n = $self->{N}->{$cmd} || $self->{N}->{"default"} || 1;

#    while (@pfns) {
#        my @somepfns = splice(@pfns,0,$n);

#        print "ns::delete Calling $cmd @pfns\n";
#        open STAT, "$cmd @pfns 2>&1 |" or die "$cmd @pfns: $!\n";
#        my @raw=(<STAT>);
#        close STAT; # or die "close $cmd $pfn: $!\n";
#    }
    
}


1;
