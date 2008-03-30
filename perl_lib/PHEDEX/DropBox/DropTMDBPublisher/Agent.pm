package PHEDEX::DropBox::DropTMDBPublisher::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use File::Path;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
	  	  MYNODE => undef,		# My TMDB node name
		  ME => 'DropTMDBPublisher',
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Actually process the drop.
sub processDrop
{
    my ($self, $drop) = @_;

    # Sanity checking
    return if (! $self->inspectDrop ($drop));
    delete $$self{BAD}{$drop};
    &timeStart($$self{STARTTIME});

    # Prepare attribute cache for this drop
    my $dropdir = "$$self{WORKDIR}/$drop";

    # Decide which nodes this is for
    my @nodes = ();
    if (-f "$dropdir/PhEDEx-Nodes.txt")
    {
        @nodes = split(/\s+/, &input ("$dropdir/PhEDEx-Nodes.txt") || '');
        do { $self->Alert("$drop: PhEDEx-Nodes.txt contained no nodes");
	     $self->markBad ($drop); return }
            if ! @nodes;
    }
    else
    {
        do { $self->Alert("$drop: no PhEDEx-Nodes.txt and no -node argument");
	     $self->markBad ($drop); return }
            if ! $$self{MYNODE};
	push(@nodes, $$self{MYNODE});
    }

    # Locate file description XML file.
    my $filedata = (<$dropdir/*.xml>)[0];
    do { $self->Alert("$drop: no catalogue"); $self->markBad ($drop); return }
        if ! $filedata;

    # Load and parse additional options.
    my $strict = 1;
    my $verbose = 1;
    my @options = split(/\s+/, &input ("$dropdir/Options.txt") || "");
    foreach my $opt (@options)
    {
	if ($opt eq '!strict')
	{
	    $strict = 0;
	}
	elsif ($opt eq 'strict')
	{
	    $strict = 1;
	}
	elsif ($opt eq '!verbose')
	{
	    $verbose = 0;
	}
	elsif ($opt eq 'verbose')
	{
	    $verbose = 1;
	}
	else
	{
	    $self->Alert("$drop: unrecognised option '$opt'");
	    $self->markBad ($drop);
	    return;
	}
    }

    # Run publish.  This is actually done by a helper program shared
    # with other tools, so we don't repeat the code here.
    my $toolhome = $0; $toolhome =~ s|/[^/]*$||; $toolhome .= "/../..";
    my @cmd = ("$toolhome/Toolkit/Request/TMDBInject",
               "-db", $$self{DBCONFIG},
	       ($strict ? "-strict" : ()),
	       ($verbose ? "-verbose" : ()),
	       "-filedata", $filedata,
	       "-nodes", join(",", @nodes));

    if (my $rc = &runcmd (@cmd))
    {
	 $self->Alert ("exit code @{[&runerror($rc)]} from @cmd");
         $self->markBad ($drop);
	 return;
    }

    # Success, relay onwards
    $self->relayDrop ($drop);
    $self->Logmsg("stats: $drop @{[&formatElapsedTime($$self{STARTTIME})]} success");
}

1;
