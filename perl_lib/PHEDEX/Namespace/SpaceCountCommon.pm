package PHEDEX::Namespace::SpaceCountCommon;
our @ISA = qw(Exporter);
our @EXPORT = qw (); # export nothing by default

# Note the structure: instead of the value being a variable that will hold
# the parsed value, we provide the default. Later, when the user wants to
# actually parse the command line arguments, they call
# PHEDEX::Namespace::Common::getCommonOptions, to set their options and
# parameter hashes automatically. Then they pass them to GetOptions.
our %options = (
              "dump=s" => undef,
              "node=s" => undef,
              "url=s"  => 'https://cmsweb-testbed.cern.ch/dmwmmon/datasvc',
              "level=i" => 6,
              "force"   => 0,
             );

PHEDEX::Namespace::Common::setCommonOptions( \%options );

1;
