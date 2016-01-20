#! /usr/bin/env perl 
use strict;
use warnings;
use Data::Dumper;
our $VAR1;
$VAR1 = {
          'PHEDEX' => {
                        'REQUEST_DATE' => '2016-01-15 23:41:22 UTC',
                        'REQUEST_CALL' => 'dumpquery',
                        'REQUEST_URL' => 'http://localhost:8280/dmwmmon/datasvc/perl/dumpquery',
                        'CALL_TIME' => '0.00697',
                        'REQUEST_VERSION' => '1.0.3-comp2',
                        'QUERYSPACE' => [
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '1',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir3/a/b',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir1',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir3/a',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '1',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir1/a/b',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir2',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir1/a',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '1',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir2/a/b',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir3',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG',
                                            'TIMESTAMP' => '1446500998000'
                                          },
                                          {
                                            'SPACE' => '2',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1/home/natasha/work/SPACEMON/DEBUG/data/store/dir2/a',
                                            'TIMESTAMP' => '1446500998'
                                          },
                                          {
                                            'SPACE' => '6',
                                            'NAME' => 'T2_Test_Buffer',
                                            'DIR' => '/storage/local/data1',
                                            'TIMESTAMP' => '1446500998'
                                          }
                                        ],
                        'REQUEST_TIMESTAMP' => '1452901282.63093',
                        'INSTANCE' => 'read'
                      }
        };

# END OF DATA OUTPUT. 

# Input parameters (API arguments): 
my %paramhash = ( 
    level       => 4, #      the depth of directories, should be less than or equal to 6 (<=6), the default is 4
    rootdir     => '/', #     the path to be queried
    #node        => 'T2_Test_Buffer', #       node name, could be multiple, all(T*). 
    #time_since  => '0', #    former time range, since this time, if not specified, time_since=0
    #time_until  => 10000000000, #     later time range, until this time, if not specified, time_until=10000000000
    # if both time_since and time_until are not specified, the latest record will be selected
);

# node name and time parameters are used in SQL query to filter out the desired entries
# (since we work on SQL output here we do not need them)
# level and rootdir parameters are used in the aggregation algorithm below

# Find all node names
my $node_names = {};
foreach my $data (@{$VAR1->{PHEDEX}->{QUERYSPACE}}) {
    $node_names->{$data->{NAME}}=1;
};
# Processing all nodes:
foreach my $nodename (keys %$node_names) { 
    print "*** Processing node:  $nodename\n"; 
    my $node_element = {};
    $node_element->{'NODE'} = $nodename;
    $node_element->{'SUBDIR'} = $paramhash{rootdir};
    # Find all timestamps for this node:
    my $timestamps = {};
    foreach my $data (@{$VAR1->{PHEDEX}->{QUERYSPACE}}) {
	$timestamps->{$data->{TIMESTAMP}}=1;
    };
    my @timebins; # Array for node aggregated data per timestamp
    my $debug_count = 0;
    foreach my $timestamp (keys %$timestamps) { 
	$debug_count++;
	my $timebin_element = {timestamp => $timestamp};
	print "  *** Aggregating data from " . gmtime ($timestamp) . " GMT ($timestamp), to level=$paramhash{level}\n"; 
	# Pre-initialize data for all levels:
	my $levelsarray = ();
	#for (my $i = 1; $i<= $paramhash{level}; $i++) {
	#    $levelsarray->[$i-1]={level => $i, data => ()};
	#}
	$timebin_element->{levels} = $levelsarray;
	push @timebins, $timebin_element;
    }    
    $node_element->{'TIMEBINS'} = \@timebins;
    #my @debug = grep {
    #	($_->{NAME} eq $nodename ) and ( print $_->{TIMESTAMP} . "\n")
    #} @{$VAR1->{PHEDEX}->{QUERYSPACE}};
    print Data::Dumper::Dumper ($node_element);
};
