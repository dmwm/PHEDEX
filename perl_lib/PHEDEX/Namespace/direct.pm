package PHEDEX::Namespace::direct;

=head1 NAME

PHEDEX::Namespace::direct - implement namespace functions for direct (posix) protocol

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item delete a file

=back

Not implemeted due to protocol limitation:

=over

=item bring online

=item check if a file is on disk

=item check if a file is on tape

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
		stat=>{cmd=>"ls",opts=>["-l"],tfcproto=>"direct",n=>10},
		delete=>{cmd=>"rm",opts=>["-f"],tfcproto=>"direct",n=>9},
		default=>{tfcproto=>'direct',n=>8},
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
        if (($_ eq 'Size')) {
            push @yes, $_;
        }
        elsif (($_ eq 'Migr') or ($_ eq 'OnDisk')) {
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
    my $pfnsref = shift;

    my @raw = @$rawref;

    print "Direct::parseRaw - ",scalar @raw, " lines\n";

    my %r = ();

    my $pfn;

    foreach (@raw) {
       print "Parsing: $_";
       chomp;
       my @s = split /\s+/, $_;
       print "Parsing: split 4, -1 = $s[4] $s[-1]\n";
       if ($s[-1] =~ m|^/| && $s[4] =~ /\d+/) {
	   #need to convert back to LFN
	   my ($lfn) = $self->pfn2lfn($cmdref, $s[-1]);
#	   print "Got LFN $lfn\n";
	   $r{$lfn}{Size} = $s[4];
        }
        else { print "Parsing: Can not parse $_!\n" }
    }

    print "direct::parseRaw - got ", scalar keys %r, " lfns\n";
    return %r;

}


1;
