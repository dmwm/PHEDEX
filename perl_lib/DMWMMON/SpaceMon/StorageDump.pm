package DMWMMON::SpaceMon::StorageDump;
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

# Allow g and b2 zipped files to uncompress on the fly: 
my %extractor = ( ".gz" => "| gzip -d - ", ".bz2" =>  "| bzip2 -d - " );

# Mapping for file suffices: 
my %format = ( ".txt" => "TEXT", ".xml" => "XML" );

sub new
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
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    validate($self);
    $self->{TIMESTAMP} = lookupTimeStamp($self);
    bless $self, $class;
    return $self;
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
    open ( my $fh, "cat $fullname $extractor{$suffix} |" ) or die "open: $fullname: $!\n";
    if ( eof $fh ){die "ERROR processing storage dump in $fullname: no data found\n"}
    $self->{FH} = $fh;
}

sub lookupTimeStamp{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lookupTimeStamp()\n" if $self->{VERBOSE};
    my $timestamp;
    my $basename = $self->{DUMPFILE};
    # Discard all known suffices first:
    my @suffices;
    push (@suffices, keys %extractor);
    push (@suffices, keys %format);
    my ($name, $path, $suffix) = fileparse( $basename, @suffices);
    while ( $suffix ) {
	$basename = $path . $name;
	($name, $path, $suffix) = fileparse( $basename, @suffices);
    }
    # Look for timestamp with 10 digits: covers years 2001-2286
    if ($basename =~ /\.([0-9]{10})$/){ 
	$timestamp = $1;
	if ($timestamp >= time) {
	    die "ERROR: time stamp $timestamp represents date in the future:\n", 
	    scalar gmtime $timestamp, "\n";
	}
	$self->{VERBOSE} && 
	    print "Detected time stamp: $timestamp corresponding to the date:\n", 
	    scalar gmtime $timestamp, "\n";
	$self->{TIMESTAMP} = $timestamp;
    }
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
