package PHEDEX::Namespace::dCache;

=head1 NAME

PHEDEX::Namespace::SRMv2 - implement namespace functions for SRM protocol

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item check if a file is on disk

=item delete a file

=item verify a file: check size, optionally checksum - N/A

=item bring online

=back

Not implemeted due to protocol limitation:

=over

=item check if a file is on tape ?!

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
		stat=>{cmd=>"dccp",opts=>["-P", "-t -1"],n=>1},
		delete=>{cmd=>"rm",opts=>[],n=>9}, #?
		bringonline=>{cmd=>"dccp",opts=>["-P"],n=>7},
		default=>{n=>8},
);

sub new
{
    my $class  = shift;

    my $self = { };
    bless($self, $class);
    $self->_init(@_, COMMANDS=>\%commands); #values from the base class
    
    print Dumper($self);

    unless (defined $ENV{LD_PRELOAD} && $ENV{LD_PRELOAD} =~ /libpdcap/) {
	warn "LD_PRELOAD not set - files >2GB may be reported incorrectly\n";
    }

    return $self;
}


#for srm we can check size, if file is on disk. But not if file is migrated
sub canChecks {
    my $checkref = shift;
    my @yes = ();

    foreach (@$checkref) {
        if ($_ eq 'OnDisk') {
            push @yes, $_;
        }
        elsif (($_ eq 'Migr') or ($_ eq "Size")) {
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
    my $rawref = shift;
    my $pfnsref = shift;

    my @raw = @$rawref;

    #let's assume all pfns have the same endpoint, 
    #and get the endpoint from the fits one.
    my $firstpfn = $pfnsref->[0];
    my ($endpoint) = ($firstpfn =~ m|(srm.*SFN=)/|);
    print "SRMv2 - got endpoint $endpoint\n";

    # this may not work if e.g. there is double slash insead of one 
    # between the endpoint and the path.
    #alternative to this is to seek for the right pfn 
    #in the whole array while parsing

    print "SRMv2::parseRaw - ",scalar @raw, " lines\n";

    my %r = ();

    my $pfn;

    foreach (@raw) {
       print "Parsing: $_";
	chomp;
        if (m|^\s+(\d+)\s(/.*)$|) {
	    
            $pfn = $endpoint.$2;
	    $r{$pfn}{Size} = $1 ;
	    print "Parsing: Got size $1 pfn $pfn\n";

        }
        elsif (defined $pfn) {
#           next if exists $stat->{$pfn}{Size};
            #we are parsing output for a pfn
            if ( m%^\s+locality\s*:\s*(\S*)% ) {
                $r{$pfn}{OnDisk} = ($1 =~ '^ONLINE')?1:0;
                print "Parsing: Got OnDisk=$r{$pfn}{OnDisk} for $pfn\n";
		$r{$pfn}{OnTape} = ($1 =~ 'NEARLINE' )?1:0;
		print "Parsing: Got OnTape=$r{$pfn}{OnTape} for $pfn\n";
                next };
        }
        else { print "Parsing: Can not parse $_!\n" }
    }

    print "SRMv2::parseRaw - got ", scalar keys %r, " pfns\n";
    return %r;

}


1;
