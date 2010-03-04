#!/usr/bin/perl

# This program is an example of using the data service to do something
# useful.  It fetches block replicas belonging to the "top" group and
# outputs an ordered list of datasets belonging to that group, and at
# which nodes they are resident.  It is meant to be an example of the
# simplicity of fetching, parsing, and processing data service
# results, regardless of the data format.

use warnings;
use strict;

use LWP::UserAgent();
use HTTP::Request;
use Time::HiRes qw(gettimeofday);
use Data::Dumper;

my $data_fmt = shift @ARGV;
$data_fmt ||= "perl"; # switch between perl, json or xml

my $uppercase_keys;
if    ($data_fmt eq 'perl') { $uppercase_keys = 1; }
elsif ($data_fmt eq 'json') { $uppercase_keys = 0; }
elsif ($data_fmt eq 'xml')  { $uppercase_keys = 0; }
else { die "'$data_fmt' format is not supported!\n"; }

my (@stats, $t1, $t2);
my $stats_fmt = "%-20s%0.3f s";

# Fetch data from data service
$t1 = &gettimeofday();
my $url = "http://cmsweb.cern.ch/phedex/datasvc/$data_fmt/prod/blockreplicas?group=top";
my $ua  = new LWP::UserAgent();
my $req = new HTTP::Request(GET => $url);
my $rsp = $ua->request($req);
my $data;
if ($rsp->is_success()) {
    $data = $rsp->content();
} else {
    die "Request for $url failed: ", $rsp->status_line(), "\n";
}
$t2 = &gettimeofday();
push @stats, sprintf($stats_fmt, "fetching", $t2-$t1);

# Parse response.  Below are examples for each data format

$t1 = &gettimeofday();
my $blocks;

if ($data_fmt eq 'perl') 
{
    ### "Parsing" done with perl is just an eval {} of the perl code
    {
	no strict 'vars';
	$data =~ s%^[^\$]*\$VAR1%\$VAR1%s; # get rid of any stuff before $VAR1
	my $data_obj = eval($data);
	die "failed to evaluate response!\nresponse was:\n$data\n" if $@;
	$blocks = $data_obj->{PHEDEX}->{BLOCK};
    }
} 
elsif ($data_fmt eq 'json')
{
    ### Parsing done with JSON response using JSON::XS
    require JSON::XS;
     my $data_obj = &JSON::XS::decode_json($data);
    $blocks = $data_obj->{phedex}->{block};
} elsif ($data_fmt eq 'xml') {
    ### Parsing done with XML response using XML::Simple
    require XML::Simple;
    my $xs = new XML::Simple;
    my $data_obj = $xs->XMLin($data, 
			      KeepRoot => 1,
			      ForceArray => [qw(block replica)],
			      KeyAttr => undef );
    $blocks = $data_obj->{phedex}->{block};
} else { die "unsupported format!\n"; }

die "Result contains no data!\nresponse was:\n$data\n" unless $blocks;
$t2 = &gettimeofday();
push @stats, sprintf($stats_fmt, "parsing", $t2-$t1);

# Process result

# Returns uppercase or lowercase depending on $uppercase_keys true or
# false. Note: Different data formats return keys in different
# casing. Normally, of course, you wouldn't have such a function
# because you would just pick a data format and stick with that
sub case() {
    return $uppercase_keys ? uc($_[0]) : lc($_[0]);
}

$t1 = &gettimeofday();
my $result = {};
foreach my $b (@$blocks) {
    my $dataset = $b->{&case("name")};
    $dataset =~ s/#.*$//;
    my $replicas = $b->{&case("replica")};
    foreach my $r (@$replicas) {
	my $node = $r->{&case("node")};
	$result->{$dataset}->{$node} = 1;
    }
}
$t2 = &gettimeofday();
push @stats, sprintf($stats_fmt, "processing", $t2-$t1);

# Print result
$t1 = &gettimeofday();
foreach my $ds (sort keys %$result) {
    my $node_list = join(',', sort keys %{$result->{$ds}});
    print "$ds $node_list\n";
}
$t2 = &gettimeofday();
push @stats, sprintf($stats_fmt, "printing", $t2-$t1);
print "\nstatistics for $data_fmt format:\n";
print "  $_", "\n" foreach @stats;

exit;
