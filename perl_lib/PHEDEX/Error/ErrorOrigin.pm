#!/usr/bin/perl -w 

package PHEDEX::Error::ErrorOrigin;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getErrorOrigin);


use XML::LibXML;
use Data::Dumper;

# This is a structure to hold
# error definitions after readinf from a file

my $errdefs = undef;

my ($parser, $doc, $errors);

#error def file is located in the perl_lib/PHEDEX/Error subdir,
#which should be in the @INC where we look fir it

my $errordeffilename;

foreach $d (@INC) {
    if ( -e "$d/PHEDEX/Error/errormap.xml" ) { 
	$errordeffilename = "$d/PHEDEX/Error/errormap.xml";
	break;
    }
}

my %seennewpattern; #this is a cache for new patterns so that we don't report it 100 times


sub getErrorOrigin {
    my $pattern = shift;

    #cache if not yet cached.
    #this only reads default, hardcoded, erro definition file.
    #to use custom file, one needs to call &readErrorDef($file)
    #explicitly and before first call to &getErrorOrigin

    $errdefs = &readErrorDef($errordeffilename) unless $errdefs;

    #strip leading and tailing nonchar
    $pattern =~ s/^\W//;$pattern =~ s/(\s+|\n+)$//;

    #now check against error definitions
    my $matchedpat = "";

    foreach my $pat (keys %$errdefs) {#	print "Checking for $pat\n";
	if ( index($pattern, $pat) != -1 ) {
	    $matchedpat = $pat;
#	    print "Got match for $pat: $errdefs{$pat}{cat} $errdefs{$pat}{origin}\n";
	    return $errdefs->{$pat}{origin}
	}
    }
    
    
    unless ($matchedpat) {
	$seennewpattern{$pattern}++;
	print "New error, no match in errordef file: $pattern\n" unless ($seennewpattern{$pattern} > 1);
	return "unknown";
    }
}

sub readErrorDef{
    my $xmlfilename = shift || $errordeffilename || die "readErrorDef: no file given";

#open error definition file

    my $parser = XML::LibXML->new();

#We parse file into a DOM object
#DOM is a document object model
    my $doc = $parser->parse_file( $xmlfilename ); #print $doc->toString();

#This is how we can look up data in the DOM object
#we can search elements by tag, return a plain perl list
    my $errors = $doc->getElementsByTagName("error"); #print Dumper $errors;

    my %errdefs = ();

#now walk thought the list of elements we found
foreach my $error (@$errors) {
    #we can get attribute of elements
    my $cat = $error->getAttribute("cat");
    my $origin = $error->getAttribute("origin");
#    print "$cat $origin\n";

    #now get error pattern - the same technique
    #note -starting not from the document root node,
    #but from the element - it works as well
    #firstChild is text node, which is sort of child of the pattern
    #and nodeValue is actually a text value of this text node - i.e. text :)
    my $pattern = $error->getElementsByTagName("pattern")
	->[0]->firstChild->nodeValue;

    #strip leading and tailing nonchar
    $pattern =~ s/^\W//;$pattern =~ s/(\s+|\n+)$//;

#    print "er pat: $pattern\n";
    next unless $pattern;

    $errdefs{$pattern} = {cat=>$cat, origin=>$origin};
}

    return \%errdefs;

}

1;
