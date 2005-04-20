package UtilsDBS; use strict; use warnings; use base 'Exporter';

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

    # Fetch the page
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/PubDB/"
	    		."GetPublishedCollectionInfoFromRefDB.php");
    die "no published data\n" if ! $data;
    die "bad published data\n" if $data !~ /<TITLE>Publication Information/;

    # Break it into bits
    my $items = [];
    my $item;
    foreach my $row (split("\n", $data))
    {
	if ($row =~ /<\/?TR[\s>]/) {
	    $item = undef;
	} elsif (! $item && $row =~ /<A HREF=.*dataset-discovery.php\?.*DSPattern=(.*)&OwPattern=(.*)'/) {
	    if (! ($item = (grep($_->{DATASET} eq $1 && $_->{OWNER} eq $2, @$items))[0]))
	    {
		push (@$items, $item = { DATASET => $1, OWNER => $2 });
	    }
	} elsif ($item && $row =~ /\?CollID=(\d+)\&collid=\1/) {
	    $item->{COLLECTION} = $1;
	} elsif ($item && $row =~ /<A HREF="Maintainer:[^>]*>([^<]*)</) {
	    $item->{SITES}{$1} = 1;
	}
    }

    return $items;
}

# Get dataset information
sub fetchDatasetInfo
{
    my ($self, $object) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/data/"
	    		."AnaInfo.php?DatasetName=$object->{DATASET}&"
			."OwnerName=$object->{OWNER}");
    die "no run data for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad run data for $object->{OWNER}/$object->{DATASET}\n" if $data =~ /ERROR.*SELECT.*FROM/s;
    foreach my $row (split("\n", $data))
    {
	if ($row =~ /^(\S+)=(.*)/) {
	    $object->{DSINFO}{$1} = $2;
	}
    }

    $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/SQL/"
	    	     ."GetCollectionInfo.php?CollectionID=$object->{COLLECTION}"
		     ."&scriptstep=1");
    die "no collection info for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad collection info for $object->{OWNER}/$object->{DATASET}\n" if $data =~ /[Ee]rror.*SELECT.*FROM/s;
    foreach my $row (split("\n", $data))
    {
	if ($row =~ /^\s*<TR><TD><B>Collection Status<\/B><TD>(\d+)$/)
	{
	    $object->{DSINFO}{CollectionStatus} = $1;
	}
    }

    $object->{BLOCKS} = {};
    $object->{RUNS} = {};
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
    die "bad run data for $object->{OWNER}/$object->{DATASET}\n" if $data =~ /ERROR.*SELECT.*FROM/s;
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

# Fill dataset with information for it
sub fillDatasetInfo
{
    my ($self, $object) = @_;
    $self->fetchDatasetInfo ($object);
    $self->fetchRunInfo ($object);
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
    return bless { @_ }, $class;
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
