use TextGlob 'glob_to_regex';
use UtilsWriters;
use UtilsReaders;
use UtilsNet;

# Ugly hacks, readXMLCatalog does markBad!
use UtilsCommand;
use UtilsLogging;
sub markBad {}

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
    my @all = ();
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
    my @pending = map { s|.*/||; $_ } <$mouth/*/{work,inbox}/*>;

    eval "use DBI"; die $@ if $@; # Allow rest to be used without DBI
    my $dbh = DBI->connect ("DBI:Oracle:$tmdb", "cms_transfermgmt_reader",
			    "slightlyJaundiced", { RaiseError => 1, AutoCommit => 1 });

    # Check all drops to see which files already exist in TMDB
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
        my $cat = &readXMLCatalog ($drop, $xml);
        my @guids = map { $_->{GUID} } values %$cat;
        my @pfns = map { @{$_->{PFN}} } values %$cat;
        @pfns = map { s|^\./|$pfnroot/|; $_; } @pfns;
        @pfns = map { s|^gsiftp://castorgrid.cern.ch/|/|; $_; } @pfns;

        # Find guids known in tmdb
        my $indb = 0;
        my $sql = "select count(guid) from $table where "
	         . join (' or ', map { "guid='$_'" } @guids);
        map { $indb += $_->[0] } $dbh->selectrow_arrayref ($sql);

        # Find out which files are in castor
        my $inmss = scalar (grep (system("rfstat $_ >/dev/null 2>&1") == 0, @pfns));

        # Add results
        my $dropname = $drop; $dropname =~ s|.*/||;
	my $nguids = scalar @guids;
	my $npending = scalar (grep ($_ eq $dropname, @pending));
	$result->{$drop} = {
	    DROPNAME => $dropname,
	    N_FILES => $nguids,
	    N_TRANSFERRED => $indb,
	    N_IN_MSS => $inmss,
	    N_PENDING_TRANSFER => $npending,
	    IS_PENDING_TRANSFER => $npending != 0,
	    IS_FULLY_TRANSFERRED => $nguids == $indb,
	    IS_FULLY_IN_MSS => $nguids == $inmss
	};
    }

    return $result;
}

sub feedDropsToAgents
{
    my ($mouth, $request, $doit, $type, $status, @drops) = @_;
    foreach my $drop (@drops)
    {
	my $info = $status->{$drop};
	die "Error: no status for $drop\n" if ! defined $info;

	my $dropname = $info->{DROPNAME};

	# If we find multiple copies, remove replicas and pretend
	# it's one we found elsewhere (= preferred version).
	if ($type ne 'Done' && -d "$request/Drops/Done/$dropname")
	{
	    print "$type $drop already in Done, removing\n";
	    (! $doit || &rmtree ($drop));
	    $type = 'Done';
	    $drop = "$request/Drops/Done/$dropname";
        }
	elsif ($type ne 'NotReady' && -d "$request/Drops/NotReady/$dropname")
	{
	    print "$type $drop already in NotReady, removing\n";
	    (! $doit || &rmtree ($drop));
	    $type = 'NotReady';
	    $drop = "$request/Drops/NotReady/$dropname";
    	}

	# Check if it it's done (and make sure done are still done!)
	if ($type ne 'Done' && $info->{IS_FULLY_TRANSFERRED})
	{
	    print "$type $drop already transferred, marking Done\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname"))
	        or die "Error: $drop: cannot move to Done: $!\n";
	}
	elsif ($type ne 'Done' && $info->{IS_PENDING_TRANSFER})
	{
	    print "$type $drop already queued, marking Done\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname"))
	        or die "Error: $drop: cannot move to Done: $!\n";
	}
	elsif ($type eq 'Done')
	{
	    print "$type $drop no longer done, marking Pending again\n";
	    (! $doit || system ("mv $drop $request/Drops/Pending/$dropname"))
		or die "Error: $drop: cannot move to Pending: $!\n";
	    $type = 'Pending';
	    $drop = "$request/Drops/Pending/$dropname";
	}

	# Process truly pending drops
	if ($info->{IS_FULLY_IN_MSS})
	{
	    print "$type $drop available, feeding to agents and marking Done\n";
	    (! $doit || system ("cp -rp $drop $mouth/$dropname"))
		or die "Error: $drop: cannot copy to $mouth: $!\n";
	    (! $doit || system ("mv $drop $request/Drops/Done/$dropname"))
	    	or die "Error: $drop: cannot move to Done: $!\n";
	}
	elsif ($type ne 'NotReady')
	{
	    print "$type $drop not yet available, marking NotReady\n";
	    (! $doit || system ("mv $drop $request/Drops/NotReady/$dropname"))
	    	or die "Error: $drop: cannot move to NotReady: $!\n";
	}
    }
}

1;

__END__
# RefDBCheck
#!/bin/sh

# Home and myself
home=$(dirname $0)
me=$(basename $0)

# Process options
while [ $# -gt 0 ]; do
  case $1 in
    -* ) echo "unrecognised option $1"; exit 1;;
    *  ) break ;;
  esac
done

# Check all PFNs of all the drops for assignment ($@) to see if they
# already exist in castor in places RefDBDrops thought they would be in
for assignment; do
  assignment=$(echo $assignment | sed 's|^drops-for-||; s|/$||')

  nfiles=0 nexists=0
  for d in drops-for-$assignment/drops/*/; do
    [ -d $d ] || continue
    pfnroot=$(grep EVDS_OutputPath $d/Smry.*.txt | sed 's/.*=//')
    for pfn in $(grep pfn $d/XMLCatFragment.*.xml | sed 's|.*<pfn .*name="\./||; s|"/>.*||'); do
      rfstat $pfnroot/$pfn >/dev/null 2>&1 && nexists=$(expr $nexists + 1)
      nfiles=$(expr $nfiles + 1)
    done
  done

  echo -n "$assignment: $nexists/$nfiles files present in castor"
  if [ $nexists = $nfiles -a $nfiles != 0 ]; then
    echo ": ready for transfer"
    touch drops-for-$assignment/ready
    for d in drops-for-$assignment/drops/*/; do
      touch $d/go
    done
  else
    echo ": not ready for transfer"
  fi
done


# RefDBReady
#!/bin/sh

# Home and myself
home=$(dirname $0)
me=$(basename $0)

# Process options
do_patterns=true do_assignments=false patfile=
while [ $# -gt 0 ]; do
  case $1 in
    -P ) do_patterns=true do_assignments=false patfile=$2; shift; shift;;
    -p ) do_patterns=true do_assignments=false; shift;;
    -a ) do_assignments=true do_patterns=false; shift;;
    -* ) echo "unrecognised option $1"; exit 1;;
    *  ) break ;;
  esac
done

# If we don't have an assignment list, generate it first from given list
# of dataset.owner patterns (default: *.*).  Merge patterns given on the
# command line and those mentioned in the optional pattern file.
$do_patterns &&
  set -- $($home/RefDBAssignments \
	   $($home/RefDBList \
	     $([ -z "$patfile" ] || echo "-P $patfile") \
	     ${1+"$@"}))

# Now check we got a list of assignments; complain only if -P/-p option
# was not used (if the pattern match failed, we already whined about it).
if [ $# -eq 0 -a $do_patterns = false ]; then
  echo "usage: RefDBReady -P DATASET.OWNER-PATTERN-FILE [-p] [dataset.owner-pattern...]"
  echo "  or:             -p [dataset.owner-pattern...]"
  echo "  or:             -a assignment..."
  exit 1
fi

# Process requested assignments
for assignment; do
  $home/RefDBDrops $assignment
done

# Now check which ones are ready for transfer.
# Do this separately from previous step to collect
# output neatly into one place.
for assignment; do
  $home/RefDBCheck $assignment
done
