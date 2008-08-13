package PHEDEX::Core::Loader;
use strict;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my ($self,$help,%params,%h);
  %h = @_;
  %params = (
	       NAMESPACE => undef,
               VERBOSE   => 0,
               DEBUG     => 0,
            );
  $self = \%params;
  map { $self->{$_} = $h{$_} } keys %h;

  die __PACKAGE__,": no NAMESPACE defined\n" unless $self->{NAMESPACE};
  $self->{NAMESPACE} =~ s%::$%%;

  if ( !defined($self->{REJECT}) )
  {
    foreach ( qw / Template UserAgent FakeAgent / )
    { push @{$self->{REJECT}}, $_; }
  }
  bless $self, $class;
  return $self;
}

sub ModuleName
{
  my ($self,$Action) = @_;
  return $self->{NAMESPACE} . '::' . $self->KnownCommands()->{lc $Action};
}

sub Load
{
  my ($self,$Action) = @_;
  my $module = $self->ModuleName($Action);
  eval("use $module");
  do { chomp ($@); die "Failed to load module $module: $@\n" } if $@;
  return $module;
}

#sub separateArgs()
#{
#  my @argv;
#  my $global = 0;
#
## static variables!
#  our @ARGV_orig;
#  our $notFirst;
#
#  if ( !$notFirst )
#  {
##   first call: set global arguments array and 'global' flag
#    @ARGV_orig = @ARGV;
#    $notFirst = $global = 1;
#  }
#
## The easy way out if there are no arguments
#  return undef unless @ARGV_orig;
#
## If we're looking for global arguments, first argument better start with '-'
#  return undef if ( $global && $ARGV_orig[0] !~ m%^-% );
#
## Remove leading '--' arguments, unless this is the first call, in
## which case they signify no global arguments.
#  $_ = shift @ARGV_orig;
#  while ( m%^--$% )
#  {
#    return undef if $global;
#    $_ = shift @ARGV_orig;
#  }
#  unshift @ARGV_orig, $_; # put back last argument for next step...
#
## Loop over remaining arguments. Terminate on '--' or when no arguments left
#  while ( $_ = shift @ARGV_orig )
#  {
#    last if m%^--$%;
#    push @argv, $_;
#  }
#
#  return \@argv;
#}

sub KnownCommands
{
  my ($self,%h) = @_;
  my ($command,%commands,$namespace);
  ($namespace = $self->{NAMESPACE}) =~ s%::%/%g;

  foreach ( @INC )
  {
    foreach ( <$_/$namespace/*pm> )
    {
      m%^.*/$namespace/(.*).pm$%;
      $command = $1;
      $commands{lc $command} = $command;
    }
  }

  foreach ( @{$self->{REJECT}} )
  { $_ = lc $_; delete $commands{$_} if exists $commands{$_}; }

  return \%commands;
}

1;
