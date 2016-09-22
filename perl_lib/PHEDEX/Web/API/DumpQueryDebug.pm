package PHEDEX::Web::API::DumpQueryDebug;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Web::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::DumpQuery - debugging only

=head1 DESCRIPTION

Query storage info with options from oracle backend
and dump results into local file on the server

=head2 Options

 required inputs: node 
 optional inputs: (as filters) level, rootdir, time_since, time_until 

  node             node name, could be multiple, all(T*). 
  level            the depth of directories, should be less than or equal to 6 (<=6), the default is 4
  rootdir          the path to be queried
  time_since       former time range, since this time, if not specified, time_since=0
  time_until       later time range, until this time, if not specified, time_until=10000000000
                   if both time_since and time_until are not specified, the latest record will be selected

=head2 Output

  <nodes>
    <timebins>
      <levels>
        <data/>
      </levels>
       ....
    </timebins>
    ....
  </nodes>
  ....

=head3 <nodes> elements

  subdir             the path searched
  node               node name

=head3 <timebins> elements

  timestamp          time for the directory info

=head3 <levels> elements

  level              the directory depth

=head3 <data> elements

  size               the size of the directory
  dir                the directory name

=cut

sub methods_allowed { return ('GET'); }
sub duration { return 0; }
sub invoke { return dumpquerydebug(@_); }

sub nrdebug {
    my $message = shift;
    open(my $fh, '>>', '/tmp/nrdebug_dumpquery_report.txt');
    print $fh $message . "\n";
    close $fh;
}

sub dumpquerydebug  {
    my ($args,) = @_;
    my ($data);
    print "Hash of arguments in dumpquerydebug:";
    #print Data::Dumper::Dumper @_;
    print "\n";
    my $result = readFromFile($args->{file});
    print "*** Processing result in dumpquerydebug...\n";
    # Find all nodes and all timestamps for each node:
    my $nodes = ();
    print "*** Query results read from the file:";
    my @query = $result->{PHEDEX}->{QUERYSPACE}[1];
    print @query;
    
    print "\nNUmber of elements in query array:\n" . string ($#query + 1);
    foreach my $i (0 .. $#query) { print "$i = $query[$i]" . "\n";};


    #foreach my $data ($result->{PHEDEX}->{QUERYSPACE}[0]) {
    foreach my $data ($query[0]) {
	print "\nbegin ===============\n";
	print Data::Dumper::Dumper ($data);
	print "\nend   ===============\n";
    }
    # Initialize array ref for the time bins (currently time stamps):
    my $timebins = ();
    # Initialize array ref for the aggregation levels  
    my $levelarray = ();
    # and iterate through the levels starting from top:
    print "Aggregating for levels from 1 to " . $args->{'level'} . "\n";
}

sub readFromFile 
{
    my $file = shift;
    my $return;
    our $VAR1;
    print "*** Reading SQL query result from file : $file \n";
    unless ($return = do $file) {
	warn "couldn't parse $file: $@" if $@;
	warn "couldn't do $file: $!"    unless defined $return;
	warn "couldn't run $file"       unless $return;
    }
    #print Data::Dumper::Dumper(%USERCFG);
    eval $return;
    #print Data::Dumper::Dumper( $VAR1);
    return $VAR1;
}
my %paramhash = ( 
    file        => '/storage/local/data1/home/natasha/work/SPACEMON/testdata/dumpquery_result', 
    node        => 'T2_Test_Buffer', #       node name, could be multiple, all(T*). 
    level       => 4, #      the depth of directories, should be less than or equal to 6 (<=6), the default is 4
    rootdir     => '/', #     the path to be queried
    #time_since  => '0', #    former time range, since this time, if not specified, time_since=0
    #time_until  => 10000000000, #     later time range, until this time, if not specified, time_until=10000000000
    # if both time_since and time_until are not specified, the latest record will be selected
);

my $output = &invoke(\%paramhash); 
1;
