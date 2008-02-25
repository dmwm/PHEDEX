package PHEDEX::Namespace::rfio;

=head1 NAME

PHEDEX::Namespace::rfio - implement namespace functions for direct (posix) protocol

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item delete a file

=item check if a file is migrated to tape

=back

Not implemeted due to protocol limitation:

=over

=item bring online

=item check if a file is cached on disk

=item verify a file: check size, optionally checksum - N/A

=back

=cut

#use strict;
use warnings;
use Data::Dumper;

#Parent Class
use base PHEDEX::Namespace::Namespace; 


#NS functions implemented,
# how many we can run in parallel etc
#put own command like this. For unknow command
#the default number is used
my %commands = (
		stat=>{cmd=>"nsls",opts=>["-l"],n=>1},
		delete=>{cmd=>"nsrm",opts=>[],n=>1},
		default=>{proto=>"direct",n=>8},
);

sub new
{
    my $class  = shift;

    my $self = { };
    bless($self, $class);
    $self->_init(@_, COMMANDS=>\%commands); #values from the base class
    
    print Dumper($self);
    return $self;
}


#for srm we can check size, if file is on disk. But not if file is migrated
sub canChecks {
    my $checkref = shift;
    my @yes = ();

    foreach (@$checkref) {
        if (($_ eq 'Size') or ($_ eq 'Migr')) {
            push @yes, $_;
        }
        elsif (($_ eq 'OnDisk')) {
            print "Attribute $_ is not supported by $self->{protocol}\n";
        }
        else {
            print "Unknown Attribute $_\n";
        }
    }

    return @yes;
}

sub parseRawStat {
    my $self = shift;
    my $cmdref = shift;
    my $rawref = shift;
    my $lfnsref = shift;

    my @raw = @$rawref;

    print "rfio::parseRaw - ",scalar @raw, " lines\n";

    my %r = ();
    my $pfn;
    my $lfn;

    foreach (@raw) {
	print "Parsing: $_";
	chomp;
	my @s = split /\s+/, $_;
	print "Parsing: split 4, -1 = $s[4] $s[-1]\n";
	if ($s[-1] =~ m|^/| && $s[4] =~ /\d+/ && $s[0] =~ /^[-dm]/) {
	    ($lfn) = $self->pfn2lfn($cmdref, $lfn); 
	    $r{$lfn}{Size} = $s[4];
	    $r{$lfn}{Migrated} = ( substr($s[0], 0, 1) eq 'm' ? 1 : 0 );
	}
	else { print "Parsing: Can not parse $_!\n" }	
    }
    
    print "rfio::parseRaw - got ", scalar keys %r, " pfns\n";
    return %r;   
}


1;
