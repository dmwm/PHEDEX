package UtilsDBS; use strict; use warnings; use base 'Exporter';

sub connect
{
    my ($self, $type, @rest) = @_;
    if ($type eq 'RefDB') {
	return new UtilsDBS::RefDB (@rest);
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
use MIME::Base64;
use Compress::Zlib;

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
    $object->{FILES} = {};
}

# Fetch information about all the jobs of a dataset
sub fetchRunInfo
{
    my ($self, $object) = @_;
    my $context = "$object->{OWNER}/$object->{DATASET}";

    # Fetch files for the collection
    foreach my $assid (&listAssignments ($object))
    {
	$object->{BLOCKS}{$context} ||= { NAME => $context, FILES => {} };

        my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			    ."data/GetAttachInfo-L25s.php?AssignmentID=${assid}"
			    ."&&OutputCollectionID=$object->{COLLECTION}");
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
		FILES => {}
	    };
	    do { &warn ("$context/$run: empty xml fragment"); next }
	    	if ($xmlfrag eq '0');

	    # Grab XML fragment and parse it into file information
	    my $xml = $runobj->{XML} = &expandXMLFragment ("$context/$run", $xmlfrag);
	    my $files = eval { &parseXMLCatalogue ($xml) };
	    do { chomp($@); &warn ("$context/$run: $@"); next } if $@;

	    foreach my $file (@$files)
	    {
		$file->{INBLOCK} = $context;
		$file->{INRUNS} = { $run => 1 };

		$object->{FILES}{$file->{GUID}} = $file;
		$object->{BLOCKS}{$context}{FILES}{$file->{GUID}} = $file;
		$object->{RUNS}{$run}{FILES}{$file->{GUID}} = $file;
	    }
	}
    }

    # Now fetch zips, their files, and file size and checksum for zips and
    # files from the ZipDB.
    my (%zips, %file2zip) = ();
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/ZipDB/"
	    		."CollectionInfo.php?cid=$object->{COLLECTION}"
			. "&zip=1&lfns=1");
    my $zip = undef;
    die "no zipdb file data for $context\n" if ! $data;
    die "bad zipdb file data for $context\n" if $data =~ /SELECT.*ERROR/si;
    foreach my $row (split(/\n/, $data))
    {
	if ($row =~ /^[ES]OF$/ || $row =~ /^Collection=/)
	{
	    $zip = undef;
	}
	elsif ($row =~ /^\s+[ES]OLFN$/)
	{
	}
	elsif ($row =~ /^[a-z]/)
	{
	    $zip = { map { /([^=]+)=(\S+)/ } split (/\s+/, $row) };
	    my @req = grep (! exists $zip->{$_}, qw(guid lfn size cksum));
	    die "missing @req for zip in $context ($row)\n" if @req;
	    $zips{$zip->{'guid'}} = $zip;
	    $zip->{FILE} = {
	        GUID => $zip->{'guid'},
	        SIZE => $zip->{'size'},
	        CHECKSUM => $zip->{'cksum'},
	        LFN => [ $zip->{'lfn'} ],
	        PFN => [ { TYPE => "EVDZip" } ],
	        INBLOCK => $context
            };
	}
	elsif ($row =~ /^\s+[a-z]/)
	{
	    $row =~ s/^\s+//;
	    my $file = { map { /([^=]+)=(\S+)/ } split (/\s+/, $row) };
	    next if $file->{'isZip'};
	    my @req = grep (! exists $file->{$_}, qw(guid lfn size cksum));
	    die "missing @req for file in zip $zip->{guid} in $context ($row)\n" if @req;
	    $zip->{'files'}{$file->{'guid'}} = $file;
	    $file2zip{$file->{'guid'}} = $zip;
	}
	else
	{
	    die "unrecognised zip line for $context ($row)\n";
        }
    }

    # Now update file size data in $object, and map zips back to runs based
    # on which files are mapped to which runs: a zip always contains a full
    # run.  Note that a single zip will be referenced by more than one run.
    foreach my $file (values %{$object->{FILES}})
    {
	my $zip = $file2zip{$file->{GUID}};
	next if ! $zip;

	$file->{SIZE} = $zip->{'files'}{$file->{GUID}}{'size'};
	$file->{CHECKSUM} = $zip->{'files'}{$file->{GUID}}{'cksum'};

	$zip->{FILE}{INBLOCK} = $file->{INBLOCK};
	map { $zip->{FILE}{INRUNS}{$_} = 1 } keys %{$file->{INRUNS}};
    }

    foreach my $zip (values %zips)
    {
	my $file = $zip->{FILE};
	$object->{FILES}{$file->{GUID}} = $file;
	$object->{BLOCKS}{$file->{INBLOCK}}{FILES}{$file->{GUID}} = $file;
	foreach my $run (keys %{$file->{INRUNS}})
	{
	    $object->{RUNS}{$run}{FILES}{$file->{GUID}} = $file;
	}
    }

    return;
}


# Get application information
sub fetchApplicationInfo
{
    my ($self, $object) = @_;
    # Pick application information from first assignment.  Should be
    # invariant within the same owner/dataset in any case.
    my @assids = &listAssignments ($object);
    die "no assignments for $object->{OWNER}/$object->{DATASET}\n" if ! @assids;
    my $ainfo = &assignmentInfo ($assids[0]);
    die "no info for assignment $assids[0]\n" if ! $ainfo;
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
    foreach my $parent (&listDatasetHistory ($object))
    {
	$self->fetchDatasetInfo ($parent);
	push (@{$object->{PARENTS}}, $parent);
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

# Get assignment information from RefDB.
sub assignmentInfo
{
    my ($assid) = @_;
    my $data = &getURL ("http://cmsdoc.cern.ch/cms/production/www/cgi/"
			."data/Info.php?AssignmentID=${assid}&display=1");
    die "$assid: no info\n" if ! $data;

    my $result = { DATA => $data };
    foreach (split(/\n/, $data)) {
	$result->{$1} = $2 if (/^(\S+?)=(.*)/);
    }

    # Dataset = DatasetName
    # owner = OutputOwnerName
    # step = ProdStepType
    # cycle = ProductionCycle
    return $result;
}

# Utility subroutine to expand a run XML fragment and to clean it up.
sub expandXMLFragment
{
    my ($context, $xmlfrag) = @_;
    my $xml = Compress::Zlib::memGunzip (decode_base64 ($xmlfrag));
    return join("\n", grep(!/^\d+a$/ && !/^\.$/, split(/\n/, $xml)));
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
    &fetchAll($self, "app_family");
    &fetchAll($self, "application");
    &fetchAll($self, "app_config");
    &fetchAll($self, "data_tier");
    &fetchAll($self, "block_status");
    &fetchAll($self, "file_status");
    &fetchAll($self, "file_type");
    &fetchAll($self, "parentage_type");

    # FIXME: fetch lazily
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
	$object->{FILES} = {};

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
	  evi.events,
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
	left join t_file_status fs
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
	    NAME => "/$object->{DATASET}/$object->{DSINFO}{DataTier}/$object->{OWNER}#$id",
	    STATUS => $status,
	    NFILES => $files,
	    NBYTES => $bytes,
	    FILES => {}
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
	    COLLECTION_INDEX => $index,
	    FILES => {}
        };
    }

    &dbbindexec ($qfile, ":id" => $object->{ID});
    while (my ($evcoll, $block, $id, $guid, $filename,
	       $checksum, $size, $status, $type) = $qfile->fetchrow ())
    {
	# FIXME: File meta attributes?
	my $file = $object->{BLOCKS_BY_ID}{$block}{FILES}{$guid} || {
	    ID => $id,
	    GUID => $guid,
	    SIZE => $size,
	    CHECKSUM => $checksum,
	    LFN => [ $filename ],
	    STATUS => $status,
	    PFN => [ { TYPE => $type } ]
        };

	$object->{FILES}{$guid} = $file;
	$object->{BLOCKS_BY_ID}{$block}{FILES}{$guid} = $file;
	$object->{RUNS_BY_ID}{$evcoll}{FILES}{$guid} = $file;

	$file->{INBLOCK} = $block;
	$file->{INRUNS}{$evcoll} = 1;
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
    my ($self, $person, $kind, $name) = @_;
    return $self->getObject ($person, $kind, { NAME => $name });
}

sub makeMediator
{
    my ($self) = @_;
    return $self->{CACHED_MEDIATOR} if $self->{CACHED_MEDIATOR};

    my $user = getpwuid($<);
    my $host = &getfullhostname();
    my $app = $0; $app =~ s|.*/||;
    my $id = "host=$host#user=$user#app=$app";
    my $m = (grep($_->{NAME} eq $id, @{$self->{PERSON}}))[0];
    return $self->{CACHED_MEDIATOR} = $m if $m;

    $self->{CACHED_MEDIATOR} = $m = { NAME => $id,
	    			      CONTACT_INFO => "$user\@$host",
				      DISTINGUISHED_NAME => "/CN=$id" };
    return $self->newObject ($m, 'person', $m);
}

sub makePerson
{
    my ($self, $object) = @_;
    return $self->{CACHED_PERSON} if $self->{CACHED_PERSON};

    die "no ~/.globus/usercert.pem, cannot identify person\n"
        if ! -f "$ENV{HOME}/.globus/usercert.pem";

    my $email = scalar getpwuid($<) . '@' . &getfullhostname();
    my $certemail = qx(openssl x509 -in \$HOME/.globus/usercert.pem -noout -email 2>/dev/null);
    my $dn = qx(openssl x509 -in \$HOME/.globus/usercert.pem -noout -subject 2>/dev/null);
    my $name = (getpwuid($<))[6]; $name =~ s/,.*//;
    do { chomp($certemail); $email = $certemail }  if $certemail;
    do { chomp($dn); $dn =~ s/^subject\s*=\s*// } if $dn;
    do { $name = $1 } if ($dn && $dn =~ /CN=(.*?)( \d+)?(\/.*)?$/);

    my $p = (grep ($_->{NAME} eq $name, @{$self->{PERSON}}))[0];
    return $self->{CACHED_PERSON} = $p if $p;

    $self->{CACHED_PERSON} = $p = { NAME => $name,
				    CONTACT_INFO => $email,
				    DISTINGUISHED_NAME => $dn };
    return $self->newObject ($p, 'person', $p);
}

sub makeAppInfo
{
    my ($self, $context, $object, $person) = @_;
    my $appname = $object->{ApplicationName};
    my $appvers = $object->{ApplicationVersion};
    my $exe = $object->{ExecutableName};

    # Compute parameter set identification
    my $pset = join ("#", map { "$_=@{[md5_base64($object->{PARAMETERS}{$_})]}" }
    		          sort keys %{$object->{PARAMETERS}});

    # my $incollobj = $self->makeNamed ($person, "collection_type", $intype);
    # my $outcollobj = $self->makeNamed ($person, "collection_type", "Output");
    my $appfamobj = $self->makeNamed ($person, "app_family", $appname);
    my $appobj = $self->getObject ($person, "application", {
	EXECUTABLE => $exe, APP_VERSION => $appvers, APP_FAMILY => $appfamobj->{ID} });
    my $appconfobj = $self->getObject ($person, "app_config", {
	APPLICATION => $appobj->{ID}, PARAMETER_SET => $pset });

    return $appconfobj;
}

sub makePrimaryDataset
{
    my ($self, $object, $person) = @_;
    my $primary = $self->getObject ($person, "primary_dataset", {
	NAME => $object->{DATASET} });
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

    my $tier = $self->makeNamed ($person, "data_tier", $object->{DSINFO}{DataTier});
    my $ppath = $self->getObject ($person, "processing_path", {
	PARENT => $parent,
	APP_CONFIG => $appinfo->{ID},
	DATA_TIER => $tier->{ID} });

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

# Prepare data for an array insert to a table.
sub prepInsert
{
    my ($self, $person, $sqlargs, $label, @args) = @_;
    my $sql = $self->{STMTS}{$label}{Statement};
    my ($kind) = ($sql =~ /insert into (\S+)/s);
    for (my $i = 0; $i < scalar @args; ++$i)
    {
	push(@{$sqlargs->{$label}{$i+1}}, $args[$i]);
    }

    push (@{$sqlargs->{IOBJHISTORY}{1}}, uc($kind));
    push (@{$sqlargs->{IOBJHISTORY}{2}}, $args[0]);
    push (@{$sqlargs->{IOBJHISTORY}{3}}, &mytimeofday());
    push (@{$sqlargs->{IOBJHISTORY}{4}}, $person->{ID});
    push (@{$sqlargs->{IOBJHISTORY}{5}}, $self->makeMediator ()->{ID});
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
    my $appinfo = $self->makeAppInfo ($object, $object->{APPINFO}, $person);

    # Now go for the core data
    my $datatier = $self->makeNamed ($person, "data_tier", $object->{DSINFO}{DataTier});
    my $primary = $self->makePrimaryDataset ($object, $person);
    my $ppath = $self->makeProcessingPath ($object, $appinfo, $person);

    # Prepare statements
    my $dbh = $self->{DBH};
    my $stmtcache = $self->{STMTS} ||= {};
    $stmtcache->{IPROCDS} ||= &dbprep ($dbh, qq{
	insert into t_processed_dataset
	(id, primary_dataset, processing_path, name, is_open)
	values (?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLL} ||= &dbprep ($dbh, qq{
	insert into t_event_collection
	(id, processed_dataset, collection_index)
	values (?, ?, ?)});

    $stmtcache->{IEVCOLLINFO} ||= &dbprep ($dbh, qq{
	insert into t_info_evcoll
	(event_collection, events, name)
	values (?, ?, ?)});

    $stmtcache->{IBLOCK} ||= &dbprep ($dbh, qq{
	insert into t_block
	(id, processed_dataset, status, files, bytes)
	values (?, ?, ?, ?, ?)});

    $stmtcache->{IFILE} ||= &dbprep ($dbh, qq{
	insert into t_file
	(id, guid, logical_name, checksum, filesize, type, inblock)
	values (?, ?, ?, ?, ?, ?, ?)});

    $stmtcache->{IEVCOLLFILE} ||= &dbprep ($dbh, qq{
	insert into t_evcoll_file
	(id, evcoll, fileid)
	values (?, ?, ?)});

    $stmtcache->{IEVCOLLPROV} ||= &dbprep ($dbh, qq{
	insert into t_evcoll_parentage
	(id, parent, child, type)
	values (?, ?, ?, ?)});

    $stmtcache->{IOBJHISTORY} ||= &dbprep ($dbh, qq{
	insert into t_object_history
	(object_type, object_id, operation, at, person, mediator)
	values (?, ?, 'INSERT', ?, ?, ?)});

    # Insert dataset information
    $self->setID ("processed_dataset", $object);
    $self->prepInsert ($person, \%sqlargs, "IPROCDS",
	$object->{ID}, $primary->{ID}, $ppath->{ID}, $object->{OWNER},
	$object->{DSINFO}{CollectionStatus} eq 6 ? 'n' : 'y');

    foreach my $run ({ EVTS => 0, NAME => 0 }, values %$runs)
    {
        $self->setID ("event_collection", $run);
        $self->prepInsert ($person, \%sqlargs, "IEVCOLL",
	    $run->{ID}, $object->{ID}, $run->{NAME});

        $self->prepInsert ($person, \%sqlargs, "IEVCOLLINFO",
	    $run->{ID}, $run->{EVTS},
	    ($run->{NAME} == 0 ? "EvC_META" : "EvC_Run$run->{NAME}"));

	my %parentsdone = ();
	foreach my $parent (@{$object->{PARENTS}})
	{
	    # For the moment put dependencies only on META/META
	    next if $run->{NAME} != 0;

	    # For the moment, suppress duplicates -- the provenance from RefDB
	    # includes complete history, not just one level up, and as we map
	    # them all on "EvC_META", we can end up with duplicates here.
	    my $parentid = $self->findParentCollection ($object, $parent);
	    die "parent $parent->{OWNER}/$parent->{DATASET} of"
		. " $object->{OWNER}/$object->{DATASET} not found\n"
	        if ! defined $parentid;
	    next if $parentsdone{$parentid};
	    $parentsdone{$parentid} = 1;

	    my $x = $self->setID ("evcoll_parentage", {});
            $self->prepInsert ($person, \%sqlargs, "IEVCOLLPROV",
		$x->{ID}, $parentid, $run->{ID},
		$self->makeNamed ($person, "parentage_type", $parent->{TYPE})->{ID});
	}
    }

    foreach my $block (values %$blocks)
    {
	my $status = $object->{DSINFO}{CollectionStatus} eq 6 ? 'Closed' : 'Open';
	my $bytes = 0; map { $bytes += $_->{SIZE} || 0; $_ } values %{$block->{FILES}};
        $self->setID ("block", $block);
        $self->prepInsert ($person, \%sqlargs, "IBLOCK",
	    $block->{ID}, $object->{ID},
	    $self->makeNamed ($person, "block_status", $status)->{ID},
	    scalar values %{$block->{FILES}}, $bytes);
    }

    foreach my $file (values %$files)
    {
	$self->setID ("file", $file);
        $self->prepInsert ($person, \%sqlargs, "IFILE",
	    $file->{ID}, $file->{GUID}, $file->{LFN}[0],
	    $file->{CHECKSUM}, $file->{SIZE},
	    # $self->makeNamed ($person, "file_status", $status)->{ID},
	    $self->makeNamed ($person, "file_type", $file->{PFN}[0]{TYPE})->{ID},
	    $object->{BLOCKS}{$file->{INBLOCK}}{ID});

	foreach my $run (keys %{$file->{INRUNS}})
	{
	    my $x = $self->setID ("evcoll_file", {});
            $self->prepInsert ($person, \%sqlargs, "IEVCOLLFILE",
	        $x->{ID}, $object->{RUNS}{$run}{ID}, $file->{ID});
        }
    }

    # Grand execute everything
    foreach my $stmtname (qw(IPROCDS IEVCOLL IEVCOLLINFO IBLOCK IFILE
			     IEVCOLLFILE IEVCOLLPROV IOBJHISTORY))
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

# Find an existing cached object, or create a new one.  Takes an
# object template, and looks for identical cached object.  If one
# is found, it is returned.  Otherwise calls 'newObject' with the
# template and returns the result.
sub getObject
{
    my ($self, $person, $kind, $x) = @_;
    foreach my $obj (@{$self->{uc($kind)}})
    {
	return $obj
	    if ! grep(! exists $obj->{$_}
		      || ((defined $obj->{$_} ? $obj->{$_} : 'undef')
		          ne (defined $x->{$_} ? $x->{$_} : 'undef')),
		      keys %$x);
    }

    return $self->newObject ($person, $kind, $x);
}

sub newObject
{
    my ($self, $person, $kind, $object, @other) = @_;

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

	# Update object history.  Note that if newObject was called by
	# makeMediator(), we produce a recursive call, but it all works
	# correctly because of the second time around it returns the
	# cached object, and we've already set the ID above on it.
	&dbexec ($self->{DBH}, qq{
	    insert into t_object_history
	    (object_type, object_id, operation, at, person, mediator)
	    values (:objtype, :objid, 'INSERT', :now, :person, :mediator)},
	    ":objtype" => uc("t_$kind"),
	    ":objid" => $object->{ID},
	    ":now" => &mytimeofday(),
	    ":person" => $person->{ID},
	    ":mediator" => $self->makeMediator()->{ID});

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
