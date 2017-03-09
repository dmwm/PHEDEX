use strict;
package T0::FileWatcher;
use POE;
use POE::Session;
use T0::Util;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
use Cwd;
$VERSION = 1.00;
@ISA = qw/ Exporter /;

$FileWatcher::Name = 'FileWatcher';

our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }
sub Verbose { T0::Util::Verbose( (shift)->{Verbose}, @_ ); }
sub Debug   { T0::Util::Debug  ( (shift)->{Debug},   @_ ); }
sub Quiet   { T0::Util::Quiet  ( (shift)->{Quiet},   @_ ); }

sub _init
{
  my $self = shift;

  $self->{Name} = "$self";
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;

  if ( $self->{File} !~ m%^/% )
  {
    $self->{File} = cwd . '/' . $self->{File};
  }

  if ( defined(%FileWatcher::Params) )
  {
    map { $self->{$_} = $FileWatcher::Params{$_}; } keys %FileWatcher::Params;
  }
  $self->{Interval} = 10 unless defined $self->{Interval};

  POE::Session->create
  (
    inline_states       => {
      _start            => \&start,
	},
    object_states	=> [
	$self => [
			AddFile		=> 'AddFile',
			CheckFile	=> 'CheckFile',
			Quit		=> 'Quit',
		 ],
	],
    args => $self,
  );
  return $self;
}

sub new
{
  my $proto  = shift;
  my $class  = ref($proto) || $proto;
  my $parent = ref($proto) && $proto;
  my $self = {  };
  bless($self, $class);
  $self->_init(@_);
}

sub Options
{
  my $self = shift;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
}

sub start
{
  my ( $self, $kernel, $session ) = @_[ ARG0, KERNEL, SESSION ];
  $kernel->alias_set( $self->{Name} );
  $self->{Session} = $session->ID;
  $self->Debug($session->ID, ": ",$self->{Name},": Starting...\n");
  $kernel->yield( 'AddFile' );
  $self->AddClient;
}

our @attrs = ( qw/ Interval File / );
our %ok_field;
for my $attr ( @attrs ) { $ok_field{$attr}++; }

sub AUTOLOAD {
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  Croak "AUTOLOAD: Invalid attribute method: ->$attr()" unless $ok_field{$attr};
  $self->{$attr} = shift if @_;
  return $self->{$attr};
}

sub AddClient
{
  my $self = shift;
  my $h = @_ ? { @_ } : $self;
  if ( $h->{Client} )
  {
    $self->Verbose(": Adding client=",$h->{Client},
			 " event=",$h->{Event},
			 " file=",$self->{File},"\n");
    $self->{clients}->{$h->{Client}} = $h->{Event};
  }
  elsif ( $h->{Function} )
  {
    $self->Verbose(": Adding function=",$h->{Function},
                         " file=",$self->{File},"\n");
    push @{$self->{functions}},$h->{Function};
  }
  elsif ( $h->{Object} )
  {
    $self->Verbose(": Adding object=",$h->{Object},
                         " file=",$self->{File},"\n");
    push @{$self->{objects}},$h->{Object};
  }
  else
  {
    $self->Quiet(": Don't know what to do with $h\n");
    die $h;
  }
}

sub RemoveClient
{
  my ( $self, $p ) = @_;
  $self->Verbose("Removing client $p for ",$self->{File},"\n");
  if ( defined $self->{clients}->{$p} )
  {
    $self->Verbose("Client $p: Event ",$self->{clients}->{$p},"\n");
  }
  else
  {
    Print "\"$p\" not among my clients\n";
  }
  delete $self->{clients}->{$p};
  $poe_kernel->post( $self->{Session} => 'Quit' ) unless scalar(keys %{$self->{clients}});
}

# Remove the object pass as argument from the objects watched 
# and kill the session if there are no more objects.
sub RemoveObject 
{
  my ( $self, $p ) = @_;
  my ( $object_stored );
  my ( $index ) = 0;
  my ( $found ) = -1; #-1 not found, other index found

  $self->Verbose("Removing object $p for ",$self->{File},"\n");

  # Look for the object and store in found the index where it was found
  foreach $object_stored (@{$self->{objects}}){

      if( $object_stored == $p ){
	  $found = $index;
      }
      $index++;
  }

  if ( $found != -1 )
  {
      $self->Verbose("Object found: Index ", $found ,".\n");

      # Remove it from ours objects
      delete $self->{objects}[$found];
  }
  else
  {
      Print "Object not among my objects.\n";
  }

  # If there are no more objects to watch kill the session
  $poe_kernel->post( $self->{Session} => 'Quit' ) unless scalar(@{$self->{objects}});
}

sub AddFile
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  if ( ! defined($self->{mtime}) )
  {
    $self->{mtime} = (stat($self->{File}))[9] or 0;
  }
  $self->Verbose($session->ID, ": Adding watch: \"",$self->{File},"\"\n");
  $kernel->delay( 'CheckFile', $self->{Interval} );
}

sub CheckFile
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $self->Debug("Checking file: ",$self->{File},' ',$self->{mtime},"\n");
  my $mtime = (stat($self->{File}))[9] or 0;
  if ( !defined($self->{mtime}) or $mtime > $self->{mtime} )
  {
    $self->{mtime} = $mtime;
    foreach ( keys %{$self->{clients}} )
    {
      $self->Verbose($self->{File}," changed: call $_",
					'->{', $self->{clients}->{$_}, "}\n");
      $kernel->post( $_, $self->{clients}->{$_}, $self->{File} );
    }
    foreach ( @{$self->{functions}} )
    {
      $_->($self->{File});
    }
    foreach ( @{$self->{objects}} )
    {
      $self->Object($_);
    }
  }
  $kernel->delay( 'CheckFile', $self->{Interval} );
}

sub Quit
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $self->Debug($self->{Name},": Quitting...\n");
  $kernel->delay( 'CheckFile' );
  undef $self->{Interval};
  $kernel->yield( '_stop' );
}

sub Object
{
  my ($self,$object) = @_;
  $object->ReadConfig($self->{File});
  $self->Interval($object->ConfigRefresh);
  $self->File    ($object->Config);
}

1;
