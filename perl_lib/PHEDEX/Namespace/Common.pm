package PHEDEX::Namespace::Null::Cache;

sub AUTOLOAD
{
# This is a dummy caching module which throws away its arguments, to keep
# the rest of the client code clean.

# my $self = shift;
# my $attr = our $AUTOLOAD;
# print "AUTOLOAD: $attr\n";
# $attr =~ s/.*:://;
};

package PHEDEX::Namespace::Common;

use strict;
use warnings;
no strict 'refs';
use PHEDEX::Core::Loader;
use PHEDEX::Core::Catalogue;
use Data::Dumper;
use Getopt::Long;

# Note the format: instead of specifying a variable to take the parsed
# value, the default is given directly here. This is all sorted out in
# getCommonOptions, below, where the real %options and %params hashes
# are built and returned to the user.
our %common_options = (
  'help'     => 0,
  'verbose!' => 0,
  'debug+'   => 0,
  'cache=s'  => undef,
  'nocache'  => 0,
);

# Any module loaded after this one may call setCommonOptions with a hashref
# specifying extra options. This defines what the options are, but does not
# parse the command-line to retrieve them. That is assumed to happen later.
#
# Note the structure of the hashref: the key is a specification that you
# would give to GetOptions. The value is the default valut to apply to that
# key. This is different to the normal use, where the value would be a
# reference to a variable that holds the default, which would then be
# overwritten when the arguments are evaluated.
#
# This is because here, at the time the common options are accumulated, you
# do not yet know where they will be parsed. That happens later, and the code
# that wants to use the common options must call getCommonOptions, below.
sub setCommonOptions {
  my $options = shift;
  my ($option,$label,$spec,$key);
  foreach $option ( keys %{$options} ) {
    $common_options{lc $option} = $options->{$option};
  }
}

# The inputs are two hashrefs, one to the options structure (that will be
# passed to GetOptions) and one to the parameters structure (that will receive
# the values that are retrieved by GetOptions).
#
# This function then maps the %common_options and %common_params into the
# input hashrefs, so they can be fed directly to GetOptions, with all the
# additional common options specified correctly.
#
# Note that if the input params structure defines a default that already exists
# in the common_params, the input value is retained. I.e. the arguments to this
# function override the common defaults.
sub getCommonOptions {
  my ($options,$params,$option,$label,$spec);
  ($options,$params) = @_;
  foreach $option ( keys %common_options ) {
      if ( $option =~ m%^([a-zA-Z0-9]+)([\+!=].*)$% ) {
      $label = uc $1;
      $spec = $2;
    } else {
      $label = uc $option;
      $spec = '';
    }
    $params->{$label} = $common_options{$option} unless $params->{$label};
    $options->{$option} = \$params->{$label};
  }
}

sub _init
{
  my ($self,%h) = @_;
  push @{$h{REJECT}}, qw / Common /;
  $self->{LOADER} = PHEDEX::Core::Loader->new( NAMESPACE => $h{NAMESPACE},
					       REJECT	 => $h{REJECT} );
  map { $self->{$_} = $h{$_} } keys %h;
  if ( $self->{LOADER}->ModuleName('Cache') && !$self->{NOCACHE} )
  {
    my $module = $self->{LOADER}->Load('Cache');
    $self->{CACHE} = $module->new($self);
    $self->{LOADER}->Delete('Cache');
  }
  else
  {
    $self->{CACHE} = bless( {}, 'PHEDEX::Namespace::Null::Cache' );
  }

  $self->{CATALOGUE} = $h{CATALOGUE} || PHEDEX::Core::Catalogue->new();
  $self->{PROTOCOL} = $h{PROTOCOL} || 'direct';
}

sub _init_commands
{
  my $self = shift;

  foreach ( keys %{$self->{LOADER}->Commands} )
  {
    $self->{COMMANDS}{$_} = $self->{LOADER}->Load($_)->new($self); 
    foreach my $k ( keys %{$self->{COMMANDS}{$_}{MAP}} )
    {
      $self->{MAP}{$k} = $_;
    }
  }
  foreach ( keys %{$self->{COMMANDS}} )
  {
    next unless ref($self->{COMMANDS}{$_}) eq 'SCALAR';
    my ($cmd,@opts) = split(' ',$self->{COMMANDS}{$_});
    $self->{COMMANDS}{$_} = { cmd => $cmd, opts => \@opts };
  }
  print "*** Namespace $self->{NAMESPACE} loaded ***\n" if $self->{DEBUG};
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return if $attr =~ /^[A-Z]+$/;  # skip DESTROY and all-cap methods

# First, see if this command is mapped into another command.
  if ( exists($self->{MAP}{$attr}) )
  {
    my $map = $self->{MAP}{$attr};
    my $r = $self->$map(@_);
    return unless ref($r);
    return $r->{$attr};
  }

# If this is a command that I must run, or a method I must execute, do so,
# and cache the results. I don't care if the cache exists because a null
# cache is provided if no proper cache is found.
#
# Note the order. Check for 'execute' capability before checking for a
# matchine command, that allows the execute function to use the command
# interface for itself.
  if ( exists($self->{COMMANDS}{$attr}) )
  {
    my $result = $self->{CACHE}->fetch($attr,\@_);
    return $result if defined $result;
    if ( $self->{COMMANDS}{$attr}->can('execute') )
    { $result = $self->{COMMANDS}{$attr}->execute($self,@_); }
    else
    { $result = $self->Command($attr,@_); }
    $self->{CACHE}->store($attr,\@_,$result) if $result;
    return $result;
  }

# For normal attributes, get/set and return the value
  if ( exists($self->{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }

# Otherwise, give up and spit the dummy
  die "\"$attr\" not known to ",__PACKAGE__,"\n";
}

sub Command
{
  my ($self,$call,$file) = @_;
  my ($h,$r,@opts,$env,$cmd);
  return unless $h = $self->{COMMANDS}{$call};
  my $protocol;
  if ( $self->{COMMANDS}{$call}->can('Protocol') ) {
      $protocol = $self->{COMMANDS}{$call}->Protocol()
  }
  else
  {
      $protocol =  $self->Protocol();
  }
  my $pfn = $self->{CATALOGUE}->lfn2pfn($file,$protocol);
  if ( not defined $pfn ) {
      print "lfn2pfn failed for lfn $file with protocol $protocol\n" if $self->{DEBUG};
      return;
  }
  @opts = ( @{$h->{opts}}, $pfn );
  $env = $self->{ENV} || '';
  $cmd = "$env $h->{cmd} @opts";
  print "Prepare to execute $cmd\n" if $self->{DEBUG};
  open CMD, "$cmd |" or die "$cmd: $!\n";
  @{$r->{STDOUT}} = <CMD>;
  close CMD or return;
  if ( $self->{COMMANDS}{$call}->can('parse') )
  {
    $r = $self->{COMMANDS}{$call}->parse($self,$r,$file)
  }
  return $r;
}

# Define the protocol to be used in looking up PFNs in the TFC. Most interfaces
# will not need to change this, but the SRM protocol does!
sub Protocol
{ 
  my $self = shift;
  return $self->{PROTOCOL};
}

sub _help
{
  my $self = shift;
  foreach ( sort keys %{$self->{COMMANDS}} )
  {
    if ( $self->{COMMANDS}{$_}->can('Help') )
    {
      print "$_: ";
      $self->{COMMANDS}{$_}->Help();
    }
  }
  exit 0;
}

1;
