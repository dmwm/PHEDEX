package PHEDEX::File::Export::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Command;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
	  	  MYNODE => undef,		# My TMDB node name
	  	  NODES => [],			# Patterns for nodes to run for
	  	  IGNORE_NODES => [],		# TMDB nodes to ignore
	  	  ACCEPT_NODES => [],		# TMDB nodes to accept
		  WAITTIME => 60 + rand(10),	# Agent activity cycle
	  	  STORAGEMAP => undef,		# Storage path mapping rules
		  LAST_LIVE => 0,		# Last time we indicated liveness
	  	  LAST_UPDATE => -1, 		# Timestamp of file catalogue file
		  PROTOCOLS => undef,		# Protocols to accept
		  ME	=> 'FileExport',
		);
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

######################################################################
sub checkCatalogueChange
{
    my ($self, $exists) = @_;
    my $now = &mytimeofday ();

    # If we don't find a catalogue, warn.
    $self->Warn ("trivial catalogue $$self{STORAGEMAP} has vanished") if (!$exists);

    # Unchanged if this is no different from our last check
    my $stamp = (stat(_))[9] if $exists;
    return 0 if (defined $stamp && $$self{LAST_UPDATE} == $stamp);

    # By default changed
    $$self{LAST_UPDATE} = $stamp if defined $stamp;
    return $stamp;
}

sub checkLivenessUpdate
{
    my ($self) = @_;
    my $now = &mytimeofday ();
    return 0 if $now - $$self{LAST_LIVE} < 5400;
    $$self{LAST_LIVE} = $now;
    return 1;
}

sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    
    eval
    {
	# Check whether we need to update catalogue, or just liveness
	# info.  We update liveness once every hour and a half or so,
	# and catalogue whenever it changes.  The agent cycle is quite
	# small so we react to catalogue changes quickly. If we don't
        # find a local catalogue file, delete it from TMDB.

	my $valid = -e $$self{STORAGEMAP};
	my $liveness = $self->checkLivenessUpdate ();
	my $changed  = $self->checkCatalogueChange ($valid);
	
	if ($changed || $liveness)
	{
	    my @nodes;
	    my $now = &mytimeofday ();
	    $dbh = $self->connectAgent();
	    @nodes = $self->expandNodes();
	    my ($filter, %filter_args) = $self->otherNodeFilter("xs.to_node");

	    foreach my $node (@nodes)
	    {
		# Upload new catalogue if it changed and
                # we have a local storage catalogue.
		if ($changed)
		{
		    # Delete old catalogue for this node.
		    &PHEDEX::Core::Catalogue::deleteCatalogue($self->{DBH}, $$self{NODES_ID}{$node});

		    # Upload current catalogue rules.		    
		    my @tfc;
		    foreach my $kind (qw(lfn-to-pfn pfn-to-lfn))
		    {
			next if !$valid;
			my $rules = {};
			# Protect against corrupted storage catalogues
			eval
			{
			    $rules = &storageRules($$self{STORAGEMAP}, $kind);
			};
			do { chomp ($@); $valid = 0;
			     $self->Alert ("error parsing storagemap $$self{STORAGEMAP}: $@");
			     last;
			 } if $@;

			# Add rules to full TFC array
			while (my ($proto, $ruleset) = each %$rules)
			{
			    foreach my $rule (@$ruleset)
			    {
				push @tfc, {
				    "RULE_TYPE" => $kind,
				    "PROTOCOL" => $proto,
				    "CHAIN" => $$rule{'chain'},
				    "DESTINATION_MATCH" => $$rule{'destination-match'},
				    "PATH_MATCH" => $$rule{'path-match'},
				    "RESULT_EXPR" => $$rule{'result'},
				    "IS_CUSTODIAL" => $$rule{'is-custodial'},
				    "SPACE_TOKEN" => $$rule{'space-token'}
				}
			    }
			}
		    }
		    
		    # Insert TFC to database
		    &PHEDEX::Core::Catalogue::insertCatalogue($self->{DBH}, 
							      $$self{NODES_ID}{$node}, 
							      \@tfc,
							      TIME_UPDATE => $changed);   
		}

		# Remove source status on links we manage.
		&dbexec($dbh, qq{
		    delete from t_xfer_source xs where xs.from_node = :me $filter},
		    ":me" => $$self{NODES_ID}{$node}, %filter_args);

		# Mark current set of managed links as live.
		&dbexec ($dbh, qq{
		    insert into t_xfer_source (from_node, to_node, protocols, time_update)
		    select xs.from_node, xs.to_node, :protocols, :now from t_adm_link xs
		    where xs.from_node = :me $filter},
		    ":me" => $$self{NODES_ID}{$node},
		    ":protocols" => "@{$$self{PROTOCOLS}}",
		    ":now" => &mytimeofday(),
		    %filter_args) if $valid;
	    }

	    $dbh->commit();
	}

	if ($changed && $valid)
	{
	    $self->Logmsg ("trivial file catalogue rules published");
	}
	elsif ($changed && !$valid)
	{
	    $self->Logmsg ("trivial file catalogue rules removed");
	}
	elsif ($liveness)
	{
	    $self->Logmsg ("refreshed export liveness (no local changes to publish)");
	}
    };

    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;
    
    # Disconnect from the database
    $self->disconnectAgent(1) if $dbh;
}

1;
