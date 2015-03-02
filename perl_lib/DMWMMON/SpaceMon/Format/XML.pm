package DMWMMON::SpaceMon::Format::XML;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';
use Time::Local;

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
    $self->{TIMESTAMP} = lookupTimeStamp($self);
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

sub lookupTimeStamp{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lookupTimeStamp()\n" if $self->{VERBOSE};
    # Read first three lines of the dump
    foreach (DMWMMON::SpaceMon::StorageDump::readDumpHead($self->{DUMPFILE})) {
	print "XML FILE line: " . $_;
	if (m/<dump recorded=\"(\S+)\">/) {return convertToUnixTime($1)};
    }
    return undef;
}

sub convertToUnixTime {
# parses time formats like "2012-02-27T12:33:23.902495" or "2012-02-20T14:46:39Z" 
# and returns unix time or undef if not parsable.
  my ($time) = shift;
  my $unixTime = undef;
  my ($unixTime, $localtime, $mon, $year, $d, $t, @d, @t);
  if ($time =~ m/^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\D+/)
    {$unixTime = timelocal($6, $5, $4, $3, $2-1, $1-1900)}
  #$localtime = localtime($unixTime);
  #print "the localtime:", $localtime->mon+1,"  ", $localtime->year+1900, "\n";
  return $unixTime;
}

1;
