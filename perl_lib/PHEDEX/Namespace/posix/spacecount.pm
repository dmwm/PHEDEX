package PHEDEX::Namespace::posix::spacecount;
# Implements space accounting for standard Disk storage technologies
use strict;
use warnings;

use PHEDEX::Core::Loader;
use PHEDEX::Namespace::SpaceCountCommon;
use PHEDEX::Namespace::Common;
use Data::Dumper;

# ================= Technology Specific code =====================
# Use this syntax if you choose common parsing methods available in SpaceCountCommon:
my $lookupFileSize = \&lookupFileSizeTxt;
my $lookupTimeStamp = \&lookupTimeStampTxt;
 
# Use this syntax if you need a customized regex: 
#my $lookupFileSize  = sub {$_=shift; if (m/^\S+\s(\/\S+)\s(\d+)$/) {return ($1, $2)} else {return 0}};
#my $lookupTimeStamp = sub{$_=shift; if (m/<dump recorded=\"(\S+)\">/) {return ($1)} else {return 0}};
#====================================================================


sub new {
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = { @_ };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  return $self;
}

sub execute {
  my ($self,$ns,$dumpfile) = @_;
  my $record;
  if ( $dumpfile ) {
    print "[INFO] Parsing storage dump in $dumpfile ... \n" if $ns->{VERBOSE};
    return doEverything($ns, $dumpfile, $lookupFileSize, $lookupTimeStamp);
  }
}

###############################################

sub Help
{
  print "Return record\n";
}

1;
