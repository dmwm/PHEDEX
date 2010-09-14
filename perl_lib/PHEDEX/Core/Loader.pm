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
    @reject = ( qw / Template UserAgent FakeAgent Mail / ) unless @reject;
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

sub ModuleHelp
{
  my ($self,$interface) = @_;
  my @interfaces = grep (!/\//,sort keys %{$self->Commands});
  if ( grep { $_ eq $interface} @interfaces ){
      my $module = $self->Load($interface);
      my $ns = $module->new();
      $ns->Help() and exit(1);
  } else {
      print "Interface '$interface' is not supported. Known interfaces are: ";
      map { print "'$_', " } @interfaces;
      print "\n";
      exit(2);
  }
}

sub Load
{
  my ($self,$Action) = @_;
  my $module = $self->ModuleName($Action);
  die __PACKAGE__,": no module found for action \"$Action\"\n" unless $module;
  eval("require $module");
  do { chomp ($@); die "Failed to load module $module: $@\n" } if $@;
  {
    no strict 'refs';
    die "Loaded $module, but no package found with that name!\n"
    unless keys %{$module . '::'};
  }
  return $module;
}

sub _commands
{
  my ($self,$namespace,$dir,$prefix) = @_;
  my ($command,$mpath);
  foreach ( <$dir/$namespace/*> )
  {
    if ( m%\.pm$% ) # is a Perl module
    {
      m%^.*/$namespace/(.*).pm$%;
      $command = $prefix . $1;
      ($mpath = $command) =~ s%/%::%g;
      $self->{COMMANDS}{lc $command} = $mpath;
      next;
    }

    if ( -d ) # is a subdirectory
    {
      next if ( m%/CVS$% ); # Explicitly ignore CVS...
      m%^.*/$namespace/(.*)%;
      $mpath = $1;
      ($_ = $mpath) =~ s%/%::%g;
      $self->{SUBSPACES}{ $self->{NAMESPACE} . '::' . $prefix . $_ }++;
      $self->_commands($namespace.'/'.$mpath,$dir,$_.'/');
      next;
    }
  }
}

sub Commands
{
  my $self = shift;
  return $self->{COMMANDS} if $self->{COMMANDS};

  my ($command,%commands,$namespace);
  ($namespace = $self->{NAMESPACE}) =~ s%::%/%g;
  $self->{SUBSPACES} = {};
  foreach ( @INC )
  {
    $self->_commands($namespace,$_,'');
  }

  foreach ( @{$self->{REJECT}} )
  { $_ = lc $_; delete $self->{COMMANDS}{$_} if exists $self->{COMMANDS}{$_}; }

  return $self->{COMMANDS}; #= \%commands;
}

sub Subspaces
{
  my $self = shift;
  return $self->{SUBSPACES};
}
1;
