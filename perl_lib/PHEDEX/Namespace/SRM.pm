package PHEDEX::Namespace::SRM;

=head1 NAME

PHEDEX::Namespace::SRM - implement namespace functions for SRM protocol

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item check if a file is on disk

=item delete a file

=item verify a file: check size, optionally checksum

=back

Not implemeted due to protocol limitation:

=over

=check if a file is migrated

=item bring online

=back

=cut

#use strict;
use warnings;
use Data::Dumper;

#Parent Class
use base PHEDEX::Namespace::Namespace; 


#NS functions implemented,
# how many we can run in parallel which protocl we use etc
#put own command like this. For unknow command
#the default number is used
my %commands = (
    stat=>{cmd=>"srm-get-metadata",opts=>[],n=>10},
    delete=>{cmd=>"srm-advisory-delete",opts=>[],n=>9},
    default=>{tfcproto=>'srm',n=>8},
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
        if (($_ eq 'Size') or ($_ eq 'OnDisk')) {
            push @yes, $_;
        }
        elsif ($_ eq 'Migr') {
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
    my @raw = @$rawref;

    print "SRM::parseRaw - ",scalar @raw, " lines\n";

    my %r = ();

    my $pfn;
    my $lfn;

    foreach (@raw) {
#       print "parsing $_";
        if (/FileMetaData\((.*)\)/) {
            $pfn = $1;
#           print "Got pfn $pfn\n";
	    #need to convert to LFN
	    ($lfn) = $self->pfn2lfn($cmdref, $pfn);
        }
        elsif (defined $pfn) {
#           next if exists $stat->{$pfn}{Size};
            #we are parsing output for a pfn
            chomp;
            if ( m%^\s+size\s*:\s*(\d+)% ) { $r{$lfn}{Size} = $1;
                                             #print "Got size for $pfn\n" ;
                                             next };
            if ( m%^\s+isCached\s*:\s*(true|false)% ) {
                $r{$lfn}{OnDisk} = ($1 eq 'true')?1:0;
                #print "Got ondisk for $pfn\n";
                next };
        }
        else { print "Can not parse $_!\n" }
    }

    print "SRM::parseRaw - got ", scalar keys %r, " pfns\n";
    return %r;

}


#this is the code went nowhere - do we need to check whther we got all pfns from stat function?
sub former_stat_proto
{
    
    foreach my $pfn ( @_ )
    {
	next if exists $stat->{$lfn}{Size};	
    }
    
    map { $r->{$_} = $stat->{$_} } @_;
    return $r;
}



1;
