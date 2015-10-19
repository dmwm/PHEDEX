package PHEDEX::Tests::File::Download::CircuitBackends::NSI::Native::TestStateMachine;

use strict;
use warnings;

use Data::Dumper;
use Test::More;
use SOAP::Lite;

#use LWP::Simple qw(get);
#use Crypt::SSLeay;
#$ENV{HTTPS_CA_FILE} = "/data/Certificates/NSI/nsi-aggr-west-cachain.pem";
#$ENV{HTTPS_CERT_FILE} = "/data/Certificates/vlad/Vlad-Lapadatescu-cert.pem";
#$ENV{HTTPS_KEY_FILE} = "/data/Certificates/vlad/Vlad-Lapadatescu-key-nopass.pem";
#$ENV{HTTPS_DEBUG} = 0;
#print get("https://nsi-aggr-west.es.net/nsi-v2/ConnectionServiceProvider?wsdl=");

my $WSDL = 'http://webservices.oorsprong.org/websamples.countryinfo/CountryInfoService.wso?WSDL';

my $client = SOAP::Lite->new();

$client->soapversion("1.1");

my $service = $client->service($WSDL);

my $response = $service->FullCountryInfo("CH");

print Dumper($response )."\n";

done_testing();

1;