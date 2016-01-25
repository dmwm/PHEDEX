package DMWMMON::SpaceMon::Format::XML;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';
use Time::Local;

# Required methods: 

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    $self->{TIMESTAMP} = lookupTimeStamp($self);
    $self->{ENTRYSET} = 0;
    return $self;
}

sub formattingHelp
{
    print "=" x 80 . "\n";
    print __PACKAGE__ . " formatting recommendations \n";
    print "=" x 80 . "\n";
    my $message = <<'EOF';

spacemon XML parser follows syncat format, defined at:
    http://www.desy.de/~paul/SynCat/syncat-1.0.tar.gz

Tools for producing storage dumps in syncat are available for dCache and DPM

Example of syntax accepted in current implementation:  

<?xml version="1.0" encoding="iso-8859-1"?><dump recorded="2012-02-27T12:33:23.902495"><for>vo:cms</for>
<entry-set>
<entry name="/dpm/site/home/cms/store/file1"><size>1139273384</size><ctime>1296671817</ctime><checksum>AD:ca793d51</checksum></entry>
<entry name="/dpm/site/home/cms/store/file2"><size>1062056867</size><ctime>1296707321</ctime><checksum>AD:9fa5feec</checksum></entry>
</entry-set></dump>
EOF
    print $message;
    print "=" x 80 . "\n";
}


sub lookupFileSize 
{
    my $self = shift;
    $_ = shift;
    if (m/\S+\sname=\"(\S+)\"\>\<size\>(\d+)\<\S+$/) {
	print "Processing line: $_     file=$1\n     size=$2\n" if $self->{VERBOSE};
	return ($1, $2+0);
    } else {
	# Because XML cnotains tags other than  file entries, we skip non matching lines without dying.
	# Sites can verify their dump format using syncat validation parser. 
	return (); 
	## Use this if if you want to implement format checking and it does not match:
	#&formattingHelp();
	#die "\nERROR: formatting error in " . __PACKAGE__ . " for line: \n$_" ;
    }
}

# Additional format specific methods: 

sub lookupTimeStamp{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lookupTimeStamp()\n" if $self->{VERBOSE};
    # Read first five lines of the dump
    foreach (DMWMMON::SpaceMon::StorageDump::readDumpHead($self->{DUMPFILE}),5) {
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
  my ($localtime, $mon, $year, $d, $t, @d, @t);
  if ($time =~ m/^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\D+/)
    {$unixTime = timelocal($6, $5, $4, $3, $2-1, $1-1900)}
  #$localtime = localtime($unixTime);
  #print "the localtime:", $localtime->mon+1,"  ", $localtime->year+1900, "\n";
  return $unixTime;
}

1;
