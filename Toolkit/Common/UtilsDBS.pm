package UtilsDBS; use strict; use warnings; use base 'Exporter';

sub connect
{
    my ($self, $type, @rest) = @_;
    if ($type eq 'RefDB') {
	return new UtilsDBS::RefDB (@rest);
    } elsif ($type eq 'PhEDEx') {
	return new UtilsDBS::PhEDEx (@rest);
    } elsif ($type eq 'DBS') {
	return new UtilsDBS::DBS (@rest);
    } else {
	die "Unrecognised DBS type $type\n";
    }
}

sub disconnect
{
}

1;

######################################################################
package UtilsDBS::RefDB; use strict; use warnings; use base 'UtilsDBS';
use UtilsTR;
use UtilsNet;
use UtilsReaders;
use UtilsLogging;

# Initialise object
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    return bless {}, $class;
}

# Get published datasets page contents
sub fetchPublishedData
{
    my ($self) = @_;
    return [ &listDatasetOwners() ];
}

# Get dataset information
sub fetchDatasetInfo
{
    my ($self, $object) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/data/"
	    		."AnaInfo-cid.php?CollectionID=$object->{COLLECTION}");
    die "no dataset info for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad dataset info for $object->{OWNER}/$object->{DATASET}\n"
        if $data =~ /ERROR.*SELECT.*FROM/si;
    foreach my $row (split("\n", $data))
    {
	if ($row =~ /^(\S+)=(.*)/) {
	    $object->{DSINFO}{$1} = $2;
	}
    }

    $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/SQL/"
	    	     ."GetCollectionInfo-TW-txt.php?CollectionID=$object->{COLLECTION}"
		     ."&scriptstep=1&format=txt");
    die "no collection info for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad collection info for $object->{OWNER}/$object->{DATASET}\n"
        if $data =~ /ERROR.*SELECT.*FROM/si;
    foreach my $row (split("\n", $data))
    {
	$object->{DSINFO}{CollectionStatus} = $1
	    if $row =~ /^CollectionStatus=(\d+)/;
    }

    $object->{BLOCKS} = {};
    $object->{RUNS} = {};
    $object->{APPINFO} = {};
    $object->{PARENTS} = [];
    $object->{FILES} = [];
}

# Fetch information about all the jobs of a dataset
sub fetchRunInfo
{
    my ($self, $object) = @_;
    foreach my $assid (&listAssignments ($object))
    {
	my $context = "$object->{OWNER}/$object->{DATASET}";
	$object->{BLOCKS}{$context} ||= { NAME => $context, FILES => [] };

        my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			    ."data/GetAttachInfo.php?AssignmentID=${assid}");
        die "no run data for $context\n" if ! $data;
        die "bad run data for $context\n" if $data =~ /GetAttachInfo/;
        my ($junk, @rows) = split(/\n/, $data);
        foreach my $row (@rows)
        {
	    my ($run, $evts, $xmlfrag, @rest) = split(/\s+/, $row);
	    my $runobj = $object->{RUNS}{$run} = {
		NAME => $run,
		EVTS => $evts,
		XML => undef,
		FILES => []
	    };
	    do { warn "$context/$run: empty xml fragment\n"; next }
	    	if ($xmlfrag eq '0');

	    # Grab XML fragment and parse it into file information
	    my $xml = $runobj->{XML} = &expandXMLFragment ("$context/$run", $xmlfrag);
	    my $files = eval { &parseXMLCatalogue ($xml) };
	    do { warn "$context/$run: $@"; next } if $@;

	    foreach my $file (@$files)
	    {
		$file->{INBLOCK} = $context;
		$file->{INRUN} = $run;

		push (@{$object->{FILES}}, $file);
		push (@{$object->{BLOCKS}{$context}{FILES}}, $file);
		push (@{$object->{RUNS}{$run}{FILES}}, $file);
	    }
	}
    }

    return;

    # Previous code, restore this when GetJobSplit also outputs assignments
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/data/"
	    		."GetJobSplit.php?DatasetName=$object->{DATASET}&"
			."OwnerName=$object->{OWNER}&FIXME_ASSIGNMENTS=1");
    die "no run data for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad run data for $object->{OWNER}/$object->{DATASET}\n"
        if $data =~ /ERROR.*SELECT.*FROM/si;
    my ($junk, @rows) = split("\n", $data);
    foreach my $row (@rows)
    {
	my ($assid, $run, $evts, $xmlfrag, @rest) = split(/\s+/, $row);
	my $label = "$object->{OWNER}/$object->{DATASET}/$assid/$run";
	my $runobj = $object->{RUNS}{$run} = {
	    ID => $run,
	    EVTS => $evts,
	    XML => undef,
	    FILES => []
        };
	do { warn "$label: empty xml fragment\n"; next }
	    if $xmlfrag eq '0';

	# Grab XML fragment and parse it into file information
	my $xml = $runobj->{XML} = &expandXMLFragment ($label, $xmlfrag);
	my $files = eval { &parseXMLCatalogue ($runobj->{XML}) };
	do { warn "$label: $@"; next } if $@;
	foreach my $file (@$files)
	{
	    my $block = "$object->{OWNER}/$object->{DATASET}/$assid";
	    $file->{INBLOCK} = $block;
	    $file->{INRUN} = $run;

	    push (@{$object->{FILES}}, $file);
	    push (@{$object->{BLOCKS}{$block}{FILES}}, $file);
	    push (@{$object->{RUNS}{$run}{FILES}}, $file);
	}
    }
}


# Get application information
sub fetchApplicationInfo
{
    my ($self, $object) = @_;
    # Pick application information from first assignment.  Should be
    # invariant within the same owner/dataset in any case.
    my @assids = &listAssignments ($object);
    my $ainfo = &assignmentInfo ($assids[0]);
    $object->{APPINFO}{ASSIGNMENT} = $assids[0];
    $object->{APPINFO}{DataTier} = $ainfo->{ProdStepType};
    $object->{APPINFO}{ProductionCycle} = $ainfo->{ProductionCycle};
    $object->{APPINFO}{ApplicationVersion} = $ainfo->{ApplicationVersion};
    $object->{APPINFO}{ApplicationName} = $ainfo->{ApplicationName};
    $object->{APPINFO}{ExecutableName} = $ainfo->{ExecutableName};                   

    # Fetch URLs: ProductionCardsURL CardsURL DetectorCardsURL PUCardsURL ParameterFileURL
    # Append data: GeometryFile GeometryFileChecksum GeomPATHversion
    foreach my $url (qw(ProductionCardsURL CardsURL DetectorCardsURL
	                PUCardsURL ParameterFileURL))
    {
	next if ! exists $ainfo->{$url};
	$ainfo->{$url} =~ s/^\s*(\S+)\s*$/$1/;
	$object->{APPINFO}{PARAMETERS}{$url} = &getURL ($ainfo->{$url});
    }

    foreach my $var (qw(GeometryFile GeometryFileChecksum GeomPATHversion
	    	        CaloDigis TrackerDigis MuonDigis
			PUCollection PUOwnerName PUDatasetName))
    {
	next if ! exists $ainfo->{$var};
	$object->{APPINFO}{PARAMETERS}{$var} = $ainfo->{$var};
    }
}

# Get the provenance
sub fetchProvenanceInfo
{
    my ($self, $object) = @_;
    $object->{PARENTS} = [ &listDatasetHistory ($object) ];
    foreach my $parent (@{$object->{PARENTS}})
    {
	eval { $self->fetchDatasetInfo ($parent) };
	if ($@)
	{
	    # May fail for generation step
	    $@ =~ s/\n/ /gs;
	    &alert ("Error extracting info for $parent->{OWNER}/$parent->{DATASET}: $@");
	    $parent->{DSINFO}{DatasetName} = $parent->{DATASET};
	    $parent->{DSINFO}{OwnerName} = $parent->{OWNER};
	    $parent->{DSINFO}{DataTier} = "Error";
	}
    }
}

# Fill dataset with information for it
sub fillDatasetInfo
{
    my ($self, $object) = @_;
    $self->fetchDatasetInfo ($object);
    $self->fetchRunInfo ($object);
    $self->fetchApplicationInfo ($object);
    $self->fetchProvenanceInfo ($object);
}

sub fetchKnownFiles
{
    die "fetchKnownFiles on RefDB not supported\n";
}

1;

######################################################################
package UtilsDBS::PhEDEx; use strict; use warnings; use base 'UtilsDBS';
use UtilsDB;
use UtilsTR;
use UtilsNet;
use UtilsReaders;
use UtilsLogging;

# Initialise object
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    return bless { DBCONFIG => shift }, $class;
}

# Get published datasets page contents
sub fetchPublishedData
{
    my ($self) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Get all current datasets
    my $datasets = &dbexec($dbh, qq{
	select id, dataset, owner from t_dbs_dataset
	order by owner, dataset})
	->fetchall_arrayref ({});

    return $datasets;
}

# Get dataset information
sub fetchDatasetInfo
{
    my ($self, $object) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Prepare statements
    my $idl = $stmtcache->{IDL} ||= &dbprep ($dbh, qq{
	select distinct location from t_dls_index where block in
	(select id from t_dbs_block where dataset = :dataset)});
    my $ids = $stmtcache->{IDS} ||= &dbprep ($dbh, qq{
	select
	    datatype,
	    dataset,
	    owner,
	    collectionid,
	    collectionstatus,
	    inputowner,
	    pudataset,
	    puowner
	from t_dbs_dataset
	where id = :dataset});

    # Get dataset info
    &dbbindexec ($ids, ":dataset" => $object->{ID});
    while (my ($datatype, $dataset, $owner, $collid, $collstatus,
	       $inputowner, $pudataset, $puowner) = $ids->fetchrow())
    {
	$object->{DATASET} = $dataset;
	$object->{OWNER} = $owner;
	$object->{COLLECTION} = $collid;
	$object->{DSINFO}{DataTier} = $datatype;
	$object->{DSINFO}{InputOwnerName} = $inputowner;
	$object->{DSINFO}{PUDatasetName} = $pudataset;
	$object->{DSINFO}{PUOwnerName} = $puowner;
	$object->{DSINFO}{CollectionStatus} = $collstatus;

	$object->{BLOCKS} = {};
	$object->{RUNS} = {};
	$object->{FILES} = [];

	$object->{BLOCKS_BY_ID} = {};
	$object->{RUNS_BY_ID} = {};
    }

    # Get dataset locations
    &dbbindexec ($idl, ":dataset" => $object->{ID});
    while (my ($loc) = $idl->fetchrow()) {
	push (@{$object->{SITES}}, $loc);
    }

    $idl->finish ();
    $ids->finish ();
}

# Fetch information about all the jobs of a dataset
sub fetchRunInfo
{
    my ($self, $object) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Prepare statements
    my $ifile = $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	select
	    guid,
	    filesize,
	    checksum,
	    filename,
	    catfragment
	from t_dbs_file
	where id = :fileid});
    my $ifattr = $stmtcache->{IFATTR} ||= &dbprep ($dbh, qq{
	select attribute, value
	from t_dbs_file_attributes
	where fileid = :fileid});
    my $iblock = $stmtcache->{IBLOCK} ||= &dbprep ($dbh, qq{
	select id, name, assignment
	from t_dbs_block
	where dataset = :dataset});
    my $irun = $stmtcache->{IRUN} ||= &dbprep ($dbh, qq{
	select id, name, events
	from t_dbs_run
	where dataset = :dataset});
    my $ifmap = $stmtcache->{IFMAP} ||= &dbprep ($dbh, qq{
	select fileid, block, run
	from t_dbs_file_map
	where dataset = :dataset});

    # Get runs and files
    &dbbindexec ($irun, ":dataset" => $object->{ID});
    while (my ($id, $name, $assignment) = $iblock->fetchrow ())
    {
	$object->{BLOCKS_BY_ID}{$id} =
	$object->{BLOCKS}{$name} = {
	    ID => $id,
	    NAME => $name,
	    ASSIGNMENT => $assignment,
	    FILES => []
        };
    }

    &dbbindexec ($irun, ":dataset" => $object->{ID});
    while (my ($id, $name, $evts) = $irun->fetchrow ())
    {
	$object->{RUNS_BY_ID}{$id} =
	$object->{RUNS}{$name} = {
	    ID => $id,
	    NAME => $name,
	    EVTS => $evts,
	    FILES => []
        };
    }

    &dbbindexec ($ifmap, ":dataset" => $object->{ID});
    while (my ($file, $block, $run) = $ifmap->fetchrow ())
    {
	# FIXME: File attributes!
	my $meta = {};
	&dbbindexec ($ifile, ":fileid" => $file);
	&dbbindexec ($ifattr, ":fileid" => $file);
	my ($guid, $size, $cksum, $filename, $frag) = $ifile->fetchrow();
	while (my ($attr, $val) = $ifattr->fetchrow())
	{
	    $attr =~ s/^POOL_//;
	    $meta->{$attr} = $val;
	}
	my $file = {
	    ID => $file,
	    GUID => $guid,
	    SIZE => $size,
	    CHECKSUM => $cksum,
	    LFN => $filename,
	    XML => $frag,
	    META => $meta,

	    INBLOCK => $object->{BLOCKS_BY_ID}{$block}{NAME},
	    INRUN => $object->{RUNS_BY_ID}{$run}{NAME}
        };
	push (@{$object->{FILES}}, $file);
	push (@{$object->{BLOCKS_BY_ID}{$block}{FILES}}, $file);
	push (@{$object->{RUNS_BY_ID}{$run}{FILES}}, $file);
    }

    $ifile->finish();
    $ifattr->finish();
    $ifmap->finish();
    $irun->finish();
    $iblock->finish();
}

# Fill dataset with information for it
sub fillDatasetInfo
{
    my ($self, $object) = @_;
    $self->fetchDatasetInfo ($object);
    $self->fetchRunInfo ($object);
}

sub fetchKnownFiles
{
    my ($self) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    return &dbexec ($dbh, qq{select id, guid from t_dbs_file})
    	   ->fetchall_arrayref ({});
}

# Update dataset information in database
sub updateDataset
{
    my ($self, $object) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    my $runs = $object->{RUNS};
    my $blocks = $object->{BLOCKS};
    my $files = $object->{FILES};
    my %sqlargs = ();

    # Prepare statements
    $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	insert into t_dbs_file
	(id, guid, filesize, checksum, filename, filetype, catfragment)
	values (?, ?, null, null, ?, ?, ?)});
    $stmtcache->{IFATTR} ||= &dbprep ($dbh, qq{
	insert into t_dbs_file_attributes
	(fileid, attribute, value)
	values (?, ?, ?)});

    $stmtcache->{IDS} ||= &dbprep ($dbh, qq{
	insert into t_dbs_dataset
	(id, datatype, dataset, owner,
	 collectionid, collectionstatus,
	 inputowner, pudataset, puowner)
	values (?, ?, ?, ?,  ?, ?,  ?, ?, ?)});
    $stmtcache->{IBLOCK} ||= &dbprep ($dbh, qq{
	insert into t_dbs_block
	(id, dataset, name, assignment)
	values (?, ?, ?, ?)});
    $stmtcache->{IRUN} ||= &dbprep ($dbh, qq{
	insert into t_dbs_run
	(id, dataset, name, events)
	values (?, ?, ?, ?)});
    $stmtcache->{IFMAP} ||= &dbprep ($dbh, qq{
	insert into t_dbs_file_map
	(fileid, dataset, block, run)
	values (?, ?, ?, ?)});
    $stmtcache->{IDLS} ||= &dbprep ($dbh, qq{
	insert into t_dls_index
	(block, location)
	values (?, ?)});

    # Insert dataset information
    &setID ($dbh, $object, "seq_dbs_dataset");
    push(@{$sqlargs{IDS}{1}}, $object->{ID});
    push(@{$sqlargs{IDS}{2}}, $object->{DSINFO}{DataTier});
    push(@{$sqlargs{IDS}{3}}, $object->{DATASET});
    push(@{$sqlargs{IDS}{4}}, $object->{OWNER});
    push(@{$sqlargs{IDS}{5}}, $object->{COLLECTION});
    push(@{$sqlargs{IDS}{6}}, $object->{DSINFO}{CollectionStatus});
    push(@{$sqlargs{IDS}{7}}, $object->{DSINFO}{InputOwnerName});
    push(@{$sqlargs{IDS}{8}}, $object->{DSINFO}{PUDatasetName});
    push(@{$sqlargs{IDS}{9}}, $object->{DSINFO}{PUOwnerName});

    foreach my $block (values %$blocks)
    {
        &setID ($dbh, $block, "seq_dbs_block");
	push(@{$sqlargs{IBLOCK}{1}}, $block->{ID});
	push(@{$sqlargs{IBLOCK}{2}}, $object->{ID});
	push(@{$sqlargs{IBLOCK}{3}}, $block->{NAME});
	push(@{$sqlargs{IBLOCK}{4}}, $block->{ASSIGNMENT});

        foreach my $loc (keys %{$object->{SITES}})
	{
	    push(@{$sqlargs{IDLS}{1}}, $block->{ID});
	    push(@{$sqlargs{IDLS}{2}}, $loc);
	}
    }

    foreach my $run (values %$runs)
    {
        &setID ($dbh, $run, "seq_dbs_run");
	push(@{$sqlargs{IRUN}{1}}, $run->{ID});
	push(@{$sqlargs{IRUN}{2}}, $object->{ID});
	push(@{$sqlargs{IRUN}{3}}, $run->{NAME});
	push(@{$sqlargs{IRUN}{4}}, $run->{EVTS});
    }
    
    # File information
    foreach my $file (@$files)
    {
	&setID ($dbh, $file, "seq_dbs_file");
	push(@{$sqlargs{IFILE}{1}}, $file->{ID});
	push(@{$sqlargs{IFILE}{2}}, $file->{GUID});
	push(@{$sqlargs{IFILE}{3}}, $file->{LFN}[0]);
	push(@{$sqlargs{IFILE}{4}}, $file->{PFN}[0]{TYPE});
	push(@{$sqlargs{IFILE}{5}}, $file->{TEXT});

    	foreach my $m (sort keys %{$file->{META}})
	{
	    push(@{$sqlargs{IFATTR}{1}}, $file->{ID});
	    push(@{$sqlargs{IFATTR}{2}}, "POOL_$m");
	    push(@{$sqlargs{IFATTR}{3}}, $file->{META}{$m});
	}

	push(@{$sqlargs{IFMAP}{1}}, $file->{ID});
	push(@{$sqlargs{IFMAP}{2}}, $object->{ID});
	push(@{$sqlargs{IFMAP}{3}}, $object->{BLOCKS}{$file->{INBLOCK}}{ID});
	push(@{$sqlargs{IFMAP}{4}}, $object->{RUNS}{$file->{INRUN}}{ID});
    }

    # Grand execute everything
    foreach my $stmtname (qw(IFILE IFATTR IDS IBLOCK IRUN IFMAP IDLS))
    {
	next if ! keys %{$sqlargs{$stmtname}};
	my $stmt = $stmtcache->{$stmtname};
	foreach my $k (keys %{$sqlargs{$stmtname}}) {
	    $stmt->bind_param_array ($k, $sqlargs{$stmtname}{$k});
	}
	$stmt->execute_array ({ ArrayTupleResult => []});
    }

    # Now commit
    $dbh->commit();
}

sub setID 
{
    my ($dbh, $object, $seq) = @_;
    ($object->{ID}) = &dbexec ($dbh, qq{select $seq.nextval from dual})
    		      ->fetchrow()
	if ! defined $object->{ID};
}

1;

######################################################################
package UtilsDBS::DBS; use strict; use warnings; use base 'UtilsDBS';
use UtilsDB;
use UtilsNet;
use UtilsTiming;
use UtilsLogging;
use Digest::MD5 'md5_base64';

# Initialise object
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = bless { DBCONFIG => shift }, $class;
    &connectToDatabase ($self, 0);
    $self->{DBH}{FetchHashKeyName} = "NAME_uc";
    $self->{DBH}{LongReadLen} = 4096;
    return $self;
}

sub disconnect
{
    my $self = shift;
    $self->{DBH}->disconnect();
}

# Simple tool to fetch everything from a table.  Useful for various
# mass fetch from various meta-data type tables.  Returns an array
# of hashes, where each hash has keys with the column names.
sub fetchAll
{
    my ($self, $kind) = @_;
    return $self->{uc($kind)}
        = &dbexec($self->{DBH}, qq{select * from t_$kind})->fetchall_arrayref ({});
}

# Get published datasets page contents
sub fetchPublishedData
{
    my ($self) = @_;

    # Get all "metadata"
    &fetchAll($self, "person");
    &fetchAll($self, "physics_group");
    &fetchAll($self, "collection_type");
    &fetchAll($self, "app_family");
    &fetchAll($self, "application");
    &fetchAll($self, "app_config");
    &fetchAll($self, "data_tier");
    &fetchAll($self, "block_status");
    &fetchAll($self, "file_status");
    &fetchAll($self, "file_type");
    &fetchAll($self, "validation_status");
    &fetchAll($self, "dataset_status");
    &fetchAll($self, "evcoll_status");
    &fetchAll($self, "parentage_type");

    # FIXME: fetch lazily
    &fetchAll($self, "desc_mc");
    &fetchAll($self, "desc_primary");
    &fetchAll($self, "primary_dataset");
    &fetchAll($self, "processing_path");

    # Get all current datasets
    return &dbexec($self->{DBH}, qq{
	select
	  procds.id id,
	  primds.name dataset,
	  procds.name owner
	from t_processed_dataset procds
	join t_primary_dataset primds
	  on primds.id = procds.primary_dataset})
  	->fetchall_arrayref ({});
}

# Get dataset information
sub fetchDatasetInfo
{
    my ($self, $object) = @_;
    my $dbh = $self->{DBH};
    my $stmtcache = $self->{STMTS} ||= {};

    # Prepare statements
    my $qprocds = $stmtcache->{QPROCDS} ||= &dbprep ($dbh, qq{
	select
	    ppath.data_tier,
	    primds.name,
	    procds.name,
	    procds.is_open
	from t_processed_dataset procds
	join t_primary_dataset primds
	  on primds.id = procds.primary_dataset
	join t_processing_path ppath
	  on ppath.id = procds.processing_path
	where procds.id = :id});

    my $qdsinputs = $stmtcache->{QDSINPUTS} || &dbprep ($dbh, qq{
	select distinct
	    pt.name,
	    procds.id,
	    ppath.data_tier,
	    primds.name,
	    procds.name
	from t_event_collection ec
	join t_evcoll_parentage ep
	  on ep.child = ec.id
	join t_event_collection ec2
	  on ec2.id = ep.parent
	join t_processed_dataset procds
	  on procds.id = ec2.processed_dataset
	join t_processing_path ppath
	  on ppath.id = procds.processing_path
	join t_primary_dataset primds
	  on primds.id = procds.primary_dataset
	join t_parentage_type pt
	  on pt.id = ep.type
	where ec.processed_dataset = :id});

    # Get dataset info
    &dbbindexec ($qprocds, ":id" => $object->{ID});
    while (my ($tier, $primary, $processed, $is_open) = $qprocds->fetchrow())
    {
	$object->{DATASET} = $primary;
	$object->{OWNER} = $processed;
	$object->{DSINFO}{DataTier}
	    = (grep($_->{ID} eq $tier, @{$self->{DATA_TIER}}))[0]->{NAME};
	$object->{DSINFO}{CollectionStatus} = $is_open eq 'y' ? 4 : 6;

	$object->{PARENTS} = [];
        &dbbindexec ($qdsinputs, ":id" => $object->{ID});
	while (my ($type, $id, $tier, $primary, $processed) = $qdsinputs->fetchrow())
	{
	    if (($processed =~ /DST/ && $type eq 'Digi')
		|| ($processed !~ /DST/ && $type eq 'Hit'))
	    {
		$object->{DSINFO}{InputOwnerName} = $processed;
	    }
	    elsif ($type eq 'PU')
	    {
		$object->{DSINFO}{PUDatasetName} = $primary;
		$object->{DSINFO}{PUOwnerName} = $processed;
	    }

	    $tier = (grep($_->{ID} eq $tier, @{$self->{DATA_TIER}}))[0]->{NAME};
	    push (@{$object->{PARENTS}}, {
		TYPE => $type,
		OWNER => $processed,
		DATASET => $primary,
		DSINFO => { OwnerName => $processed,
		            DatasetName => $primary,
		            DataTier =>  $tier }
	    });
	}

	$object->{BLOCKS} = {};
	$object->{RUNS} = {};
	$object->{APPINFO} = {};
	$object->{SITES} = {};
	$object->{FILES} = [];

	$object->{BLOCKS_BY_ID} = {};
	$object->{RUNS_BY_ID} = {};
    }

    $qprocds->finish ();
    $qdsinputs->finish ();
}

# Fetch information about all the jobs of a dataset
sub fetchRunInfo
{
    my ($self, $object) = @_;
    my $dbh = $self->{DBH};
    my $stmtcache = $self->{STMTS} ||= {};

    # Prepare statements
    my $qblock = $stmtcache->{QBLOCK} ||= &dbprep ($dbh, qq{
	select id, status, files, bytes from t_block
	where processed_dataset = :id});

    my $qevcoll = $stmtcache->{QEVCOLL} ||= &dbprep ($dbh, qq{
	select
	  evc.id,
	  evc.collection_index,
	  evc.is_primary,
	  evi.events,
	  evi.status,
	  evi.validation_status,
	  evi.name
	from t_event_collection evc
	join t_info_evcoll evi on evi.event_collection = evc.id
	where evc.processed_dataset = :id});

    my $qfile = $stmtcache->{QFILE} ||= &dbprep ($dbh, qq{
	select
	  evc.id,
	  f.inblock,
	  f.id,
	  f.guid,
	  f.logical_name,
	  f.checksum,
	  f.filesize,
	  fs.name,
	  ft.name
	from t_event_collection evc
	join t_evcoll_file evf
	  on evf.evcoll = evc.id
	join t_file f
	  on f.id = evf.fileid
	join t_file_status fs
	  on fs.id = f.status
	join t_file_type ft
	  on ft.id = f.type
	where evc.processed_dataset = :id});

    # Get blocks, event collections (runs) and files
    &dbbindexec ($qblock, ":id" => $object->{ID});
    while (my ($id, $status, $files, $bytes) = $qblock->fetchrow ())
    {
	$object->{BLOCKS_BY_ID}{$id} =
	$object->{BLOCKS}{"$id"} = {
	    ID => $id,
	    NAME => "$object->{DATASET}/$object->{DSINFO}{DataTier}/$object->{OWNER}/#$id",
	    STATUS => $status,
	    NFILES => $files,
	    NBYTES => $bytes,
	    FILES => []
        };
    }

    &dbbindexec ($qevcoll, ":id" => $object->{ID});
    while (my ($id, $index, $primary, $evts, $st, $vst, $name) = $qevcoll->fetchrow ())
    {
	next if $name eq 'EvC_META';
	my $oldname = $name; $oldname =~ s/^EvC_Run//;
	$object->{RUNS_BY_ID}{$id} =
	$object->{RUNS}{$oldname} = {
	    ID => $id,
	    NAME => "$oldname",
	    EVTS => $evts,
	    STATUS => $st,
	    VALIDATION_STATUS => $vst,
	    IS_PRIMARY => $primary,
	    COLLECTION_INDEX => $index,
	    FILES => []
        };
    }

    &dbbindexec ($qfile, ":id" => $object->{ID});
    while (my ($evcoll, $block, $id, $guid, $filename,
	       $checksum, $size, $status, $type) = $qfile->fetchrow ())
    {
	# FIXME: File meta attributes?
	my $file = {
	    ID => $id,
	    GUID => $guid,
	    SIZE => $size,
	    CHECKSUM => $checksum,
	    LFN => [ $filename ],
	    STATUS => $status,
	    TYPE => $type,

	    INBLOCK => $object->{BLOCKS_BY_ID}{$block}{NAME},
	    INRUN => $object->{RUNS_BY_ID}{$evcoll}{NAME}
        };
	push (@{$object->{FILES}}, $file);
	push (@{$object->{BLOCKS_BY_ID}{$block}{FILES}}, $file);
	push (@{$object->{RUNS_BY_ID}{$evcoll}{FILES}}, $file);
    }

    $qfile->finish();
    $qevcoll->finish();
    $qblock->finish();
}

# Get application information
sub fetchApplicationInfo
{
    my ($self, $object) = @_;
    my $dbh = $self->{DBH};
    my $stmtcache = $self->{STMTS} ||= {};

    # Prepare statements
    my $qappinfo = $stmtcache->{QAPPINFO} ||= &dbprep ($dbh, qq{
	select
	    dt.name,
	    app.executable,
	    app.app_version,
	    af.name,
	    ct.name
	from t_processed_dataset pd
	join t_processing_path pp
	  on pp.id = pd.processing_path
	join t_data_tier dt
	  on dt.id = pp.data_tier
	join t_app_config ac
	  on ac.id = pp.app_config
	join t_application app
	  on app.id = ac.application
	join t_app_family af
	  on af.id = app.app_family
	join t_collection_type ct
	  on ct.id = app.input_type
	where pd.id = :id});

    &dbbindexec ($qappinfo, ":id" => $object->{ID});
    if (my ($tier, $exe, $appvers, $appname, $intype) = $qappinfo->fetchrow())
    {
	$object->{APPINFO}{ASSIGNMENT} = 0;
	$object->{APPINFO}{DataTier} = $intype;
	$object->{APPINFO}{ProductionCycle} = 'N/A'; # FIXME
	$object->{APPINFO}{ApplicationVersion} = $appvers;
	$object->{APPINFO}{ApplicationName} = $appname;
	$object->{APPINFO}{ExecutableName} = $exe;
    }

    $qappinfo->finish();
}

# Fill dataset with information for it
sub fillDatasetInfo
{
    my ($self, $object) = @_;
    $self->fetchDatasetInfo ($object);
    $self->fetchRunInfo ($object);
    $self->fetchApplicationInfo ($object);
}

sub fetchKnownFiles
{
    my ($self) = @_;
    return &dbexec ($self->{DBH}, qq{select * from t_file})
    	->fetchall_arrayref ({});
}

sub makeNamed
{
    my ($self, $kind, $name, $person) = @_;
    return (grep($_->{NAME} eq $name, @{$self->{uc($kind)}}))[0]
	|| $self->newObject ($kind, {
	    NAME => $name,
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });
}

sub makePerson
{
    my ($self, $object) = @_;
    my $email = scalar getpwuid($<) . '@' . &getfullhostname();
    my $certemail = qx(openssl x509 -in \$HOME/.globus/usercert.pem -noout -email 2>/dev/null);
    my $dn = qx(openssl x509 -in \$HOME/.globus/usercert.pem -noout -subject 2>/dev/null);
    my $name = (getpwuid($<))[6]; $name =~ s/,.*//;
    do { chomp($certemail); $email = $certemail }  if $certemail;
    do { chomp($dn); $dn =~ s/^subject\s*=\s*// } if $dn;
    do { $name = $1 } if ($dn && $dn =~ /CN=(.*?)( \d+)?(\/.*)?$/);

    my $p = (grep ($_->{NAME} eq $name, @{$self->{PERSON}}))[0];
    return $p if $p;

    $p = { NAME => $name,
	   CONTACT_INFO => $email,
	   DISTINGUISHED_NAME => $dn,
           CREATED_AT => &mytimeofday() };
    return $self->newObject ('person', $p, 'CREATED_BY');
}

sub makePhysicsGroup
{
    my ($self, $object, $person) = @_;
    my $group = (grep ($_->{NAME} eq "Fake Imported", @{$self->{PHYSICS_GROUP}}))[0]
        || $self->newObject ("physics_group", {
	    NAME => "Fake Imported",
	    CONVENOR => undef,
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });
    return $group;
}

sub makeAppInfo
{
    my ($self, $context, $object, $person, $pgroup) = @_;
    my $intype = $object->{DataTier};
    my $appname = $object->{ApplicationName};
    my $appvers = $object->{ApplicationVersion};
    my $exe = $object->{ExecutableName};

    # Compute parameter set identification
    my $pset = join ("#", map { "$_=@{[md5_base64($object->{PARAMETERS}{$_})]}" }
    		          sort keys %{$object->{PARAMETERS}});

    # FIXME: Figure out output collection stuff
    # FIXME: Input/output collection types are not part of t_application key!?
    my $incollobj = (grep($_->{NAME} eq $intype, @{$self->{COLLECTION_TYPE}}))[0]
        || $self->newObject ("collection_type", {
	    NAME => $intype,
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });
    my $outcollobj = (grep($_->{NAME} eq "Output", @{$self->{COLLECTION_TYPE}}))[0]
        || $self->newObject ("collection_type", {
	    NAME => "Output",
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} }); # FIXME
    my $appfamobj = (grep($_->{NAME} eq $appname, @{$self->{APP_FAMILY}}))[0]
        || $self->newObject ("app_family", {
	    NAME => $appname,
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });
    my $appobj = (grep($_->{EXECUTABLE} eq $exe
		       && $_->{APP_VERSION} eq $appvers
		       && $_->{APP_FAMILY} eq $appfamobj->{ID},
		       @{$self->{APPLICATION}}))[0]
	|| $self->newObject ("application", {
	    EXECUTABLE => $exe,
	    APP_VERSION => $appvers,
	    APP_FAMILY => $appfamobj->{ID},
	    INPUT_TYPE => $incollobj->{ID},
	    OUTPUT_TYPE => $outcollobj->{ID},
    	    CREATED_AT => &mytimeofday (),
    	    CREATED_BY => $person->{ID} });
    my $appconfobj = (grep($_->{APPLICATION} eq $appobj->{ID}
		           && $_->{PARAMETER_SET} eq $pset
		           && $_->{CONDITIONS_VERSION} eq "None",
			   @{$self->{APP_CONFIG}}))[0]
	|| $self->newObject ("app_config", {
	    APPLICATION => $appobj->{ID},
	    PARAMETER_SET => $pset,
	    CONDITIONS_VERSION => "None",
	    CREATED_AT => &mytimeofday (),
	    CREATED_BY => $person->{ID} });

    return $appconfobj;
}

sub makePrimaryDataset
{
    my ($self, $object, $person, $pgroup) = @_;

    # FIXME: Do this lazily.
    my $mcdesc = (grep ($_->{DESCRIPTION} eq $object->{DATASET}, @{$self->{DESC_MC}}))[0]
	|| $self->newObject ("desc_mc", {
	    DESCRIPTION => $object->{DATASET},
	    PRODUCTION => "FIXME",
	    DECAY_CHAIN => "FIXME",
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });

    my $primdesc = (grep ($_->{MC_CHANNEL} eq $mcdesc->{ID}, @{$self->{DESC_PRIMARY}}))[0]
	|| $self->newObject ("desc_primary", {
	    MC_CHANNEL => $mcdesc->{ID},
	    IS_MC_DATA => 'y',
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });

    my $primary = (grep ($_->{NAME} eq $object->{DATASET}, @{$self->{PRIMARY_DATASET}}))[0]
	|| $self->newObject ("primary_dataset", {
	    NAME => $object->{DATASET},
	    DESCRIPTION => $primdesc->{ID},
	    PHYSICS_GROUP => $pgroup->{ID},
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });

    return $primary;
}

sub makeProcessingPath
{
    my ($self, $object, $appinfo, $person) = @_;

    # If we have an input owner, use its processing path as a parent
    # to this one.  Otherwise start from null parent.
    my $parent = undef;
    if ($object->{DSINFO}{InputOwnerName})
    {
	($parent) = &dbexec($self->{DBH}, qq{
	    select procds.processing_path
	    from t_processed_dataset procds
	    join t_primary_dataset primds
	      on primds.id = procds.primary_dataset
	    where procds.name = :owner
	      and primds.name = :dataset},
            ":owner" => $object->{DSINFO}{InputOwnerName},
	    ":dataset" => $object->{DATASET})
    	    ->fetchrow();
    }

    my $tier = (grep($_->{NAME} eq $object->{DSINFO}{DataTier},
		     @{$self->{DATA_TIER}}))[0];
    my $ppath = (grep($_->{APP_CONFIG} eq $appinfo->{ID}
		      && ((defined $_->{PARENT} ? $_->{PARENT} : 'undef')
			   eq (defined $parent ? $parent : 'undef'))
		      && $_->{DATA_TIER} eq $tier->{ID},
		      @{$self->{PROCESSING_PATH}}))[0]
	|| $self->newObject ("processing_path", {
	    PARENT => $parent,
	    APP_CONFIG => $appinfo->{ID},
	    FULL_PATH => "FIXME",
	    DATA_TIER => $tier->{ID},
	    CREATED_AT => &mytimeofday(),
	    CREATED_BY => $person->{ID} });

    return $ppath;
}

sub findParentCollection
{
    my ($self, $object, $parent) = @_;
    my $qparent = $self->{STMTS}{QPARENT} ||= &dbprep ($self->{DBH}, qq{
	select ec.id
	from t_processed_dataset procds
	join t_primary_dataset primds
	  on primds.id = procds.primary_dataset
	join t_event_collection ec
	  on ec.processed_dataset = procds.id
	join t_info_evcoll evi
	  on evi.event_collection = ec.id
	where procds.name = :owner
          and primds.name = :dataset
          and evi.name = 'EvC_META'});

    &dbbindexec($qparent,
		":dataset" => $parent->{DATASET},
		":owner" => $parent->{OWNER});
    my ($id) = $qparent->fetchrow();
    $qparent->finish ();
    return $id;
}

# Update dataset information in database
sub updateDataset
{
    my ($self, $object) = @_;

    my %sqlargs = ();
    my $runs = $object->{RUNS};
    my $blocks = $object->{BLOCKS};
    my $files = $object->{FILES};

    # Initialise basic meta data (FIXME: take person etc. as input!)
    my $person = $self->makePerson ($object);
    my $pgroup = $self->makePhysicsGroup ($object, $person);
    my $appinfo = $self->makeAppInfo ($object, $object->{APPINFO}, $person, $pgroup);

    # Now go for the core data
    my $datatier = $self->makeNamed ("data_tier", $object->{DSINFO}{DataTier}, $person);
    my $primary = $self->makePrimaryDataset ($object, $person, $pgroup);
    my $ppath = $self->makeProcessingPath ($object, $appinfo, $person);

    # Prepare statements
    my $dbh = $self->{DBH};
    my $stmtcache = $self->{STMTS} ||= {};
    $stmtcache->{IPROCDS} ||= &dbprep ($dbh, qq{
	insert into t_processed_dataset
	(id, primary_dataset, processing_path, name, is_open,
	 created_at, created_by)
	values (?, ?, ?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLL} ||= &dbprep ($dbh, qq{
	insert into t_event_collection
	(id, processed_dataset, collection_index, is_primary,
	 created_at, created_by)
	values (?, ?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLLINFO} ||= &dbprep ($dbh, qq{
	insert into t_info_evcoll
	(event_collection, events, status, validation_status, name,
	 created_at, created_by)
	values (?, ?, ?, ?, ?, ?, ?)});

    $stmtcache->{IBLOCK} ||= &dbprep ($dbh, qq{
	insert into t_block
	(id, processed_dataset, status, files, bytes,
	 created_at, created_by)
	values (?, ?, ?, ?, ?, ?, ?)});

    $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	insert into t_file
	(id, guid, logical_name, checksum, filesize,
	 status, type, inblock, created_at, created_by)
	values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLLFILE} ||= &dbprep ($dbh, qq{
	insert into t_evcoll_file
	(id, evcoll, fileid, created_at, created_by)
	values (?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLLPROV} ||= &dbprep ($dbh, qq{
	insert into t_evcoll_parentage
	(parent, child, type, created_at, created_by)
	values (?, ?, ?, ?, ?)});

    # Insert dataset information
    $self->setID ("processed_dataset", $object);
    push(@{$sqlargs{IPROCDS}{1}}, $object->{ID});
    push(@{$sqlargs{IPROCDS}{2}}, $primary->{ID});
    push(@{$sqlargs{IPROCDS}{3}}, $ppath->{ID});
    push(@{$sqlargs{IPROCDS}{4}}, $object->{OWNER});
    push(@{$sqlargs{IPROCDS}{5}}, $object->{DSINFO}{CollectionStatus} eq 6 ? 'n' : 'y');
    push(@{$sqlargs{IPROCDS}{6}}, &mytimeofday());
    push(@{$sqlargs{IPROCDS}{7}}, $person->{ID});

    foreach my $run ({ EVTS => 0, NAME => 0 }, values %$runs)
    {
        $self->setID ("event_collection", $run);
	push(@{$sqlargs{IEVCOLL}{1}}, $run->{ID});
	push(@{$sqlargs{IEVCOLL}{2}}, $object->{ID});
	push(@{$sqlargs{IEVCOLL}{3}}, $run->{NAME}); # FIXME: collection_index?
	push(@{$sqlargs{IEVCOLL}{4}}, 'y');
	push(@{$sqlargs{IEVCOLL}{5}}, &mytimeofday());
	push(@{$sqlargs{IEVCOLL}{6}}, $person->{ID});

	push(@{$sqlargs{IEVCOLLINFO}{1}}, $run->{ID});
	push(@{$sqlargs{IEVCOLLINFO}{2}}, $run->{EVTS});
	push(@{$sqlargs{IEVCOLLINFO}{3}}, $self->makeNamed ("evcoll_status", "FIXME", $person)->{ID});
	push(@{$sqlargs{IEVCOLLINFO}{4}}, $self->makeNamed ("validation_status", "FIXME", $person)->{ID});
	push(@{$sqlargs{IEVCOLLINFO}{5}}, ($run->{NAME} == 0 ? "EvC_META"
					   : "EvC_Run$run->{NAME}"));
	push(@{$sqlargs{IEVCOLLINFO}{6}}, &mytimeofday());
	push(@{$sqlargs{IEVCOLLINFO}{7}}, $person->{ID});

	my %parentsdone = ();
	foreach my $parent (@{$object->{PARENTS}})
	{
	    # For the moment put dependencies only on META/META
	    next if $run->{NAME} != 0;

	    # Ignore Init{Digi,Hit} dependnecies for now.
	    next if $parent->{TYPE} =~ /^Init/;

	    # For the moment, suppress duplicates -- the provenance from RefDB
	    # includes complete history, not just one level up, and as we map
	    # them all on "EvC_META", we can end up with duplicates here.
	    my $parentid = $self->findParentCollection ($object, $parent);
	    do { &warn ("parent $parent->{OWNER}/$parent->{DATASET} of"
			. " $object->{OWNER}/$object->{DATASET} not found\n"); next }
	        if ! defined $parentid;
	    next if $parentsdone{$parentid};
	    $parentsdone{$parentid} = 1;

	    push(@{$sqlargs{IEVCOLLPROV}{1}}, $parentid);
	    push(@{$sqlargs{IEVCOLLPROV}{2}}, $run->{ID});
	    push(@{$sqlargs{IEVCOLLPROV}{3}}, $self->makeNamed ("parentage_type", $parent->{TYPE}, $person)->{ID});
	    push(@{$sqlargs{IEVCOLLPROV}{4}}, &mytimeofday());
	    push(@{$sqlargs{IEVCOLLPROV}{5}}, $person->{ID});
	}
    }

    foreach my $block (values %$blocks)
    {
	my $status = $object->{DSINFO}{CollectionStatus} eq 6 ? 'Closed' : 'Open';
	my $bytes = 0; map { $bytes += $_->{SIZE} || 0; $_ } @{$block->{FILES}};
        $self->setID ("block", $block);
	push(@{$sqlargs{IBLOCK}{1}}, $block->{ID});
	push(@{$sqlargs{IBLOCK}{2}}, $object->{ID});
	push(@{$sqlargs{IBLOCK}{3}}, $self->makeNamed ("block_status", $status, $person)->{ID});
	push(@{$sqlargs{IBLOCK}{4}}, scalar @{$block->{FILES}});
	push(@{$sqlargs{IBLOCK}{5}}, $bytes);
	push(@{$sqlargs{IBLOCK}{6}}, &mytimeofday());
	push(@{$sqlargs{IBLOCK}{7}}, $person->{ID});
    }

    foreach my $file (@$files)
    {
	my $status = "FIXME";
	$self->setID ("file", $file);
	push(@{$sqlargs{IFILE}{1}}, $file->{ID});
	push(@{$sqlargs{IFILE}{2}}, $file->{GUID});
	push(@{$sqlargs{IFILE}{3}}, $file->{LFN}[0]);
	push(@{$sqlargs{IFILE}{4}}, -1); # checksum
	push(@{$sqlargs{IFILE}{5}}, -1); # size
	push(@{$sqlargs{IFILE}{6}}, $self->makeNamed ("file_status", $status, $person)->{ID});
	push(@{$sqlargs{IFILE}{7}}, $self->makeNamed ("file_type", $file->{PFN}[0]{TYPE}, $person)->{ID});
	push(@{$sqlargs{IFILE}{8}}, $object->{BLOCKS}{$file->{INBLOCK}}{ID});
	push(@{$sqlargs{IFILE}{9}}, &mytimeofday());
	push(@{$sqlargs{IFILE}{10}}, $person->{ID});

	my $x = $self->setID ("evcoll_file", {});
	push(@{$sqlargs{IEVCOLLFILE}{1}}, $x->{ID});
	push(@{$sqlargs{IEVCOLLFILE}{2}}, $object->{RUNS}{$file->{INRUN}}{ID});
	push(@{$sqlargs{IEVCOLLFILE}{3}}, $file->{ID});
	push(@{$sqlargs{IEVCOLLFILE}{4}}, &mytimeofday());
	push(@{$sqlargs{IEVCOLLFILE}{5}}, $person->{ID});
    }

    # Grand execute everything
    foreach my $stmtname (qw(IPROCDS IEVCOLL IEVCOLLINFO IBLOCK
			     IFILE IEVCOLLFILE IEVCOLLPROV))
    {
	next if ! keys %{$sqlargs{$stmtname}};
	my $stmt = $stmtcache->{$stmtname};
	foreach my $k (keys %{$sqlargs{$stmtname}}) {
	    $stmt->bind_param_array ($k, $sqlargs{$stmtname}{$k});
	}
	$stmt->execute_array ({ ArrayTupleResult => []});
    }

    # Now commit
    $dbh->commit();
}

sub newObject
{
    my ($self, $kind, $object, @other) = @_;

    # If the object does not yet have an ID, allocate a new one,
    # create the object, and update our internal tables.
    if (! defined $object->{ID})
    {
	# Allocate new ID for this object
	($object->{ID}) = &dbexec ($self->{DBH},
	    qq{select seq_$kind.nextval from dual})->fetchrow();
	map { $object->{$_} = $object->{ID} } @other;

	# Execute SQL to create the object in the table
	my $createsql = "insert into t_$kind ("
	    . join (", ", map { lc($_) } sort keys %$object)
	    . ") values ("
	    . join (", ", map { ":" . lc($_) } sort keys %$object)
	    . ")";
	my %params = map { ":" . lc($_) => $object->{$_} } sort keys %$object;
	&dbexec ($self->{DBH}, $createsql, %params);

	# Memoize it
	push (@{$self->{uc($kind)}}, $object);
    }

    return $object;
}

sub setID
{
    my ($self, $kind, $object, @other) = @_;
    if (! defined $object->{ID})
    {
	($object->{ID}) = &dbexec ($self->{DBH},
	    qq{select seq_$kind.nextval from dual})->fetchrow();
	map { $object->{$_} = $object->{ID} } @other;
    }

    return $object;
}

1;
