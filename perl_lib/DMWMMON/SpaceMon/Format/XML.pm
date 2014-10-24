package DMWMMON::SpaceMon::Format::XML;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';

# class methods:
sub formattingHelp
{
    my $message = <<'EOF';
======== Formatting help =========
XML formatting recommendations: 

XML format has been agreed with dCache sites, as they can produce the dump using 
the pnfs-dump or the chimera-dump tools, that support XML output format. 

More details here: http://www.desy.de/~paul/SynCat/syncat-1.0.tar.gz

Similar tools exist for DPM storage. 
===================================
EOF
    print $message;
}
# Object methods:

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub lookupFileSize 
{
    my $self = shift;
    $_ = shift;
    if (m/\S+\sname=\"(\S+)\"\>\<size\>(\d+)\<\S+$/) {
	#print "Found match for file: $1 and size: $2 \n" if $self->{VERBOSE};
	return ($1, $2);
    } else {
	return ();
    }
}

1;
