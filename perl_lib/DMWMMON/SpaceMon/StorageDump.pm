package DMWMMON::SpaceMon::StorageDump;
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

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
    # adopted from 
    my $self = shift;
    my $dumpfile=$self->{DUMPFILE};
    my $filebasename = $dumpfile;
    my $fh;
    if ( $dumpfile =~ m%.gz$% ) {
	$filebasename = substr($dumpfile, 0, -3) . "\n";
	open $fh , "cat $dumpfile | gzip -d - |" or die "open: $dumpfile: $!\n";
    } elsif ( $dumpfile =~ m%.bz2$% ) {
	$filebasename = substr($dumpfile, 0, -4) . "\n";
	open $fh, "cat $dumpfile | bzip2 -d - |" or die "open: $dumpfile: $!\n";
    } else {
	open $fh, "<$dumpfile" or die "open: $dumpfile: $!\n";
    }
    if ( eof $fh ){die "ERROR processing input in $dumpfile no data found\n"}
    $self->{FH} = $fh;
}

sub lookupTimeStamp{
    my $self = shift; 
    my $timestamp = 0; # if not found
    my $now = time;
    print "I am in ",__PACKAGE__,"->lookupTimeStamp()\n" if $self->{VERBOSE};
    foreach ( split /\./, $self->{DUMPFILE}) {
	print "NRDEBUG: $_\n";
	if ( $_ =~ /^[0-9.]/ ) {
	    print "NRDEBUG: matches numeric value: $_  !!!\n";
	    my $human_readable = scalar gmtime ($_);
	    if ($_ >=  $now) {
		warn "Detected timestamp $_ represents date in the future: $human_readable\n ";
	    }
	    if (substr($human_readable, -5, -2) ne " 20"){
		warn "Detected timestamp $_ represent date not in current century: $human_readable\n";
	    }
	    $timestamp = $_;
	    $self->{VERBOSE} && print "Detected timestamp: $_ corresponding to the date: $human_readable\n";
	} 		
    }
    return $timestamp;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
