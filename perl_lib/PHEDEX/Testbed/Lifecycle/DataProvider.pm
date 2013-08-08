package PHEDEX::Testbed::Lifecycle::DataProvider;
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use POE;
use JSON::XS;
use File::Path;
use File::Basename;
use Data::Dumper;

our %params = (
	  DATAPROVIDER => 'dataprovider --system phedex',
	);

sub new {
  my $proto = shift;
  my $parent = shift;
  my $workflow = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new();
  $self->{parent} = $parent;

  my $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;
  $self->{ME} = $package;

  my $p = $workflow->{$package};
  map { $self->{$_} = $params{$_} } keys %params;
  map { $self->{$_} = $p->{$_} } keys %{$p};

  bless $self, $class;

  return $self;
}

sub register { PHEDEX::Testbed::Lifecycle::Agent::register(@_); }

sub generate {
  my ($self,$kernel,$session,$payload,$args) = @_;
  my ($workflow,@cmd,$cmd,$json,$postback,$in,$out,$log,$tmp,$timeout);
  $self->{PARENT_SESSION} = $session unless $self->{PARENT_SESSION};
  $cmd = $args->{cmd};

  $workflow = $payload->{workflow};
  $tmp = $workflow->{TmpDir};
  if ( ! -d $tmp ) {
    mkpath($tmp) || $self->Fatal("Cannot mkdir $tmp: $!\n");
  }

  $tmp = $self->{parent}->tmpFile($payload);
  ($in,$out,$log) = map { $tmp . $_ } ( 'in', 'out', 'log' );
  @cmd = split(' ',$cmd);
  push @cmd, ('--in',$in) unless $args->{no_input};
  push @cmd, ('--out',$out);

# TW
# Should not need to protect for $no_input, and should pass $payload to the
# JSON encoder, but the dataprovider doesn't yet understand the full payload
# structure
  if ( ! $args->{no_input} ) {
    $json = encode_json($workflow->{data}); # TODO should be ($payload);
    open IN, ">$in" or $self->Fatal("open $in: $!\n");
    print IN $json;
    close IN;
  }

  $self->register($args->{callback});
  $postback = $session->postback($args->{callback},$payload,$in,$out,$log,join(' ',@cmd));
  $timeout = $workflow->{Timeout} || 999;
  $self->{parent}{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub makeDataset {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $self->register('madeDataset');
  $workflow = $payload->{workflow};
  $workflow->{Datasets} = 1 unless defined $workflow->{Datasets};
  $cmd  = $self->{DATAPROVIDER} . ' --generate datasets ';
  $cmd .= "--num $workflow->{Datasets} ";

  $self->Logmsg('makeDataset: creating ',$workflow->{Datasets},' datasets');
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'madeDataset',
		   cmd      => $cmd,
		   no_input => 1,
		  }
		  );
}

sub madeDataset {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  my ($payload,$workflow,$in,$out,$log,$result,$name,$i);

  $result = $self->{parent}->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $workflow = $payload->{workflow};

# TW Override the dataset name explicitly!
  if ( $workflow->{Dataset} ) {
    $i = 0;
    foreach ( @{$result} ) {
      $_->{dataset}{name} = sprintf($workflow->{Dataset},$i++);
    }
  }

# TW Override the DBS name explicitly!
  if ( $workflow->{DBS} ) {
    foreach ( @{$result} ) {
      $_->{dataset}{dbs_name} = $workflow->{DBS};
    }
  }

  $workflow->{data} = $result;
  $kernel->yield('nextEvent',$payload);
}

sub makeBlocks {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $workflow = $payload->{workflow};
  $workflow->{blockCounter} = 0 unless defined $workflow->{blockCounter};
  $workflow->{Blocks}       = 1 unless defined $workflow->{Blocks};
  $cmd  = $self->{DATAPROVIDER} . ' --action add_blocks ';
  $cmd .= "--num $workflow->{Blocks} ";
  
  $self->Logmsg('makeBlocks: creating ',$workflow->{Blocks},' blocks per open dataset');
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'standardCallback',
		   cmd      => $cmd,
		  }
		  );
}

sub standardCallback {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  $arg0->[0]->{workflow}{data} = $self->{parent}->post_exec($arg0,$arg1);
  $kernel->yield('nextEvent',$arg0->[0]);
}

sub makeFiles {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $workflow = $payload->{workflow};
  $workflow->{Files} = 1 unless defined $workflow->{Files};
  $cmd  = $self->{DATAPROVIDER} . ' --action add_files ';
  $cmd .= "--num $workflow->{Files} ";
  
  $self->Logmsg('makeFiles: creating ',$workflow->{Files},' files per open block');
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'standardCallback',
		   cmd      => $cmd,
		  }
		  );
}

sub addData {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow,$event,$id,$datasets,$blocks,$files,$dataset,$dsname,$nClosed,@active);

  $workflow = $payload->{workflow};
  $event    = $workflow->{Event};
  $id       = $payload->{id};
  $datasets = $workflow->{Datasets};
  $blocks   = $workflow->{Blocks};
  $files    = $workflow->{Files};
  $dataset  = $workflow->{data}[0]{dataset};
  $dsname   = $dataset->{name};

# Delete closed blocks from the data-structure to limit growth, if so required.
  if ( $workflow->{DropClosedBlocks} ) {
    $nClosed = 0;
    foreach ( @{$dataset->{blocks}} ) {
      if ( $_->{block}{'is-open'} eq 'n' ) {
        $nClosed++;
      } else {
        push @active, $_;
      }
    }
    if ( $nClosed ) {
      $self->Logmsg("addData ($dsname): drop $nClosed closed blocks");
      $dataset->{blocks} = \@active;
    }
  }

# Take default block/file counts from the dataset. Take the last block for
# the number of files. May not be correct, but good enough!
  $workflow->{InjectionsThisBlock} ||= int(scalar @{$dataset->{blocks}[-1]{block}{files}}/$files);
  $workflow->{BlocksThisDataset}   ||=  scalar @{$dataset->{blocks}};
# TW N.B. Assume I have only one dataset!
  $self->Logmsg("addData ($dsname): $workflow->{BlocksThisDataset} blocks, $workflow->{InjectionsThisBlock} injections this block, $workflow->{BlocksPerDataset} blocks/dataset, $workflow->{InjectionsPerBlock} injections/block");

  $workflow->{InjectionsThisBlock}++;
  if ( $workflow->{InjectionsThisBlock} > $workflow->{InjectionsPerBlock} ) {
#   These blocks are full. Close them, and go on to the next set
    foreach ( @{$dataset->{blocks}} ) {
      $_->{block}{'is-open'} = 'n';
      $workflow->{blockCounter}++;
    }
    $self->Logmsg("addData ($dsname): close one or more blocks");
    $workflow->{BlocksThisDataset}++;
    if ( $workflow->{BlocksThisDataset} > $workflow->{BlocksPerDataset} ) {
      $self->Logmsg("addData ($dsname): all blocks are complete, terminating.");
      $kernel->yield('nextEvent',$payload);
      return;
    }

#   Start a new block
    $self->Logmsg("addData ($dsname): create one or more new blocks");
    $workflow->{InjectionsThisBlock} = 0;
    $kernel->call($session,'makeBlocks',$payload);
    PHEDEX::Testbed::Lifecycle::Agent::post_push($self,'addData',$payload);
    PHEDEX::Testbed::Lifecycle::Agent::post_unshift($self,'addData',$payload);
    return;
  }

# Add files, be it to a new or an existing block
  $self->Logmsg("addData ($dsname): add files to block(s)");
  $kernel->call($session,'makeFiles',$payload);
  PHEDEX::Testbed::Lifecycle::Agent::post_push($self,'addData',$payload);
  PHEDEX::Testbed::Lifecycle::Agent::post_unshift($self,'addData',$payload);
  return;
}

sub closeBlocks {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($data,$dataset,$dsname);
  my ($nDatasets,$nBlocks,$nOpenDatasets,$nBlocksClosed);

  $nDatasets = $nBlocks = $nOpenDatasets = $nBlocksClosed = 0;
  $data = $payload->{workflow}{data};
  $dsname = $data->[0]{dataset}{name};

  foreach $dataset ( @{$data} ) {
    $nDatasets++;
    next if ( $dataset->{dataset}{'is-open'} eq 'n' );
    $nOpenDatasets++;
    foreach ( @{$dataset->{dataset}{blocks}} ) {
      $nBlocks++;
      next if ( $_->{block}{'is-open'} eq 'n' );
      $nBlocksClosed++;
      $_->{block}{'is-open'} = 'n';
    }
  }
  $self->Logmsg("closeBlocks ($dsname): Closed $nBlocksClosed blocks in $nOpenDatasets open datasets (out of $nBlocks blocks in $nDatasets datasets)");
  $kernel->yield('nextEvent',$payload);
}
 
sub closeDatasets {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($data,$dataset,$dsname,$nDatasets,$nClosedDatasets);

  $self->register('closeBlocks');
  $kernel->call($session,'closeBlocks',$payload);
  $nDatasets = $nClosedDatasets = 0;
  $data   = $payload->{workflow}{data};
  $dsname = $data->[0]{dataset}{name};

  foreach $dataset ( @{$data} ) {
    $nDatasets++;
    next if ( $dataset->{dataset}{'is-open'} eq 'n' );
    $nClosedDatasets++;
    $dataset->{dataset}{'is-open'} = 'n';
  }
  $self->Logmsg("closeDatasets ($dsname): Closed $nClosedDatasets datasets out of $nDatasets total");
  $kernel->yield('nextEvent',$payload);
}
 
sub makeLinks {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($d,$f,$i,$j,$k,$l);
  my ($data,$dataset,$block,$file,$srcFile,$linkDir,$style,$workflow);

  $workflow = $payload->{workflow};
  $srcFile = $workflow->{makeLinks}{SrcFile};
  $linkDir = $workflow->{makeLinks}{LinkDir};
  $style   = $workflow->{makeLinks}{LinkStyle};
  $data    = $workflow->{data};
  -f $srcFile->{Name} ||
  -l $srcFile->{Name} or
     $self->Fatal("SrcFile '$srcFile->{Name}' not a file or symlink");

  $l = sprintf("%09s",$workflow->{blockCounter});
  foreach $i ( @{$data} ) {
    $dataset = $i->{dataset};
    foreach $j ( @{$dataset->{blocks}} ) {
      $block = $j->{block};
      foreach $k ( @{$block->{files}} ) {
        $file = $k->{file};
        $file->{name} =~ s%/000000000/%/$l/%;
        $f = $linkDir . $file->{name};
        next if -e $f;
        $d = dirname($f);
        -d $d || mkpath $d;
        if ( $style eq 'soft' ) {
          symlink $srcFile->{Name}, $f;
        } elsif ( $style eq 'hard' ) {
          link $srcFile->{Name}, $f;
        } else {
          $self->Fatal("LinkStyle parameter must be 'hard' or 'soft'");
        }
        $file->{bytes}    = $srcFile->{Size} if defined $srcFile->{Size};
        $file->{checksum} = $srcFile->{Checksum} if defined $srcFile->{Checksum};
      }
    }
  }
  $kernel->yield('nextEvent',$payload);
}
 
sub dumpData {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($i,$j,$k,$data,$dataset,$block,$file,$nDatasets,$nBlocks,$nFiles);

  $nDatasets = $nBlocks = $nFiles = 0;
  $data = $payload->{workflow}{data};
  foreach $i ( @{$data} ) {
    $dataset = $i->{dataset};
    $nDatasets++;
    print "dataset: name=\"$dataset->{name}\", is-open=\"$dataset->{'is-open'}\"\n";
    foreach $j ( @{$dataset->{blocks}} ) {
      $block = $j->{block};
      $nBlocks++;
      print "  block: name=\"$block->{name}\", is-open=\"$block->{'is-open'}\"\n";
      foreach $k ( @{$block->{files}} ) {
        $file = $k->{file};
        $nFiles++;
        print "    file: name=\"$file->{name}\" bytes=\"$file->{bytes}\" checksum=\"$file->{checksum}\"\n";
      }
    }
  }
  $self->Logmsg("dumpData: Total of $nDatasets datasets, $nBlocks blocks, and $nFiles files");
  $kernel->yield('nextEvent',$payload);
}

1;
