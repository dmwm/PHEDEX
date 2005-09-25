package UtilsTR; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(usage readPatterns expandPatterns
	         assignmentData assignmentInfo assignmentFileCategory
	         expandXMLFragment listDatasetOwners listAssignments);
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
    @patterns = &listDatasetOwners (@patterns);
    return @patterns if $mode eq 'p';

    # Walk dataset history
    my @pats;
    foreach my $pat (@patterns) {
	push (@pats, &listDatasetHistory ($pat));
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
	    push (@result, [ $owner, $ds ]) if grep ("$owner/$ds" =~ /$_/, @patterns);
	}
    }

    return @result;
}

# Generate a list of additional dataset.owner patterns for the history.
sub listDatasetHistory
{
    my ($dso) = @_;
    my ($o, $ds) = @$dso;

    # First get a page that tells us the dataset/owner numbers (ugh)
    my ($dsn, $on) = (undef, undef);
    foreach (split(/\n/, &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
	    			  ."SQL/dataset-discovery.php?ProducedOn=&scriptstep=1&"
				  ."DSPattern=$ds&OwPattern=$o")))
    {
	if (/INPUT.*SelDataset\[(\d+)\]/) {
	    $dsn = $1;
	} elsif (/OPTION.*value=["'\''].*\((\d+)\)["'\'']/) {
	    $on = $1;
        }
    }

    # Now get the history for this pair
    my $found = 0;
    my @result = ();
    foreach (split(/\n/, &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
	    		   	  ."SQL/dataset-discovery.php?DSPattern=$ds&"
			   	  ."OwPattern=$o&SelDataset[$dsn]=$ds&SelOwner[$dsn]=$o($on)&"
			   	  ."OnlyRecent=&ProducedOn=&"
			   	  ."browse=DSHistory&scriptstep=2")))
    {
	if (! $found && /<TD.*>$ds(<|$)/) {
	    $found = 1;
	} elsif ($found && /<TD>(\S+)/) {
	    push (@result, [ $1, $ds ]);
	} elsif ($found && /<TR/) {
	    last;
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
