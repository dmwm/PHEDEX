package PHEDEX::Core::Catalogue;

=head1 NAME

PHEDEX::Core::Catalogue

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(pfnLookup lfnLookup storageRules dbStorageRules applyStorageRules makeTransferTask);
use XML::Parser;
use PHEDEX::Core::DB;
use PHEDEX::Core::Timing;
use PHEDEX::Core::SQL;

# Cache of already parsed storage rules.  Keyed by rule type, then by
# file name, and stores as value the file time stamp and parsed result.
my %cache;

# Calculate source and destination PFNs for a transfer task.
sub makeTransferTask
{
    my ($self, $task, $cats) = @_;
    my ($from, $to) = @$task{"FROM_NODE_ID", "TO_NODE_ID"};
    my (@from_protos,@to_protos);

#   This twisted logic lets me call this function with an object or a plain
#   DBH handle.
    my $dbh = $self;
    if ( grep( $_ eq 'DBH',  keys %{$self} ) ) { $dbh = $self->{DBH}; }

    if ( ref($task->{FROM_PROTOS}) eq 'ARRAY' )
         { @from_protos = @{$task->{FROM_PROTOS}}; }
    else { @from_protos = split(/\s+/, $$task{FROM_PROTOS} || ''); }
    if ( ref($task->{TO_PROTOS}) eq 'ARRAY' )
         { @to_protos = @{$task->{TO_PROTOS}}; }
    else { @to_protos = split(/\s+/, $$task{TO_PROTOS} || ''); }

    my ($from_name, $to_name, $node_map);
    $node_map = PHEDEX::Core::SQL::getNodeMap($self,$from,$to);
    $from_name = $node_map->{$from};
    $to_name = $node_map->{$to};

    my ($from_cat, $to_cat);
    $from_cat    = &dbStorageRules($dbh, $cats, $from);
    $to_cat      = &dbStorageRules($dbh, $cats, $to);

    my $protocol    = undef;

    # Find matching protocol.
    foreach my $p (@to_protos)
    {
        next if ! grep($_ eq $p, @from_protos);
        $protocol = $p;
        last;
    }

#   This has been moved up to the FileIssue agent
#    # If this is MSS->Buffer transition, pretend we have a protocol.
#    $protocol = 'srm' if ! $protocol && $$task{FROM_KIND} eq 'MSS';

    # Check that we have prerequisite information to expand the file names
    die "no catalog for from=$from_name\n" unless $from_cat;
    die "no catalog for to=$to_name\n" unless $to_cat;
    die "no protocol match for link ${from_name}->${to_name}\n" unless $protocol;
    die "no TFC rules for matching protocol '$protocol' for from=$from_name\n" unless $$from_cat{$protocol};
    die "no TFC rules for matching protocol '$protocol' for to=$to_name\n" unless $$to_cat{$protocol};

    # If we made it through the above, we should be ok
    # Expand the file name. Follow destination-match instead of remote-match
   my ($from_token,$from_pfn,$to_token,$to_pfn);
   ($from_token,$from_pfn) = &applyStorageRules
				(
				  $from_cat,
				  $protocol,
				  $to_name,
				  'pre',
				  $task->{LOGICAL_NAME},
				  $task->{IS_CUSTODIAL}
				);
   ($to_token,$to_pfn) = &applyStorageRules
				(
				  $to_cat,
				  $protocol,
				  $to_name,
			 	  'pre',
			 	  $task->{LOGICAL_NAME},
			 	  $task->{IS_CUSTODIAL}
				);
  return {
	   FROM_PFN	=> $from_pfn,
	   FROM_NODE	=> $from_name,
	   FROM_TOKEN	=> $from_token,
	   TO_PFN	=> $to_pfn,
	   TO_NODE	=> $to_name,
	   TO_TOKEN	=> $to_token,
	 };
}

# Map a LFN to a PFN using a storage mapping catalogue.  The first
# argument is either a single scalar LFN, or a reference to an array
# of LFNs.  The second and third arguments are desired protocol and
# destination node making query ("direct", "local" meaning direct
# access from the system agent is running on.  The last argument is
# the location of the storage catalogue.
#
# If given a single LFN, returns a single PFN, or undef if the name
# cannot be mapped.  If given an array of LFNs, returns a hash of
# LFN => PFN mappings; the hash will have an entry for every LFN,
# but the value will be undef if no PFN could be constructed.
sub pfnLookup
{
    my ($input, $proto, $dest, $mapping, $custodial) = @_;
    my @args = (&storageRules ($mapping, 'lfn-to-pfn'), $proto, $dest, 'pre');
    if (ref $input)
    {
	return { map { $_ => [&applyStorageRules(@args, $_, $custodial)] } @$input };
    }
    else
    {
	return &applyStorageRules(@args, $input, $custodial);
    }
}

# Map a PFN to a LFN using a storage mapping catalogue.  This is like
# pfnLookup, but simply works the other way around.
sub lfnLookup
{
    my ($input, $proto, $dest, $mapping, $custodial) = @_;
    my @args = (&storageRules ($mapping, 'pfn-to-lfn'), $proto, $dest, 'post');
    if (ref $input)
    {
	return { map { $_ => [&applyStorageRules(@args, $_, $custodial)] } @$input };
    }
    else
    {
	return &applyStorageRules(@args, $input, $custodial);
    }
}

# Read in rules for storage mappings.  Returns a reference to a hash
# by protocol, each of which points to an array of rules of $kind in
# the order in which they appeared in the <storage-mapping>.
#
# The storage rules are expected to be of the form:
#   all::   <storage-mapping> rule+ </storage-mapping>
#   rule::  <lfn-to-pfn args> | <pfn-to-lfn args>
#   args::  protocol="..." [destination-match="..."] [chain="..."]
#           path-match="..." result="..."
#
# More than one rule may be specified; the first applicable one wins.
# The value for the "protocol" argument is required and is compared
# literally to the protocol given by the client.  The "destination-
# match" argument is, if given, used as a perl regular expression to
# match the client's destination argument.  If the "chain" argument
# is present, it designates another protocol whose rules are applied
# to the file name on input (lfn-to-pfn) or ouput (pfn-to-lfn) of
# the current rule.
# 
# If the protocol and destination match, the file name is matched
# against the perl regular expression "path-match".   If matched,
# the name is transformed according to "result", following the
# conventions of the perl s/// operator.  Once the path has been
# matched rule processing ends.
#
# Example:
#   <storage-mapping>
#     <lfn-to-pfn protocol="direct"
#       path-match="/+(.*)" result="/castor/cern.ch/cms/$1"/>
#     <lfn-to-pfn protocol="srm" chain="direct"
#       path-match="(.*)" result="srm://srm.cern.ch/srm/managerv1?SFN=$1"/>
#
#     <pfn-to-lfn protocol="direct"
#       path-match="/+castor/cern\.ch/cms/(.*)" result="/$1"/>
#     <pfn-to-lfn protocol="srm" chain="direct"
#       path-match=".*\?SFN=(.*)" result="$1"/>
#   </storage-mapping>
#
# This would map LFN=/foo PROTO=srm DEST=(any) to
#   srm://srm.cern.ch/srm/managerv1?SFN=/castor/cern.ch/cms/foo.
sub storageRules
{
    my ($file, $kind) = @_;

    # Check if we have a valid cached result
    if (exists $cache{$kind}{$file})
    {
	my $modtime = (stat($file))[9];
	return $cache{$kind}{$file}{RULES}
	    if $cache{$kind}{$file}{MODTIME} == $modtime;
    }

    # Parse the catalogue and remove top-level white space
    my $tree = (new XML::Parser (Style => "Tree"))->parsefile ($file);
    splice (@$tree, 0, 2) while ($$tree[0] eq "0" && $$tree[1] =~ /^\s*$/s);
    splice (@$tree, -2) while ($$tree[scalar @$tree- 2] eq "0"
				&& $$tree[scalar @$tree- 1] =~ /^\s*$/s);

    # Verify we understand the storage catalogue structure
    die "$file: expected one top-level element\n" if scalar @$tree != 2;
    die "$file: expected storage-mapping element\n" if $$tree[0] ne 'storage-mapping';

    # Collect the rules we wanted
    my ($attrs, @rules) = @{$$tree[1]};
    my $result = {};
    while (@rules)
    {
	my ($element, $value) = splice(@rules, 0, 2);
	next if $element ne $kind;
	# $$value[0]{'path-match'} = do { my $z = $$value[0]{'path-match'}; qr/$z/ };
	# $$value[0]{'result'} = do { my $z = $$value[0]{'result'}; eval "sub { \$_[0] =~ s!\$_[1]!$z! }" };
	push (@{$$result{$$value[0]{protocol}}}, $$value[0]);
    }

    # Cache the result
    $cache{$kind}{$file} = { MODTIME => (stat($file))[9], RULES => $result };

    # Return to the caller
    return $result;
}

# Apply storage mapping rules to a file name.  See "storageRules" for details.
#
# new optional parameters: $custodial and $space_token
#
# if $custodial is not defined, it is assumed to be 'n'.
# if "is-custodial" is not defined in the rule, it is assumed to be 'n'.
# $custodial has to match "is-custodial"
#
# if the end result of applying current rule produces a defined
# space-toke, return it; otherwise, return the value passed-in
# through the argument $space_token
#
# applyStorageRules() returns ($space_token, $name)
sub applyStorageRules
{
    my ($rules, $proto, $dest, $chain, $givenname, $custodial, $space_token) = @_;

    # Bail out if $givenname is undef
    if (! defined ($givenname))
    {
        return undef;
    }

    # if omitted, $custodial is default to "n"
    if (! defined ($custodial))
    {
        $custodial = "n";
    }

    foreach my $rule (@{$$rules{$proto}})
    {
	my $name = $givenname;

	# take care of custodial flag
        #
        # if is-custodial is undefined, it matches any $custodial value
        # if is-custodial is defined, it has to match $custodial
        next if ($$rule{'is-custodial'} && ($$rule{'is-custodial'} ne $custodial));

	next if (defined $$rule{'destination-match'}
		 && $dest !~ m!$$rule{'destination-match'}!);
	if (exists $$rule{'chain'} && $chain eq 'pre') {
	    ($space_token, $name) = &applyStorageRules($rules, $$rule{'chain'}, $dest, $chain, $name, $custodial, $space_token);
	}

        # It's a failure if the name is undef
        next if (!defined ($name));

	if ($name =~ m!$$rule{'path-match'}!)
	{
	    if (ref $$rule{'result'} eq 'CODE')
	    {
		&{$$rule{'result'}} ($name, $$rule{'path-match'});
	    }
	    else
	    {
		eval "\$name =~ s!\$\$rule{'path-match'}!$$rule{'result'}!";
	    }
            if ($$rule{'space-token'})
            {
                $space_token = $$rule{'space-token'};
            }
	    ($space_token, $name) = &applyStorageRules($rules, $$rule{'chain'}, $dest, $chain, $name, $custodial, $space_token)
		if (exists $$rule{'chain'} && $chain eq 'post');
	    return ($space_token, $name);
	}
	
    }

    return undef;
}


# Fetch TFC rules for the given node and cache it to the given
# hashref.  Database is checked for newer rules and an update will be
# done if newer rules are found
sub dbStorageRules
{
    my ($dbh, $cats, $node) = @_;

    # check if cached rules are old
    my $changed = 0;
    if (exists $$cats{$node}) {
	$changed = &checkDBCatalogueChange($dbh, $node, $$cats{$node}{TIME_UPDATE});
    }
    
    # If we haven't yet built the catalogue, fetch from the database.
    if (! exists $$cats{$node} || $changed)
    {
        $$cats{$node} = {};

        my $q = &dbexec($dbh, qq{
	    select protocol, chain, destination_match, path_match, result_expr, is_custodial, space_token, time_update
	    from t_xfer_catalogue
	    where node = :node and rule_type = 'lfn-to-pfn'
	    order by rule_index asc},
	    ":node" => $node);

        while (my ($proto, $chain, $dest, $path, $result, $custodial, $space_token, $time_update) = $q->fetchrow())
        {
	    # Check the pattern is valid.  If not, abort.
            my $pathrx = eval { qr/$path/ };
	    if ($@) {
		$$cats{$node} = {};
		die "invalid path pattern for node=$node:  $@\n";
	    }

            my $destrx = defined $dest ? eval { qr/$dest/ } : undef;
	    if ($@) {
		$$cats{$node} = {};
		die "invalid dest pattern for node=$node:  $@\n";
	    }

	    # Add the rule to our list.
	    $$cats{$node}{TIME_UPDATE} = $time_update;
	    push(@{$$cats{$node}{$proto}}, {
		    (defined $chain ? ('chain' => $chain) : ()),
		    (defined $dest ? ('destination-match' => $destrx) : ()),
                    (defined $custodial ? ('is-custodial' => $custodial) : ()),
                    (defined $space_token ? ('space-token' => $space_token) : ()),
		    'path-match' => $pathrx,
		    'result' => eval "sub { \$_[0] =~ s!\$_[1]!$result! }" });
        }
    }

    return $$cats{$node};
}

# delete a catalogue from the database for $node_id
sub deleteCatalogue
{
    my ($dbh, $node_id) = @_;
    &dbexec($dbh, qq{
	delete from t_xfer_catalogue where node = :node},
	    ":node" => $node_id);
}

# insert an array of storage rules ($tfc) for a node ($node_id) into the database
sub insertCatalogue
{
    my ($dbh, $node_id, $tfc, %h) = @_;
    $h{TIME_UPDATE} ||= &mytimeofday(); # default time is now
    
    # Statement to upload rules.
    my $stmt = &dbprep ($dbh, qq{
	insert into t_xfer_catalogue
	(node, rule_index, rule_type, protocol, chain,
	 destination_match, path_match, result_expr,
	 is_custodial, space_token, time_update)
	values (:node, :rule_index, :rule_type, :protocol, :chain,
	        :destination_match, :path_match, :result_expr,
		:is_custodial, :space_token, :time_update)});

    my $index = 0;
    foreach my $rule (@$tfc)
    {
	&dbbindexec($stmt,
		    ":node" => $node_id,
		    ":rule_index" => $index++,
		    ":rule_type" => $rule->{RULE_TYPE},
		    ":protocol" => $rule->{PROTOCOL},
		    ":chain" => $rule->{CHAIN},
		    ":destination_match" => $rule->{DESTINATION_MATCH},
		    ":path_match" => $rule->{PATH_MATCH},
		    ":result_expr" => $rule->{RESULT_EXPR},
		    ":is_custodial" => $rule->{IS_CUSTODIAL},
		    ":space_token" => $rule->{SPACE_TOKEN},
		    ":time_update" => $h{TIME_UPDATE});
    }

    return $index;
}

sub checkDBCatalogueChange
{
    my ($dbh, $node_id, $check_time) = @_;
    $check_time ||= &mytimeofday();
    my ($newrules) = &dbexec($dbh, qq{ 
	select 1 from t_xfer_catalogue
	 where node = :node and time_update > :check_time
	   and rownum = 1 },
        ':node' => $node_id, ':check_time' => $check_time)->fetchrow();
    return $newrules ? 1 : 0;
}

1;
