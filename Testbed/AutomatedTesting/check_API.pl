#!/usr/bin/perl
use Module::Load;
#---------------------------------
# Define URL with instance
$URL="https://phedex-integ.cern.ch/phedex/datasvc/perl/integration/";
# Define which agent should be tested
$API="Agents";
#$API="Nodes";
#----------------------------------
my $module = 'PHEDEX::Web::API::'.$API;
load $module;
use PHEDEX::Web::ArgsValidation;
use Data::Dumper;

my $apispec=${$module.'::spec'};
my $test = build_test();
my $url;

foreach my $key ( keys %$test )
{
    @url = build_url($test, $key, 'true');
    test_url(@url);
    @url = build_url($test, $key, 'false');
    test_url(@url);   
}

#----------------------------------------------------------
sub build_test{
    my $szenario;

    while ( ($key1, $value1) = each %{$apispec} )
    {

	if (! exists( $PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'true'})){die "Check PHEDEX::Web::ArgsValidation::ARG_DEFS for missing 'true' in $value1"};
	if (! exists($PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'false'})){die "Check PHEDEX::Web::ArgsValidation::ARG_DEFS for missing 'false' in $value1"};
	if (! exists($PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'description'})){die "Check PHEDEX::Web::ArgsValidation::ARG_DEFS for missing 'description' in $value1"};
	if (! exists($PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'coderef'})){die "Check PHEDEX::Web::ArgsValidation::ARG_DEFS for missing 'coderef' in $value1"};
	my $trues = $PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'true'};
	my $falses = $PHEDEX::Web::ArgsValidation::ARG_DEFS{$value1->{'using'}}->{'false'};

	my $ismult = "0";
	if(exists($value1->{'multiple'}) && $value1->{'multiple'} eq '1'){
	    $ismult = "1";
	}
	if($ismult eq "1"){
            $szenario->{$key1}{'true'} = $trues;
            $szenario->{$key1}{'false'} = $falses;
	    }else{
	    my $sizet =scalar @{$trues};
	    my $sizef =scalar @{$falses};
	    $szenario->{$key1}->{'true'} = @{$trues}[${int(rand($sizet))}];
	    $szenario->{$key1}->{'false'} = @{$falses}[${int(rand($sizef))}];
	}
    }
    return $szenario;
}
#----------------------------------------------------------
sub build_url{
    my %tests = %{(shift)};
    my $para = shift;
    my $truefalse = shift;
    my $success = "-1";
    my $string = $URL.lcfirst($API)."?";
    print $para, " ";
    if( ref(%tests->{$para}->{$truefalse}) eq 'ARRAY'){
	print "[";
	foreach (@{%tests->{$para}->{$truefalse}}){
	    $string = $string."$para=$_;";
	}
	print join(',',@{%tests->{$para}->{$truefalse}});
	print "] ";
    } else{
	print %tests->{$para}->{$truefalse}, " ";
	$string = $string.$para."=".%tests->{$para}->{$truefalse}.";";
    }
    if($truefalse eq 'true'){
	$success = "1";
    }
    if($truefalse eq 'false'){
	$success = "0";
    }
    return ($string, $success); 
};
#----------------------------------------------------------
sub test_url {
    my $string="\"".@_[0]."\"";
    my $result = @_[1];
#    print "string: ", $string, "\n";
#    print "result: ", $result, "\n";
    my @args = ("wget -O - --server-response", $string, "2>&1 | awk '/^  HTTP/{print \$2}'"); 
    my $output = `@args`;
    if ( $output =~ m/200/){
	print "accepted ";
	if($result =~ m/^1$/){
	    print "success ";
	} else{
	    print "fail ";
	}
    } elsif( $output =~ m/400/){
	print "rejected ";
#	my $why = `w3m $string`;
#	print "FAIL: $why \n";
#	print "FAIL\n";
	if($result =~ m/^0$/){
	    print "success ";
	}else{
	    print "fail ";
        }
    } else{
	print "unknown:$output:fail ";
    }
    $string =~ s/^.(.*).$/$1/;;
    print $string;
    print "\n";
    return $output;
}


exit;
