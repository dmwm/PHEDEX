package PHEDEX::Error::GraphTool;

## This package is a poor man's perl interface to 
## Brian Bockelman's GraphTool python library
## http://t2.unl.edu/documentation/using-graphtool

use strict;
use POSIX;
use Data::Dumper;

# data = { label:num, ... }
sub PieGraph {
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= &pythProlog();
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);
    $pyth .= &pythEpilog ($filename);

    return $pyth
}

# data = { label:num, ... }
# data = { num:num, ... }
sub BarGraph{
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= &pythProlog();
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);
    $pyth .= &pythEpilog ($filename);

    return $pyth
}


#data = {'label':{label:num, ...}, ... }
#data = {'label':{num:num, ...}, ... }
sub StackedBarGraph{
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= &pythProlog();
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);    
    $pyth .= &pythEpilog ($filename);

    return $pyth

}

#data = {time:num, ... }
sub  TimeBarGraph {
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= <<HERE;
from graphtool.graphs.common_graphs import BarGraph, StackedBarGraph
from graphtool.graphs.graph import TimeGraph

class TimeBarGraph( TimeGraph, BarGraph ):
    pass

HERE
    
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);
    $pyth .= &pythEpilog ($filename);

    return $pyth
}

#data = {'label':{time:num, ...}, ... }
sub  TimeStackedBarGraph {
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

#prolog
    $pyth .= <<HERE;
#import time, os, random, datetime
from graphtool.graphs.common_graphs import BarGraph, StackedBarGraph
from graphtool.graphs.graph import TimeGraph

class TimeStackedBarGraph( TimeGraph, StackedBarGraph ):
    pass

HERE

$pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);
    $pyth .= &pythEpilog ($filename);

    return $pyth
}


#data = {'label':{time:num, ...}, ... }
sub CumulativeGraph {
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= &pythProlog();   
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);    
    $pyth .= &pythEpilog ($filename);

    return $pyth
}


#data = {'label':{time:num, ...}, ... }
#num is 0-1
#there is a color override metadata field. refere to the original doc
sub QualityMap{
    my $data = shift;
    my $filename = shift;
    my $metadata = shift;

    my $pyth = "";

    $pyth .= &pythProlog();
    $pyth .= &pythMetadata($metadata);
    $pyth .= &pythData($data);
    $pyth .= &pythEpilog ($filename);

    return $pyth
}

sub pythProlog{

    my $function = (caller(1))[3]; ($function) = ($function =~ m/(\w+)$/);

    my $pyth = <<HERE;
from graphtool.graphs.common_graphs import $function

HERE

return $pyth

}

sub pythMetadata{
    my $metadata = shift;

    my $pyth = "metadata = {";
    $pyth .= join ",", map { "\'$_\':". (($metadata->{$_} =~ m/\D+/)?"\'$metadata->{$_}\'":$metadata->{$_})  } keys %$metadata;
    $pyth .= "}\n";

    return $pyth
}


sub pythData{
    my $data = shift;

#data = {'label':{label:num, ...}, ... }
#data = {'label':{num:num, ...}, ... } #also time:num
#data = {'label':num, ... }

    my $pyth = "";

    my $scounter = 0 ;
    my $dataline = "";
    foreach my $s (keys %$data) {
	if ($data->{$s} !~ /HASH/) {
	    #this is a plain hash, not hash of hashes, pass as such
	    $dataline = join " , ", map { /\w+/?"\'$_\'":"$_".":". $data->{$_} } keys %$data ;
	    last;
	}

	$scounter++;
	$dataline .= ' , ', if $dataline; #add a separator before the next record
	$dataline .= (($s =~ /\D+/)?"\'$s\'":$s) . ":data$scounter";

	my $sd = $data->{$s};
	#let's make a data dictionary
	$pyth .= "data$scounter = {";
	$pyth .=  join " , ", map { (/\D+/?"\'$_\'":"$_").":". ($sd->{$_} || 0 )} keys %$sd ;
	$pyth .= "}\n";
    }

    $pyth .= "data = {" . $dataline . "}\n";

    return $pyth
}


sub pythEpilog{
    my $filename = shift;
    my $function = (caller(1))[3]; ($function) = ($function =~ m/(\w+)$/);

    my $pyth = "";
    $pyth .= <<HERE;
filename = '$filename'
file = open( filename, 'w' )
myG = $function()
myG( data, file, metadata )

HERE

return $pyth
}

#execute python code
sub execPyth{
    my $pyth = shift;

    open P, "|/usr/bin/env python" or die "Can not open python: $!\n";
    print P $pyth;
    close P or die "Can not close python: $!\n";
}


#TO DO: need to align bins to an hour!

#ser is {label=>string, data=>[time,time,...]}, 
sub HistoForGraphTool {
    my $starttime = shift;
    my $endtime = shift;
    my $span = shift;
    my $ser = shift;

    my $nbins = ceil(($endtime - $starttime)/$span);

    #initialize return hash
    #data = {label=>{time=>num, ... }, ...}

    my %data = ();

#    print "making histo: $starttime, $endtime, $span, diff=",$endtime-$starttime,"bins=",floor(($endtime-$starttime)/$span) ,"\n";

    # foreach data serie, 
    foreach my $s (@$ser) {
        my $data_i = {};

        foreach my $t (@{$s->{data}}) {
            #in which bin?
            my $bin = floor(($t - $starttime)/$span);
            $data_i->{int($starttime + $span*$bin)}++ ;
        }

	$data{$s->{label}} = $data_i;
    }
    
#    print "DATA "; print Dumper \%data;

    return \%data;
}


1;
