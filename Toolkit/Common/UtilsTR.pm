package UtilsTR; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(usage readPatterns expandPatterns
	         assignmentData assignmentInfo assignmentFileCategory
	         expandXMLFragment listDatasetOwners listAssignments
		 listDatasetHistory);
use TextGlob 'glob_to_regex';
use UtilsWriters;
use UtilsReaders;
use UtilsCommand;
use UtilsNet;
use MIME::Base64;
use Compress::Zlib;

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

    # If "-f" or "-p" option, the patterns are owner/dataset.
    # For "-p", expand to the matching pairs.  For "-f", expand
    # the resulting list by navigating backwards using assignment
    # InputOwnerName in the DST/Digi/Hits chain.
    my @info = &listDatasetOwners (@patterns);
    return @info if $mode eq 'p';

    # Walk dataset history
    my @pats = @info;
    foreach my $pat (@info) {
	foreach my $prev (&listDatasetHistory ($pat)) {
	    push (@pats, $prev) if ! grep ($_->{OWNER} eq $prev->{OWNER}
					   && $_->{DATASET} eq $prev->{DATASET},
					   @pats);
	}
    }

    return @pats;
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

# Utility subroutine to expand a run XML fragment and to clean it up.
sub expandXMLFragment
{
    my ($context, $xmlfrag) = @_;
    my $xml = Compress::Zlib::memGunzip (decode_base64 ($xmlfrag));
    return join("\n", grep(!/^\d+a$/ && !/^\.$/, split(/\n/, $xml)));
}

# Query RefDB for a list of dataset/owner pairs that match the
# given glob patterns.
sub listDatasetOwners
{
    my (@patterns) = @_;
    my @result;

    # Make an array of perl regexps
    @patterns = map { glob_to_regex($_) } @patterns;

    # Get list from the production web page
    foreach (split(/\n/, &getURL ("http://cmsdoc.cern.ch/cms/production/www/ZipDB/"
			          ."ListProductionZipAndPublicationSites.php?"
				  ."rc=&owner=%&dataset=%&bycoll=&ascii=1&unAssigned=")))
    {
	next if /^Dataset:Owner:/;
	my ($dataset, $owner, $id, $zipsites, $prodsites, $pubsites) = split(/:/);
	my @published = grep($_ ne '', split(/;/, $pubsites));
	push (@result, {
		COLLECTION => $id,
		TYPE => undef,
		DATASET => $dataset,
		OWNER => $owner,
		SUBCOLLECTION => $dataset,
		SITES => { map { $_ => 1 } @published } })
	    if (! @patterns || grep ("$owner/$dataset" =~ /$_/, @patterns));
    }

    return @result;
}

# Generate a list of additional datasets required by this one.
sub listDatasetHistory
{
    my ($dso) = @_;
    my @result;

    foreach (split(/\n/, &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			    	  ."SQL/CollectionTreeAndPU.php?"
				  ."dataset=$dso->{DATASET}&owner=$dso->{OWNER}")))
    {
	if (/ID=(\d+), Name=(\S+), Type=(\S+), Owner=(\S+), Dataset=(\S+)$/)
	{
	    # Type = DST/Digi/Hit/PU
	    next if ($3 eq 'InitHit' || $3 eq 'InitDigi');
	    push (@result, {
		COLLECTION => $1,
		TYPE => $3,
		DATASET => $5,
		OWNER => $4,
		SUBCOLLECTION => $2 })
		if ! ($5 eq $dso->{DATASET} && $4 eq $dso->{OWNER});
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

1;
