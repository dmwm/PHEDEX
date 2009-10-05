package PHEDEX::Namespace::SRMv2;

=head1 NAME

PHEDEX::Namespace::SRMv2 - implement namespace functions for SRM protocol

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item check if a file is on disk

=item check if a file is on tape

=item delete a file

=item verify a file: check size, optionally checksum - N/A

=back

Not implemeted due to protocol limitation:

=over

=item bring online

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
		stat=>{cmd=>"srmls",opts=>["-l"],n=>10},
		delete=>{cmd=>"srmrm",opts=>[],n=>9},
		bringonline=>{cmd=>"srm-bring-online",opts=>[],n=>7},
		default=>{tfcproto=>'srmv2',n=>8},
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
        if (($_ eq 'Size') or ($_ eq 'OnDisk') or ($_ eq 'Migr')) {
            push @yes, $_;
        }
#        elsif () {
#            print "Attribute $_ is not supported by $self->{protocol}\n";
#        }
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

    #let's assume all pfns have the same endpoint, 
    #and get the endpoint from the first one.
    my $firstlfn = $lfnsref->[0];
    my ($firstpfn) = $self->lfn2pfn($cmdref, $firstlfn);
    my ($endpoint) = ($firstpfn =~ m|(srm.*SFN=)/|);
    print "SRMv2 - got endpoint $endpoint from first pfn $firstpfn\n";

    # this may not work if e.g. there is double slash insead of one 
    # between the endpoint and the path.
    #alternative to this is to seek for the right pfn 
    #in the whole array while parsing

    print "SRMv2::parseRaw - ",scalar @raw, " lines\n";

    my %r = ();

    my $pfn;
    my $lfn;

    foreach (@raw) {
       print "Parsing: $_";
	chomp;
        if (m|^\s+(\d+)\s(/.*)$|) {	    
            $pfn = $endpoint.$2;
	    ($lfn) = $self->pfn2lfn($cmdref,$pfn);
	    $r{$lfn}{Size} = $1 ;
	    print "Parsing: Got Size $1 PFN $pfn LFN $lfn\n";

        }
        elsif (defined $pfn) {
#           next if exists $stat->{$pfn}{Size};
            #we are parsing output for a pfn
            if ( m%^\s+locality\s*:\s*(\S*)% ) {
                $r{$lfn}{OnDisk} = ($1 =~ '^ONLINE')?1:0;
                print "Parsing: Got OnDisk=$r{$lfn}{OnDisk} for $pfn\n";
		$r{$lfn}{Migr} = ($1 =~ 'NEARLINE' )?1:0;
		print "Parsing: Got OnTape=$r{$lfn}{Migr} for $pfn\n";
                next };
        }
        else { print "Parsing: Can not parse $_!\n" }
    }

    print "SRMv2::parseRaw - got ", scalar keys %r, " pfns\n";
    return %r;

}


1;
