#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;

use PHEDEX::Core::DB;
use PHEDEX::Core::Identity;
use PHEDEX::RequestAllocator2::Core;
use PHEDEX::RequestAllocator2::SQL;
use PHEDEX::Core::SQL;
use PHEDEX::Core::Timing;
use PHEDEX::Core::XML;


my %args;
&GetOptions ("db=s"            => \$args{DBCONFIG});
die "Need -db !" unless $args{DBCONFIG};
my $self = { DBCONFIG => $args{DBCONFIG} };
bless $self;
my $dbh = &connectToDatabase ($self);
my $now = &mytimeofday();

my $data = '<data version="2.0">
  <dbs name="http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query">
    <dataset name="/sample/dataset" is-open="y">
      <block name="/sample/dataset#1" is-open="y">
        <file name="file1" bytes="10" checksum="cksum:1234,adler32:9876"/>
        <file name="file2" bytes="22" checksum="cksum:456,adler32:789"/>
      </block>
    </dataset>
  </dbs>
</data>';

$data = PHEDEX::Core::XML::parseData( XML => $data);

($data) = values %{$data->{DBS}};
$data->{FORMAT} = 'tree';

#my $client_id = &PHEDEX::Core::Identity::logClientInfo( $self,
#							1,
#							"Remote host" => 'casamia',
#							"User agent"  => 'ilmiobrowser');


my %h = (CLIENT_ID => 9, TYPE => 'invalidation', INSTANCE => 'nicolo', LEVEL => 'BLOCK', COMMENTS => 'this is a test request by Nicolo', NOW => $now);

print "parameters: ",join(', ', map { "$_=>$h{$_}" } sort keys %h), "\n";

&test_validateRequest($data,[],%h);                                                                                                                         

exit;

sub test_validateRequest{
    my @valid_args = &PHEDEX::RequestAllocator2::Core::validateRequest($self,@_);
    my $rid = &PHEDEX::RequestAllocator2::Core::createRequest($self,@valid_args);
    print "Created request ",$rid,"\n";
    &PHEDEX::Core::SQL::execute_commit($self);                                                                                                                                   
}

1; # end TestSQL package

