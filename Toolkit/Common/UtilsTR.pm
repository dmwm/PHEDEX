use TextGlob 'glob_to_regex';
use UtilsWriters;
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

sub checkAssignmentFiles {}
sub checkDrops {}

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
