package PHEDEX::Core::Agent::Dropbox;

use strict;
use warnings;
use POSIX;
use File::Path;
use File::Basename;
use PHEDEX::Core::Command;

our @required_params = qw / DROPDIR DBCONFIG /;
our @writeable_dirs  = qw / DROPDIR INBOX WORKDIR OUTDIR /;
our @writeable_files = qw / LOGFILE PIDFILE /;

our @all_dropbox = qw / NODAEMON ME NEXTDIR STARTTIME NODES IGNORE_NODES ACCEPT_NODES BAD JUNK DROPDIR DBCONFIG INBOX WORKDIR OUTDIR LOGFILE PIDFILE /; #/ needed parameters from calling class 

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {};

# Map requiered parameters from calling Class
  map { $self->{$_} = ${$h{_AC}}{$_} } @all_dropbox;
  $self->{_AC} = $h{_AC};

  return bless $self, $class;
}

# this workaround is ugly but allow us NOT rewrite everything
sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;      # skip all-cap methods

# if $attr exits, catch the reference to it
  if ( $self->{_AC}->can($attr) ) { $self->{_AC}->$attr(@_); } 
  else { PHEDEX::Core::Logging::Alert($self,"Un-known method $attr for Dropbox"); }     
}

sub isInvalid
{
  my $self = shift;
  my %h = @_;
  @{$h{REQUIRED}} = @required_params unless $h{REQUIRED};
  @{$h{WRITEABLE_DIRS}}  = @writeable_dirs  unless $h{WRITEABLE_DIRS};
  @{$h{WRITEABLE_FILES}} = @writeable_files unless $h{WRITEABLE_FILES};

  my $errors = 0;
  foreach ( @{$h{REQUIRED}} )
  {
   next if defined $self->{$_};
    $errors++;
    $self->Warn("Required parameter \"$_\" not defined!\n");
  }

# Some parameters must be writeable directories
  foreach my $key ( @{$h{WRITEABLE_DIRS}} )
  {
    $_ = $self->{$key};
    while ( my $x = readlink($_) ) { $_ = $x; } # Follow symlinks!

#   If the directory doesn't exist, attempt to create it...
    eval { mkpath $_ } unless -e;
    $self->Fatal("PERL_FATAL: $key directory $_ does not exist")   unless -e;
    $self->Fatal("PERL_FATAL: $key exists but is not a directory") unless -d;
    $self->Fatal("PERL_FATAL: $key directory $_ is not writeable") unless -w;
  }

# Some parameters must be writeable files if they exist, or the parent
# directory must be writeable. Non-definition is tacitly allowed
  foreach my $key ( @{$h{WRITEABLE_FILES}} )
  {
    if ( defined($_=$self->{$key}) )
    {
      while ( my $x = readlink($_) ) { $_ = $x; } # Follow symlinks!
      if ( -e $_ )
      {
#       If it exists, it better be a writeable file
        $self->Fatal("PERL_FATAL: $key exists but is not a file") unless -f;
        $self->Fatal("PERL_FATAL: $key file $_ is not writeable") unless -w;
      }
      else
      {
#       If it doesn't exist, the parent must be a writeable directory
#       If that parent directory doesn't exist, attempt to create it...
        if ( ! -e )
        {
          $_ = dirname($_);
          eval { mkpath $_ } unless -e;
        }
        $self->Fatal("PERL_FATAL: $key directory $_ does not exist")   unless -e;
        $self->Fatal("PERL_FATAL: $key exists but is not a directory") unless -d;
        $self->Fatal("PERL_FATAL: $key directory $_ is not writeable") unless -w;
      }
    }
  }

  if ( !defined($self->{LOGFILE}) && !$self->{NODAEMON} )
  {
#   LOGFILE not defined is fatal unless NODAEMON is set!
    $self->Fatal("PERL_FATAL: LOGFILE not set but process will run as a daemon");
  }

  return $errors;
}


# Look for pending drops in inbox.
sub readInbox
{
    my ($self, $get_all) = @_;

    die "$self->{ME}: fatal error: no inbox directory given\n" if ! $self->{INBOX};

    # Scan the inbox.  If this fails, file an alert but keep going,
    # the problem might be transient (just sleep for a while).
    my @files = ();
    $self->Alert("cannot list inbox(".$self->{INBOX}."): $!")
	if (! getdir($self->{INBOX}, \@files));

    # Check for junk
    foreach my $f (@files)
    {
	# Make sure we like it.
	if (! -d "$self->{INBOX}/$f")
	{
	    $self->Alert("junk ignored in inbox: $f") if ! exists $self->{JUNK}{$f};
	    $self->{JUNK}{$f} = 1;
        }
	else
	{
	    delete $self->{JUNK}{$f};
        }
    }

    # Return those that are ready, unless we want all;
    return $get_all ? @files : grep(-f "$self->{INBOX}/$_/go", @files);
}

# Look for pending tasks in the work directory.
sub readPending
{
    my $self = shift;
    die "$self->{ME}: fatal error: no work directory given\n" if ! $self->{WORKDIR};

    # Scan the work directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list workdir(".$self->{WORKDIR}."): $!")
	if (! getdir($self->{WORKDIR}, \@files));

    return @files;
}

# Look for tasks waiting for transfer to next agent.
sub readOutbox
{
    my $self = shift;
    die "$self->{ME}: fatal error: no outbox directory given\n" if ! $self->{OUTDIR};

    # Scan the outbox directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list outdir(".$self->{OUTDIR}."): $!")
	if (! getdir ($self->{OUTDIR}, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($self, $drop, $newname) = @_;
    &mv ("$self->{WORKDIR}/$drop", "$self->{WORKDIR}/$newname")
        || do { $self->Alert ("can't rename $drop to $newname"); return 0; };
    return 1;
}

# Utility to undo from failed scp bridge operation
sub scpBridgeFailed
{
    my ($self,$msg, $remote) = @_;
    # &runcmd ("ssh", $host, "rm -fr $remote");
    $self->Alert ($msg);
    return 0;
}

sub scpBridgeDrop
{
    my ($self,$source, $target) = @_;

    return $self->scpBridgeFailed ("failed to chmod $source", $target)
        if ! chmod(0775, "$source");

    return $self->scpBridgeFailed ("failed to copy $source", $target)
        if &runcmd ("scp", "-rp", "$source", "$target");

    return $self->scpBridgeFailed ("failed to copy /dev/null to $target/go", $target)
        if &runcmd ("scp", "/dev/null", "$target/go"); # FIXME: go-pending?

    return 1;
}

# Utility to undo from failed rfio bridge operation
sub rfioBridgeFailed
{
    my ($self,$msg, $remote) = @_;
    &rfrmall ($remote) if $remote;
    $self->Alert ($msg);
    return 0;
}

sub rfioBridgeDrop
{
    my ($self,$source, $target) = @_;
    my @files = <$source/*>;
    do { $self->Alert ("empty $source"); return 0; } if ! scalar @files;

    return $self->rfioBridgeFailed ("failed to create $target")
        if ! &rfmkpath ($target);

    foreach my $file (@files)
    {
        return $self->rfioBridgeFailed ("failed to copy $file to $target", $target)
            if ! &rfcp ("$source/$file", "$target/$file");
    }

    return $self->rfioBridgeFailed ("failed to copy /dev/null to $target", $target)
        if ! &rfcp ("/dev/null", "$target/go");  # FIXME: go-pending?

    return 1;
}

# Transfer the drop to the next agent
sub relayDrop
{
    my ($self, $drop) = @_;

    # Move to output queue if not done yet
    if (-d "$self->{WORKDIR}/$drop")
    {
        &mv ("$self->{WORKDIR}/$drop", "$self->{OUTDIR}/$drop") || return;
    }

    # Check if we've already successfully copied this one downstream.
    # If so, just nuke it; manual recovery is required to kick the
    # downstream ones forward.
    if (-f "$self->{OUTDIR}/$drop/gone") {
	&rmtree ("$self->{OUTDIR}/$drop");
	return;
    }

    # Clean up our markers
    &rmtree("$self->{OUTDIR}/$drop/go");
    &rmtree("$self->{OUTDIR}/$drop/gone");
    &rmtree("$self->{OUTDIR}/$drop/bad");
    &rmtree("$self->{OUTDIR}/$drop/done");

    # Copy to the next ones.  We want to be careful with the ordering
    # here -- we want to copy the directory exactly once, ever.  So
    # execute in an order that is safe even if we get interrupted.
    if (scalar @{$self->{NEXTDIR}} == 0)
    {
	&rmtree ("$self->{OUTDIR}/$drop");
    }
    elsif (scalar @{$self->{NEXTDIR}} == 1 && $self->{NEXTDIR}[0] !~ /^([a-z]+):/)
    {
	-d "$self->{NEXTDIR}[0]/inbox"
	    || mkdir "$self->{NEXTDIR}[0]/inbox"
	    || -d "$self->{NEXTDIR}[0]/inbox"
	    || return $self->Alert("cannot create $self->{NEXTDIR}[0]/inbox: $!");

	# Make sure the destination doesn't exist yet.  If it does but
	# looks like a failed copy, nuke it; otherwise complain and give up.
	if (-d "$self->{NEXTDIR}[0]/inbox/$drop"
	    && -f "$self->{NEXTDIR}[0]/inbox/$drop/go-pending"
	    && ! -f "$self->{NEXTDIR}[0]/inbox/$drop/go") {
	    &rmtree ("$self->{NEXTDIR}[0]/inbox/$drop")
        } elsif (-d "$self->{NEXTDIR}[0]/inbox/$drop") {
	    return $self->Alert("$self->{NEXTDIR}[0]/inbox/$drop already exists!");
	}

	&mv ("$self->{OUTDIR}/$drop", "$self->{NEXTDIR}[0]/inbox/$drop")
	    || return $self->Alert("failed to copy $drop to $self->{NEXTDIR}[0]/$drop: $!");
	&touch ("$self->{NEXTDIR}[0]/inbox/$drop/go")
	    || $self->Alert ("failed to make $self->{NEXTDIR}[0]/inbox/$drop go");
    }
    else
    {
        foreach my $dir (@{$self->{NEXTDIR}})
        {
	    if ($dir =~ /^scp:/) {
		$self->scpBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    } elsif ($dir =~ /^rfio:/) {
		$self->rfioBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    }

	    # Local.  Create destination inbox if necessary.
	    -d "$dir/inbox"
	        || mkdir "$dir/inbox"
	        || -d "$dir/inbox"
	        || return $self->Alert("cannot create $dir/inbox: $!");

	    # Make sure the destination doesn't exist yet.  If it does but
	    # looks like a failed copy, nuke it; otherwise complain and give up.
	    if (-d "$dir/inbox/$drop"
	        && -f "$dir/inbox/$drop/go-pending"
	        && ! -f "$dir/inbox/$drop/go") {
	        &rmtree ("$dir/inbox/$drop")
            } elsif (-d "$dir/inbox/$drop") {
	        return $self->Alert("$dir/inbox/$drop already exists!");
	    }

	    # Copy to the next stage, preserving everything
	    my $status = &runcmd  ("cp", "-Rp", "$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
	    return $self->Alert ("can't copy $drop to $dir/inbox: $status") if $status;

	    # Mark it almost ready to go
	    &touch("$dir/inbox/$drop/go-pending");
        }

        # Now mark myself gone downstream so we won't try copying again
        # (FIXME: error checking?)
        &touch ("$self->{OUTDIR}/$drop/gone");

        # All downstream versions copied safely now.  Now really let them
        # go onwards.  If this fails, it's not fatal because someone can
        # still manually fix them to be in ready state.  We haven't lost
        # anything.  (FIXME: avoidable?)
        foreach my $dir (@{$self->{NEXTDIR}}) {
	    next if $dir =~ /^([a-z]+):/; # FIXME: also handle here?
	    &mv("$dir/inbox/$drop/go-pending", "$dir/inbox/$drop/go");
        }

        # Now junk it here
        &rmtree("$self->{OUTDIR}/$drop");
    }
}

# Check what state the drop is in and indicate if it should be
# processed by agent-specific code.
sub inspectDrop
{
    my ($self, $drop) = @_;

    if (! -d "$self->{WORKDIR}/$drop")
    {
	$self->Alert("$drop is not a pending task");
	return 0;
    }

    if (-f "$self->{WORKDIR}/$drop/bad")
    {
	$self->Alert("$drop marked bad, skipping") if ! exists $self->{BAD}{$drop};
	$self->{BAD}{$drop} = 1;
	return 0;
    }

    if (! -f "$self->{WORKDIR}/$drop/go")
    {
	$self->Alert("$drop is incomplete!");
	return 0;
    }

    if (-f "$self->{WORKDIR}/$drop/done")
    {
	&relayDrop ($self, $drop);
	return 0;
    }

    return 1;
}

# Mark a drop bad.
sub markBad
{
    my ($self, $drop) = @_;
    &touch("$self->{WORKDIR}/$drop/bad");
    $self->Logmsg("stats: $drop @{[&formatElapsedTime($self->{STARTTIME})]} failed");
}

1;
