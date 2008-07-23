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
		     LFN => "/rick/test/file-${n}.root",
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
write efficiency.  Duplicate entries will trigger an ORACLE error so
the data to be injected must be checked for duplicates beforehand.

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

=item createDBS(%h)

Creates a DBS in TMDB and returns its id.  Input is a hash containing
the following.

Required arguments:
 NAME   : the name of the DBS
 DLS    : the name of the DLS to use with this DBS

Optional arguments:
 TIME_CREATE : the time this DBS was created (default current time)

=cut

sub createDBS
{
    my ($self, %h) = @_;
    foreach ( qw(NAME DLS TIME_CREATE) ) {
	die "createDBS:  $_ is a required parameter\n" unless $h{$_};
    }
    
    my $sql =  qq{
	insert into t_dps_dbs (id, name, dls, time_create)
	values (seq_dps_dbs.nextval, :name, :dls, :time_create)
	returning id into :id };

    my $dbs_id;
    &execute_sql( $self, $sql, 
		  ":name" => $h{NAME}, ":dls" => $h{DLS},
		  ":id" => \$dbs_id, ":time_create" => $h{TIME_CREATE} );
    
    return $dbs_id;
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

    my $sql = qq{
	insert into t_dps_dataset (id, dbs, name, is_open, is_transient, time_create)
	values (seq_dps_dataset.nextval, ?, to_char(?), 'y', ?, ?) };
    
    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $ds (@$datasets) {
	$n = 1;
	push(@{$binds{$n++}}, $ds->{DBS});
	push(@{$binds{$n++}}, $ds->{NAME});
	push(@{$binds{$n++}}, $ds->{IS_TRANSIENT});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    &execute_sql($self, $sql, %binds);

    unless ($h{NO_IDS}) {
	my $dsid_sql = qq{ select id from t_dps_dataset where name = to_char(:name) };
	foreach my $ds (@$datasets) {
	    $ds->{ID} = &select_scalar($self, $dsid_sql, ':name' => $ds->{NAME});
	}
    }

    return $datasets;
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

    my $sql = qq{
	insert into t_dps_block (id, dataset, name, files, bytes, is_open, time_create)
        values (seq_dps_block.nextval, ?, to_char(?), 0, 0, 'y', ?)  };

    my %binds;
    my $now = &mytimeofday();

    my $n;
    foreach my $b (@$blocks) {
	$n = 1;
	push(@{$binds{$n++}}, $b->{DATASET});
	push(@{$binds{$n++}}, $b->{NAME});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    &execute_sql($self, $sql, %binds);

    unless ($h{NO_IDS}) {
	my $bid_sql = qq{ select id from t_dps_block where name = to_char(:name) };
	foreach my $b (@$blocks) {
	    $b->{ID} = &select_scalar($self, $bid_sql, ':name' => $b->{NAME});
	}
    }

    return $blocks;
}

=pod

=item bulkCreateFiles($files, %h)

Creates new files in TMDB with a replica at the files originating node
from an array reference $files containing hashrefs which contain the
file attributes.  The required attributes are:

 BLOCK        : the block id, which block these files belong to
 NODE         : the node id, for the origin node of these files
 LFN          : the logical file name
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
	push(@{$binds{$n++}}, $file->{BLOCK});
	push(@{$binds{$n++}}, $file->{LFN});  # LFNs are param 3
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
	my $fileid_sql = qq{ select id from t_dps_file where logical_name = to_char(:lfn) };
	foreach my $file (@$files) {
	    $file->{ID} = &select_scalar($self, $fileid_sql, ':lfn' => $file->{LFN});
	}
    }

    return $files;
}

1;

=pod

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
