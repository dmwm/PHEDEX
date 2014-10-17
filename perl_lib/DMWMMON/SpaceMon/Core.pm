package DMWMMON::SpaceMon::Core;
our @ISA = qw(Exporter);
our @EXPORT = qw (uploadRecord openDump openDumpUsage);

use Time::Local;
use Time::localtime;
use PHEDEX::CLI::UserAgent;

sub version(){
    return "1.0-dev";
}

sub openDumpUsage {
    my  $argname = shift || DUMPFILE;
    print <<EOF;
 $argname is file name of a storage dump file in txt or XML format. 
 If '-' is given instead of file name, the script will read from stdin. 
 Gzipped (*.gz) or bzipped (*.bz2) files can be read directly.

 Passing the timestamp of the storage dump produced
 Since file mtime/ctime may change when it is copied or moved, there are
 several ways to pass the actual dump creation time:
  - creation time (seconds since epoch) encoded in the file name for txt files
  - creation time (seconds since epoch) passed via --timestamp option
  - passed via <dump recorded=...> tag in XML file
 See examples in: 
 https://twiki.cern.ch/twiki/bin/view/LCG/ConsistencyChecksSEsDumps#Format_of_SE_dumps
EOF
}

sub openDump {
  my $dumpfile = shift;
  my $filebasename = $dumpfile;
  my $fh;
  if ( $dumpfile =~ m%.gz$% ) {
      $filebasename = substr($dumpfile, 0, -3) . "\n";
      open $fh , "cat $dumpfile | gzip -d - |" or die "open: $dumpfile: $!\n"; 
  } elsif ( $dumpfile =~ m%.bz2$% ) { 
      $filebasename = substr($dumpfile, 0, -4) . "\n";
      open $fh, "cat $dumpfile | bzip2 -d - |" or die "open: $dumpfile: $!\n";
  } else { 
      open $fh, "<$dumpfile" or die "open: $dumpfile: $!\n";
  }
  if ( eof $fh ){die "ERROR processing input in $dumpfile no data found\n"}
  return $fh;
}

sub lookupTimeStampXml{$_=shift; if (m/<dump recorded=\"(\S+)\">/) {return ($1)} else {return 0}}
sub lookupTimeStampTxt{$_=shift; my @ar= split /\./; return $ar[-2]} # pass filename as argument


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
                                      CA_DIR    => '/etc/grid-security/certificates',
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
