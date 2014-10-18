package DMWMMON::SpaceMon::Format::XML;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';

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
    $_ = shift;
    if (m/^\S+\s(\/\S+)\s(\d+)$/) {
	return ($1, $2);
    } else {
	return 0;
    }
}

sub formattingHelp
{
    my $message = <<'EOF';

XML formatting recommendations: 

XML format has been agreed with dCache sites, as they can produce the dump using 
the pnfs-dump or the chimera-dump tools, that support XML output format. 

More details here: http://www.desy.de/~paul/SynCat/syncat-1.0.tar.gz

Similar tools exist for DPM storage. 


EOF
    print $message;
}

1;
