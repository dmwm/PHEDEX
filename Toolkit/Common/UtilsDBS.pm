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

1;

######################################################################
package UtilsDBS::RefDB; use strict; use warnings; use base 'Exporter';
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
	    		."AnaInfo.php?DatasetName=$object->{DATASET}&"
			."OwnerName=$object->{OWNER}");
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
	    	     ."GetCollectionInfo-TW.php?CollectionID=$object->{COLLECTION}"
		     ."&scriptstep=1");
    die "no collection info for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad collection info for $object->{OWNER}/$object->{DATASET}\n"
        if $data =~ /ERROR.*SELECT.*FROM/si;
    foreach my $row (split("\n", $data))
    {
	if ($row =~ /^\s*<TR><TD><B>Collection Status<\/B><TD>(\d+)$/)
	{
	    $object->{DSINFO}{CollectionStatus} = $1;
	}
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
    foreach my $assid (&listAssignments ($object->{DATASET}, $object->{OWNER}))
    {
	my $context = "$object->{OWNER}/$object->{DATASET}/$assid";
	$object->{BLOCKS}{$context} = { NAME => $context, ASSIGNMENT => $assid, FILES => [] };

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
    my @assids = &listAssignments ($object->{DATASET}, $object->{OWNER});
    my $ainfo = &assignmentInfo ($assids[0]);
    $object->{APPINFO}{ASSIGNMENT} = $assids[0];
    $object->{APPINFO}{ProdStepType} = $ainfo->{ProdStepType};
    $object->{APPINFO}{ProductionCycle} = $ainfo->{ProductionCycle};
    $object->{APPINFO}{ApplicationVersion} = $ainfo->{ApplicationVersion};
    $object->{APPINFO}{ApplicationName} = $ainfo->{ApplicationName};
    $object->{APPINFO}{ExecutableName} = $ainfo->{ExecutableName};                   
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
	    $parent->{DSINFO}{InputProdStepType} = "Error";
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
package UtilsDBS::PhEDEx; use strict; use warnings; use base 'Exporter';
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
	$object->{DSINFO}{InputProdStepType} = $datatype;
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
    push(@{$sqlargs{IDS}{2}}, $object->{DSINFO}{InputProdStepType});
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
package UtilsDBS::DBS; use strict; use warnings; use base 'Exporter';
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

# Simple tool to fetch everything from a table.  Useful for various
# mass fetch from various meta-data type tables.  Returns an array
# of hashes, where each hash has keys with the column names.
sub fetchAll
{
    my ($dbh, $table) = @_;
    return &dbexec($dbh, qq{select * from $table})->fetchall_arrayref ({});
}

# Get published datasets page contents
sub fetchPublishedData
{
    my ($self) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Get all "metadata"
    $self->{PEOPLE} = &fetchAll($dbh, "t_person");
    $self->{PHYSICS_GROUP} = &fetchAll($dbh, "t_physics_group");
    $self->{COLLECTION_TYPE} = &fetchAll($dbh, "t_collection_type");
    $self->{APP_FAMILY} = &fetchAll($dbh, "t_app_family");
    $self->{APPLICATION} = &fetchAll($dbh, "t_application");
    $self->{APP_CONFIG} = &fetchAll($dbh, "t_app_config");
    $self->{DATA_TIER} = &fetchAll($dbh, "t_data_tier");
    $self->{BLOCK_STATUS} = &fetchAll($dbh, "t_block_status");
    $self->{FILE_STATUS} = &fetchAll($dbh, "t_file_status");
    $self->{FILE_TYPE} = &fetchAll($dbh, "t_file_type");
    $self->{VALIDATION_STATUS} = &fetchAll($dbh, "t_validation_status");
    $self->{DATASET_STATUS} = &fetchAll($dbh, "t_dataset_status");
    $self->{EVCOLL_STATUS} = &fetchAll($dbh, "t_evcoll_status");
    $self->{PARENTAGE_TYPE} = &fetchAll($dbh, "t_parentage_type");

    # Get all current datasets
    return &dbexec($dbh, qq{
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
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Prepare statements
    my $qprocds = $stmtcache->{QPROCDS} ||= &dbprep ($dbh, qq{
	select
	    ppath.data_tier,
	    primds.name,
	    procds.name
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
	join t_primary_dataset primds
	  on primds.id = procds.primary_dataset
	join t_parentage_type pt
	  on pt.id = ep.type
	where ec.processed_dataset = :id});

    # Get dataset info
    &dbbindexec ($qprocds, ":id" => $object->{ID});
    while (my ($tier, $primary, $processed) = $qprocds->fetchrow())
    {
	$object->{DATASET} = $primary;
	$object->{OWNER} = $processed;
	$object->{COLLECTION} = undef;
	$object->{DSINFO}{InputProdStepType}
	    = (grep($_->{NAME} eq $tier, @{$self->{DATA_TIER}}))[0];
	$object->{DSINFO}{CollectionStatus} = undef;

        &dbbindexec ($qdsinputs, ":id" => $object->{ID});
	while (my ($type, $id, $tier, $primary, $processed) = $qdsinputs->fetchrow())
	{
	    if ($type eq 'Input')
	    {
		$object->{DSINFO}{InputOwnerName} = $processed;
	    }
	    elsif ($type eq 'PU')
	    {
		$object->{DSINFO}{PUDatasetName} = $primary;
		$object->{DSINFO}{PUOwnerName} = $processed;
	    }

	    push (@{$object->{PARENTS}}, {
		TYPE => $type,
		DSINFO => { OwnerName => $processed,
		            DatasetName => $primary,
		            InputProdStepType => $tier }
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
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

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
	where processed_dataset = :id});

    my $qfile = $stmtcache->{QFILE} ||= &dbprep ($dbh, qq{
	select
	  evc.id,
	  f.inblock,
	  f.id,
	  f.guid,
	  f.logical_name,
	  f.checksum,
	  f.filesize,
	  f.status,
	  f.type
	from t_event_collection evc
	join t_evcoll_file evf
	  on evf.evcoll = ec.id
	join t_file f
	  on f.id = evf.fileid
	where ec.processed_dataset = :id});

    # Get blocks, event collections (runs) and files
    &dbbindexec ($qblock, ":id" => $object->{ID});
    while (my ($id, $status, $files, $bytes) = $qblock->fetchrow ())
    {
	$object->{BLOCKS_BY_ID}{$id} =
	$object->{BLOCKS}{"$id"} = {
	    ID => $id,
	    NAME => "#$id", # FIXME: $object->{PATH}#ID
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
	    LFN => $filename,
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
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    # Prepare statements
    my $qappinfo = $stmtcache->{QAPPINFO} ||= &dbprep ($dbh, qq{
	select
	    dt.name
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

    if (my ($tier, $exe, $appvers, $appname, $intype) = $qappinfo->fetchrow())
    {
	$object->{APPINFO}{ASSIGNMENT} = 0;
	$object->{APPINFO}{ProdStepType} = $intype;
	$object->{APPINFO}{ProductionCycle} = 'N/A';
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
    my $dbh = &connectToDatabase ($self, 0);
    $dbh->{FetchHashKeyName} = "NAME_uc";
    $dbh->{LongReadLen} = 4096;

    return &dbexec ($dbh, qq{select * from t_file})
    	   ->fetchall_arrayref ({});
}

# Update dataset information in database
sub updateDataset
{
    my ($self, $object) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};

    my %sqlargs = ();
    my $runs = $object->{RUNS};
    my $blocks = $object->{BLOCKS};
    my $files = $object->{FILES};

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
    push(@{$sqlargs{IDS}{2}}, $object->{DSINFO}{InputProdStepType});
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
