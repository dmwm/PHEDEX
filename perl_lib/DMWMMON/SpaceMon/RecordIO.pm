package DMWMMON::SpaceMon::RecordIO;
use strict;
use warnings;
use Data::Dumper;
use DMWMMON::SpaceMon::Record;
use PHEDEX::CLI::UserAgent;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = (
		  DEBUG => 1,
		  VERBOSE => 1,
		  );
    my %args = (@_);
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;        
    
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;    
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub readFromFile 
{
    my $self = shift;
    my ($file,) = (@_);
    print "RecordIO reading from file: $file\n";
    my $data = do {
	if( open my $fh, '<', $file ) 
	{ local $/; <$fh> }
	else { undef }
    };    
    my $record;
    eval $data;    
    $self->{VERBOSE} && print "Record read from $file:\n", $record->dump();
    return $record;
}

sub writeToFile
{
    my $self = shift;
    my ($record, $where) = (@_);
    print "I am in ",__PACKAGE__,"->writeToFile()\n" if $self->{VERBOSE};
    print "RecordIO writing to file: $where\n";
    open (my $fh, '>', $where) or die "Could not open file '$where' $!";
    my $dd = Data::Dumper->new(
			       [ $record ],
			       [ qw(record) ]
			       );
    print $fh $dd->Dump();
    # NR: it looks like Dump above empties the dumped object, so I can't 
    # print it again into stdout
    close $fh;
}

sub upload
{    
    my $self = shift;
    my ($url, $record) = (@_);
    $url='https://cmsweb.cern.ch/dmwmmon/datasvc' unless  (defined $url);

    print "I am in ",__PACKAGE__,"->upload()\n" if $self->{VERBOSE};
    print "In RecordIO::upload: testing upload from StorageAccounting::Core.\n Record=\n", Dumper($record);
    my $result= uploadRecord($url, $self->{VERBOSE},  $self->{DEBUG}, $ {$record} {'DIRS'});
    return $result;
}

sub uploadRecord{
  # Code from Utilities/testSpace/spaceInsert   <<<
  my $url = shift;
  my $verbose=shift;
  my $debug=shift;
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


sub show
{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->show()\n" if $self->{VERBOSE};
}

sub uploadToDatasvc
{ # Upload without dependency on PhEDEx - either curl or LWA/UserAgent based
    return;
}

sub uploadRecordAsFile
{ # Upload record as a file to some Grid enabled storage. 
    return;
}

1;
