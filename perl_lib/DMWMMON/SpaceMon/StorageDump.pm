package DMWMMON::SpaceMon::StorageDump;
use strict;
use warnings;
use Carp;
use File::Basename;
use File::Spec::Functions;
use Data::Dumper;

# Allow g and b2 zipped files to uncompress on the fly: 
my %extractor = ( ".gz" => "| gzip -d - ", ".bz2" =>  "| bzip2 -d - " );

# Mapping for file suffices: 
my %formats = ( ".txt" => "TXT", ".xml" => "XML" );

sub instantiate
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = (
		  DEBUG => 1,
		  VERBOSE => 1,
		  DUMPFILE => undef,		  
		  TIMESTAMP => undef,
		  );
    my %args = (@_);
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;
    print "I am in a base class ",__PACKAGE__,"->instantiate()\n" if $self->{VERBOSE};
    validate($self);

    my $format = undef;
    #if ($self->looksLikeTXT()) {
    if (looksLikeTXT(\%params)) {
	print "Looks like TXT file\n";
	$format = "TXT";
    } else {
	print "Does not look like TXT file\n";    
    }
    if ( not defined $format)
    {
	if ($self->looksLikeXML()) {
	    print "Looks like XML file\n";
	    $format = "XML";
	} else {
	    print "Does not look like XML file\n";    
	}
    }
    
    $class = join "::" , (__PACKAGE__ , $format);
    my $plugin = catfile (split "::", $class) . ".pm";
    print " require $plugin \n";
    require $plugin;
    #$self->{TIMESTAMP} = lookupTimeStamp($self);
    #&openDump($self);
    #bless $self, $class;
    #return $self;
    return  $class->new(@_);
}

sub validate {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->validate()\n" if $self->{VERBOSE};
    ( &file_defined($self)  &&
      &file_exists($self)
      ) or die "ERROR: Invalid storage dump file\n";
}

sub file_defined {    
    my $self = shift;
    if ( not defined $self->{DUMPFILE} ){
	warn "Storage dump file name is not defined\n";
	return 0;
    }
    return 1;
}

sub file_exists {
    my ($self, $validity) = shift, 1;
    if ( not -f $self->{DUMPFILE} ){
	warn "File does not exist: $self->{DUMPFILE}\n";
	return 0;
    }
    return 2;
}

sub openDump {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->openDump()\n" if $self->{VERBOSE};
    my $fullname = $self -> {DUMPFILE};
    my ($name,$path,$suffix) = fileparse($fullname, keys %extractor);
    open ( my $fh, ($suffix) ? "cat $fullname $extractor{$suffix} |" : "<$fullname")
	or die "open: $fullname: $!\n";
    if ( eof $fh ){die "ERROR processing storage dump in $fullname: no data found\n"}
    $self->{FH} = $fh;
}

# Reads first line or N lines, if N is passed as an argument:
sub readDumpHead {
    my $self = shift;
    my $n = (@_) ? shift : 1;
    print "I am in ",__PACKAGE__,"->readDumpHead($n)\n" if $self->{VERBOSE};
    my $fullname = $self -> {DUMPFILE};
    my ($name,$path,$suffix) = fileparse($fullname, keys %extractor);
    open ( HEAD, ($suffix) ? "head -$n $fullname $extractor{$suffix} |" : " head -$n $fullname | ") 
	or die "open: $fullname: $!\n";
    my @headlines = <HEAD>;
    close HEAD;
    return @headlines;
}

sub lookupTimeStamp{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lookupTimeStamp()\n" if $self->{VERBOSE};
    my $timestamp;
    my $basename = $self->{DUMPFILE};
    # Discard all known suffices first:
    my @suffices;
    push (@suffices, keys %extractor);
    push (@suffices, keys %formats);
    my ($name, $path, $suffix) = fileparse( $basename, @suffices);
    while ( $suffix ) {
	$basename = $path . $name;
	($name, $path, $suffix) = fileparse( $basename, @suffices);
    }
    # Look for timestamp with 10 digits: covers years 2001-2286
    if ($basename =~ /\.([0-9]{10})$/){ 
	$timestamp = $1;
	if ($timestamp > time) {
	    die "ERROR: time stamp $timestamp represents date in the future:\n", 
	    scalar gmtime $timestamp, "\n";
	}
	$self->{VERBOSE} && 
	    print "Detected time stamp: $timestamp corresponding to the date:\n", 
	    scalar gmtime $timestamp, "\n";
	$self->{TIMESTAMP} = $timestamp;
    }
}

sub lookupTimeStampXML{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lookupTimeStampXML()\n" if $self->{VERBOSE};
}

sub looksLikeXML{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->looksLikeXML\n" if $self->{VERBOSE};
    my ($firstline) = $self->readDumpHead();
    if ($firstline !~ /^</ ) {
	return 0;
    }
    return 1;
}

sub looksLikeTXT{
    #my $self = shift;
    #print "I am in ",__PACKAGE__,"->looksLikeTXT\n" if $self->{VERBOSE};
    print "I am in ",__PACKAGE__,"->looksLikeTXT\n";
    #my ($firstline) = $self->readDumpHead();
    #if ($firstline !~ /^\// ) {
#	return 0;
 #   }
    return 1;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
