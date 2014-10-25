package DMWMMON::SpaceMon::FormatFactory;
use strict;
use warnings;
use DMWMMON::SpaceMon::StorageDump;
use Data::Dumper;

sub instantiate 
{
    my $class = shift;
    my %params = @_;
    my $h = \%params;	
    if ($h->{VERBOSE}) {
	print "Supported formats are: ";
	print join "," , values %DMWMMON::SpaceMon::StorageDump::formats;
	print "\n";
    }
    # Validatate input file:
    if ( not defined $h->{DUMPFILE} ){
	die "ERROR: storage dump file name was not defined\n"; 
	# TODO: give a recipe how to define dumpfile.
    }
    if ( not -f $h->{DUMPFILE} ){
	die "ERROR: file does not exist: $h->{DUMPFILE}\n";
    }
    # and format:
    if (defined $h->{DUMPFORMAT}){
	print "Already defined format: $h->{DUMPFORMAT}\n" if $h->{VERBOSE};	
    } else {
	$h->{DUMPFORMAT} = "UNKNOWN";
	print  "Checking format of file: $h->{DUMPFILE}\n" if $h->{VERBOSE};
	if (&DMWMMON::SpaceMon::StorageDump::looksLikeTXT($h->{DUMPFILE})) {
	    print "Looks like TXT file\n" if $h->{VERBOSE};
	    $h->{DUMPFORMAT} = "TXT";
	} else {
	    print "Does not look like TXT file\n";
	}
	if (&DMWMMON::SpaceMon::StorageDump::looksLikeXML($h->{DUMPFILE})) {
	    print "Looks like XML file\n" if $h->{VERBOSE};
	    $h->{DUMPFORMAT} = "XML";
	} else {
	    print "Does not look like XML file\n";
	}
    }
    
    if ( ! grep /$h->{DUMPFORMAT}/, values %DMWMMON::SpaceMon::StorageDump::formats) {	
	die "ERROR: unknown format $h->{DUMPFORMAT}\n";
    }
    my $location       = "DMWMMON/SpaceMon/Format/" . $h->{DUMPFORMAT} . ".pm";
    $class             = "DMWMMON::SpaceMon::Format::" . $h->{DUMPFORMAT};
    require $location;
    return $class->new(%{$h});
}

1;
