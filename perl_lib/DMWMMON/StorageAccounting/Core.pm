package DMWMMON::SpaceAccounting::Core;
our @ISA = qw(Exporter);
our @EXPORT = qw (uploadRecord);

use Time::Local;
use Time::localtime;
use PHEDEX::Namespace::Common  ( qw / setCommonOptions / );

# Note the structure: instead of the value being a variable that will hold
# the parsed value, we provide the default. Later, when the user wants to
# actually parse the command line arguments, they call
# PHEDEX::Namespace::Common::getCommonOptions, to set their options and
# parameter hashes automatically. Then they pass them to GetOptions.
our %options = (
              "url=s"  => 'https://cmsweb-testbed.cern.ch/dmwmmon/datasvc',
		);

PHEDEX::Namespace::Common::setCommonOptions( \%options );

sub uploadRecord{
  # Code from Utilities/testSpace/spaceInsert   <<<
  my $url = shift;
  my $hashref = shift; # pass %payload by reference
  my $method   = 'post';
  my $timeout  = 500;
  my $pua = PHEDEX::CLI::UserAgent->new (
                                      URL        => $url,
                                      FORMAT    => 'perl',
                                      INSTANCE    => '',
                                     );
  my ($response,$content,$target);
  print "Begin to connect data service.....\n" if $debug;
  $pua->timeout($timeout) if $timeout;
  $pua->CALL('storageinsert');
  #$pua->CALL('auth'); # for testing authentication without writing into the database.
  $target = $pua->target;
  print "[DEBUG] User agent target=$target\n" if ($debug);
  $response = $pua->$method($target,$hashref);
  if ( $pua->response_ok($response) )
    {
      # HTTP call returned correctly, print contents and quit...
      no strict 'vars';
      $content = eval($response->content());
      $content = $content->{PHEDEX}{STORAGEINSERT};
      Data::Dumper->Dump([ $content ]);
      foreach $record ( @{$content} ) {
        print "Inserting Record:\n  ",join('  ',map { "$_:$record->{$_}" } sort keys %{$record}),"\n";
      }
    }
  else
    {
      # Something went wrong...
      print "Error from server ",$response->code(),"(",$response->message(),"), output below:\n",
        $response->content(),"\n";
      print "[DEBUG] Web user agent parameters:\n" . Data::Dumper->Dump([ $pua]) if ($debug); 
      die "exiting after failure\n";
    }
  print  "Done!\n";
}

1;
