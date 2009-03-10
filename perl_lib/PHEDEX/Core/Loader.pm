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
    no strict 'refs';
    my @reject = @{$self->{NAMESPACE} . '::_loader_reject'};
    @reject = ( qw / Template UserAgent FakeAgent / ) unless @reject;
    $self->{REJECT} = \@reject;
  }
  bless $self, $class;
  $self->Commands();
  return $self;
}

sub Delete
{
  my ($self,$Action) = @_;
  delete $self->Commands()->{lc $Action};
}

sub ModuleName
{
  my ($self,$Action) = @_;
  my $module = $self->Commands()->{lc $Action};
  return undef unless $module;
  return $self->{NAMESPACE} . '::' . $module;
}

sub Load
{
  my ($self,$Action) = @_;
  my $module = $self->ModuleName($Action);
  die __PACKAGE__,": no module found for action \"$Action\"\n" unless $module;
  eval("use $module");
  do { chomp ($@); die "Failed to load module $module: $@\n" } if $@;
  return $module;
}

sub Commands
{
  my $self = shift;
  return $self->{COMMANDS} if $self->{COMMANDS};

  my ($command,%commands,$namespace);
  ($namespace = $self->{NAMESPACE}) =~ s%::%/%g;

  $self->{SUBSPACES} = [];
  foreach ( @INC )
  {
    foreach ( <$_/$namespace/*> )
    {
      if ( m%\.pm$% ) # is a Perl module
      {
        m%^.*/$namespace/(.*).pm$%;
        $command = $1;
        $commands{lc $command} = $command;
        next;
      }

      if ( -d ) # is a subdirectory
      {
        next if ( m%/CVS$% ); # Explicitly ignore CVS...
        m%^.*/$namespace/(.*)%;
        ($_ = $1) =~ s%/%::%;
        push @{$self->{SUBSPACES}}, $self->{NAMESPACE} . '::' . $_;
        next;
      }
    }
  }

  foreach ( @{$self->{REJECT}} )
  { $_ = lc $_; delete $commands{$_} if exists $commands{$_}; }

  return $self->{COMMANDS} = \%commands;
}

sub Subspaces
{
  my $self = shift;
  return $self->{SUBSPACES};
}
1;
