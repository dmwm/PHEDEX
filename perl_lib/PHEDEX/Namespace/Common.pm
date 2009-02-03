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

=head1 NAME

PHEDEX::Namespace::Common - implement common namespace functions for all protocols

=head1 SYNOPSIS

=cut

use strict;
use warnings;
no strict 'refs';
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

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
}

sub _init_commands
{
  my $self = shift;

  foreach ( keys %{$self->{LOADER}->Commands} )
  {
    $self->{COMMANDS}{$_} = $self->{LOADER}->Load($_)->new(); 
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
    return $result if $result;
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
  my ($h,$r,$parse,@opts);
  return unless $h = $self->{COMMANDS}{$call};
  @opts = ( @{$h->{opts}}, $file );
  print "Prepare to execute $h->{cmd} @opts\n" if $self->{VERBOSE};
  open CMD, "$h->{cmd} @opts |" or die "$h->{cmd} @opts: $!\n";
  @{$r->{STDOUT}} = <CMD>;
  close CMD or return;
  $parse = $h->{parse} || 'parse_' . $call;
  if ( $self->{COMMANDS}{$call}->can($parse) )
  {
    $r = $self->{COMMANDS}{$call}->$parse($self,$r,$file)
  }
  return $r;
}

sub _help
{
  my $self = shift;
  foreach ( sort keys %{$self->{COMMANDS}} )
  {
    if ( $self->{COMMANDS}{$_}->can('Help') )
    {
      print "$_: ",$self->{COMMANDS}{$_}->Help();
    }
  }
}

1;
