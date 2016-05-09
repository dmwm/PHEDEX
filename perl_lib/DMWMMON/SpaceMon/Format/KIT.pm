package DMWMMON::SpaceMon::Format::KIT;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';
use Scalar::Util qw(looks_like_number);

# Required methods: 

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub formattingHelp
{
    print "=" x 80 . "\n";
    print __PACKAGE__ . " formatting recommendations \n";
    print "=" x 80 . "\n";
    my $message = <<'EOF';
Storage dump file contains file information groupped by directories. 
Each group starts with a new line containing a full directory name (starting with /), 
followed by a list of files, one line per each file, with the following values separated by a tab: 
 * File name (contains no slashes)
 * PnfsId of the file in chimera
 * File\'s checksum
 * File\'s size in bytes
 * File\'s creation time in seconds since epoch
 * Comma separated list of pools hosting the replicas of this file

Example of syntax accepted in current implementation: 

/pnfs/gridka.de/cms/disk-only/store/data/None/BTag/RECO/v0/00000
CCF3B214-2C11-E411-A220-002590A831CC.root	0000F76ACEB0623242C39E2597ABC0C79BF0	db3c751c	2467455654	1405987061	f01-081-113-e_5D_cms
DEBF787C-3411-E411-9257-002590A37118.root	00006A0E9BCB83F84F99B3B7186436C62BAF	6b9e04b4	2120283870	1405988016	f01-065-101-e_2D_cms,f01-081-113-e_5D_cms
/pnfs/gridka.de/cms/disk-only/store/data/Run2011A/Photon/AOD/BackfillTestAttempt-v2/00000
001E1E92-5C9A-E311-BBC0-B499BAA2AC54.root	00004008EFDFD8C34667A3D77CDBF4693C99	b5256e1b	4147274099	1392927441	f01-081-113-e_2D_cms
00827A63-3599-E311-B3CB-002590200898.root	00000188D27EF1A74E288E6F6377D76E5543	98ed1251	4236224247	1392797826	f01-081-113-e_2D_cms
0085B039-FCA4-E311-8215-0025B3E05BA8.root	00002021E477D8634DD08C4DED81B2CD1AD7	8167c81f	3328257739	1394101546	f01-080-128-e_2D_cms,f01-081-113-e_2D_cms
00F66C5B-BE98-E311-9349-002590200A00.root	000041202CD2238841C08C59A857951ADF25	cac73df8	2277054513	1392743224	f01-080-130-e_3D_cms
00FADEC4-F99B-E311-A410-002590A3C992.root	0000A12CC7A746284B91B47A736C49D102AA	878b8c4c	4089279227	1393099295	f01-080-128-e_2D_cms

For more details see: 
https://github.com/FredStober/chimera-list
http://ekphappyface.physik.uni-karlsruhe.de/upload/gridka/chimera.example
EOF
    print $message;
    print "=" x 80 . "\n";
}

sub lookupFileSize
{
    my $self = shift;
    $_ = shift;
    chomp;
    # Check if line contains a directory name and cache it:
    if (m/^\//) {
	$self->{DIRNAME} = $_;
	print "Parsing directory " . $_ . "\n" if $self->{VERBOSE};
	return;
    }
    my ($file, $pnfsid, $chksum, $size, $rest) = split /\t/;

    if (looks_like_number($size)) {
	$size+=0;
	$file = $self->{DIRNAME}. "/" . $file;
	print "Found match for file: $file and size: $size \n" if $self->{VERBOSE};
	return ($file, $size);
    } else {
	&formattingHelp();
	die "\nERROR: formatting error in " . __PACKAGE__ . " for line: \n$_" ;
    }
}

1;
