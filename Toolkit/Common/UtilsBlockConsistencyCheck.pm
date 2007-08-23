package UtilsBlockConsistencyCheck;
use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use UtilsHelp;
use UtilsDB;
use UtilsCatalogue;
use UtilsNamespace;
use Carp;

our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }

our @EXPORT = qw( );
our ($dbh);
our ($verbose,$debug,$terse);
our (%h,$conn,$dumpstats,$readstats,$msscache,%msscache);
our ($DBCONFIG,@check,$autoBlock);
our (@DATASET,@BLOCK,@LFN,@BUFFER);
our (@dataset,@block,@lfn,@buffer,@bufferIDs);
our ($data,$lfn);
our ($tfcprotocol,$mssprotocol,$destination,$tfc,$ns);
our (%info_Files_TMDB);
our (%check,%params);

%check = (
		'SIZE'		=> 0,
 		'MIGRATION'	=> 0,
 		'CKSUM'		=> 0,
 		'DBS'		=> 0,
	 );

%params = (
		DBH		=> undef,
		DBCONFIG	=> undef,
		BLOCK		=> undef,
		DATASET		=> undef,
		LFN		=> undef,
		BUFFER		=> undef,
        	STORAGEMAP	=> undef,
		TFCPROTOCOL	=> 'direct',
		MSSPROTOCOL	=> '',
		DESTINATION	=> 'any',
		CHECK		=> \%check,
		AUTOBLOCK	=> 0,

		VERBOSE		=> 0,
		DEBUG		=> 0,
		TERSE		=> 1,
		MSSCACHE	=> undef,

		NS		=> undef,
    );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {};
# my $self = $class->SUPER::new(@_);
    
  my %args = (@_);
  map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
  bless $self, $class;

  $self->_init();

  return $self;
}

sub _init
{
  my $self = shift;
  $self->NS();
  $verbose = 3;
}

sub NS
{
  my $self = shift;
  return $self->{NS} if defined($self->{NS});
  $self->{NS} = UtilsNamespace->new( 
                                     verbose => $self->{VERBOSE},
                                     debug   => $self->{DEBUG},
                                   );
  $self->{MSSPROTOCOL} = 'srm' if $self->{TFCPROTOCOL} eq 'srm';
  $self->{NS}->protocol( $self->{MSSPROTOCOL} ) if $self->{MSSPROTOCOL};
  return $self->{NS};
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
  Croak "AUTOLOAD: Invalid attribute method: ->$attr()\n";
}

sub InjectTest
{
  my ($self,%h,@fields,$sql,$id,%p,$q);

  $self = shift;
  %h = @_;
  @fields = qw / block node test n_files time_expire priority /;

  $sql = 'insert into t_dvs_block (id,' . join(',', @fields) . ')';
  foreach ( @fields )
  {
    defined($h{$_}) or die "'$_' missing in dvsInjectTest!\n";
  }

  $sql .= ' values (seq_dvs_block.nextval, ' .
          join(', ', map { ':' . $_ } @fields) .
          ') returning id into :id';

  map { $p{':' . $_} = $h{$_} } keys %h;
  $p{':id'} = \$id;
  $q = execute_sql( $self->{DBH}, $sql, %p );
  $id or return undef;

# Insert an entry into the status table...
  $sql = qq{ insert into t_status_block_verify
        (id,block,node,test,n_files,n_tested,n_ok,time_reported,status)
        values (:id,:block,:node,:test,:n_files,0,0,:time,0) };
  foreach ( qw / :time_expire :priority / ) { delete $p{$_}; }
  $p{':id'} = $id;
  $p{':time'} = time();
  $q = execute_sql( $self->{DBH}, $sql, %p );

# Now populate the t_dvs_file table.
  $sql = qq{ insert into t_dvs_file (id,request,fileid,time_queued)
        select seq_dvs_file.nextval, :request, id, :time from t_dps_file
        where inblock = :block};
  %p = ( ':request' => $id, ':block' => $h{block}, ':time' => time() );
  $q = execute_sql( $self->{DBH}, $sql, %p );

  return $id;
}

sub getTestResults
{
  my $self = shift;
  my ($sql,$q,$nodelist,@r);

  $nodelist = join(',',@_);
  $sql = qq{ select v.id, b.name block, n_files, n_tested, n_ok,
             s.name status, t.name test, time_reported
             from t_status_block_verify v join t_dvs_status s on v.status = s.id
             join t_dps_block b on v.block = b.id
             join t_dvs_test t on v.test = t.id
             where node in ($nodelist) and status > 0
             order by s.id, time_reported
           };

  $q = execute_sql( $self->{DBH}, $sql, () );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

sub getDetailedTestResults
{
  my $self = shift;
  my $request = shift;
  my ($sql,$q,@r);

  $sql = qq{ select logical_name, name status from t_dps_file f
                join t_dvs_file_result r on f.id = r.fileid
                join t_dvs_status s on r.status = s.id
                where request = :request and status in
                 (select id from t_dvs_status where not
                                (name = 'OK' or name = 'None' ) )
           };

  $q = execute_sql( $self->{DBH}, $sql, ( ':request' => $request ) );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

sub checkArguments
{
  Croak "Untested, maybe unwanted...?\n";
  my ($self) = shift;

  if( !$self->{DBH} ||
      !$self->{BUFFER}    ||
      ( !$self->{BLOCK}   &&
        !$self->{DATASET} &&
        !$self->{LFN}
      )
    )
  {
    Carp "Insufficient parameters for BlockConsistencyCheck.\n";
  }
}

#-------------------------------------------------------------------------------
sub Checks
{
  my ($self,@checks) = @_;
  if ( ! @checks ) { @checks = $self->{CHECKS}; }

# Which integrity checks are we going to run?
  foreach ( split m|[,\s*]|, "@checks" )
  {
    my $v = 1;
    if ( s%^no%% ) { $v = 0; }
    my $k = uc($_);

    if ( !defined($check{$k}) )
    {
      print "Unknown check \"$_\" requested. Known checks are: ",
	  join(', ',
		  map { "\"$_\"(" . $check{$_} . ")" } sort keys %check),
	  "\n";
      exit 1;
    }
    $self->{CHECKS}{$k} = $v;
  }

  my $nchecks=0;
  $verbose >= 2 && print "Perform the following checks:\n";
  foreach ( sort keys %{$self->{CHECKS}} )
  {
    $verbose >= 2 && printf " %10s : %3s\n", $_,
		 ($self->{CHECKS}{$_} ? 'yes' : 'no');
    $nchecks += $self->{CHECKS}{$_};
  }

  return $nchecks;
}

sub DBH
{
  my ($self,$dbh) = @_;
  $self->{DBH} = $dbh if not defined($self->{DBH});
  return $self->{DBH} if defined( $self->{DBH} = $self->{DBH} ?
				  $self->{DBH} :
				  $dbh
				);

  my $conn = { DBCONFIG => $self->{DBCONFIG} };
  $self->{DBH} = &connectToDatabase ( $conn, 0 );
  return $self->{DBH};
}

#-------------------------------------------------------------------------------
sub Buffers
{
# Croak "Untested, maybe unwanted...?\n";
  my ($self,@buffer) = @_;
  @buffer = @{$self->{BUFFER}} unless @buffer;

  @buffer = split m|[,\s*]|, "@buffer";
  foreach my $buffer ( @buffer )
  {
    $debug && print "Getting buffers with names like '$buffer'\n";
    my $tmp = getBufferFromWildCard($self->{DBH},$buffer);
    map { $self->{result}{Buffers}{ID}{$_} = $tmp->{$_} } keys %$tmp;
  }
  $debug && exists($self->{result}{Buffers}{ID}) && print "done getting buffers!\n";
  @bufferIDs = sort keys %{$self->{result}{Buffers}{ID}};
  @bufferIDs or die "No buffers found matching \"@BUFFER\", typo perhaps?\n";

# Check the technologies!
  my %t;
  map { $t{$self->{result}{Buffers}{ID}{$_}{TECHNOLOGY}}++ } @bufferIDs;
  Croak "Woah, too many technologies! (",join(',', keys %t),")\n" if ( scalar keys %t > 1 );
  return ( (keys %t)[0] ); # unless $mssprotocol;
}

#-------------------------------------------------------------------------------
sub Datasets
{
  my ($self,@dataset) = @_;
# Here I cheat. Dataset names are simply short forms of block names, so I
# add a wildcard to the dataset name and call it a block!
#
# Cunning, eh?
  Croak "Untested, maybe unwanted...?\n";
  @dataset = @{$self->{DATASET}} unless @dataset;
  @dataset = split m|[,\s*]|, "@dataset";
  my @block = map { $_ . '%' } @dataset;
  $self->Blocks(@block);
}

#-------------------------------------------------------------------------------
# Blocks next...

# Expand the BLOCK argument...
sub Blocks
{
  my ($self,@blocl) = @_;
  Croak "Untested, maybe unwanted...?\n";
  @block = @{$self->{BLOCK}} unless @block;
  push @block, split m|[,\s*]|, "@block";
  if ( @block )
  {
#   Find those I want and mark them, then GC the rest...
    my %g;
    foreach my $block ( @block )
    {
      $debug && print "Getting blocks with names like '$block'\n";
      my $tmp = getBlocksOnBufferFromWildCard ($block);
      map { $g{$_}++ } @$tmp;
      map { $self->{result}{Blocks}{$_} = {} } @$tmp;
    }
    foreach my $block ( keys %{$self->{result}{Blocks}} )
    {
      if ( ! defined($g{$block}) )
      {
        my $data = $self->{result}{Blocks}{$block}{Dataset};
        delete $self->{result}{Datasets}{$data}{Blocks}{$block};
        delete $self->{result}{Blocks}{$block};
      }
    }
  }
}

#-------------------------------------------------------------------------------
sub LFNRef
{
# Quick hack to get off the ground...
  my ($self,$r) = @_;
  $self->{result}{LFN} = $r;
}

sub LFN
{
  my ($self,@lfn) = @_;
  Croak "Untested, maybe unwanted...?\n";
  @lfn = @{$self->{LFN}} unless @lfn;
  push @lfn, split m|[,\s*]|, "@lfn";

  @lfn = split m|[,\s*]|, "@LFN";
  foreach my $lfn ( @lfn )
  {
    $verbose >= 3 && print "Getting lfns with names like '$lfn'\n";
    my $tmp = getLFNsFromWildCard($lfn);
    map { $h{LFNs}{$_} = {} } @$tmp;
  }

  foreach my $lfn ( keys %{$h{LFNs}} )
  {
    next if exists($h{LFNs}{$lfn}{Block});
    my $tmp = getBlocksFromLFN($lfn);
    map { $h{LFNs}{$lfn}{Block} = $_   } @$tmp;
    map { $h{Blocks}{$_}{LFNs}{$lfn}++ } @$tmp;
  }
  $debug && defined($h{LFNs}) && print "done getting LFNs!\n";
}

#-------------------------------------------------------------------------------
sub getOnWithItThen
{
# Fill in relationships between Blocks and Datasets or LFNs. Do this after
# inserting LFNs because then {Blocks}{$b}{LFNs} will exist, so blocks which
# are inserted only because they match LFNs will not be expanded!
  foreach my $block ( keys %{$h{Blocks}} )
  {
    if ( !defined($h{Blocks}{$block}{Dataset}) )
    {
#     Set up Block<->Dataset mapping
      my $tmp = getDatasetsFromBlock($block);
      map { $h{Datasets}{$_}{Blocks}{$block}++ } @$tmp;
      map { $h{Blocks}{$block}{Dataset} = $_   } @$tmp;
    }

    if ( $autoBlock || !defined($h{Blocks}{$block}{LFNs}) )
    {
#     Set up Block<->LFN mapping
      my $tmp = getLFNsFromBlock($block);
      map { $h{LFNs}{$_}{Block} = $block   } @$tmp;
      map { $h{Blocks}{$block}{LFNs}{$_}++ } @$tmp;
    }
  }

  $debug && print "done getting block-lfn mapping!\n\n";
  printf "Got %8d Buffers\n",  scalar keys %{$h{Buffers}{ID}};
  printf "Got %8d Datasets\n", scalar keys %{$h{Datasets}};
  printf "Got %8d Blocks\n",   scalar keys %{$h{Blocks}};
  printf "Got %8d LFNs\n",     scalar keys %{$h{LFNs}};

#-------------------------------------------------------------------------------
# Now to start extracting information to check against the storage
  foreach my $lfn ( keys %{$h{LFNs}} )
  {
    $debug and print "Getting TMDB stats for $lfn\n";
    my $tmp = getTMDBFileStats($lfn);
    map { $h{LFNs}{$lfn}{$_} = $tmp->{$_} } keys %{$tmp};
  }

#-------------------------------------------------------------------------------
# All TMDB lookups are done, from here on I compare with storage
  $dbh->disconnect();

  my %args = (
               PROTOCOL    => 'direct',
               DESTINATION => 'any',
               CATALOGUE   => '/afs/cern.ch/user/w/wildish/public/COMP/SITECONF/CERN/PhEDEx/storage.xml'
             );
  foreach $lfn ( keys %{$h{LFNs}} )
  {
    my $pfn = pfnLookup($lfn, $tfcprotocol, $destination, $tfc );
    $h{LFN}{$lfn}{PFN} = $pfn;
  }

#-------------------------------------------------------------------------------
#   Get the information needed for checking...

  my ($t,$step,$last,$etc);
  $step = 1;
  $last = $t = 0;
  if ( $check{SIZE} || $check{MIGRATION} )
  {
#   Determine the castor size and migration status of the LFNs...
    my ($i,$j);
    $i = scalar keys %{$h{LFNs}};
    foreach $lfn ( keys %{$h{LFNs}} )
    {
      $j++;
      $h{SE}{$lfn} = $msscache{$lfn} if exists($msscache{$lfn});
      next if defined $h{SE}{$lfn};

      if ( time - $t > 1 )
      {
        print STDERR "Getting SE stats: file $j / $i";
        $t = time;
        if ( $last )
        {
          $etc = int( 10 * $step * ($i-$j)/($j-$last) ) / 10;
          print STDERR ". Done in $etc seconds  ";
          my $dt = $ns->proxy();
          if ( defined($dt) )
          {
            $dt -= time();
            if ( $dt < $etc || $dt < 300 ) { print "(proxy: $dt seconds left) "; }
            die "\nuh-oh, proxy expired. :-(\n" if $dt < 0;
          }
        }
        $last = $j;
        print STDERR "\r";
      }

      my $pfn = $h{LFN}{$lfn}{PFN};
      $h{SE}{$lfn} = {};

      my $sesize = $ns->statsize($h{LFN}{$lfn}{PFN});
      if ( defined($h{SE}{$lfn}{SIZE} = $sesize) )
      {
        $h{SE}{$lfn}{MIGRATION} = $ns->statmode($h{LFN}{$lfn}{PFN});
      }
    }
  }
  print STDERR "\n";

#-------------------------------------------------------------------------------
#   Now to start doing the checks.
  if ( $check{SIZE} )
  {
    foreach $lfn ( keys %{$h{SE}} )
    {
#     Don't care about files not in TMDB
      next unless exists $h{LFNs}{$lfn};


      my $block   = $h{LFNs}{$lfn}{Block} or
				 die "Cannot determine block for $lfn\n";
      my $dataset = $h{Blocks}{$block}{Dataset} or
				 die "Cannot determine dataset for $block\n";

      my ($field);
      if ( defined($h{SE}{$lfn}{SIZE}) )
      {
        if ( $h{LFNs}{$lfn}{SIZE} == $h{SE}{$lfn}{SIZE} ) { $field = 'OK'; }
        else { $field = 'SIZE_MISMATCH'; }
        $h{Checks}{SIZE}{Dataset}{$dataset}{SIZE} += $h{LFNs}{$lfn}{SIZE};
        $h{Checks}{SIZE}{Blocks} {$block}  {SIZE} += $h{LFNs}{$lfn}{SIZE};
      }
      else { $field = 'Missing'; }
      $h{Checks}{SIZE}{Dataset}{$dataset}{$field}++;
      $h{Checks}{SIZE}{Blocks} {$block}  {$field}++;
      $h{Checks}{SIZE}{LFNs}   {Total}   {$field}++;
  
      if ( $field ne 'OK' ) { $h{Detail}{$dataset}{$block}{$lfn}{$field}++; }
      $h{LFNs}{$lfn}{$field}++;
    }
  }

  if ( $check{MIGRATION} )
  {
    foreach $lfn ( keys %{$h{SE}} )
    {
#     Don't care about files not in TMDB
      next unless exists $h{LFNs}{$lfn};


      my $block   = $h{LFNs}{$lfn}{Block} or
				 die "Cannot determine block for $lfn\n";
      my $dataset = $h{Blocks}{$block}{Dataset} or
				 die "Cannot determine dataset for $block\n";

      my $field = 'Errors';
      if ( defined($h{SE}{$lfn}{MIGRATION}) )
      {
        $field = $h{SE}{$lfn}{MIGRATION} ? 'OK' : 'NotOnTape';
      }
      else { $field = 'Missing'; }
      $h{Checks}{MIGRATION}{Dataset}{$dataset}{$field}++;
      $h{Checks}{MIGRATION}{Blocks} {$block}  {$field}++;
      $h{Checks}{MIGRATION}{LFNs}   {Total}   {$field}++;

      if ( $field ne 'OK' ) { $h{Detail}{$dataset}{$block}{$lfn}{$field}++; }
    }
  }

#   Print report
  print "\n";
  my ($check,$k,$l,$m);
  foreach $k ( qw / LFNs Blocks Dataset / )
  {
    print "#------------------------------------------------------------------\n";
    print " ==> summarising $k\n";
    foreach $check ( sort keys %{$h{Checks}} )
    {
      print " checking \"$check\"\n\n";
      foreach $l ( sort keys %{$h{Checks}{$check}{$k}} )
      {
        print " $l\n";
        foreach $m ( sort keys %{$h{Checks}{$check}{$k}{$l}} )
        {
          if ( $m eq 'SIZE' )
          {
            next unless $verbose;
            my $n = $h{Checks}{$check}{$k}{$l}{$m};
            $n = int($n*100/1024/1024/1024)/100;
            $h{Checks}{$check}{$k}{$l}{$m} = "$n GB";
          }
          print " $m=",$h{Checks}{$check}{$k}{$l}{$m};
        }
        print "\n\n";
      }
    }
  }

  print "#------------------------------------------------------------------\n";
  if ( ! keys %{$h{Detail}} )
  {
    print "There were no failures detected!\n";
  }
  elsif ( $verbose )
  {
    print " Detailed list of failures:\n";
    foreach my $dataset ( sort keys %{$h{Detail}} )
    {
      print " ==> Dataset=$dataset\n";
      foreach my $block ( sort keys %{$h{Detail}{$dataset}} )
      {
        print " ==> Block=$block\n";
        foreach my $lfn ( sort keys %{$h{Detail}{$dataset}{$block}} )
        {
          print "     LFN=$lfn ";
          print join(' ', sort keys %{$h{Detail}{$dataset}{$block}{$lfn}} ),"\n";
          if ( $verbose >= 2 )
          {
            print $ns->Raw($h{LFN}{$lfn}{PFN});
          }
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#return a hash with size and checksum keys for an lfn from TMDB
sub getTMDBFileStats
{
  my $sql = qq {select logical_name, checksum, filesize from t_dps_file
                where logical_name like :filename };
  my $l = shift @_;
  my %p = ( ":filename" => $l );
  my $r = select_hash( $sql, 'LOGICAL_NAME', %p );
  my $s;
  $s->{SIZE} = $r->{$l}->{FILESIZE};
  foreach ( split( '[,;#$%/\s]+', $r->{$l}->{CHECKSUM} ) )
  {
    my ($k,$v) = m%^\s*([^:]+):(\S+)\s*$%;
    $s->{$k} = $v;
  }
  return $s;
}

#-------------------------------------------------------------------------------
sub getLFNsFromBlock
{
  my $dbh = shift;
  my $sql = qq {select logical_name from t_dps_file where inblock in
	        (select id from t_dps_block where name like :block)};
  my %p = ( ":block" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromLFN
{
  my $dbh = shift;
  my $sql = qq {select name from t_dps_block where id in
      (select inblock from t_dps_file where logical_name like :lfn )};
  my %p = ( ":lfn" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetsFromBlock
{
  my $dbh = shift;
  my $sql = qq {select name from t_dps_dataset where id in
		(select dataset from t_dps_block where name like :block ) };
  my %p = ( ":block" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromDataset
{
  my $dbh = shift;
  my $sql = qq {select name from t_dps_block where dataset in
                (select id from t_dps_dataset where name like :dataset ) };
  my %p = ( ":dataset" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getLFNsFromWildCard
{
  my $dbh = shift;
  my $sql =
	qq {select logical_name from t_dps_file where logical_name like :lfn };
  my %p = ( ":lfn" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromWildCard
{
  my $dbh = shift;
  my $sql = qq {select name from t_dps_block where name like :block_wild};
  my %p = ( ":block_wild" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetFromWildCard
{
  my $dbh = shift;
  my $sql = qq {select name from t_dps_dataset where name like :dataset_wild };
  my %p = ( ":dataset_wild" => @_ );
  my $r = select_single( $dbh, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBufferFromWildCard
{
  my $dbh = shift;
  my $sql =
	qq {select id, name, technology from t_adm_node where name like :node };
  my %p = ( ":node" => @_ );
  my $r = select_hash( $dbh, $sql, 'ID', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksOnBufferFromWildCard
{
  my $dbh = shift;
  my $buffers = join(',',@bufferIDs);
  my $sql = qq {select name from t_dps_block b join t_dps_block_replica br
                on b.id = br.block where name like :block_wild and
                node in ($buffers)};
  my %p = ( ":block_wild" => @_ );
  my $r = select_single( $dbh, $sql, %p );

#  my $sql =
#        qq {select node, is_active, node_files, files, is_open, b.name block
#	from t_dps_block b join t_dps_block_replica br on br.block = b.id
#        join t_adm_node n on n.id = br.node
#	where n.name = :buffer };
#  my %p = ( ":buffer" => @_ );
#  my $r = select_hash( $sql, 'BLOCK', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub select_single
{
  my ( $dbh, $query, %param ) = @_;
  my ($q,@r);

  $q = execute_sql( $dbh, $query, %param );
  @r = map {$$_[0]} @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_hash
{
  my ( $dbh, $query, $key, %param ) = @_;
  my ($q,$r);

  $q = execute_sql( $dbh, $query, %param );
  $r = $q->fetchall_hashref( $key );

  my %s;
  map { $s{$_} = $r->{$_}; delete $s{$_}{$key}; } keys %$r;
  return \%s;
}

#-------------------------------------------------------------------------------
sub execute_sql
{
  my ( $dbh, $query, %param ) = @_;
  my ($q,$r);

  if ( $query =~ m%\blike\b%i )
  {
    foreach ( keys %param ) { $param{$_} =~ s%_%\\_%g; }
    $query =~ s%like\s+(:[^\)\s]+)%like $1 escape '\\' %gi;
  }

  if ( $debug )
  {
    print " ==> About to execute\n\"$query\"\nwith\n";
    foreach ( sort keys %param ) { print "  \"$_\" = \"$param{$_}\"\n"; }
    print "\n";
  }
  $q = &dbexec($dbh, $query, %param);
  return $q;
}

sub lfn2pfn
{
  my $self = shift;
  my $lfn = shift;
  my $pfn = pfnLookup(	$lfn,
			$self->{TFCPROTOCOL},
			$self->{DESTINATION},
			$self->{STORAGEMAP}
		     );
  return $pfn;
}

1;
