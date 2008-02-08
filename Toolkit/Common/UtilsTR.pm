package UtilsTR; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(usage readPatterns expandPatterns
	         listDatasetOwners listAssignments
		 listDatasetHistory);
use Text::Glob 'glob_to_regex';
use UtilsWriters;
use UtilsReaders;
use UtilsCommand;
use UtilsNet;

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
			    	  ."SQL/CollectionTreeAndPU.php?cid=$dso->{COLLECTION}")))
    {
	if (/ID=(\d+), Name=(\S+), Type=(\S+), Owner=(\S+), Dataset=(\S+)$/)
	{
	    # Type = DST/Digi/Hit/PU
	    # FIXME: Pick only immediate parents?
	    next if ($1 eq $dso->{COLLECTION});
	    next if ($3 eq 'InitHit' || $3 eq 'InitDigi');
	    push (@result, {
		COLLECTION => $1,
		TYPE => $3,
		DATASET => $5,
		OWNER => $4,
		SUBCOLLECTION => $2 });
	}
    }

    return @result;
}

# Generate a list of assignments for a particular dataset.owner pair
sub listAssignments
{
    my ($dso) = @_;
    my $key = (exists $dso->{COLLECTION} ? "CollectionID=$dso->{COLLECTION}"
	       : "DatasetName=$dso->{DATASET}&OwnerName=$dso->{OWNER}");
    my $everything = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			      ."SQL/DsOwnToAs-txt.php?$key&scriptstep=1&format=txt");
    die "no assignments for @{[split('&', $key)]}\n" if ! $everything;
    return map { (/(\d+)/g) } grep(/^Assignments\s*=/, split(/\n/, $everything));
}

print STDERR "WARNING:  use of Common/UtilsTR.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
