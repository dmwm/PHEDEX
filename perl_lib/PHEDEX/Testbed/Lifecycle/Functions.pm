package PHEDEX::Testbed::Lifecycle::Functions;

use strict;
use warnings;
use POE;
use base 'PHEDEX::Testbed::Lifecycle::UA', 'PHEDEX::Core::Logging';
use Clone qw(clone);
use Data::Dumper;
use PHEDEX::CLI::UserAgent;
use JSON::XS;

our %params = (
	  Verbose       => undef,
          Debug         => undef,
	       );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { parent => shift };
    my $workflow = shift;

    my $package;
    $self->{ME} = $package = __PACKAGE__;
    $package =~ s%^$workflow->{Namespace}::%%;

    my $p = $workflow->{$package};
    map { $self->{params}{uc $_} = $params{$_} } keys %params;
    map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
    map { $self->{$_} = $p->{$_} } keys %{$p};

    $self->{Verbose} = $self->{parent}->{Verbose};
    $self->{Debug}   = $self->{parent}->{Debug};
    bless $self, $class;
    return $self;
}


sub switch {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($tmp, $workflow, $i);
    $payload->{workflow}->{data} = $payload->{workflow}->{'Phedex'};
    $kernel->yield('nextEvent',$payload);
    return $payload;
}

sub errorhandler {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($data, $workflow, $i,$j,$k, @errors, $block, $file, $filename, $dataset);

    my $blocksize = 0;
    my @skippedevts = ();
    my @errorsmsg = ("PhedexSkipFileFail", "PhedexChangeCksumFail" , "PhedexChangeSizeFail");

    $data = $payload->{workflow}->{data};

    foreach $i ( @{$data} ) {
        $dataset = $i->{dataset};
        foreach $j ( @{$dataset->{blocks}} ) {
            $block = $j->{block};
            my $fileit = -1;
            foreach $k ( @{$block->{files}} ) {
                $fileit += 1;
                $file = $k->{file};
                $filename = $file->{name};
                if ( $filename =~ /$errorsmsg[0]/ ){
                    push(@skippedevts, $fileit);
                    next;
                }
                if ( $filename =~ /$errorsmsg[1]/ ){
                    my @checksums= split(',',$file->{checksum});
                    my @val1 = split(':',$checksums[0]);
                    my @val2 = split(':',$checksums[1]);
                    $val1[1]+=1;
                    $val2[1]+=1;
                    $file->{checksum} = $val1[0].':'.$val1[1].','.$val2[0].':'.$val2[1];
                }
                if ( $filename =~ /$errorsmsg[2]/ ){
                    $file->{bytes} += 10;
                    $block->{size} += 10;
		}
                $blocksize += $file->{bytes};
                $k->{file} = $file;
            }
            @skippedevts= sort{ $b <=> $a} @skippedevts;
            foreach ( @skippedevts ) {
                $block->{size} -= $block->{files}[$_]->{file}->{bytes};
                $block->{nfiles}-=1;
                splice(@{$block->{files}}, $_, 1);
            }
            $j->{block} = $block;
            $blocksize = 0;
            @skippedevts = ();
        }
	$i->{dataset} = $dataset;
    }
    $payload->{workflow}->{data} = $data;

    $kernel->yield('nextEvent',$payload);
    return $payload;
}



1;
