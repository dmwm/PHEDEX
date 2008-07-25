package PHEDEX::Core::Inject;

=head1 NAME

PHEDEX::Core::Inject - encapsulated SQL for writing CMS data
structures (datasets, blocks and files) to TMDB

=head1 SYNOPSIS

 use PHEDEX::Core::Inject;
 print "Injecting one DBS...\n";
 my $dbs = &PHEDEX::Core::Inject::createDBS($self, 
                                            NAME => 'rickTestDBS',
                                            DLS => 'rickTestDBS',
                                            TIME_CREATE => $now);

 print "Done.  dbs id=$dbs\n";

 print "Injecting one dataset...\n";
 my $datasets = [{ DBS => $dbs,
                   NAME => '/rick/test/dataset',
                   IS_TRANSIENT => 'n' }];

 &PHEDEX::Core::Inject::bulkCreateDatasets( $self,
	 			 	    $datasets,
					    TIME_CREATE => $now );
 my $ds_id = $datasets->[0]->{ID};
 print "Done.  dataset id=$ds_id\n";
 print Dumper($datasets), "\n";

 print "Injecting one block...\n";
 my $blocks = [{ DATASET => $ds_id,
		 NAME => '/rick/test/block#1' }];
 &PHEDEX::Core::Inject::bulkCreateBlocks( $self,
					  $blocks,
					  TIME_CREATE => $now );
 my $b_id = $blocks->[0]->{ID};
 print "Done.  block id=$b_id\n";
 print Dumper($blocks), "\n";

 print "Injecting some files...\n";
 my $files = [];
 for my $n (1..10) {
     push @$files, { NODE => 1,
	 	     BLOCK => $b_id,
		     LOGICAL_NAME => "/rick/test/file-${n}.root",
		     CHECKSUM => int(rand(100000)),
		     SIZE => int(rand(100000)) };
 }

 &PHEDEX::Core::Inject::bulkCreateFiles( $self,
					 $files,
					 TIME_CREATE => $now );
 print "Done.\n";


=head1 DESCRIPTION

Contains methods for writing CMS data structures (datasets, blocks and
files) to the TMDB.  These methods are "bulk" operations optimized for
write efficiency.  With the exception of the injectData() function,
duplicate entries will trigger an ORACLE error so the data to be
injected must be checked for duplicates beforehand.  This module
provides methods (see get*) to perform these checks.

Developer note: These 'bulk' insertion methods were debeloped with
DBD::Oracle 1.21 bind_param_inout_array in mind.  It turend out that
this function had serious memory problems in version 1.21, but will
hopefully be fixed in a future release.  If this method were to work
properly we could eliminate the expensive ID filling loops at the end
of each bulk insertion.

=head1 METHODS

=over

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use PHEDEX::Core::Timing;

use Carp;

our @EXPORT = qw( );

# Probably will never need parameters for this object, but anyway...
our %params =
	(
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

#-------------------------------------------------------------------------------
=pod

=item injectData($data, $src_node, %h)

Injects DBSes, datasets, blocks and files from a data structure $data
at the source node $src_node.

$data is a hashref of DBSes, datasets, blocks, and files of the
structure returned by PHEDEX::Core::XML::parseData.

Datasets and blocks are checked for existence and whether they are
open.  By default injecting blocks into closed datasets or files into
closed blocks will cause this function to die.  Injecting files which
already exist will cause this function to die.  This can be overridden
by setting STRICT => 0, in which case these conditions will be
skipped.  If VERBOSE => 1, then information about what was skipped is
printed.

Returns a hashref of statistics on what was done, including number of
datasets, blocks, and files injected and number of datasets and blocks
closed.

=cut

sub injectData
{
    my ($self, $data, $src_node, %h) = @_;

    die "injectData requires data!\n" unless $data;
    die "injectData requires a SOURCE_NODE\n" unless $src_node;

    my $verbose = exists $h{VERBOSE} ? $h{VERBOSE} : 1;
    my $strict = exists $h{STRICT} ? $h{STRICT} : 1;

    my $now = &mytimeofday();

    my $new_datasets = [];
    my $new_blocks = [];
    my $new_files = [];
    my $close_datasets = [];
    my $close_blocks = [];

    print "processing injections...\n" if $verbose;
    foreach my $dbs (values %{$data->{DBS}}) {
	unless ($dbs->{ID}) {
	    # try to fetch
	    my $db_dbs = &getDbs($self, DBS_NAME => $dbs->{NAME});
	    $dbs->{ID} = $db_dbs->{ID};

	    # insert
	    $dbs->{TIME_CREATE} = $now;
	    &createDBS($self, $dbs) unless $dbs->{ID};
	}

	foreach my $ds (values %{$dbs->{DATASETS}}) {
	    $ds->{DBS} = $dbs->{ID};
	    # try to fetch
	    my $db_ds = &getDataset($self,
				    DATASET_NAME => $ds->{NAME},
				    DBS_ID => $ds->{DBS});
	    if ($db_ds && $db_ds->{ID}) { # dataset exists
		$ds->{ID} = $db_ds->{ID};
	    } else {                      # dataset does not exist
		push @$new_datasets, $ds;
	    }

	    my $dataset_closed = ($db_ds && $db_ds->{IS_OPEN} eq 'n') ? 1 : 0;
	    if ($dataset_closed) { # dataset is closed, we will not consider it
		my $msg = "dataset $ds->{NAME} is closed";
		die "injectData error: $msg\n" if $strict;
		print "$msg ...skipping\n" if $verbose; next;
	    }

	    if ($ds->{IS_OPEN} eq 'n') { # dataset will be closed
		push @$close_datasets, $ds;
	    }

	    foreach my $b (values %{$ds->{BLOCKS}}) {
		$b->{DATASET_REF} = \$ds->{ID};

		my $db_b;
		if ($ds->{ID}) {
		    # try to fetch (and lock)
		    $db_b = &getBlock($self,
				      BLOCK_NAME => $b->{NAME},
				      DATASET_ID => $ds->{ID},
				      LOCK => 1);
		}

		if ($db_b && $db_b->{ID}) { # block exists
		    $b->{ID} = $db_b->{ID};
		} else { # block does not exist
		    push @$new_blocks, $b;			
		}

		my $block_closed = ($db_b && $db_b->{IS_OPEN} eq 'n') ? 1 : 0;
		if ($b->{IS_OPEN} eq 'n' && !$block_closed) { # block will be closed
		    push @$close_blocks, $b;
		}

		my $dbfiles = &getLFNsFromBlocks($self, $b->{NAME});

		foreach my $f (values %{$b->{FILES}}) {
		    $f->{BLOCK_REF} = \$b->{ID};
		    if (grep($_ eq $f->{LOGICAL_NAME}, @$dbfiles)) { # file exists
			my $msg = "file $f->{LOGICAL_NAME} exists";
			die "injectData error: $msg\n" if $strict;
			print "$msg ...skipping\n" if $verbose; next;
		    } else { # file does not exist
			if (!$block_closed) {
			    $f->{NODE} = $src_node;
			    push @$new_files, $f;
			} else {
			    my $msg = "block $b->{NAME} is closed, cannot inject new file";
			    die "injectData error: $msg\n" if $strict;
			    print "$msg ...skipping\n" if $verbose; next;
			}
		    }
		} # /file
	    } # /block
	} # /dataset
    } # /dbs	

    # inject everything we need to
    my %stats;
    print "inserting data.\n" if $verbose;
    $stats{'new datasets'} = &bulkCreateDatasets($self, $new_datasets, TIME_CREATE => $now);
    $stats{'new blocks'} = &bulkCreateBlocks($self, $new_blocks, TIME_CREATE => $now);
    $stats{'new files'} = &bulkCreateFiles($self, $new_files, TIME_CREATE => $now, NO_ID => 1);
    $stats{'closed datasets'} = &bulkCloseDatasets($self, $close_datasets, TIME_UPDATE => $now);
    $stats{'closed blocks'} = &bulkCloseBlocks($self, $close_blocks, TIME_UPDATE => $now);

    return \%stats;
}

=pod

=item createDBS(%h)

Creates a DBS in TMDB and returns its id.  Input is a hashref containing
the following.

Required arguments:
 NAME   : the name of the DBS
 DLS    : the name of the DLS to use with this DBS

Optional arguments:
 TIME_CREATE : the time this DBS was created (default current time)

ID is set with the created DBS id

returns the DBS hashref

=cut

sub createDBS
{
    my ($self, $dbs) = @_;
    foreach ( qw(NAME DLS TIME_CREATE) ) {
	die "createDBS:  $_ is a required parameter\n" unless $dbs->{$_};
    }
    
    my $sql =  qq{
	insert into t_dps_dbs (id, name, dls, time_create)
	values (seq_dps_dbs.nextval, :name, :dls, :time_create)
	returning id into :id };

    my $dbs_id;
    &execute_sql( $self, $sql, 
		  ":name" => $dbs->{NAME},
		  ":dls" => $dbs->{DLS},
		  ":id" => \$dbs->{ID},
		  ":time_create" => $dbs->{TIME_CREATE} || &mytimeofday()
		  );
    
    return 1;
}

=pod

=item bulkCreateDatasets($datasets, %h)

Creates new datasets in TMDB from an array reference $datasets
containing hashrefs which contain the dataset attributes.  The
required attributes are:

 DBS          : the DBS id, which DBS these datasets belong to
 NAME         : the dataset name
 IS_TRANSIENT : whether the dataset can be automatically removed from TMDB

The remaining hash of arguments %h may optionally contain the following:

 TIME_CREATE : timestamp for dataset creation time, default is the current time
 NO_ID       : if true, the IDs of the new $datasets are not retrieved

Datasets are created with is_open=y.

Each dataset in $datasets will have its ID attribute set when this function runs.

Returns the $datasets hashref.

=cut

sub bulkCreateDatasets
{
    my ($self, $datasets, %h) = @_;
    return 0 if (!$datasets || ! scalar @$datasets);

    my $sql = qq{
	insert into t_dps_dataset (id, dbs, name, is_open, is_transient, time_create)
	values (seq_dps_dataset.nextval, ?, to_char(?), 'y', ?, ?) };
    
    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $ds (@$datasets) {
	$n = 1;
	push(@{$binds{$n++}}, $ds->{DBS} || ${$ds->{DBS_REF}});
	push(@{$binds{$n++}}, $ds->{NAME});
	push(@{$binds{$n++}}, $ds->{IS_TRANSIENT});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    &execute_sql($self, $sql, %binds);

    unless ($h{NO_IDS}) {
	foreach my $ds (@$datasets) {
	    
	    my $db_ds = &getDataset($self,
				    DATASET_NAME => $ds->{NAME},
				    DBS_ID => $ds->{DBS} || ${$ds->{DBS_REF}});
	    $ds->{ID} = $db_ds->{ID};
	}
    }

    return scalar @$datasets;
}

=pod

=item bulkCreateBlocks($blocks, %h)

Creates new blocks in TMDB from an array reference $blocks
containing hashrefs which contain the block attributes.  The
required attributes are:

 DATASET      : the DATASET id, which dataset these blocks belong to
 NAME         : the block name

The remaining hash of arguments %h may optionally contain the following:

 TIME_CREATE : timestamp for dataset creation time, default is the current time
 NO_ID       : if true, the IDs of the new $blocks are not retrieved

Blocks are created with is_open=y, zero files and zero bytes.

Each block in $blocks will have its ID attribute set when this function runs.

Returns the $blocks hashref.

=cut


sub bulkCreateBlocks
{
    my ($self, $blocks, %h) = @_;
    return 0 if (!$blocks || ! scalar @$blocks);

    my $sql = qq{
	insert into t_dps_block (id, dataset, name, files, bytes, is_open, time_create)
        values (seq_dps_block.nextval, ?, to_char(?), 0, 0, 'y', ?)  };

    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $b (@$blocks) {
	$n = 1;
	push(@{$binds{$n++}}, $b->{DATASET} || ${$b->{DATASET_REF}});
	push(@{$binds{$n++}}, $b->{NAME});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    &execute_sql($self, $sql, %binds);

    unless ($h{NO_IDS}) {
	my $bid_sql = qq{ select id from t_dps_block where name = to_char(:name) };
	foreach my $b (@$blocks) {
	    my $db_b = &getBlock($self,
			      BLOCK_NAME => $b->{NAME},
			      DATASET_ID => $b->{DATASET} || ${$b->{DATASET_REF}});
	    $b->{ID} = $db_b->{ID};
	}
    }

    return scalar @$blocks;
}

=pod

=item bulkCreateFiles($files, %h)

Creates new files in TMDB with a replica at the files originating node
from an array reference $files containing hashrefs which contain the
file attributes.  The required attributes are:

 BLOCK        : the block id, which block these files belong to
 NODE         : the node id, for the origin node of these files
 LOGICAL_NAME : the logical file name
 SIZE         : number of bytes
 CHECKSUM     : cksum checksum

The remaining hash of arguments %h may optionally contain the following:

 TIME_CREATE : timestamp for dataset creation time, default is the current time
 NO_REPLICAS : if true, then replicas at each file NODE will not be created
 NO_ID       : if true, then the IDs of the new $files are not be retrieved

Each file in $files will have its ID attribute set when this function runs.

Returns the $files hashref.

=cut

sub bulkCreateFiles
{
    my ($self, $files, %h) = @_;
    return 0 if (!$files || ! scalar @$files);

    my $file_sql = qq{
	insert into t_dps_file
	(id, node, inblock, logical_name, checksum, filesize, time_create)
	values (seq_dps_file.nextval, ?, ?, to_char(?), ?, ?, ?) 
    };

    my $xfer_sql = qq{
	insert into t_xfer_file
	(id, inblock, logical_name, checksum, filesize)
	(select id, inblock, logical_name, checksum, filesize
	  from t_dps_file where logical_name = to_char(?)) };

    my $rep_sql = qq{
	insert into t_xfer_replica
	(id, fileid, node, state, time_create, time_state)
	(select seq_xfer_replica.nextval, id, node, 0, time_create, time_create
	  from t_dps_file where logical_name = to_char(?)) };

    my $now = &mytimeofday();

    my %binds;
    
    # Input parameter arays
    my $n = 1;
    foreach my $file (@$files) {
	$n = 1;
	push(@{$binds{$n++}}, $file->{NODE});
	push(@{$binds{$n++}}, $file->{BLOCK} || ${$file->{BLOCK_REF}});
	push(@{$binds{$n++}}, $file->{LOGICAL_NAME});  # LFNs are param 3
	push(@{$binds{$n++}}, $file->{CHECKSUM});
	push(@{$binds{$n++}}, $file->{SIZE});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    &execute_sql($self, $file_sql, %binds);

    # Bulk inject the xfer_files and xfer_replicas
    # LFNs are param 3
    &execute_sql($self, $xfer_sql, '1' => $binds{3});
    &execute_sql($self, $rep_sql, '1' => $binds{3}) unless $h{NO_REPLICAS};

    # Add created IDs to file hashrefs
    unless ($h{NO_ID}) {
	foreach my $f (@$files) {
	    my $db_f = &getFile($self, ':lfn' => $f->{LOGICAL_NAME});
	    $f->{ID} = $db_f->{ID};
	}
    }

    return scalar @$files;
}

=pod

=item bulkCloseDatasets($datasets, %h)

Closes all datasets (and blocks in the dataset) in arrayref $datasets using their ID.

=cut

sub bulkCloseDatasets
{
    my ($self, $datasets, %h) = @_;
    return 0 if (!$datasets || ! scalar @$datasets);    

    my $sql1 = qq{ update t_dps_dataset
		      set is_open = 'n', time_update = ?
		    where id = ? };
    my $sql2 = qq{ update t_dps_block
                      set is_open = 'n', time_update = ?
		    where dataset = ? };

    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $ds (@$datasets) {
	$n = 1;
	push(@{$binds{$n++}}, $h{TIME_UPDATE} || $now);
	push(@{$binds{$n++}}, $ds->{ID});
    }

    &execute_sql($self, $sql1, %binds);
    &execute_sql($self, $sql2, %binds);

    return scalar @$datasets;
}

=pod

=item bulkCloseBlocks($blocks, %h)

Closes all blocks in arrayref $blocks using their ID.

=cut

sub bulkCloseBlocks
{
    my ($self, $blocks, %h) = @_;
    return 0 if (!$blocks || ! scalar @$blocks);
    
    my $sql = qq{ update t_dps_block
	          set is_open = 'n', time_update = ?
		  where id = ?};

    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $b (@$blocks) {
	$n = 1;
	push(@{$binds{$n++}}, $h{TIME_UPDATE} || $now);
	push(@{$binds{$n++}}, $b->{ID});
    }

    &execute_sql($self, $sql, %binds);

    return scalar @$blocks;
}


=pod

=item getDbs(%h)

Returns a DBS as a hashref given its NAME.

=cut

sub getDbs
{
    my ($self, %h) = @_;
    my $sql = qq{ select * from t_dps_dbs where name = :name };
    my $q = execute_sql($self, $sql, ':name' => $h{DBS_NAME});
    return $q->fetchrow_hashref();
}

=pod

=item getDatasetID(%h)

Returns a dataset as a hashref given its DATASET_NAME and DBS_ID.

=cut

sub getDataset
{
    my ($self, %h) = @_;

    my $sql = qq{ select * from t_dps_dataset
		   where dbs = :dbs and name = :name };

    my $q = execute_sql($self, $sql, 
			':name' => $h{DATASET_NAME},
			':dbs'  => $h{DBS_ID});

    return $q->fetchrow_hashref();
}

=pod

=item getBlock(%h)

Returns a block as a hashref given its BLOCK_NAME and DATASET_ID.

=cut

sub getBlock
{
    my ($self, %h) = @_;

    my $sql = qq{ select * from t_dps_block
		   where name = :name
		    and dataset = :dataset };
    $sql.= ' for update' if $h{LOCK};
    
    my $q = execute_sql($self, $sql,
			':name' => $h{BLOCK_NAME},
			':dataset' => $h{DATASET_ID});

    return $q->fetchrow_hashref();
}

=pod

=item getFile(%h)

Returns a file as a hashref given its LOGICAL_NAME

=cut

sub getFile
{
    my ($self, %h) = @_;

    my $sql = qq{ select * from t_dps_file where logical_name = :lfn };
    
    my $q = execute_sql($self, $sql,
			':lfn' => $h{LOGICAL_NAME});

    return $q->fetchrow_hashref();
}


1;

=pod

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
