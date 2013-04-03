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

sub dascheck {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($tmp, $workflow, $i);
    $tmp = $payload->{workflow}->{'Phedex'};
    my $tmp2 = $payload->{workflow}->{'DASP'};#->{'data'};
    my $tmp3 = $payload->{workflow}->{'DASD'};#->{'data'};
    $self->Logmsg("workflow->Phedex=,",Data::Dumper->Dump([$tmp]),")\n");
    $self->Logmsg("workflow->DASP,",Data::Dumper->Dump([$tmp2]),")\n");
    $self->Logmsg("workflow->DASD,",Data::Dumper->Dump([$tmp3]),")\n");
   $kernel->yield('nextEvent',$payload);
    return $payload;
}
sub check {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($tmp, $workflow, $i);
#    $tmp = $payload->{workflow};
#    $self->Logmsg("Payload before das: ",Data::Dumper->Dump([$payload]), "\n");
    my $myjson = encode_json $payload;
    $self->Dbgmsg("PAYLOAD JSON: ",Data::Dumper->Dump([$myjson]), "\n");
    $kernel->yield('nextEvent',$payload);
    return $payload;
}

sub errorhandler {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($data, $workflow, $i,$j,$k, @errors, $block, $file, $filename, $dataset);

    $payload->{workflow}->{data} = $payload->{workflow}->{'Phedex'};

    my $blocksize = 0;
    my @skippedevts = ();
    my @errorsmsg = ("PhedexSkipFileFail", "PhedexChangeCksumFail" , "PhedexChangeSizeFail");
    
    $data = $payload->{workflow}->{data};
#    $data = $payload->{workflow}->{'Phedex'};
##    my $copy = clone ($data);
##    $payload->{workflow}->{data_orig}=$copy;
#    $self->Logmsg("workflow->data=,",Data::Dumper->Dump([$data]),")\n\n\n\n");
#    $self->Logmsg("workflow->Phedex=,",Data::Dumper->Dump($payload->{workflow}->{'Phedex'}),")\n\n\n\n");
    
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
                my @skipped_file=splice(@{$block->{files}}, $_, 1);
		push(@{$block->{skipped_files}},@skipped_file);
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


sub compare_das{
    # Consistency check DAS output vs. injected data to phedex-integ.cern.ch
    # All files should be the same
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($tmp, $data_phedex, $data_das , $workflow, $i,$j,$k, $l, $idas, $jdas, $kdas, $block_phedex, $block_das, $file_phedex, $file_das, $filename_phedex, $filename_das, $dataset_phedex, $dataset_das);
    
    $self->Logmsg("Start check Injected(Phedex) against DAS(Phedex):\n");

    # Injected data:
    $data_phedex = $payload->{workflow}->{data};
    # Data received from DAS query
    $data_das    = $payload->{workflow}->{DASP};
    my $all_files = 0;
    my $found_files = 0;
    my $failed_files = 0;
    my @skipped = ();
    foreach $i ( @{$data_phedex} ) {
	$dataset_phedex = $i->{dataset};
        foreach $j ( @{$dataset_phedex->{blocks}} ) {
            $block_phedex = $j->{block};
	    foreach $l ( @{$block_phedex->{skipped_files}} ) {
		push (@skipped,$l->{file}->{name});
	    }
            foreach $k ( @{$block_phedex->{files}} ) {
		$all_files++;
		my $fail = 1;
		my $found = 0;
                $file_phedex = $k->{file};
                $filename_phedex = $file_phedex->{name};
		foreach $idas ( @{$data_das} ) {
		    my $block_das = $idas->{data};
		    foreach $jdas (@{$block_das}) {
			$file_das=$jdas->{file};
			foreach $kdas (@{$file_das}){
			    next if( !defined $kdas->{checksum});
			    $filename_das=$kdas->{name};
			    if ( $filename_das =~ /$filename_phedex/ ){
				$fail = 0;
				$found = 1;
				my @checksums= split(',',$file_phedex->{checksum});
				my @val1 = split(':',$checksums[0]);
				my @val2 = split(':',$checksums[1]);
				if ( ($kdas->{adler32} != $val2[1]) || ($kdas->{checksum} != $val1[1]) ){
				    $fail = 1;
				    $self->Logmsg("File $filename_phedex failed due to checksum check\n");
                                }
				if ( $kdas->{size} !=  $file_phedex->{bytes} ){
				    $fail = 1;
				    $self->Logmsg("File $filename_phedex failed due to size check\n");
				}
			    }
			    last if $found==1;
			}
		    }
		}
		if( $found != 0 ) {
		    $found_files++;
		}
		$failed_files += $fail;
            }
        }
    }
#    $self->Logmsg("$found_files / $all_files files found, $failed_files failed\n");
    if($found_files==$all_files && $failed_files == 0){
	$self->Logmsg("All $all_files files passed the checks\n");
    }
    else{
	my $failure=$all_files;
	$failure -= $found_files;
	$self->Logmsg("!!! $failure files not found! $failed_files files failed the checks\n");
	return 245;
    }
    my $correctSkip=0;
    my $item;
    foreach $item (@skipped){
	if( $item =~ /PhedexSkipFileFail/ ){
	    $correctSkip++;
	}
    }
    my $noskipped=@skipped;

    if( $noskipped == $correctSkip ){
	$self->Logmsg("... This is correct! \n");
    }
    else{
	$self->Logmsg("... This is NOT correct!!!! \n");
	return 246;
    }
    $kernel->yield('nextEvent',$payload);
    return $payload;
}


sub compare_dbsphedex{
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($data_phedex, $data_dbs , $workflow, $i,$j,$k, $l, $idbs, $jdbs, $kdbs, $block_phedex, $block_dbs, $file_phedex, $file_dbs, $filename_phedex, $filename_dbs, $dataset_phedex, $dataset_dbs);

    $self->Logmsg("Start check DAS(DBS) against DAS(Phedex):\n");

    $data_phedex = $payload->{workflow}->{DASP};
    $data_dbs    = $payload->{workflow}->{DASD};
    my $all_files = 0;
    my $found_files = 0;
    my $failed_files = 0;
    my $true_failed_files = 0;
    my @phedex_notfound = ();

    foreach $i ( @{$data_phedex} ) {
	$block_phedex = $i->{data};
	foreach $j (@{$block_phedex}) {
	    $file_phedex=$j->{file};
	    foreach $k (@{$file_phedex}){
		next if( !defined $k->{checksum});
		$filename_phedex=$k->{name};
		$all_files++;
		my $failcs = 1;
		my $fails  = 1;
		my $truefailcs  = 0;
		my $truefails  = 0;
		my $found = 0;
		foreach $idbs ( @{$data_dbs} ) {
		    $block_dbs = $idbs->{data};
		    foreach $jdbs (@{$block_dbs}) {
		    $file_dbs=$jdbs->{file};
			foreach $kdbs (@{$file_dbs}){
			    next if( !defined $kdbs->{check_sum});
			    $filename_dbs=$kdbs->{name};
			    if ( $filename_dbs =~ /$filename_phedex/ ){
				$failcs = 0;
				$fails = 0;
				$found = 1;
				if ( ($kdbs->{adler32} != $k->{adler32})||($kdbs->{check_sum} != $k->{checksum})){
				    if( $filename_phedex =~ /ChangeCksumFail/){
					$truefailcs  = 1;
				    }
				    else{
					$failcs = 1;
					$self->Logmsg("$filename_phedex NOT correct!\n");
				    }
                                }
				if ( $kdbs->{size} !=  $k->{size} ){
				    if( $filename_phedex =~ /ChangeSizeFail/){
					$truefails  = 1;
				    }
				    else{
					$fails = 1;
					$self->Logmsg("$filename_phedex NOT correct!\n");
				    }
				}
			    }
			}
		    }
		    #workaroud because dataset is checked in dbs 3 times (?)
		    last;
		}
		if( $found != 0 ) {
		    $found_files++;
		}
		else{
		    push (@phedex_notfound,$filename_phedex);
		}
		if ( $fails==1 || $failcs==1 ){
		    $failed_files += 1;
		}
		if ( ($truefails==1 || $truefailcs==1) && ( $fails==0 && $failcs==0 ) ){
		    $true_failed_files += 1;
		}
            }
        }
    }
    $self->Logmsg("$all_files files were found in DAS(Phedex)");
    my $correctNotfound=0;
    my $item;
    foreach $item (@phedex_notfound){
        if( $item =~ /DBSSkipFileFail/ ){
            $correctNotfound++;
        }
    }
    my $noskipped=@phedex_notfound;
    $self->Logmsg("$found_files / $all_files these files found in DAS(DBS), $failed_files failed\n");
    if( ($noskipped == $correctNotfound) && ($noskipped == $failed_files) ){
        $self->Logmsg("... This is correct! (include \"DBSSkipFileFail\") \n");
    }
    else{
        $self->Logmsg("... This is NOT correct!!!! \n");
        return 246;
    }
   $self->Logmsg("$true_failed_files files have different size and/or checksum in DAS(DBS) and DAS(Phedex) intentionally\n");
    $kernel->yield('nextEvent',$payload);
    return $payload;
}


sub compare_phedexdbs{
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($data_dbs, $data_phedex , $workflow, $i,$j,$k, $l, $iphedex, $jphedex, $kphedex, $block_dbs, $block_phedex, $file_dbs, $file_phedex, $filename_dbs, $filename_phedex, $dataset_dbs, $dataset_phedex);

    $self->Logmsg("Start check DAS(Phedex) against DAS(DBS):\n");

    $data_phedex = $payload->{workflow}->{DASP};
    $data_dbs    = $payload->{workflow}->{DASD};
    my $all_files = 0;
    my $found_files = 0;
    my $failed_files = 0;
    my $true_failed_files = 0;
    my @dbs_notfound = ();

    foreach $i ( @{$data_dbs} ) {
	$block_dbs = $i->{data};
	foreach $j (@{$block_dbs}) {
	    $file_dbs=$j->{file};
	    foreach $k (@{$file_dbs}){
		next if( !defined $k->{check_sum});
		$filename_dbs=$k->{name};
		$all_files++;
		my $failcs = 1;
		my $fails  = 1;
		my $truefails = 0;
		my $truefailcs = 0;
		my $found = 0;
		foreach $iphedex ( @{$data_phedex} ) {
		    $block_phedex = $iphedex->{data};
		    foreach $jphedex (@{$block_phedex}) {
			$file_phedex=$jphedex->{file};
			foreach $kphedex (@{$file_phedex}){
			    next if( !defined $kphedex->{checksum});
			    $filename_phedex=$kphedex->{name};
			    if ( $filename_phedex =~ /$filename_dbs/ ){
				$failcs = 0;
				$fails = 0;
				$found = 1;
				if ( ($kphedex->{adler32} != $k->{adler32})|| ($kphedex->{checksum} != $k->{check_sum})){
				    if( $filename_dbs =~ /ChangeCksumFail/){
					$truefailcs = 1;
				    }
				    else{
					$failcs = 1;
					$self->Logmsg("$filename_dbs NOT correct!\n");
				    }
                                }
				if ( $kphedex->{size} !=  $k->{size} ){
				    if( $filename_dbs =~ /ChangeSizeFail/){
					$truefails = 1;
				    }
				    else{
					$fails = 1;
					$self->Logmsg("$filename_dbs NOT correct!\n");
				    }
				}
			    }
			}
		    }
		}
		if( $found != 0 ) {
		    $found_files++;
		}
		else{
		    push (@dbs_notfound,$filename_dbs);
		}
		if ( $fails==1 || $failcs==1 ){
		    $failed_files += 1;
		}
		if ( ($truefails==1 || $truefailcs==1) && ( $fails==0 && $failcs==0 ) ){
                    $true_failed_files += 1;
                }
            }
        }
	#workaroud because dataset is checked in dbs 3 times (?)
	last;
    }

    $self->Logmsg("$all_files files were found in DAS(DBS)");
    my $correctNotfound=0;
    my $item;
    foreach $item (@dbs_notfound){
        if( $item =~ /PhedexSkipFileFail/ ){
            $correctNotfound++;
        }
    }
    my $noskipped=@dbs_notfound;
    $self->Logmsg("$found_files / $all_files these files found in DAS(Phedex), $failed_files failed\n");
    if( ($noskipped == $correctNotfound) && ($noskipped == $failed_files) ){
        $self->Logmsg("... This is correct! (include \"PhedexSkipFileFail\") \n");
    }
    else{
        $self->Logmsg("... This is NOT correct!!!! \n");
        return 246;
    }
    $self->Logmsg("$true_failed_files files have different size and/or checksum in DAS(DBS) and DAS(Phedex) intentionally\n");
    $kernel->yield('nextEvent',$payload);
    return $payload;
}

1;
