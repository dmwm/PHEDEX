package UtilsTR; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(usage readPatterns expandPatterns expandAssignments
	         assignmentData assignmentInfo assignmentFileCategory
	         assignmentDrops listDatasetOwners listAssignments
	         castorCheck checkAssignmentFiles feedDropsToAgents);
use TextGlob 'glob_to_regex';
use UtilsWriters;
use UtilsReaders;
use UtilsCommand;
use UtilsNet;

sub usage
{
    print STDERR @_;
    open (ME, "< $0")
        && print(STDERR map { s/^\#\#H ?//; $_ } grep (/^\#\#H/, <ME>))
	&& close(ME);
    exit(1);
}

# Read the pattern files.  Reads each file, splits it at white
# space, and returns the list of all patterns in all the files.
sub readPatterns
{
    my (@files) = @_;
    my @patterns = ();
    foreach my $file (@files)
    {
	if ($file =~ /^\@(.*)/) {
	    open (FILE, "< $1") or die "$1: cannot read\n";
	    push(@patterns, map { chomp; split(/\s+/, $_); } <FILE>);
	    close (FILE);
	} else {
	    push(@patterns, $file);
	}
    }

    return @patterns;
}

# Expand patterns according to the operating mode.  Returns the
# list of all dataset.owner pairs that match the mode and the
# input patterns.
sub expandPatterns 
{
    my ($mode, @patterns) = @_;

    # If "-a" option, the patterns are really assignment numbers
    return @patterns if $mode eq 'a';

    # If "-f" or "-p" option, the patterns are dataset.owners.
    # For "-p", expand to the matching pairs.  For "-f", expand
    # the resulting list by navigating backwards using assignment
    # InputOwnerName in the DST/Digi/Hits chain.
    @patterns = &listDatasetOwners (@patterns);
    return @patterns if $mode eq 'p';

    # FIXME: get assignment info, and walk to InputOwnerName
    return @patterns;
}

# Expand patterns to assignment ids
sub expandAssignments
{
    my @patterns = @_;
    my @assignments = ();
    foreach my $item (@patterns)
    {
	if ($item =~ /^\d+$/) {
	    push (@assignments, $item);
	} else {
	    push (@assignments, &listAssignments (@$item));
	}
    }

    return @assignments;
}

# Get assignment data from RefDB: the result xml catalogues for each run
sub assignmentData
{
    my ($assid) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			."data/GetAttachInfo.php?AssignmentID=${assid}");
    die "$assid: no assignment data\n" if ! $data;
    die "$assid: bad assignment data\n" if $data =~ /GetAttachInfo/;

    my $result = { DATA => $data };
    return $result;
}

# Get assignment information from RefDB.
sub assignmentInfo
{
    my ($assid) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			."data/Info.php?AssignmentID=${assid}&display=1");
    die "$assid: no info\n" if ! $data;

    my $result = { DATA => $data };
    foreach (split(/\n/, $data)) {
	$result->{$1} = $2 if (/^(\S+)=(.*)/);
    }

    # Dataset = DatasetName
    # owner = OutputOwnerName
    # step = ProdStepType
    # cycle = ProductionCycle
    return $result;
}

# Determine the assignment file category.  This is the subdirectory into
# which the files from the assignment will be uploaded to.
sub assignmentFileCategory
{
    my ($ainfo) = @_;
    if ($ainfo->{ProdStepType} eq 'OSCAR') {
	return "Hit";
    } elsif ($ainfo->{ProdStepType} eq 'Digi' && $ainfo->{ProductionCycle} =~ /^DST/) {
	return $ainfo->{ProductionCycle} =~ /(.*)_\d+$/ ? $1 : $ainfo->{ProductionCycle};
    } elsif ($ainfo->{ProdStepType} eq 'Digi' || $ainfo->{ProdStepType} eq 'Hit') {
	return $ainfo->{ProdStepType};
    } else {
	return undef;
    }
}

# Generate XML fragments and summary information for every run of the
# assignment.  Returns a hash with members XML and SMRY in each.
sub assignmentDrops
{
    my ($assid, $adata, $ainfo, $subdir, $basedir) = @_;
    $adata ||= &assignmentData ($assid);
    $ainfo ||= &assignmentInfo ($assid);
    $subdir ||= &assignmentFileCategory ($ainfo);
    $basedir ||= "/castor/cern.ch/cms/PCP04";
    die "$assid: cannot determine file category\n" if ! $subdir;

    # Expand XML fragments and summary info
    my $result = {};
    my ($junk, @rows) = split(/\n/, $adata->{DATA});
    foreach my $row (@rows)
    {
	my ($run, $junk1, $xmlfrag, @rest) = split(/\s+/, $row);
	my $dropid = "$ainfo->{DatasetName}.$ainfo->{OutputOwnerName}"
		     . ".$assid-$ainfo->{ProdStepType}-$ainfo->{ProductionCycle}"
		     . ".$run";
	do { warn "$dropid: empty xml fragment\n"; next } if ($xmlfrag eq '0');
	open (XMLEXP, "echo '$xmlfrag' | mimencode -u | gzip -dc |")
	    or die "$dropid: cannot expand xml fragment\n";
	my $xml = join("", grep(!/^\d+a$/ && !/^\.$/, <XMLEXP>));
	close (XMLEXP) or die "$dropid: cannot expand xml fragment\n";

	$result->{$dropid} = {
	    XML => &genXMLPreamble() . $xml . &genXMLTrailer(),
	    SMRY => "EVDS_OutputPath=$basedir/$subdir/$ainfo->{DatasetName}\n"
	};
    }

    return $result;
}

# Query RefDB for a list of dataset/owner pairs that match the
# given glob patterns.
sub listDatasetOwners
{
    my (@patterns) = @_;

    # Make an array of perl regexps
    @patterns = map { glob_to_regex($_) } @patterns;

    # Get list from the production web page
    my $everything = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			      ."SQL/dataset-discovery.php?DSPattern=%25&"
			      ."OwPattern=%25&ProducedOn=&scriptstep=1");
    die "cannot list dataset/owner pairs\n" if ! $everything;

    # Parse and pick matching ones into result
    my ($ds, $owner);
    my @result = ();
    foreach (split(/\n/, $everything))
    {
        if (/INPUT.*SelDataset.*value=["'\''](.*)["'\'']>/) {
	    $ds = $1;
	} elsif (/OPTION.*value=["'\''](.*)\(\d+\)["'\'']/) {
	    $owner = $1;
	    push (@result, [ $ds, $owner ]) if grep ("$ds.$owner" =~ /$_/, @patterns);
	}
    }

    return @result;
}

# Generate a list of assignments for a particular dataset.owner pair
sub listAssignments
{
    my ($ds, $owner) = @_;
    my $everything = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			      ."SQL/DsOwnToAs.php?DatasetName=$ds&"
			      ."OutputOwner=$owner&scriptstep=1");
    die "no assignments for $ds, $owner\n" if ! $everything;
    return map { s/.*<TD>//; ($_ =~ /(\d+)/g) }
	   grep(/Assignments.*<TD>/, split(/\n/, $everything));
}

# Efficiently check which files exist in castor
sub castorCheck
{
    my ($known, @files) = @_;

    # Determine all directories we need to look in
    my %dirs = ();
    foreach my $file (@files)
    {
	$file =~ s|/[^/]+$||;
	$dirs{$file} = 1;
    }
	
    # List the contents of all the directories
    foreach my $dir (sort keys %dirs)
    {
	open (NSLS, "nsls $dir |") or die "cannot run nsls: $!\n";
	while (<NSLS>)
	{
	    chomp;
	    $known->{"$dir/$_"} = 1;
	}
	close (NSLS);
    }
}

# /drop/box/area should be the directory containing the state
# directories for the drop box agents, so the script can check
# which drops are still being processed ("pending")
#
# database should be the name of the tmdb oracle database, and
# table should be the name of the file table (filesfortransfer
# for v1, t_files_for_transfer for v2).
#
# The rest of the arguments are expected to be "drop" directories.
# This tool reads the XML catalogue fragments from the drops, gets
# the list of the GUIDs, and compares both with the tmdb database
# and the drop box area to evaluate the status of the drop.
#
# For each drop, a line is printed out with the name of the drop,
# the number of files found in the catalogue, the number of guids
# already registered in tmdb, and two flags, "TRANSFERRED" and/or
# "PENDING".  The former indicates that all the files were found
# in tmdb, the second indicates there is still a drop in the disk
# queues.
sub checkAssignmentFiles
{
    my ($mouth, $tmdb, $table, @dirs) = @_;
    my @pending = map { s|.*/||; $_ }
	<$mouth/*/{work,inbox}/*>
	<$mouth/*/worker-*/{work,inbox}/*>;

    # Collect information for all drops first.
    my $result = {};
    foreach my $drop (@dirs)
    {
        # Evaluate drop data
        my $xml = (<$drop/XMLCatFragment.*.{txt,xml}>)[0];
        my $smry = (<$drop/Smry.*.txt>)[0];
        my $pfnroot = (map { split('=', $_) } grep(/^EVDS_OutputPath=/, split(/\n/, &input($smry))))[1];
        defined $xml or die "no xml catalogue in $drop\n";
        defined $smry or die "no summary file in $drop\n";
        defined $pfnroot or die "no pfn root in $drop\n";

        # Get guids and pfns
        my $cat = &readXMLCatalog ($xml);
        my @guids = map { $_->{GUID} } values %$cat;
        my @pfns = map { @{$_->{PFN}} } values %$cat;
        @pfns = map { s|^\./|$pfnroot/|; $_; } @pfns;
        @pfns = map { s|^sfn://castorgrid.cern.ch/|/|; $_; } @pfns;

        # Initialise results
        my $dropname = $drop; $dropname =~ s|.*/||;
	$result->{$drop} = {
	    DROPNAME => $dropname,
	    GUIDS => [ @guids ],
	    PFNS => [ @pfns ]
	};
    }

    # Check all known pfns in the directories involved
    my %knownpfn;
    &castorCheck (\%knownpfn, map { @{$_->{PFNS}} } values %$result);

    # Get all known guids (this *is* faster than asking for each guid)
    my %knownguid;
    eval "use DBI"; die $@ if $@; # Allow rest to be used without DBI
    my $dbh = DBI->connect ("DBI:Oracle:$tmdb", "cms_transfermgmt_reader",
			    "slightlyJaundiced", { RaiseError => 1, AutoCommit => 1 });
    my $stmt = $dbh->prepare ("select guid from $table");
    $stmt->execute();
    while (my @row = $stmt->fetchrow_array()) {
	$knownguid{$row[0]} = 1;
    }
    undef $dbh;

    # Now finish off the results
    foreach my $drop (@dirs)
    {
	my @guids = @{$result->{$drop}{GUIDS}};
	my @pfns = @{$result->{$drop}{PFNS}};

        # Find guids/files known in tmdb and castor
        my $indb = grep ($knownguid{$_}, @guids);
	my $inmss = scalar (grep ($knownpfn{$_}, @pfns));

	# Fill in result
	my $nguids = scalar @guids;
	my $npending = scalar (grep ($_ eq $result->{$drop}{DROPNAME}, @pending));

	$result->{$drop}{N_FILES}		= $nguids;
	$result->{$drop}{N_TRANSFERRED}		= $indb;
	$result->{$drop}{N_IN_MSS}		= $inmss;
	$result->{$drop}{N_PENDING_TRANSFER}	= $npending;
	$result->{$drop}{IS_PENDING_TRANSFER}	= $npending != 0;
	$result->{$drop}{IS_FULLY_TRANSFERRED}	= $nguids == $indb;
	$result->{$drop}{IS_FULLY_IN_MSS}	= $nguids == $inmss;
    }

    return $result;
}

sub feedDropsToAgents
{
    my ($mouth, $request, $doit, $droptype, $status, @drops) = @_;
    foreach my $drop (@drops)
    {
	my $info = $status->{$drop};
	die "Error: no status for $drop\n" if ! defined $info;

	my $dropname = $info->{DROPNAME};
	my $type = $droptype;

	# If we find multiple copies, remove replicas and pretend
	# it's one we found elsewhere (= preferred version).
	if ($type ne 'Done' && -d "$request/Drops/Done/$dropname")
	{
	    print "$type $drop already in Done, removing\n";
	    (! $doit || &rmtree ($drop));
	    $type = 'Done';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
        }
	elsif ($type ne 'NotReady' && -d "$request/Drops/NotReady/$dropname")
	{
	    print "$type $drop already in NotReady, removing\n";
	    (! $doit || &rmtree ($drop));
	    $type = 'NotReady';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
    	}

	# Check if it it's done (and make sure done are still done!)
	if ($type ne 'Done' && $info->{IS_FULLY_TRANSFERRED})
	{
	    print "$type $drop already transferred, marking Done\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname") == 0)
	        or die "Error: $drop: cannot move to Done: $?\n";
	    $type = 'Done';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
	}
	elsif ($type ne 'Done' && $info->{IS_PENDING_TRANSFER})
	{
	    print "$type $drop already queued, marking Done\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname") == 0)
	        or die "Error: $drop: cannot move to Done: $?\n";
	    $type = 'Done';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
	}
	elsif ($type eq 'Done'
	       && ! ($info->{IS_FULLY_TRANSFERRED}
		     || $info->{IS_PENDING_TRANSFER}))
	{
	    print "$type $drop no longer done, marking Pending again\n";
	    (! $doit || system ("mv $drop $request/Drops/Pending/$dropname") == 0)
		or die "Error: $drop: cannot move to Pending: $?\n";
	    $type = 'Pending';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
	}

	# Process truly pending drops
	if ($type ne 'Done' && $info->{IS_FULLY_IN_MSS})
	{
	    print "$type $drop available, feeding to agents and marking Done\n";
	    (-f "$drop/go" || ! $doit || system ("touch $drop/go") == 0)
		or die "Error: $drop: cannot touch go: $?\n";
	    (! $doit || system ("cp -rp $drop $mouth/entry/inbox/$dropname") == 0)
		or die "Error: $drop: cannot copy to $mouth/entry/inbox: $?\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname") == 0)
	    	or die "Error: $drop: cannot move to Done: $?\n";
	    $type = 'Done';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
	}
	elsif ($type ne 'NotReady' && ! $info->{IS_FULLY_IN_MSS})
	{
	    print "$type $drop not yet available, marking NotReady\n";
	    (! $doit || unlink ("$drop/go"));
	    (! $doit || system ("mv $drop $request/Drops/NotReady/$dropname") == 0)
	    	or die "Error: $drop: cannot move to NotReady: $?\n";
	    $type = 'NotReady';
	    $drop = "$request/Drops/$type/$dropname";
	    $status->{$drop} = $info;
	}
    }
}

1;
