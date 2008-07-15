package PHEDEX::Core::Inject;

=head1 NAME

PHEDEX::Core::Inject - encapsulated SQL for injecting data into TMDB

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item method1($args)

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

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

sub bulkCreateDatasets
{
    my ($self, $datasets, %h) = @_;

    my $sql = qq{
	insert into t_dps_dataset (id, dbs, name, is_open, is_transient, time_create)
	values (seq_dps_dataset.nextval, :dbs, to_char(:name), 'y', :transient, :time_create)
	returning id into :id };

    foreach my $ds (@$datasets) {
	&execute_sql ( $self, $sql,
		       ":id" => \$ds->{ID},
		       ":dbs" => $ds->{DBS},
		       ":name" => $ds->{NAME},
		       ":transient" => $ds->{IS_TRANSIENT},
		       ":time_create" => $h{TIME_CREATE} || &mytimeofday() );
    }

    return $datasets;
}

sub bulkCreateBlocks
{
    my ($self, $blocks, %h) = @_;

    my $sql = qq{
	insert into t_dps_block (id, dataset, name, files, bytes, is_open, time_create)
        values (seq_dps_block.nextval, :dataset, to_char(:name), 0, 0, 'y', :time_create)
        returning id into :id };

    foreach my $b (@$blocks) {
	&execute_sql ( $self, $sql,
		       ":id" => \$b->{ID},
		       ":dataset" => $b->{DATASET},
		       ":name" => $b->{NAME},
		       ":time_create" => $h{TIME_CREATE} || &mytimeofday() );
    }

    return $blocks;
}

sub bulkCreateFiles
{
    my ($self, $files, %h) = @_;

    my $file_sql = qq{
	insert into t_dps_file
	(id, node, inblock, logical_name, checksum, filesize, time_create)
	values (seq_dps_file.nextval, ?, ?, to_char(?), ?, ?, ?) 
	returning id into ?
    };

    my $xfer_sql = qq{
	insert into t_xfer_file
	(id, inblock, logical_name, checksum, filesize)
	(select id, inblock, logical_name, checksum, filesize
	  from t_dps_file where id = ?) };

    my $rep_sql = qq{
	insert into t_xfer_replica
	(id, fileid, node, state, time_create, time_state)
	(select seq_xfer_replica.nextval, id, node, 0, time_create, time_create
	  from t_dps_file where id = ?) };

    my $now = &mytimeofday();

    my %binds;
    
    # Input parameter arays
    my $n = 1;
    foreach my $file (@$files) {
	$n = 1;
	push(@{$binds{$n++}}, $$file{NODE});
	push(@{$binds{$n++}}, $$file{BLOCK});
	push(@{$binds{$n++}}, $$file{LFN});
	push(@{$binds{$n++}}, $$file{CHECKSUM});
	push(@{$binds{$n++}}, $$file{SIZE});
	push(@{$binds{$n++}}, $h{TIME_CREATE} || $now);
    }

    # Output parameter arrays
    my $id_param = 'out:'.$n++;
    my $ids = [];
    $binds{$id_param} = $ids;

    # Bulk inject the files
    &execute_sql($self, $file_sql, %binds);

    # Bulk inject the xfer_files and xfer_replicas
    &execute_sql($self, $xfer_sql, '1' => $ids);
    &execute_sql($self, $rep_sql, '1' => $ids);

    # Add created IDs to file hashrefs
    $n = 0;
    foreach my $file (@$files) {
	$$file{ID} = $$ids[$n];
	$n++;
    }

    return $files;
}



1;
