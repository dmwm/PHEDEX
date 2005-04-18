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
	} elsif ($item && $row =~ /list-collections.php\?CollID=(\d+)/) {
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
}

# Fetch information about all the jobs of a dataset
sub fetchRunInfo
{
    my ($self, $object) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/data/"
	    		."GetJobSplit.php?DatasetName=$object->{DATASET}&"
			."OwnerName=$object->{OWNER}");
    die "no run data for $object->{OWNER}/$object->{DATASET}\n" if ! $data;
    die "bad run data for $object->{OWNER}/$object->{DATASET}\n" if $data =~ /ERROR.*SELECT.*FROM/s;
    my ($junk, @rows) = split("\n", $data);
    foreach my $row (@rows)
    {
	my ($run, $evts, $xmlfrag, @rest) = split(/\s+/, $row);
	my $label = "$object->{OWNER}/$object->{DATASET}/$run";
	my $runobj = { ID => $run, EVTS => $evts, XML => undef, FILES => [] };
	push (@{$object->{RUNS}}, $runobj);
	if ($xmlfrag eq '0') {
	    &warn ("$label: no xml fragment\n");
	} else {
	    # Grab XML fragment
	    $runobj->{XML} = &expandXMLFragment ($label, $xmlfrag);

	    # Parse XML into per-file data
	    eval { $runobj->{FILES} = &parseXMLCatalogue ($runobj->{XML}) };
	    &warn ("$label: $@") if $@;
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
	select id, dataset, owner from t_dsb_dataset order by owner, dataset})
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
    $stmtcache->{IDL} ||= &dbprep ($dbh, qq{
	select location from t_dsb_dataset_availability where dataset = :dataset});
    $stmtcache->{IDS} ||= &dbprep ($dbh, qq{
	select datatype, dataset, owner, inputowner, pudataset, puowner from t_dsb_dataset where id = :dataset});

    # Get dataset info
    &dbbindexec ($stmtcache->{IDS}, ":dataset" => $object->{ID});
    while (my ($datatype, $dataset, $owner, $inputowner, $pudataset, $puowner) = $stmtcache->{IDS}->fetchrow()) {
	$object->{DATASET} = $dataset;
	$object->{OWNER} = $owner;
	$object->{COLLECTION} = ""; # FIXME
	$object->{DSINFO}{InputProdStepType} = $datatype;
	$object->{DSINFO}{InputOwnerName} = $inputowner;
	$object->{DSINFO}{PUDatasetName} = $pudataset;
	$object->{DSINFO}{PUOwnerName} = $puowner;
	$object->{DSINFO}{CollectionStatus} = ""; # FIXME
    }

    # Get dataset locations
    &dbbindexec ($stmtcache->{IDL}, ":dataset" => $object->{ID});
    while (my ($loc) = $stmtcache->{IDL}->fetchrow()) {
	push (@{$object->{SITES}}, $loc);
    }

    $stmtcache->{IDL}->finish ();
    $stmtcache->{IDS}->finish ();
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
    $stmtcache->{IGUID} ||= &dbprep ($dbh, qq{
	select guid from t_dsb_fileid where id = :fileid});
    $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	select filesize, checksum, filename, catfragment from t_dsb_file where fileid = :fileid});
    $stmtcache->{IDR} ||= &dbprep ($dbh, qq{
	select runid, events from t_dsb_dataset_run where dataset = :dataset});
    $stmtcache->{IDRF} ||= &dbprep ($dbh, qq{
	select fileid from t_dsb_dataset_run_file where dataset = :dataset and runid = :runid});

    # Get runs and files
    &dbbindexec ($stmtcache->{IDR}, ":dataset" => $object->{ID});
    while (my ($runid, $evts) = $stmtcache->{IDR}->fetchrow ())
    {
	my $run = { ID => $runid, EVTS => $evts, FILES => [] };
	push (@{$object->{RUNS}}, $run);
	&dbbindexec ($stmtcache->{IDRF}, ":dataset" => $object->{ID}, ":runid" => $runid);
	while (my ($fileid) = $stmtcache->{IDRF}->fetchrow ())
	{
	    &dbbindexec ($stmtcache->{IGUID}, ":fileid" => $fileid);
	    my ($guid) = $stmtcache->{IGUID}->fetchrow();

	    &dbbindexec ($stmtcache->{IFILE}, ":fileid" => $fileid);
	    my ($size, $cksum, $filename, $frag) = $stmtcache->{IFILE}->fetchrow();
	    push (@{$run->{FILES}}, { ID => $fileid,
				      GUID => $guid,
				      SIZE => $size,
				      CHECKSUM => $cksum,
				      LFN => $filename,
				      XML => $frag });
	}
    }

    $stmtcache->{IGUID}->finish ();
    $stmtcache->{IFILE}->finish ();
    $stmtcache->{IDRF}->finish ();
    $stmtcache->{IDR}->finish ();
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

    return &dbexec ($dbh, qq{select id, guid from t_dsb_fileid})
    	   ->fetchall_arrayref ({});
}

# Update dataset information in database
sub updateDatasetDB
{
    my ($self, $object) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $stmtcache = $self->{STMTS} ||= {};
    my $runs = $object->{RUNS};
    my @dsfiles = map { @{$_->{FILES}} } @$runs;
    foreach my $file (@dsfiles) {
	&clearFileFromDB ($dbh, $file) if defined $file->{ID};
    }
    &clearDatasetFromDB ($dbh, $object) if defined $object->{ID};

    # Prepare statements
    $stmtcache->{IFID} ||= &dbprep ($dbh, qq{
	insert into t_dsb_fileid (id, guid) values (?, ?)});
    $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	insert into t_dsb_file
	(fileid, filesize, checksum, filename, filetype, catfragment)
	values (?, -1, -1, ?, ?, ?)});
    $stmtcache->{IFATTR} ||= &dbprep ($dbh, qq{
	insert into t_dsb_file_attributes (fileid, attribute, value)
	values (?, ?, ?)});

    $stmtcache->{IDS} ||= &dbprep ($dbh, qq{
	insert into t_dsb_dataset
	(id, datatype, dataset, owner, inputowner, pudataset, puowner)
	values (?, ?, ?, ?, ?, ?, ?)});
    $stmtcache->{IDR} ||= &dbprep ($dbh, qq{
	insert into t_dsb_dataset_run (dataset, runid, events) values (?, ?, ?)});
    $stmtcache->{IDRF} ||= &dbprep ($dbh, qq{
	insert into t_dsb_dataset_run_file (dataset, runid, fileid) values (?, ?, ?)});
    $stmtcache->{IDL} ||= &dbprep ($dbh, qq{
	insert into t_dsb_dataset_availability (dataset, location) values (?, ?)});

    # Build array insert parameters for file data
    my %sqlargs = ();
    foreach my $file (@dsfiles)
    {
	($file->{ID}) = &dbexec($dbh, qq{select seq_dsb_fileid.nextval from dual})
				->fetchrow() if ! defined $file->{ID};
	push(@{$sqlargs{IFID}{1}}, $file->{ID});
	push(@{$sqlargs{IFID}{2}}, $file->{GUID});
	
	push(@{$sqlargs{IFILE}{1}}, $file->{ID});
	push(@{$sqlargs{IFILE}{2}}, $file->{LFN}[0]);
	push(@{$sqlargs{IFILE}{3}}, $file->{PFN}[0]{TYPE});
	push(@{$sqlargs{IFILE}{4}}, $file->{TEXT});

    	foreach my $m (sort keys %{$file->{META}})
	{
	    push(@{$sqlargs{IFATTR}{1}}, $file->{ID});
	    push(@{$sqlargs{IFATTR}{2}}, "POOL_$m");
	    push(@{$sqlargs{IFATTR}{3}}, $file->{META}{$m});
	}
    }

    # Insert dataset information
    ($object->{ID}) = &dbexec($dbh, qq{select seq_dsb_dataset.nextval from dual})
    		      ->fetchrow() if ! defined $object->{ID};

    push(@{$sqlargs{IDS}{1}}, $object->{ID});
    push(@{$sqlargs{IDS}{2}}, $object->{DSINFO}{InputProdStepType});
    push(@{$sqlargs{IDS}{3}}, $object->{DATASET});
    push(@{$sqlargs{IDS}{4}}, $object->{OWNER});
    push(@{$sqlargs{IDS}{5}}, $object->{DSINFO}{InputOwnerName});
    push(@{$sqlargs{IDS}{6}}, $object->{DSINFO}{PUDatasetName});
    push(@{$sqlargs{IDS}{7}}, $object->{DSINFO}{PUOwnerName});

    foreach my $run (@$runs)
    {
	push(@{$sqlargs{IDR}{1}}, $object->{ID});
	push(@{$sqlargs{IDR}{2}}, $run->{ID});
	push(@{$sqlargs{IDR}{3}}, $run->{EVTS});

    	foreach my $file (@{$run->{FILES}})
	{
	    push(@{$sqlargs{IDRF}{1}}, $object->{ID});
	    push(@{$sqlargs{IDRF}{2}}, $run->{ID});
	    push(@{$sqlargs{IDRF}{3}}, $file->{ID});
	}
    }
    
    foreach my $loc (keys %{$object->{SITES}})
    {
	push(@{$sqlargs{IDL}{1}}, $object->{ID});
	push(@{$sqlargs{IDL}{2}}, $loc);
    }

    # Grand execute everything
    foreach my $stmtname (qw(IFID IFILE IFATTR IDS IDR IDRF IDL))
    {
	my $stmt = $stmtcache->{$stmtname};
	foreach my $k (keys %{$sqlargs{$stmtname}}) {
	    $stmt->bind_param_array ($k, $sqlargs{$stmtname}{$k});
	}
	$stmt->execute_array ({ ArrayTupleResult => []});
    }

    # Now commit
    $dbh->commit();
}

sub clearDatasetFromDB
{
    my ($dbh, $object) = @_;
    my %id = (":id" => $object->{ID});
    &dbexec ($dbh, qq{delete from t_dsb_dataset_availability where dataset = :id}, %id);
    &dbexec ($dbh, qq{delete from t_dsb_dataset_run_file where dataset = :id}, %id);
    &dbexec ($dbh, qq{delete from t_dsb_dataset_run where dataset = :id}, %id);
    &dbexec ($dbh, qq{delete from t_dsb_dataset where id = :id}, %id);
}

sub clearFileFromDB
{
    my ($dbh, $object) = @_;
    my %id = (":id" => $object->{ID});
    &dbexec ($dbh, qq{delete from t_dsb_file_attributes where fileid = :id}, %id);
    &dbexec ($dbh, qq{delete from t_dsb_file where fileid = :id}, %id);
    &dbexec ($dbh, qq{delete from t_dsb_fileid where id = :id}, %id);
}

1;
