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

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {};
  bless $self, $class;

  $self->{_AL} = $h{_AL};

#/Before basic validation, we need to derive a few other parameters.
  $self->{_AL}->{DROPDIR} .= '/' unless $self->{_AL}->{DROPDIR} =~ m%\/$%;
  $self->{_AL}->{INBOX}    = $self->{_AL}->{DROPDIR} . 'inbox'; 
  $self->{_AL}->{OUTDIR}   = $self->{_AL}->{DROPDIR} . 'outbox';
  $self->{_AL}->{PIDFILE}  = $self->{_AL}->{DROPDIR} . 'pid';
  $self->{_AL}->{STOPFLAG} = $self->{_AL}->{DROPDIR} . 'stop';
  $self->{_AL}->{WORKDIR}  = $self->{_AL}->{DROPDIR} . 'work';

  return $self;
}

# this workaround is ugly but allow us NOT rewrite everything
sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;      # skip all-cap methods

  # if $attr exits, catch the reference to it, note we will call something
  # only if belogs to the parent calling class.
  if ( $self->{_AL}->can($attr) ) { $self->{_AL}->$attr(@_); } 
  else { PHEDEX::Core::Logging::Alert($self,"Unknown method $attr for Agent::Dropbox"); }     
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
   next if defined $self->{_AL}->{$_};
    $errors++;
    $self->Warn("Required parameter \"$_\" not defined!\n");
  }

# Some parameters must be writeable directories
  foreach my $key ( @{$h{WRITEABLE_DIRS}} )
  {
    $_ = $self->{_AL}->{$key};
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
    if ( defined($_=$self->{_AL}->{$key}) )
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

  if ( !defined($self->{_AL}->{LOGFILE}) && !$self->{_AL}->{NODAEMON} )
  {
#   LOGFILE not defined is fatal unless NODAEMON is set!
    $self->Fatal("PERL_FATAL: LOGFILE not set but process will run as a daemon");
  }

  return $errors;
}

# Make a basic cleanup
sub cleanDropbox
{
    my $self = shift;
    my $me = shift;
 
    foreach my $dir (@{$self->{_AL}->{NEXTDIR}}) {
        if ($dir =~ /^([a-z]+):/) {
            die "$me: fatal error: unrecognised bridge $1" if ($1 ne "scp" && $1 ne "rfio");
        } else {
            die "$me: fatal error: no downstream drop box\n" if ! -d $dir;
        }
    }

    if (-f $self->{_AL}->{PIDFILE})
    {
        if (my $oldpid = &input($self->{_AL}->{PIDFILE}))
        {
            chomp ($oldpid);
            die "$me: pid $oldpid already running in $self->{_AL}->{DROPDIR}\n"
                if kill(0, $oldpid);
            print "$me: pid $oldpid dead in $self->{_AL}->{DROPDIR}, overwriting\n";
            unlink ($self->{_AL}->{PIDFILE});
        }
    }

    if (-f $self->{_AL}->{STOPFLAG})
    {
        print "$me: removing old stop flag $self->{_AL}->{STOPFLAG}\n";
        unlink ($self->{_AL}->{STOPFLAG});
    }

}

# Look for pending drops in inbox.
sub readInbox
{
    my ($self, $get_all) = @_;

    die "$self->{_AL}->{ME}: fatal error: no inbox directory given\n" if ! $self->{_AL}->{INBOX};

    # Scan the inbox.  If this fails, file an alert but keep going,
    # the problem might be transient (just sleep for a while).
    my @files = ();
    $self->Alert("cannot list inbox(".$self->{_AL}->{INBOX}."): $!")
	if (! getdir($self->{_AL}->{INBOX}, \@files));

    # Check for junk
    foreach my $f (@files)
    {
	# Make sure we like it.
	if (! -d "$self->{_AL}->{INBOX}/$f")
	{
	    $self->Alert("junk ignored in inbox: $f") if ! exists $self->{_AL}->{JUNK}{$f};
	    $self->{_AL}->{JUNK}{$f} = 1;
        }
	else
	{
	    delete $self->{_AL}->{JUNK}{$f};
        }
    }

    # Return those that are ready, unless we want all;
    return $get_all ? @files : grep(-f "$self->{_AL}->{INBOX}/$_/go", @files);
}

# Look for pending tasks in the work directory.
sub readPending
{
    my $self = shift;
    die "$self->{_AL}->{ME}: fatal error: no work directory given\n" if ! $self->{_AL}->{WORKDIR};

    # Scan the work directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list workdir(".$self->{_AL}->{WORKDIR}."): $!")
	if (! getdir($self->{_AL}->{WORKDIR}, \@files));

    return @files;
}

# Look for tasks waiting for transfer to next agent.
sub readOutbox
{
    my $self = shift;
    die "$self->{_AL}->{ME}: fatal error: no outbox directory given\n" if ! $self->{_AL}->{OUTDIR};

    # Scan the outbox directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list outdir(".$self->{_AL}->{OUTDIR}."): $!")
	if (! getdir ($self->{_AL}->{OUTDIR}, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($self, $drop, $newname) = @_;
    &mv ("$self->{_AL}->{WORKDIR}/$drop", "$self->{_AL}->{WORKDIR}/$newname")
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
    if (-d "$self->{_AL}->{WORKDIR}/$drop")
    {
        &mv ("$self->{_AL}->{WORKDIR}/$drop", "$self->{_AL}->{OUTDIR}/$drop") || return;
    }

    # Check if we've already successfully copied this one downstream.
    # If so, just nuke it; manual recovery is required to kick the
    # downstream ones forward.
    if (-f "$self->{_AL}->{OUTDIR}/$drop/gone") {
	&rmtree ("$self->{_AL}->{OUTDIR}/$drop");
	return;
    }

    # Clean up our markers
    &rmtree("$self->{_AL}->{OUTDIR}/$drop/go");
    &rmtree("$self->{_AL}->{OUTDIR}/$drop/gone");
    &rmtree("$self->{_AL}->{OUTDIR}/$drop/bad");
    &rmtree("$self->{_AL}->{OUTDIR}/$drop/done");

    # Copy to the next ones.  We want to be careful with the ordering
    # here -- we want to copy the directory exactly once, ever.  So
    # execute in an order that is safe even if we get interrupted.
    if (scalar @{$self->{_AL}->{NEXTDIR}} == 0)
    {
	&rmtree ("$self->{_AL}->{OUTDIR}/$drop");
    }
    elsif (scalar @{$self->{_AL}->{NEXTDIR}} == 1 && $self->{_Al}->{NEXTDIR}[0] !~ /^([a-z]+):/)
    {
	-d "$self->{_AL}->{NEXTDIR}[0]/inbox"
	    || mkdir "$self->{_AL}->{NEXTDIR}[0]/inbox"
	    || -d "$self->{_AL}->{NEXTDIR}[0]/inbox"
	    || return $self->Alert("cannot create $self->{_AL}->{NEXTDIR}[0]/inbox: $!");

	# Make sure the destination doesn't exist yet.  If it does but
	# looks like a failed copy, nuke it; otherwise complain and give up.
	if (-d "$self->{_AL}->{NEXTDIR}[0]/inbox/$drop"
	    && -f "$self->{_AL}->{NEXTDIR}[0]/inbox/$drop/go-pending"
	    && ! -f "$self->{_AL}->{NEXTDIR}[0]/inbox/$drop/go") {
	    &rmtree ("$self->{_AL}->{NEXTDIR}[0]/inbox/$drop")
        } elsif (-d "$self->{_AL}->{NEXTDIR}[0]/inbox/$drop") {
	    return $self->Alert("$self->{_AL}->{NEXTDIR}[0]/inbox/$drop already exists!");
	}

	&mv ("$self->{_AL}->{OUTDIR}/$drop", "$self->{_AL}->{NEXTDIR}[0]/inbox/$drop")
	    || return $self->Alert("failed to copy $drop to $self->{_AL}->{NEXTDIR}[0]/$drop: $!");
	&touch ("$self->{_AL}->{NEXTDIR}[0]/inbox/$drop/go")
	    || $self->Alert ("failed to make $self->{_AL}->{NEXTDIR}[0]/inbox/$drop go");
    }
    else
    {
        foreach my $dir (@{$self->{_AL}->{NEXTDIR}})
        {
	    if ($dir =~ /^scp:/) {
		$self->scpBridgeDrop ("$self->{_AL}->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    } elsif ($dir =~ /^rfio:/) {
		$self->rfioBridgeDrop ("$self->{_AL}->{OUTDIR}/$drop", "$dir/inbox/$drop");
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
	    my $status = &runcmd  ("cp", "-Rp", "$self->{_AL}->{OUTDIR}/$drop", "$dir/inbox/$drop");
	    return $self->Alert ("can't copy $drop to $dir/inbox: $status") if $status;

	    # Mark it almost ready to go
	    &touch("$dir/inbox/$drop/go-pending");
        }

        # Now mark myself gone downstream so we won't try copying again
        # (FIXME: error checking?)
        &touch ("$self->{_AL}->{OUTDIR}/$drop/gone");

        # All downstream versions copied safely now.  Now really let them
        # go onwards.  If this fails, it's not fatal because someone can
        # still manually fix them to be in ready state.  We haven't lost
        # anything.  (FIXME: avoidable?)
        foreach my $dir (@{$self->{_AL}->{NEXTDIR}}) {
	    next if $dir =~ /^([a-z]+):/; # FIXME: also handle here?
	    &mv("$dir/inbox/$drop/go-pending", "$dir/inbox/$drop/go");
        }

        # Now junk it here
        &rmtree("$self->{_AL}->{OUTDIR}/$drop");
    }
}

# Check what state the drop is in and indicate if it should be
# processed by agent-specific code.
sub inspectDrop
{
    my ($self, $drop) = @_;

    if (! -d "$self->{_AL}->{WORKDIR}/$drop")
    {
	$self->Alert("$drop is not a pending task");
	return 0;
    }

    if (-f "$self->{_AL}->{WORKDIR}/$drop/bad")
    {
	$self->Alert("$drop marked bad, skipping") if ! exists $self->{_AL}->{BAD}{$drop};
	$self->{_AL}->{BAD}{$drop} = 1;
	return 0;
    }

    if (! -f "$self->{_AL}->{WORKDIR}/$drop/go")
    {
	$self->Alert("$drop is incomplete!");
	return 0;
    }

    if (-f "$self->{_AL}->{WORKDIR}/$drop/done")
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
    &touch("$self->{_AL}->{WORKDIR}/$drop/bad");
    $self->Logmsg("stats: $drop @{[&formatElapsedTime($self->{_AL}->{STARTTIME})]} failed");
}

1;
