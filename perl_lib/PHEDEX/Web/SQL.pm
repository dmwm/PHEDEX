package PHEDEX::Web::SQL;

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';
use Carp;
use POSIX;
use Data::Dumper;
use PHEDEX::Core::Identity;
use PHEDEX::Core::Timing;

our @EXPORT = qw( );
our (%params);
%params = ( DBH	=> undef );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
## my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
  my $self  = $class->SUPER::new(@_);

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  bless $self, $class;
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

sub getBlockReplicas
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);

    $sql = qq{
        select b.name block_name,
	       b.id block_id,
               b.files block_files,
               b.bytes block_bytes,
               b.is_open,
	       n.name node_name,
	       n.id node_id,
	       n.se_name se_name,
               br.node_files replica_files,
               br.node_bytes replica_bytes,
               br.time_create replica_create,
               br.time_update replica_update,
	       case when b.is_open = 'n' and
                         br.node_files = b.files
                    then 'y'
                    else 'n'
               end replica_complete,
               case when br.dest_files = 0
                    then 'n'
                    else 'y'
               end subscribed,
	       br.is_custodial,
	       g.name user_group
          from t_dps_block_replica br
	  join t_dps_block b on b.id = br.block
	  join t_dps_dataset ds on ds.id = b.dataset
	  join t_adm_node n on n.id = br.node
     left join t_adm_group g on g.id = br.user_group
	 where (br.node_files != 0 or br.dest_files !=0)
       };

    if (exists $h{COMPLETE}) {
	if ($h{COMPLETE} eq 'n') {
	    $sql .= qq{ and (br.node_files != b.files or b.is_open = 'y') };
	} elsif ($h{COMPLETE} eq 'y') {
	    $sql .= qq{ and br.node_files = b.files and b.is_open = 'n' };
	}
    }

    if (exists $h{SUBSCRIBED}) {
	if ($h{SUBSCRIBED} eq "y")
	{
	    $sql .= qq{ and br.dest_files <> 0 };
	}
	elsif ($h{SUBSCRIBED} eq "n")
	{
	    $sql .= qq{ and br.dest_files = 0 };
	}
    }
    
    if (exists $h{CUSTODIAL}) {
	if ($h{CUSTODIAL} eq 'n') {
	    $sql .= qq{ and br.is_custodial = 'n' };
	} elsif ($h{CUSTODIAL} eq 'y') {
	    $sql .= qq{ and br.is_custodial = 'y' };
	}
    }

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h, ( NODE  => 'n.name',
						      SE    => 'n.se_name',
						      BLOCK => 'b.name',
						      GROUP => 'g.name',
                                                      DATASET => 'ds.name' ));
    $sql .= " and ($filters)" if $filters;

    if (exists $h{CREATE_SINCE}) {
	$sql .= ' and br.time_create >= :create_since';
	$p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    if (exists $h{UPDATE_SINCE}) {
	$sql .= ' and br.time_update >= :update_since';
	$p{':update_since'} = &str2time($h{UPDATE_SINCE});
    }

     # return $q in spooling mode
    $q = execute_sql( $self, $sql, %p );
    if ($h{'__spool__'})
    {
        return $q;
    }

    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

sub getFileReplicas
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);
    
    $sql = qq{
    select b.id block_id,
           b.name block_name,
           b.files block_files,
           b.bytes block_bytes,
           b.is_open,
           f.id file_id,
           f.logical_name,
           f.filesize,
           f.checksum,
           f.time_create,
           ns.name origin_node,
           n.id node_id,
           n.name node_name,
           n.se_name se_name,
           xr.time_create replica_create,
           case when br.dest_files = 0
                then 'n'
                else 'y'
           end subscribed,
           br.is_custodial,
           g.name user_group
    from t_dps_block b
    join t_dps_file f on f.inblock = b.id
    join t_adm_node ns on ns.id = f.node
    join t_dps_block_replica br on br.block = b.id
    left join t_adm_group g on g.id = br.user_group
    left join t_xfer_replica xr on xr.node = br.node and xr.fileid = f.id
    left join t_adm_node n on ((br.is_active = 'y' and n.id = xr.node) 
                            or (br.is_active = 'n' and n.id = br.node))
    where (br.node_files != 0 or br.dest_files != 0)
    };

    if (exists $h{COMPLETE}) {
	if ($h{COMPLETE} eq 'n') {
	    $sql .= qq{ and (br.node_files != b.files or b.is_open = 'y') };
	} elsif ($h{COMPLETE} eq 'y') {
	    $sql .= qq{ and br.node_files = b.files and b.is_open = 'n' };
	}
    }

    if (exists $h{SUBSCRIBED}) {
	if ($h{SUBSCRIBED} eq "y")
	{
	    $sql .= qq{ and br.dest_files <> 0 };
	}
	elsif ($h{SUBSCRIBED} eq "n")
	{
	    $sql .= qq{ and br.dest_files = 0 };
	}
    }

    if (exists $h{DIST_COMPLETE}) {
	if ($h{DIST_COMPLETE} eq 'n') {
	    $sql .= qq{ and (b.is_open = 'y' or
			     not exists (select 1 from t_dps_block_replica br2
                                          where br2.block = b.id 
                                            and br2.node_files = b.files)) };
	} elsif ($h{DIST_COMPLETE} eq 'y') {
	    $sql .= qq{ and b.is_open = 'n' 
			and exists (select 1 from t_dps_block_replica br2
                                     where br2.block = b.id 
                                       and br2.node_files = b.files) };
	}
    }

    if (exists $h{CUSTODIAL}) {
	if ($h{CUSTODIAL} eq 'n') {
	    $sql .= qq{ and br.is_custodial = 'n' };
	} elsif ($h{CUSTODIAL} eq 'y') {
	    $sql .= qq{ and br.is_custodial = 'y' };
	}
    }

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h, ( NODE  => 'n.name',
						      SE    => 'n.se_name',
						      BLOCK => 'b.name',
						      GROUP => 'g.name',
                                                      LFN => 'f.logical_name'));
    $sql .= " and ($filters)" if $filters;

    if (exists $h{CREATE_SINCE}) {
	$sql .= ' and br.time_create >= :create_since';
	$p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    if (exists $h{UPDATE_SINCE}) {
	$sql .= ' and br.time_update >= :update_since';
	$p{':update_since'} = &str2time($h{UPDATE_SINCE});
    }

    $sql .= qq{ order by block_id };
    $q = execute_sql( $self, $sql, %p );

    if ($h{'__spool__'})
    {
        return $q;
    }

    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

sub getTFC {
   my ($self, %h) = @_;
   my ($sql,$q,%p,@r);

   return [] unless $h{node};

   $sql = qq{
        select c.rule_type element_name,
	       c.protocol,
	       c.destination_match "destination-match",
               c.path_match "path-match",
               c.result_expr "result",
	       c.chain,
	       c.is_custodial,
	       c.space_token
         from t_xfer_catalogue c
	 join t_adm_node n on n.id = c.node
        where n.name = :node
        order by c.rule_index asc
    };

   $p{':node'} = $h{node};

    $q = execute_sql( $self, $sql, %p );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
   
   return \@r;
}

sub SiteDataInfo
{
  my ($core,%args) = @_;

  my $dbg = $core->{DEBUG};
  my $asearchcli = $args{ASEARCHCLI};

  my $dbh = $core->{DBH};
  $dbh->{LongTruncOk} = 1;

# get site id and name based on name pattern
  my $sql=qq(select id,name from t_adm_node where name like :sitename and not name like 'X%' );
  my $sth = dbprep($dbh, $sql);
  my @handlearr=($sth,
	   ':sitename' => $args{SITENAME});
  dbbindexec(@handlearr);

  my $row = $sth->fetchrow_hashref() or die "Error: Could not resolve sitename '$args{SITENAME}'\n";

  my $nodeid = $row->{ID};
  my $fullsitename = $row->{NAME};

  print "(DBG) Site ID: $nodeid   Name: $fullsitename\n" if $dbg;

  my $sqlrowlimit=" and rownum <= $args{NUMLIMIT}" if $args{NUMLIMIT} >0;
# show all accepted requests for a node, including dataset name, where the dataset still is on the node
  $sql = qq(select distinct r.id, r.created_by, r.time_create,r.comments, rds.dataset_id, rds.name  from t_req_request r join t_req_type rt on rt.id = r.type join t_req_node rn on rn.request = r.id left join t_req_decision rd on rd.request = r.id and rd.node = rn.node join t_req_dataset rds on rds.request = r.id where rn.node = :nodeid and rt.name = 'xfer' and rd.decision = 'y' and dataset_id in (select distinct b.dataset  from t_dps_block b join t_dps_block_replica br on b.id = br.block join t_dps_dataset d on d.id = b.dataset where node = :nodeid)  $sqlrowlimit order by r.time_create desc);

  $sth = dbprep($dbh, $sql);
  @handlearr=($sth,':nodeid' => $nodeid);
  dbbindexec(@handlearr);


# prepare query to get comment texts
  $sql = qq(select comments from T_REQ_COMMENTS where id = :commentid);
  my $sth_com = dbprep($dbh, $sql);

# prepare query to get dataset stats
  $sql = qq(select name,files,bytes from t_dps_block where dataset = :datasetid);
  my $sth_stats = dbprep($dbh,$sql);

  my %dataset;
  my %requestor;
# we arrange everything in a hash sorted by dataset id and then request id
  while (my $row = $sth->fetchrow_hashref()) {
    #print Dumper($row) . "\n";
    $dataset{$row->{DATASET_ID}}{requestids}{$row->{ID}} = { requestorid => $row->{CREATED_BY},
					       commentid => $row->{COMMENTS},
					       time  => $row->{TIME_CREATE} };

    @handlearr=($sth_com,':commentid' => $row->{COMMENTS});
    dbbindexec(@handlearr);
    my $row_com = $sth_com->fetchrow_hashref();
    $dataset{$row->{DATASET_ID}}{requestids}{$row->{ID}}{comment} = $row_com->{COMMENTS};
  
    $dataset{$row->{DATASET_ID}}{name} = $row->{NAME};
    $requestor{$row->{CREATED_BY}}=undef;

    if($args{STATS}) {
      @handlearr=($sth_stats,':datasetid' => $row->{DATASET_ID});
      dbbindexec(@handlearr);
      $dataset{$row->{DATASET_ID}}{bytes}=0;
      $dataset{$row->{DATASET_ID}}{blocks}=0;
      $dataset{$row->{DATASET_ID}}{files}=0;
      while (my $row_stats = $sth_stats->fetchrow_hashref()) { # loop over blocks
        $dataset{$row->{DATASET_ID}}{bytes} += $row_stats->{BYTES};
        $dataset{$row->{DATASET_ID}}{blocks}++;
        $dataset{$row->{DATASET_ID}}{files} += $row_stats->{FILES};
      }
    }

    # for later getting a sensible order we use the latest order for this set
    $dataset{$row->{DATASET_ID}}{order} = 0 unless defined($dataset{$row->{DATASET_ID}}{order});
    $dataset{$row->{DATASET_ID}}{order} = $row->{TIME_CREATE}
      if $row->{TIME_CREATE} > $dataset{$row->{DATASET_ID}}{order};
  }

# map all requestors to names
  $sql = qq(select ident.name from t_adm_identity ident join t_adm_client cli on cli.identity = ident.id where cli.id = :requestorid);
  $sth = dbprep($dbh, $sql);
  foreach my $r (keys %requestor) {
    @handlearr=($sth,':requestorid' => $r);
    dbbindexec(@handlearr);
    my $row = $sth->fetchrow_hashref();
    $requestor{$r}=$row->{NAME};
  }

  foreach my $dsid(keys %dataset) {
    foreach my $reqid (keys %{$dataset{$dsid}{requestids}}) {
        $dataset{$dsid}{requestids}{$reqid}{requestor}=
	    $requestor{ $dataset{$dsid}{requestids}{$reqid}{requestorid} };
    }
  }

  if ($args{LOCATION}) {
    foreach my $dsid(keys %dataset) {
      my @location;
      my @output=`$asearchcli --xml --dbsInst=cms_dbs_prod_global --limit=-1 --input="find site where dataset = $dataset{$dsid}{name}"`;
      my $se;
      while (my $line = shift @output) {
        if ( (($se) = $line =~ m/<sename>(.*)<\/sename>/) ) {
	  push @location,$se;
        }
      }
      my $nreplica=$#location + 1;
      $dataset{$dsid}{replica_num}=$nreplica;
      $dataset{$dsid}{replica_loc}=join(",", sort {$a cmp $b } @location);  #unelegant, but currently for xml output
    }
  }

  return {
	   SiteDataInfo =>
  	   {
		%args,
		requestor => \%requestor,
		dataset   => \%dataset,
	   }
	 };
}

# get Agent information
sub getAgents
{
    my ($core, %h) = @_;

    # take care of version=CVS|!CVS
    if (exists $h{VERSION})
    {
        if (ref($h{VERSION} eq "ARRAY"))
        {
            my @version;
            my @revision;
            foreach ($h{VERSION})
            {
                if ($_ eq 'CVS')
                {
                    push @revision, '!NULL';
                }
                elsif ($_ eq '!CVS')
                {
                    push @revision, 'NULL';
                }
                else
                {
                    push @version, $_;
                }
            }
            if (@version)
            {
                $h{VERSION} = \@version;
            }
            if (@revision)
            {
                $h{REVISION} = \@revision;
            }
        }
        else
        {
            if ($h{VERSION} eq 'CVS')
            {
                delete $h{VERSION};
                $h{REVISION} = '!NULL';
            }
            elsif ($h{VERSION} eq '!CVS')
            {
                delete $h{VERSION};
                $h{REVISION} = 'NULL';
            }
        }
    }

    my %p;
    my $agent_version_filters = "";
    build_multi_filters($core, \$agent_version_filters, \%p, \%h, (
        VERSION => 'release',
        REVISION => 'revision'));
    if ($agent_version_filters)
    {
        $agent_version_filters = qq {
        where
            $agent_version_filters};
    }
    my $code_select = "";
    my $code_select2 = "";
    my $agent_version = qq {
        (select
            node,
            agent,
            release,
            sum(
                case
                    when revision is null then 0
                    else 1
                end
            ) from_cvs
        from
            t_agent_version
        $agent_version_filters
        group by node, agent, release ) v};

    if (exists $h{DETAIL})
    {
        $code_select = qq {
            v.filename,
            v.filesize,
            v.checksum,
            v.revision,
            v.tag,};
        $agent_version = qq {
            (select
                node,
                agent,
                release,
                revision,
                filename,
                filesize,
                checksum,
                tag,
                case
                    when revision is null then 0
                    else 1
                end from_cvs
            from
                t_agent_version
            $agent_version_filters) v};
    }

    my $sql = qq {
        select
            n.name as node,
            n.id as id,
            a.name as name,
            s.label,
            n.se_name as se,
            s.host_name as host,
            s.directory_path as state_dir,
            case
                when v.from_cvs = 0 then v.release
                else 'CVS'
            end as version,
            $code_select
            s.process_id as pid,
            s.time_update
        from
            t_agent_status s,
            t_agent a,
            t_adm_node n,
            $agent_version
        where
            s.node = n.id and
            s.agent = a.id and
            s.node = v.node and
            s.agent = v.agent and
            not n.name like 'X%' };

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        NODE => 'n.name',
        SE   => 'n.se_name',
        AGENT => 'a.name'));
    $sql .= " and ($filters) " if $filters;

    $sql .= qq {
        order by n.name, a.name
    };

    my @r;
    my $q = execute_sql($core, $sql, %p);
    while ( $_ = $q->fetchrow_hashref())
    {
        push @r, $_;
    }

    return \@r;
}

my %state_name = (
    0 => 'assigned',
    1 => 'exported',
    2 => 'transferring',
    3 => 'done'
    );

sub getTransferQueueStats
{
    my ($core, %h) = @_;
    my $sql = qq {
        select
            time_update,
            ns.name as "from",
            nd.name as "to",
            xs.from_node as from_id,
            xs.to_node as to_id,
            state,
            priority,
            files,
            bytes
        from
            t_status_task xs,
            t_adm_node ns,
            t_adm_node nd
        where
            ns.id = xs.from_node and
            nd.id = xs.to_node and
            not ns.name like 'X%' and
            not nd.name like 'X%' };

    my (@r, %p, $filters);

    $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM => 'ns.name',
        TO   => 'nd.name'));
    $sql .= " and ($filters) " if $filters;

    $sql .= qq {\n        order by nd.name, ns.name, state};

    my $q = execute_sql($core, $sql, %p);
    my %link;
    while ( $_ = $q->fetchrow_hashref())
    {
        $_ -> {'STATE'} = $state_name{$_ -> {'STATE'}};
        if ($link{$_ -> {'FROM'} . "=" . $_ -> {'TO'}})
        {
            push @{$link{$_ -> {'FROM'} . "=" . $_ -> {'TO'}}->{transfer_queue}}, {
                    state => $_ -> {'STATE'},
                    is_local => ($_-> {'PRIORITY'}%2 == 0? 'y': 'n'),
                    priority => PHEDEX::Core::Util::priority($_ -> {'PRIORITY'}, 1),
                    files => $_ -> {'FILES'},
                    bytes => $_ -> {'BYTES'},
                    time_update => $_ -> {'TIME_UPDATE'}
            };
        }
        else
        {
            $link{$_ -> {'FROM'} . "=" . $_ -> {'TO'}} = {
                from => $_ -> {'FROM'},
                to => $_ -> {'TO'},
                from_id => $_ -> {'FROM_ID'},
                to_id => $_ -> {'TO_ID'},
                transfer_queue => [{
                    state => $_ -> {'STATE'},
                    is_local => ($_-> {'PRIORITY'}%2 == 0? 'y': 'n'),
                    priority => PHEDEX::Core::Util::priority($_ -> {'PRIORITY'}, 1),
                    files => $_ -> {'FILES'},
                    bytes => $_ -> {'BYTES'},
                    time_update => $_ -> {'TIME_UPDATE'}
                }]
            };
        }
    }

    while (my ($key, $value) = each(%link))
    {
        push @r, $value;
    }

    return \@r;
}

sub getTransferHistory
{
    # optional inputs are:
    #     strattime, endtime, binwidth, from_node and to_node

    my ($core, %h) = @_;

    # take care of FROM/FROM_NODE and TO/TO_NODE
    $h{FROM_NODE} = delete $h{FROM} if $h{FROM};
    $h{TO_NODE} = delete $h{TO} if $h{TO};

    my %param;

    # default BINWIDTH is 1 hour
    if (exists $h{BINWIDTH})
    {
        $param{':BINWIDTH'} = $h{BINWIDTH};
    }
    else
    {
        $param{':BINWIDTH'} = 3600;
    }

    # default endtime is now
    if (exists $h{ENDTIME})
    {
        $param{':ENDTIME'} = &str2time($h{ENDTIME});
    }
    else
    {
        $param{':ENDTIME'} = time();
    }

    # default start time is 1 hour before
    if (exists $h{STARTTIME})
    {
        $param{':STARTTIME'} = &str2time($h{STARTTIME});
    }
    else
    {
        $param{':STARTTIME'} = $param{':ENDTIME'} - $param{':BINWIDTH'};
    }

    my $full_extent = ($param{':BINWIDTH'} == ($param{':ENDTIME'} - $param{':STARTTIME'}));

    my $sql = qq {
    select
        n1.name as "from",
        n2.name as "to",
        :BINWIDTH as binwidth, };

    if ($full_extent)
    {
        $sql .= qq { :STARTTIME as timebin, };
    }
    else
    {
        $sql .= qq {
        trunc(timebin / :BINWIDTH) * :BINWIDTH as timebin, };
    }

    $sql .= qq {
        nvl(sum(done_files), 0) as done_files,
        nvl(sum(done_bytes), 0) as done_bytes,
        nvl(sum(fail_files), 0) as fail_files,
        nvl(sum(fail_bytes), 0) as fail_bytes,
        nvl(sum(expire_files), 0) as expire_files,
        nvl(sum(expire_bytes), 0) as expire_bytes,
        cast((nvl(sum(done_bytes), 0) / :BINWIDTH) as number(20, 2)) as rate
    from
        t_history_link_events,
        t_adm_node n1,
        t_adm_node n2
    where
        from_node = n1.id and
        to_node = n2.id and
        not n1.name like 'X%' and
        not n2.name like 'X%' };

    my $where_stmt = "";
    my $filters = '';
    build_multi_filters($core, \$filters, \%param, \%h, (
        FROM_NODE => 'n1.name',
        TO_NODE   => 'n2.name'));
    $sql .= " and ($filters) " if $filters;

    # These is always start time
    $where_stmt .= qq { and\n        timebin >= :STARTTIME};
    $where_stmt .= qq { and\n        timebin < :ENDTIME};

    # now take care of the where clause

    $sql .= $where_stmt;


    if ($full_extent)
    {
        $sql .= qq {\ngroup by n1.name, n2.name };
        $sql .= qq {\norder by n1.name, n2.name };
    }
    else
    {
        $sql .= qq {\ngroup by trunc(timebin / :BINWIDTH) * :BINWIDTH, n1.name, n2.name };
        $sql .= qq {\norder by 2, 3, 1 asc};
    };

    # now execute the query
    my $q = PHEDEX::Core::SQL::execute_sql( $core, $sql, %param );

    if (exists $h{__spool__})
    {
        return $q;
    }

    my @r;
    while ( $_ = $q->fetchrow_hashref() )
    {
        # format the time stamp
        if ($_->{'TIMEBIN'} and exists $h{CTIME})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime( $_->{'TIMEBIN'}));
        }
        
	push @r, $_;
    }

    return \@r;
}

sub getTransferQueueHistory
{
    # optional inputs are:
    #     strattime, endtime, binwidth, from_node and to_node

    my ($core, %h) = @_;

    # take care of FROM/FROM_NODE and TO/TO_NODE
    $h{FROM_NODE} = delete $h{FROM} if $h{FROM};
    $h{TO_NODE} = delete $h{TO} if $h{TO};

    my $sql = qq {
    select
        n1.name as "from",
        n2.name as "to",
        :BINWIDTH as binwidth,
        trunc(timebin / :BINWIDTH) * :BINWIDTH as timebin,
        nvl(sum(pend_files) keep (dense_rank last order by timebin asc),0) pend_files,
        nvl(sum(pend_bytes) keep (dense_rank last order by timebin asc),0) pend_bytes,
        nvl(sum(wait_files) keep (dense_rank last order by timebin asc),0) wait_files,
        nvl(sum(wait_bytes) keep (dense_rank last order by timebin asc),0) wait_bytes,
        nvl(sum(ready_files) keep (dense_rank last order by timebin asc),0) ready_files,
        nvl(sum(ready_bytes) keep (dense_rank last order by timebin asc),0) ready_bytes,
        nvl(sum(xfer_files) keep (dense_rank last order by timebin asc),0) xfer_files,
        nvl(sum(xfer_bytes) keep (dense_rank last order by timebin asc),0) xfer_bytes,
        nvl(sum(confirm_files) keep (dense_rank last order by timebin asc),0) confirm_files,
        nvl(sum(confirm_bytes) keep (dense_rank last order by timebin asc),0) confirm_bytes
    from
        t_history_link_stats,
        t_adm_node n1,
        t_adm_node n2
    where
        from_node = n1.id and
        to_node = n2.id and
        not n1.name like 'X%' and
        not n2.name like 'X%' };

    my $where_stmt = "";
    my %param;

    # default endtime is now
    if (exists $h{ENDTIME})
    {
        $param{':ENDTIME'} = &str2time($h{ENDTIME});
    }
    else
    {
        $param{':ENDTIME'} = time();
    }

    # default BINWIDTH is 1 hour
    if (exists $h{BINWIDTH})
    {
        $param{':BINWIDTH'} = $h{BINWIDTH};
    }
    else
    {
        $param{':BINWIDTH'} = 3600;
    }

    # default start time is 1 hour before
    if (exists $h{STARTTIME})
    {
        $param{':STARTTIME'} = &str2time($h{STARTTIME});
    }
    else
    {
        $param{':STARTTIME'} = $param{':ENDTIME'} - $param{':BINWIDTH'};
    }

    my $filters = '';
    build_multi_filters($core, \$filters, \%param, \%h, (
        FROM_NODE => 'n1.name',
        TO_NODE   => 'n2.name'));
    $sql .= " and ($filters) " if $filters;

    # These is always start time
    $where_stmt .= qq { and\n        timebin >= :STARTTIME};
    $where_stmt .= qq { and\n        timebin < :ENDTIME};

    # now take care of the where clause

    $sql .= $where_stmt;

    $sql .= qq {\ngroup by trunc(timebin / :BINWIDTH) * :BINWIDTH, n1.name, n2.name };
    $sql .= qq {\norder by 2, 3, 1 asc};

    # now execute the query
    my $q = PHEDEX::Core::SQL::execute_sql( $core, $sql, %param );

    if (exists $h{__spool__})
    {
        return $q;
    }

    my @r;
    while ( $_ = $q->fetchrow_hashref() )
    {
        # format the time stamp
        if ($_->{'TIMEBIN'} and exists $h{CTIME})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime( $_->{'TIMEBIN'}));
        }

	push @r, $_;
    }

    return \@r;
}


sub getClientData 
{
    my ($self, $clientid) = @_;
    my $clientinfo = &PHEDEX::Core::Identity::getClientInfo($self, $clientid);
    my $identity = &PHEDEX::Core::Identity::getIdentityFromDB($self, $clientinfo->{IDENTITY});
    return {
        NAME => $identity->{NAME},
        ID => $identity->{ID},
        DN => $identity->{DN},
        USERNAME => $identity->{USERNAME},
        EMAIL => $identity->{EMAIL},
        HOST => $clientinfo->{"Remote host"},
        AGENT => $clientinfo->{"User agent"}
    };
}

#
# Optional parameters
#
#      REQUEST: request number
#         NODE: name of the destination node
#        GROUP: group name
#        LIMIT: maximal number of records
# CREATE_SINCE: created since this time
#
sub getRequestData
{
    my ($self, %h) = @_;

    # save LongReadLen & LongTruncOk
    my $LongReadLen = $$self{DBH}->{LongReadLen};
    my $LongTruncOk = $$self{DBH}->{LongTruncOk};

    $$self{DBH}->{LongReadLen} = 10_000;
    $$self{DBH}->{LongTruncOk} = 1;

    # if $h{REQUEST} is specified, get its type from database
    if (exists $h{'REQUEST'} and not exists $h{'TYPE'})
    {
        $h{'TYPE'} = &getRequestType($self, ("REQUEST" => $h{'REQUEST'}));
    }

    my @r;
    my $data = {};
    my $sql = qq {
        select
            r.id,
            r.created_by creator_id,
            r.time_create,
            rdbs.name dbs, 
            rdbs.dbs_id dbs_id, 
	    rc.comments,};

    if ($h{TYPE} eq 'xfer')
    {
        $sql .= qq {
            rx.priority priority,
            rx.is_custodial custodial,
            rx.is_move move,
            rx.is_static static,
            g.name "group",
            rx.data usertext};
    }
    else
    {
        $sql .= qq {
            rd.rm_subscriptions,
            rd.data usertext};
    }

    $sql .= qq {
        from
            t_req_request r
        join t_req_type rt on rt.id = r.type
        join t_req_dbs rdbs on rdbs.request = r.id
        left join t_req_comments rc on rc.id = r.comments};

    if ($h{TYPE} eq 'xfer')
    {
        $sql .= qq {
        join t_req_xfer rx on rx.request = r.id
        left join t_adm_group g on g.id = rx.user_group
        where
            rt.name = 'xfer'};
    }
    else
    {
        $sql .= qq {
        join t_req_delete rd on rd.request = r.id
        where
            rt.name = 'delete'};
    }

    my %p;
    my $filters = '';


    if ($h{TYPE} eq 'xfer')
    {
        build_multi_filters($self, \$filters, \%p, \%h,
            ( REQUEST => 'r.id',
              GROUP => 'g.name' ));
    }
    else
    {
        build_multi_filters($self, \$filters, \%p, \%h,
    	    ( REQUEST => 'r.id' ));
    }

    $sql .= " and ($filters) " if $filters;

    if (exists $h{LIMIT})
    {
        $sql .= qq {\n            and rownum <= :limit };
        $p{':limit'} = $h{LIMIT};
    }

    if (exists $h{CREATE_SINCE})
    {
        $sql .= qq {\n            and r.time_create >= :create_since };
        $p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    my $filters2 = '';
    build_multi_filters($self, \$filters2, \%p, \%h,
        ( NODE => 'an.name' ));

    # if NODE exists
    if ($filters2)
    {
        $sql .= qq {
            and r.id in (
                select
                    rn.request
                from
                    t_req_node rn,
                    t_adm_node an
                where
                    rn.node = an.id
                    and ($filters2))};
    }

    # order by

    $sql .= qq {\n        order by r.time_create};
    my $node_sql = qq {
	select
            n.name,
            n.id,
            n.se_name se,
            rd.decision,
            rd.decided_by,
            rd.time_decided,
            rc.comments
        from
            t_req_node rn
        join t_adm_node n on n.id = rn.node
        left join t_req_decision rd on rd.request = rn.request and rd.node = rn.node
        left join t_req_comments rc on rc.id = rd.comments
        where rn.request = :request and
            rn.point = :point };

    # same as $node_sql except no point distinction
    my $node_sql2 = qq {
	select
            n.name,
            n.id,
            n.se_name se,
            rd.decision,
            rd.decided_by,
            rd.time_decided,
            rc.comments
        from
            t_req_node rn
        join t_adm_node n on n.id = rn.node
        left join t_req_decision rd on rd.request = rn.request and rd.node = rn.node
        left join t_req_comments rc on rc.id = rd.comments
        where rn.request = :request };

    my $delete_sql = qq {
	select
            rd.rm_subscriptions,
            rd.data
	from
            t_req_delete rd
	where rd.request = :request };

    my $dataset_sql = qq {
	select
            rds.name,
            ds.id,
            nvl(sum(b.files),0) files,
            nvl(sum(b.bytes),0) bytes
	from
            t_req_dataset rds
        left join t_dps_dataset ds on ds.id = rds.dataset_id
        left join t_dps_block b on b.dataset = ds.id
        where rds.request = :request
        group by rds.name, ds.id };

    my $block_sql = qq {
        select
            rb.name,
            b.id,
            b.files,
            b.bytes
        from
            t_req_block rb
        left join t_dps_block b on b.id = rb.block_id
        where rb.request = :request };

    my $q = &execute_sql($$self{DBH}, $sql, %p);

    while ($data = $q ->fetchrow_hashref())
    {
        $$data{REQUESTED_BY} = &getClientData($self, delete $$data{CREATOR_ID});

        $$data{DATA}{DBS}{NAME} = delete $$data{DBS};
        $$data{DATA}{DBS}{ID}   = delete $$data{DBS_ID};

	my @process_nodes;
        if ($h{TYPE} eq 'xfer')
        {
            # take care of priority
            $$data{PRIORITY} = PHEDEX::Core::Util::priority($$data{PRIORITY});
            $$data{DESTINATIONS}->{NODE} = &execute_sql($$self{DBH}, $node_sql, ':request' => $$data{ID}, ':point' => 'd')->fetchall_arrayref({});
	    @process_nodes = @{$$data{DESTINATIONS}->{NODE}};
	    if ($$data{MOVE} eq 'y') {
		$$data{MOVE_SOURCES}->{NODE} = &execute_sql($$self{DBH}, $node_sql, ':request' => $$data{ID}, ':point' => 's')->fetchall_arrayref({});
		push @process_nodes, @{$$data{MOVE_SOURCES}->{NODE}};
	    }
        }
        else
        {
            $$data{NODES}->{NODE} = &execute_sql($$self{DBH}, $node_sql2, ':request' => $$data{ID})->fetchall_arrayref({});
            @process_nodes = @{$$data{NODES}->{NODE}};
        }
	foreach my $node (@process_nodes) 
	{
	    if ($$node{DECIDED_BY}) {
		$$node{DECIDED_BY} = &getClientData($self, $$node{DECIDED_BY});
		$$node{DECIDED_BY}{DECISION} = $$node{DECISION};
		$$node{DECIDED_BY}{TIME_DECIDED} = $$node{TIME_DECIDED};
		$$node{DECIDED_BY}{COMMENTS}{'$T'} = $$node{COMMENTS} if $$node{COMMENTS};
	    } else {
		delete $$node{DECIDED_BY};
	    }
	    delete @$node{qw(DECISION TIME_DECIDED COMMENTS)};
	}

        $$data{DATA}{USERTEXT}{'$T'} = delete $$data{USERTEXT};
	$$data{REQUESTED_BY}{COMMENTS}{'$T'} = delete $$data{COMMENTS};

        $$data{DATA}{DBS}{DATASET} = &execute_sql($$self{DBH}, $dataset_sql, ':request' => $$data{ID})->fetchall_arrayref({});
        $$data{DATA}{DBS}{BLOCK} = &execute_sql($$self{DBH}, $block_sql, ':request' => $$data{ID})->fetchall_arrayref({});

        my ($total_files, $total_bytes) = (0, 0);

        foreach my $item (@{$$data{DATA}{DBS}{BLOCK}},@{$$data{DATA}{DBS}{DATASET}})
        {
            $total_files += $item->{FILES} || 0;
            $total_bytes += $item->{BYTES} || 0;
        }
        $$data{DATA}{BYTES} = $total_bytes;
        $$data{DATA}{FILES} = $total_files;

        push @r, $data;
    }

    # restore LongReadLen & LongTruncOk

    $$self{DBH}->{LongReadLen} = $LongReadLen;
    $$self{DBH}->{LongTruncOk} = $LongTruncOk;

    return \@r;
}

# get the type of request
sub getRequestType
{
    my ($core, %h) = @_;
    my $sql = qq {
        select
            t.name as type
        from
            t_req_request r,
            t_req_type t
        where
            r.type = t.id and
            r.id = :rid
    };

    my $q = execute_sql($core, $sql, (':rid' => $h{REQUEST}));
    $_ = $q->fetchrow_hashref();
    if ($_)
    {
        return $_->{'TYPE'};
    }
    else
    {
        return "unknown";
    }
}

# get Group Usage information
sub getGroupUsage
{
    my ($core, %h) = @_;
    my $sql = qq {
        select
            nvl(g.name, 'undefined') user_group,
            n.name node,
            n.id,
            g.id gid,
            n.se_name,
            s.dest_files,
            s.dest_bytes,
            s.node_files,
            s.node_bytes
        from
            t_status_group s
            left join t_adm_group g on g.id = s.user_group
             join t_adm_node n on n.id = s.node };

    my @r;

    # take care of 'group'
    if (exists $h{GROUP})
    {
        if (ref ($h{GROUP}) eq "ARRAY")
        {
            my @user_group;
            foreach (@{$h{GROUP}})
            {
                if ($_ eq "undefined")
                {
                    push @user_group, "NULL";
                }
                elsif ($_ eq "!undefined")
                {
                    push @user_group, "!NULL";
                }
                else
                {
                    push @user_group, $_;
                }
            }
            $h{USER_GROUP} = \@user_group;
        }
        else
        {
            if ($h{GROUP} eq "undefined")
            {
                $h{USER_GROUP} = 'NULL';
            }
            elsif ($h{GROUP} eq "!undefined")
            {
                $h{USER_GROUP} = '!NULL';
            }
            else
            {
                $h{USER_GROUP} = $h{GROUP};
            }
        }
    }

    my %p;
    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        NODE => 'n.name',
        SE => 'n.se_name',
        USER_GROUP => 'g.name'));

    $sql .= " where ($filters) " if $filters;
    my $q = execute_sql($core, $sql, %p);
    my %node;

    while ($_ = $q->fetchrow_hashref()) {push @r, $_;}

    return \@r;
}

sub getNodeUsage
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);

    # FIXME: This massive union subquery should be written to a
    # t_status_ table by PerfMonitor this SQL is used at any
    # reasonable frequency
    $sql = qq{
      select * from (
        select 'SUBS_CUST' category,
               n.name node,
               sum(br.node_files) node_files, sum(br.node_bytes) node_bytes,
               sum(br.dest_files) dest_files, sum(br.dest_bytes) dest_bytes
          from t_dps_block_replica br
               join t_adm_node n on br.node = n.id
         where br.dest_files != 0 and br.is_custodial = 'y'
         group by n.name
         union
        select 'SUBS_NONCUST' category,
               n.name node,
               sum(br.node_files) node_files, sum(br.node_bytes) node_bytes,
               sum(br.dest_files) dest_files, sum(br.dest_bytes) dest_bytes
               from t_dps_block_replica br
          join t_adm_node n on br.node = n.id
         where br.dest_files != 0 and br.is_custodial = 'n'
         group by n.name
         union
        select 'NONSUBS_SRC' category,
               n.name node,
               sum(br.node_files) node_files, sum(br.node_bytes) node_bytes,
               0 dest_files, 0 dest_bytes
          from t_dps_block_replica br
          join t_adm_node n on br.node = n.id
         where br.dest_files = 0 and br.src_files != 0
         group by n.name
         union
        select 'NONSUBS_NONSRC' category, -- non-subscribed, non-origin data
               n.name node,
               sum(br.node_files) node_files, sum(br.node_bytes) node_bytes,
               0 dest_files, 0 dest_bytes
          from t_dps_block_replica br
          join t_adm_node n on br.node = n.id
         where br.dest_files = 0 and br.src_files = 0
         group by n.name
		     )};

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h,  node  => 'node');
    $sql .= " where ($filters)" if $filters;

    $q = execute_sql( $self, $sql, %p );
    return $q->fetchall_hashref([qw(NODE CATEGORY)]);
}

sub getTransferQueue
{
    my ($self, %h) = @_;

    # determine level of data:  file or block level
    my $filelevel  = 0;
    if (exists $h{LEVEL} && $h{LEVEL} eq 'FILE') {
	$filelevel = 1;
	delete $h{LEVEL};
    }

    my $select = qq{ from_name, from_id, from_se,
		     to_name, to_id, to_se,
		     priority, state,
		     block_name, block_id, is_custodial, time_assign,
                     time_expire, xte_time_update, xtx_time_update,
                     xtd_time_update };
    my $level_select;
    if ($filelevel) {
	$level_select = qq{ fileid, filesize, checksum, logical_name };
    } else {
	$level_select = qq{ count(fileid) files, sum(filesize) bytes };
    }

    my ($sql, $q, %p);
    $sql = qq {
      select $select,
             $level_select
       from (
      select fn.name from_name, fn.id from_id, fn.se_name from_se, 
             tn.name to_name, tn.id to_id, tn.se_name to_se,
             b.name block_name, b.id block_id,
             f.id fileid, f.filesize, f.checksum, f.logical_name,
             xt.priority, d.name dataset,
        case when xtd.task is not null then 3
             when xtx.task is not null then 2
             when xte.task is not null then 1
             else 0
         end state,
             xt.is_custodial,
             xt.time_assign,
             xt.time_expire,
             xte.time_update xte_time_update,
             xtx.time_update xtx_time_update,
             xtd.time_update xtd_time_update
        from t_xfer_task xt
             left join t_xfer_task_export xte on xte.task = xt.id
             left join t_xfer_task_inxfer xtx on xtx.task = xt.id
             left join t_xfer_task_done   xtd on xtd.task = xt.id
             join t_xfer_file f on f.id = xt.fileid
             join t_dps_block b on b.id = f.inblock
             join t_dps_dataset d on d.id = b.dataset
             join t_adm_node fn on fn.id = xt.from_node
             join t_adm_node tn on tn.id = xt.to_node
         )
   };
    
    # prepare priority filter
    if (exists $h{PRIORITY}) {
	my $priority = PHEDEX::Core::Util::priority_num($h{PRIORITY}, 0);
	$h{PRIORITY} = [ $priority, $priority+1 ]; # either local or remote
    }

    # prepare state filter
    if (exists $h{STATE}) {
	my %state_id = reverse %state_name;
	$h{STATE} = $state_id{$h{STATE}};
    }
    
    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h,  
			FROM => 'from_name',
			TO   => 'to_name',
			PRIORITY => 'priority',
			BLOCK    => 'block_name',
                        DATASET => 'dataset',
			STATE    => 'state');

    $sql .= qq{ where ($filters) } if $filters;

    if (!$filelevel) {
	$sql .= qq{ group by $select };
    }

    $q = PHEDEX::Core::SQL::execute_sql( $self, $sql, %p);
    my $r = $q->fetchall_arrayref({});

    # Transform the flat representation into a heirarchy
    my $links = {};
    foreach my $row ( @$r ) {
	# link
	my $link_key = $row->{FROM_ID}.':'.$row->{TO_ID};
	my $link = $links->{$link_key};
	if (! $link ) {
	    $link = { FROM => $row->{FROM_NAME},
		      FROM_ID => $row->{FROM_ID},
		      FROM_SE => $row->{FROM_SE},
		      TO => $row->{TO_NAME},
		      TO_ID => $row->{TO_ID},
		      TO_SE => $row->{TO_SE},
		      Q_HASH => {} };
	    $links->{$link_key} = $link;
	}

	# queue
	my $queue_key = $row->{STATE}.':'.$row->{PRIORITY};
	my $queue = $link->{Q_HASH}->{$queue_key};
	if (! $queue ) {
	    $queue = { STATE => $state_name{$row->{STATE}},
		       PRIORITY => &PHEDEX::Core::Util::priority($row->{PRIORITY}, 1),
		       B_HASH => {} };
	    $link->{Q_HASH}->{$queue_key} = $queue;
	}

	# block
	my $block_key = $row->{BLOCK_ID};
	my $block = $queue->{B_HASH}->{$block_key};
	if (! $block ) {
	    $block =
	    { NAME => $row->{BLOCK_NAME},
	      ID => $row->{BLOCK_ID} };
	    $queue->{B_HASH}->{$block_key} = $block;
	    if ($filelevel) {
		$block->{FILE} = [];
	    } else {
		$block->{FILES} = $row->{FILES};
		$block->{BYTES} = $row->{BYTES};
	    }
	}

        # time_state
        my $time_state;
        if ($row->{STATE} eq '0')
        {
            $time_state = $row->{TIME_ASSIGN};
        }
        elsif ($row->{STATE} eq '1')
        {
            $time_state = $row->{XTE_TIME_UPDATE};
        }
        elsif ($row->{STATE} eq '2')
        {
            $time_state = $row->{XTX_TIME_UPDATE};
        }
        elsif ($row->{STATE} eq '3')
        {
            $time_state = $row->{XTD_TIME_UPDATE};
        }

        # block level time stamp
        if ((! exists $block->{TIME_ASSIGN}) or 
            (int($row->{TIME_ASSIGN}) < int($block->{TIME_ASSIGN})))
        {
            $block->{TIME_ASSIGN} = $row->{TIME_ASSIGN};
        }

        if ((! exists $block->{TIME_EXPIRE}) or 
            (int($row->{TIME_EXPIRE}) < int($block->{TIME_EXPIRE})))
        {
            $block->{TIME_EXPIRE} = $row->{TIME_EXPIRE};
        }

        if ((! exists $block->{TIME_STATE}) or 
            (int($time_state) < int($block->{TIME_STATE})))
        {
            $block->{TIME_STATE} = $time_state;
        }

	# file
	if ($filelevel) {
	    push @{$block->{FILE}}, { NAME => $row->{LOGICAL_NAME},
				      ID => $row->{FILEID},
				      BYTES => $row->{FILESIZE},
				      CHECKSUM => $row->{CHECKSUM},
                                      IS_CUSTODIAL => $row->{IS_CUSTODIAL},
                                      TIME_ASSIGN => $row->{TIME_ASSIGN},
                                      TIME_EXPIRE => $row->{TIME_EXPIRE},
                                      TIME_STATE => $time_state };
	}
    }
    
    # Transform hashes into arrays for auto-formatting
    foreach my $link (values %$links) {
	foreach my $queue (values %{$link->{Q_HASH}}) {
	    foreach my $block (values %{$queue->{B_HASH}}) {
		$queue->{BLOCK} ||= [];
		push @{$queue->{BLOCK}}, $block;
	    }
	    delete $queue->{B_HASH};
	    $link->{TRANSFER_QUEUE} ||= [];
	    push @{$link->{TRANSFER_QUEUE}}, $queue;
	}
	delete $link->{Q_HASH};
    }
    
    return $links;
}

# get which files are in the transfer error logs
sub getErrorLogSummary
{
    my ($core, %h) = @_;

    # take care of FROM/FROM_NODE and TO/TO_NODE
    $h{FROM_NODE} = delete $h{FROM} if $h{FROM};
    $h{TO_NODE} = delete $h{TO} if $h{TO};

    my $sql = qq {
        select
            fn.name "from",
            fn.id from_id,
            fn.se_name from_se,
            tn.name "to",
            tn.id to_id,
            tn.se_name to_se,
            b.name block_name,
            b.id   block_id,
            f.logical_name file_name,
            f.id   file_id,
            f.filesize file_size,
            f.checksum checksum,
            count(f.id) num_errors
        from
            t_xfer_error xe
            join t_adm_node fn on fn.id = xe.from_node
            join t_adm_node tn on tn.id = xe.to_node
            join t_xfer_file f on f.id = xe.fileid
            join t_dps_block b on b.id = f.inblock
            join t_dps_dataset d on b.dataset = d.id
        where
            not fn.name like 'X%' and
            not tn.name like 'X%'
        };

    my @r;
    my %p;
    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM_NODE => 'fn.name',
        TO_NODE => 'tn.name',
        BLOCK => 'b.name',
        LFN => 'f.logical_name',
        DATASET => 'd.name'
        ));

    $sql .= " and ( $filters )" if $filters;
    $sql .= qq {
        group by fn.name, fn.id, fn.se_name, tn.name, tn.id, tn.se_name,
            b.name, b.id, f.logical_name, f.id, f.filesize, f.checksum
        order by fn.name, tn.name
        };

    my $q = execute_sql($core, $sql, %p);

    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref()) {push @r, $_;}

    return \@r;
}

# get transfer error details from the log
sub getErrorLog
{
    my ($core, %h) = @_;

    # save LongReadLen & LongTruncOk
    my $LongReadLen = $$core{DBH}->{LongReadLen};
    my $LongTruncOk = $$core{DBH}->{LongTruncOk};

    $$core{DBH}->{LongReadLen} = 10_000;
    $$core{DBH}->{LongTruncOk} = 1;

    # take care of FROM/FROM_NODE and TO/TO_NODE
    $h{FROM_NODE} = delete $h{FROM} if $h{FROM};
    $h{TO_NODE} = delete $h{TO} if $h{TO};

    my $sql = qq {
        select
            fn.name "from",
            fn.id from_id,
            fn.se_name from_se,
            tn.name "to",
            tn.id to_id,
            tn.se_name to_se,
            b.name block_name,
            b.id   block_id,
            f.logical_name file_name,
            f.id   file_id,
            f.filesize file_size,
            f.checksum checksum,
            xe.xfer_code transfer_code,
            xe.report_code,
            xe.time_assign,
            xe.time_expire,
            xe.time_export,
            xe.time_inxfer,
            xe.time_xfer,
            xe.time_done,
            xe.time_expire,
            xe.from_pfn,
            xe.to_pfn,
            xe.space_token,
            xe.log_xfer,
            xe.log_detail,
            xe.log_validate
        from
            t_xfer_error xe
            join t_adm_node fn on fn.id = xe.from_node
            join t_adm_node tn on tn.id = xe.to_node
            join t_xfer_file f on f.id = xe.fileid
            join t_dps_block b on b.id = f.inblock
            join t_dps_dataset d on b.dataset = d.id
        where
            not fn.name like 'X%' and
            not tn.name like 'X%'
        };

    my @r;
    my %p;
    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM_NODE => 'fn.name',
        TO_NODE => 'tn.name',
        BLOCK => 'b.name',
        LFN => 'f.logical_name',
        DATASET => 'd.name'
        ));

    $sql .= " and ( $filters )" if $filters;
    $sql .= qq {
        order by fn.name, tn.name, xe.time_done desc
        };

    my $q = execute_sql($core, $sql, %p);

    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref())
    {
        $_->{LOG_XFER} = {'$T' => delete $_->{LOG_XFER}};
        $_->{LOG_DETAIL} = {'$T' => delete $_->{LOG_DETAIL}};
        $_->{LOG_VALIDATE} = {'$T' => delete $_->{LOG_VALIDATE}};
        push @r, $_;
    }

    # restore LongReadLen & LongTruncOk

    $$core{DBH}->{LongReadLen} = $LongReadLen;
    $$core{DBH}->{LongTruncOk} = $LongTruncOk;

    return \@r;
}

sub getBlockTestFiles
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    my ($detailed_items, $detailed_from);
    if ($h{'#DETAILED#'})
    {
        $detailed_items = qq {,
            f.logical_name,
            s2.name f_status,
            f.id f_id,
            f.filesize f_bytes,
            f.checksum
        };
        $detailed_from = qq {
            join t_dvs_file_result r on r.request = v.id
            join t_dps_file f on f.id = r.fileid
            join t_dvs_status s2 on r.status = s2.id
        };
    }

    $sql = qq {
        select
            v.id,
            b.name block,
            block blockid,
            b.files,
            b.bytes,
            n_files,
            n_tested,
            n_ok,
            s.name status,
            t.name kind,
            time_reported,
            n.name node,
            n.id nodeid,
            n.se_name se
            $detailed_items
        from
            t_status_block_verify v
            join t_dvs_status s on v.status = s.id
            left join t_dps_block b on v.block = b.id
            join t_dvs_test t on v.test = t.id
            join t_adm_node n on n.id = v.node
            $detailed_from
    };

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, ( NODE => 'n.name',
						      BLOCK => 'b.name',
                                                      KIND => 't.name',
                                                      STATUS => 's.name',
                                                      TEST => 'v.id'
						      ));

    $sql .= " where ($filters) " if  $filters;

    if (exists $h{TEST_SINCE})
    {
        if ($filters)
        {
            $sql .= " and time_reported >= :test_since ";
        }
        else
        {
            $sql .= " where time_reported >= :test_since ";
        }
        $p{':test_since'} = &str2time($h{TEST_SINCE});
    }

    $sql .= " order by time_reported ";
    $q = execute_sql( $core, $sql, %p);

    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
    return \@r;
}

sub getDataSubscriptions
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            s.request,
            NVL2(s.block, 'block', 'dataset') "level",
            NVL2(s.block, s.block, s.dataset) item_id,
            NVL2(s.block, b.name, ds.name) item_name,
            NVL2(s.block, b.is_open, ds.is_open) open,
            NVL2(s.block, b.time_update, ds.time_update) time_update,
            ds.id dataset_id,
            ds.name dataset_name,
            n.id node_id,
            n.name node,
            n.se_name se,
            s.dataset subs_dataset,
            s.block subs_block,
            s.priority,
            s.is_move move,
            s.is_custodial custodial,
            g.name "group",
            NVL2(s.time_suspend_until, 'y', 'n') suspended,
            s.time_suspend_until suspend_until,
            s.time_create,
            b.files files,
            b.bytes bytes,
            reps.node_files,
            reps.node_bytes
        from
            t_dps_subscription s
            join t_adm_node n on n.id = s.destination
            left join t_dps_block b on b.id = s.block
            left join t_dps_dataset ds on ds.id = s.dataset or ds.id = b.dataset
            left join t_adm_group g on g.id = s.user_group
            join
            (select
                s2.destination,
                s2.dataset,
                s2.block,
                sum(br.node_files) node_files,
                sum(br.node_bytes) node_bytes
            from
                t_dps_subscription s2
                left join t_dps_block b2 on b2.dataset = s2.dataset or b2.id = s2.block
                left join t_dps_block_replica br on br.node = s2.destination and br.block = b2.id
            group by
                s2.destination,
                s2.dataset,
                s2.block
            ) reps
            on reps.destination = s.destination
            and (reps.dataset = s.dataset or reps.block = s.block)
    };

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, ( 
                                                      SE => 'n.se_name',
                                                      REQUEST => 's.request',
                                                      GROUP => 'g.name',
                                                      NODE => 'n.name',
                                                      BLOCK => 'b.name',
                                                      DATASET => 'ds.name'
						      ));

    if (exists $h{SUSPENDED})
    {
        if ($h{SUSPENDED} eq 'y')
        {
            if ($filters)
            {
                $filters .= qq { and not s.time_suspend_until is null };
            }
            else
            {
                $filters = qq { not s.time_suspend_until is null };
            }
        }
        elsif ($h{SUSPENDED} eq 'n')
        {
            if ($filters)
            {
                $filters .= qq { and s.time_suspend_until is null };
            }
            else
            {
               $filters = qq { s.time_suspend_until is null };
            }
        }
    }

    if (exists $h{CREATE_SINCE})
    {
        if ($filters)
        {
            $filters .= " and s.time_create >= :create_since ";
        }
        else
        {
            $filters = " s.time_create >= :create_since ";
        }
        $p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    if (exists $h{PRIORITY})
    {
        if ($filters)
        {
            $filters .= " and s.priority = :priority ";
        }
        else
        {
            $filters = " s.priority = :priority ";
        }
        $p{':priority'} = PHEDEX::Core::Util::priority_num($h{PRIORITY}, 0);
    }

    if (exists $h{MOVE})
    {
        if ($filters)
        {
            $filters .= " and s.is_move = :move ";
        }
        else
        {
            $filters = " s.is_move = :move ";
        }
        $p{':move'} = $h{MOVE};
    }

    if (exists $h{CUSTODIAL})
    {
        if ($filters)
        {
            $filters .= " and s.is_custodial = :custodial";
        }
        else
        {
            $filters = " s.is_custodial = :custodial";
        }
        $p{':custodial'} = $h{CUSTODIAL};
    }

    $sql .= "where ($filters) " if ($filters);
    $sql .= qq {
        order by
            s.time_create desc,
            s.dataset desc,
            s.block desc,
            n.name
    };

    $q = execute_sql( $core, $sql, %p);

    while ( $_ = $q->fetchrow_hashref() )
    {
        $_->{PRIORITY} = PHEDEX::Core::Util::priority($_ -> {'PRIORITY'}, 0);
        push @r, $_;
    }
    return \@r;
    
}


# getMissingFiles
sub getMissingFiles
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            b.id block_id,
            b.name block_name,
            b.files block_files,
            b.bytes block_bytes,
            b.is_open,
            f.id file_id,
            f.logical_name,
            f.filesize,
            f.checksum,
            f.time_create,
            ns.name origin_node,
            n.id node_id,
            n.name node_name,
            n.se_name se_name,
            case
                when br.dest_files = 0 then 'n'
                else 'y'
            end subscribed,
            br.is_custodial,
            g.name user_group
        from t_dps_block b
        join t_dps_dataset d on b.dataset = d.id,
        join t_dps_file f on f.inblock = b.id
        join t_adm_node ns on ns.id = f.node
        join t_dps_block_replica br on br.block = b.id and br.is_active = 'y'
        left join t_adm_group g on g.id = br.user_group
        left join t_adm_node n on n.id = br.node
        where
            (br.node_files != 0 or br.dest_files != 0) and
            not exists (
                select
                    id
                from
                    t_xfer_replica xr
                where
                    xr.node = br.node and xr.fileid = f.id
            )
            and not ns.name like 'X%'
            and not n.name like 'X%'
    };

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
                                              SE => 'n.se_name',
                                              GROUP => 'g.name',
                                              LFN => 'f.logical_name',
                                              DATASET => 'd.name'));

    $sql .= " and ($filters) " if ($filters);

    if (exists $h{BLOCK})
    {
        # translate the wildcard character
        $h{BLOCK} =~ s/\*/%/g;

        $sql .= " and (" . filter_and_like($core, undef, \%p, 'b.name', $h{BLOCK}) . ") ";
    }

    if (exists $h{NODE})
    {
        # translate the wildcard character
        $h{NODE} =~ s/\*/%/g;

        $sql .= " and (" . filter_and_like($core, undef, \%p, 'n.name', $h{NODE}) . ") ";
    }

    if (exists $h{SUBSCRIBED})
    {
        if ($h{SUBSCRIBED} eq 'y')
        {
            $sql .= " and br.dest_files <> 0 ";
        }
        elsif ($h{SUBSCRIBED} eq 'n')
        {
            $sql .= " and br.dest_files = 0 ";
        }
    }

    if (exists $h{CUSTODIAL})
    {
        $sql .= " and br.is_custodial = :custodial ";
        $p{':custodial'} = $h{CUSTODIAL};
    }

    $sql .= qq {
        order by
            b.name,
            f.logical_name,
            n.name
    };

    $q = execute_sql($core, $sql, %p);
    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref())
    {
        push @r, $_;
    }
    return \@r

}

# getLinks -- get link information
sub getLinks
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            fn.name from_node,
            tn.name to_node,
            l.is_active,
            l.is_local,
            fn.kind from_kind,
            tn.kind to_kind,
            xso.time_update source_update,
            xso.protocols source_protos,
            xsi.time_update sink_update,
            xsi.protocols sink_protos
        from
            t_adm_link l
            join t_adm_node fn on fn.id = l.from_node
            join t_adm_node tn on tn.id = l.to_node
            left join t_xfer_source xso on xso.from_node = fn.id
                    and xso.to_node = tn.id
            left join t_xfer_sink xsi on xsi.from_node = fn.id
                    and xsi.to_node = tn.id
        where
            not fn.name like 'X%' and
            not tn.name like 'X%'
    };

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM => 'fn.name',
        TO => 'tn.name'
    ));

    $sql .= " and ($filters) " if ($filters);

    my $now = time();
    my $downtime = 5400 + 15*60;  # Hour and a half (real expiration) + 15 minutes grace time

    $q = execute_sql($core, $sql, %p);
    my $links = $q->fetchall_arrayref();
    my %link_params;
    my (%from_nodes, %to_nodes);
    foreach my $link (@{$links}) {
        my ($from, $to, $is_active, $is_local, $from_kind, $to_kind,
            $xso_update, $xso_protos, $xsi_update, $xsi_protos) = @{$link};
        my $key = $from.'-->'.$to;
        $link_params{$key} = { 
                               FROM => $from,
                               TO => $to,
                               TO_AGENT_UPDATE => $xsi_update,
                               FROM_AGENT_UPDATE => $xso_update,
                               FROM_KIND => $from_kind,
                               TO_KIND => $to_kind,
                               FROM_AGENT_PROTOCOLS => $xso_protos,
                               TO_AGENT_PROTOCOLS => $xsi_protos
                               };

	# Explain why links are valid or invalid.  For now we benefit
	# from the fact the xfer_source/xfer_sink tables are never
	# cleaned up.  Exclusion deletes from xfer_source, and
	# xfer_sink, so if there is an old update we know the agent is
	# down, if there is no entry, we know the node has been
	# excluded.  It would be nice to do a more explicit check for
	# this but for now the logic is ok.
	if ($from_kind eq 'MSS' && $to_kind eq 'Buffer') { # Staging link
	    $link_params{$key}{VALID} = 1;
	    $link_params{$key}{STATUS} = 'ok';
            $link_params{$key}{KIND} = 'Staging';
	} elsif ($from_kind eq 'Buffer' && $to_kind eq 'MSS') { # Migration link
            $link_params{$key}{KIND} = 'Migration';
	    if (!$xsi_update) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'mi_excluded';
	    } elsif ($xsi_update <= ($now - $downtime)) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'mi_down';
		$link_params{$key}{TO_AGENT_AGE} = &age($now - $xsi_update);
	    } else {
		$link_params{$key}{VALID} = 1;
		$link_params{$key}{STATUS} = 'ok';
		$link_params{$key}{TO_AGENT_AGE} = &age($now - $xsi_update);
	    }
	} else { # WAN or Local link
            if ($is_local eq 'y')
            {
                $link_params{$key}{KIND} = 'Local';
            }
            else
            {
                $link_params{$key}{KIND} = 'WAN';
            }

	    if (!$xso_update) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'from_excluded';
	    } elsif ($xso_update <= ($now - $downtime)) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'from_down';
		$link_params{$key}{FROM_AGENT_AGE} = &age($now - $xso_update);
	    } elsif (!$xsi_update) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'to_excluded';
	    } elsif ($xsi_update <= ($now - $downtime)) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = 'to_down';
		$link_params{$key}{TO_AGENT_AGE} = &age($now - $xsi_update);
	    } else {
		$link_params{$key}{VALID} = 1;
		$link_params{$key}{STATUS} = 'ok';
		$link_params{$key}{FROM_AGENT_AGE} = &age($now - $xso_update);
		$link_params{$key}{TO_AGENT_AGE} = &age($now - $xsi_update);
	    }
	}

 	# Check active state
 	if ($is_active ne 'y') {
 	    $link_params{$key}{VALID} = 0;
 	    $link_params{$key}{STATUS} = "deactivated";
 	}
	
	# Check protocols
	if ($link_params{$key}{VALID}) {
	    my @from_protos = split(/\s+/, $xso_protos || '');
	    my @to_protos   = split(/\s+/, $xso_protos || '');
	    my $match = 0;
	    foreach my $p (@to_protos) {
		next if ! grep($_ eq $p, @from_protos);
		$match = 1;
		last;
	    }
	    unless ($match) {
		$link_params{$key}{VALID} = 0;
		$link_params{$key}{STATUS} = "No matching protocol";
	    }
	}

    }

    # handle status and/or kind arguments
    # -- perl does not have "in" operator, got to simulate it

    my (%status, %kind);

    if (exists $h{STATUS})
    {
        if (ref($h{STATUS}) eq 'ARRAY')
        {
            foreach (@{$h{STATUS}})
            {
                $status{$_} = 1;
            }
        }
        else
        {
            $status{$h{STATUS}} = 1;
        }
    }
    
    if (exists $h{KIND})
    {
        if (ref($h{KIND}) eq 'ARRAY')
        {
            foreach (@{$h{KIND}})
            {
                $kind{$_} = 1;
            }
        }
        else
        {
            $kind{$h{KIND}} = 1;
        }
    }
    
    while (my ($key, $link) = each(%link_params))
    {
        if (%status)
        {
            if (not $status{$$link{STATUS}})
            {
                next; # short-circuit
            }
        }

        if (%kind)
        {
            if (not $kind{$$link{KIND}})
            {
                next; # short-circuit
            }
        }

        delete $$link{VALID};
        push @r, $link;
    }

    return \@r;
}

sub getDeletions
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            del.request,
            n.name node,
            n.id node_id,
            n.se_name se,
            b.name block,
            b.id block_id,
            b.files,
            b.bytes,
            d.is_open,
            d.name dataset,
            d.id dataset_id,
            del.time_request,
            del.time_complete,
            case
                when del.time_complete >= del.time_request then 'y'
                else 'n'
            end complete
        from
            t_dps_block_delete del
            join t_dps_block b on b.id = del.block
            join t_adm_node n on n.id = del.node
            join t_dps_dataset d on del.dataset = d.id
        where
            not n.name like 'X%'
    };

    # completness
    if (exists $h{COMPLETE})
    {
        if ($h{COMPLETE} eq 'y')
        {
            $sql .= " and del.time_complete >= del.time_request ";
        }
        elsif ($h{COMPLETE} eq 'n')
        {
            $sql .= " and del.time_complete is null ";
        }
        # ignore other values
    }

    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        NODE => 'n.name',
        ID => 'b.id',
        REQUEST => 'del.request',
        SE => 'n.se_name',
        DATASET => 'd.name'));

    $sql .= qq { and ($filters) } if ($filters);

    if (exists $h{BLOCK})
    {
        $sql .= " and ( " . filter_and_like($core, undef, \%p, 'b.name', $h{BLOCK}) . " ) ";
    }

    if (exists $h{REQUEST_SINCE})
    {
        $sql .= " and del.time_request >= :request_since ";
        $p{':request_since'} =  str2time($h{REQUEST_SINCE}, $h{REQUEST_SINCE});
    }

    if (exists $h{COMPLETE_SINCE})
    {
        $sql .= " and del.time_complete >= :complete_since";
        $p{':complete_since'} = str2time($h{COMPLETE_SINCE}, $h{COMPLETE_SINCE});
    }

    $sql .= qq {
            order by del.time_complete desc, del.time_request desc
    };

    $q = execute_sql( $core, $sql, %p);
    while ( $_ = $q->fetchrow_hashref() )
    {
        push @r, $_;
    }

    return \@r;
}

sub getRoutingInfo
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            nd.name destination,
            ns.name source,
            b.name block,
            b.id block_id,
            b.files,
            b.bytes,
            s.priority,
            s.is_valid,
            s.route_files,
            s.route_bytes,
            s.xfer_attempts,
            s.time_request
        from
            t_status_block_path s
            join t_adm_node nd on nd.id = s.destination
            join t_adm_node ns on ns.id = s.src_node
            join t_dps_block b on b.id = s.block
        where
            not nd.name like 'X%' and
            not ns.name like 'X%'
    };

    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        SOURCE => 'ns.name',
        DESTINATION => 'nd.name'));

    $sql .= qq { and ($filters) } if ($filters);

    if (exists $h{BLOCK})
    {
        $sql .= " and ( " . filter_and_like($core, undef, \%p, 'b.name', $h{BLOCK}) . " ) ";
    }

    $sql .= qq {
        order by s.time_request
    };

    $q = execute_sql($core, $sql, %p);

    while ($_ = $q->fetchrow_hashref())
    {
        $_->{'PRIORITY'} = &PHEDEX::Core::Util::priority($_->{'PRIORITY'});
        $_->{AVG_ATTEMPTS} = ($_->{ROUTE_FILES})?($_->{XFER_ATTEMPTS}/$_->{ROUTE_FILES}): 'N/A';

        push @r, $_;
    }

    return \@r;

}

sub getRoutedBlocks
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    $sql = qq {
        select
            ns.name "from",
            ns.id from_id,
            ns.se_name from_se,
            nd.name "to",
            nd.id to_id,
            nd.se_name to_se,
            b.name block,
            b.id block_id,
            b.files,
            b.bytes,
            s.priority,
            case s.is_valid
                when 1 then 'y'
                else 'n'
            end valid,
            s.route_files,
            s.route_bytes,
            s.xfer_attempts,
            s.time_request
        from
            t_status_block_path s
            join t_adm_node nd on nd.id = s.destination
            join t_adm_node ns on ns.id = s.src_node
            join t_dps_block b on b.id = s.block
            join t_dps_dataset d on b.dataset = d.id
        where
            not nd.name like 'X%' and
            not ns.name like 'X%'
    };

    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM => 'ns.name',
        TO => 'nd.name',
        BLOCK => 'b.name',
        DATASET => 'd.name'));

    $sql .= qq { and ($filters) } if ($filters);

    if (exists $h{VALID})
    {
        if ($h{VALID} eq 'y')
        {
            $sql .= " and s.is_valid = 1 ";
        }
        elsif ($h{VALID} eq 'n')
        {
            $sql .= " and s.is_valid = 0 ";
        }
    }

    $sql .= qq {
        order by s.time_request
    };

    $q = execute_sql($core, $sql, %p);

    while ($_ = $q->fetchrow_hashref())
    {
        $_->{'PRIORITY'} = &PHEDEX::Core::Util::priority($_->{'PRIORITY'});
        $_->{AVG_ATTEMPTS} = ($_->{ROUTE_FILES})?($_->{XFER_ATTEMPTS}/$_->{ROUTE_FILES}): 'N/A';

        push @r, $_;
    }

    return \@r;

}

sub getAgentHistory
{
    my $core = shift;
    my %h = @_;
    my ($sql, $q, %p, @r);

    if (not exists $h{UPDATE_SINCE})
    {
        $h{UPDATE_SINCE} = time() - 3600*24;
    }

    $sql = qq {
        select
            time_update,
            reason,
            user_name,
            host_name,
            process_id pid,
            working_directory,
            state_directory
        from
            t_agent_log
    };

    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        USER => 'user_name',
        HOST => 'host_name'));

    $sql .= " where time_update >= :update_since ";
    $p{':update_since'} = str2time($h{UPDATE_SINCE}, $h{UPDATE_SINCE});

    $sql .= " and ($filters) " if ($filters);

    $sql .= " order by time_update ";

    $q = execute_sql($core, $sql, %p);
    while ($_ = $q->fetchrow_hashref())
    {
        push @r, $_;
    }

    return \@r;
}

sub getAgentLogs
{
    my ($core, %h) = @_;

    # save LongReadLen & LongTruncOk
    my $LongReadLen = $$core{DBH}->{LongReadLen};
    my $LongTruncOk = $$core{DBH}->{LongTruncOk};

    $$core{DBH}->{LongReadLen} = 10_000;
    $$core{DBH}->{LongTruncOk} = 1;

    my ($sql, $q, %p, @r);

    if (not exists $h{UPDATE_SINCE})
    {
        $h{UPDATE_SINCE} = time() - 3600*24;
    }

    $sql = qq {
        select
            l.time_update,
            l.reason,
            l.user_name "user",
            l.host_name host,
            l.process_id pid,
            l.working_directory,
            l.state_directory,
            nvl(a.name, 'N/A') agent,
            n.name node,
            n.id node_id,
            n.se_name se,
            l.message
        from
            t_agent_log l
            left join t_agent_status s on
                l.host_name = s.host_name and
                l.process_id = s.process_id
            left join t_agent a on a.id = s.agent
            join t_adm_node n on s.node = n.id
    };

    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        USER => 'l.user_name',
        HOST => 'l.host_name',
        NODE => 'n.name',
        PID => 'l.process_id',
        AGENT => 'a.name'));

    $sql .= " where l.time_update >= :update_since ";
    $p{':update_since'} = str2time($h{UPDATE_SINCE}, $h{UPDATE_SINCE});

    $sql .= " and ($filters) " if ($filters);
    $sql .= " order by n.name, l.time_update ";

    $q = execute_sql($core, $sql, %p);
    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref())
    {
        $_->{MESSAGE} = {'$T' => delete $_->{MESSAGE}}; 
        push @r, $_;
    }

    $$core{DBH}->{LongReadLen} = $LongReadLen;
    $$core{DBH}->{LongTruncOk} = $LongTruncOk;

    return \@r;
}

sub getNodeUsageHistory
{
    my ($core, %h) = @_;
    my ($sql, $q, %p, @r);

    # default BINWIDTH is 1 hour
    if (exists $h{BINWIDTH})
    {
        $p{':BINWIDTH'} = $h{BINWIDTH};
    }
    else
    {
        $p{':BINWIDTH'} = 3600;
    }

    # default endtime is now
    if (exists $h{ENDTIME})
    {
        $p{':ENDTIME'} = &str2time($h{ENDTIME});
    }
    else
    {
        $p{':ENDTIME'} = time();
    }

    # default start time is 1 hour before
    if (exists $h{STARTTIME})
    {
        $p{':STARTTIME'} = &str2time($h{STARTTIME});
    }
    else
    {
        $p{':STARTTIME'} = $p{':ENDTIME'} - $p{':BINWIDTH'};
    }

    my $full_extent = ($p{':BINWIDTH'} == ($p{':ENDTIME'} - $p{':STARTTIME'}));

    $sql = qq {
        select
            n.name as node_name,
            n.id as node_id,
            n.se_name as se, 
            :BINWIDTH as binwidth,
    };

    if ($full_extent)
    {
        $sql .= qq { :STARTTIME as timebin, };
    }
    else
    {
        $sql .= qq {
            trunc(timebin / :BINWIDTH) * :BINWIDTH as timebin, };
    }

    $sql .= qq {
            trunc(nvl(avg(d.cust_node_files), 0)) as cust_node_files,
            trunc(nvl(avg(d.cust_node_bytes), 0)) as cust_node_bytes,
            trunc(nvl(avg(d.cust_dest_files), 0)) as cust_dest_files,
            trunc(nvl(avg(d.cust_dest_bytes), 0)) as cust_dest_bytes,
            trunc(nvl(avg(d.node_files - d.cust_node_files), 0)) as noncust_node_files,
            trunc(nvl(avg(d.node_bytes - d.cust_node_bytes), 0)) as noncust_node_bytes,
            trunc(nvl(avg(d.dest_files - d.cust_dest_files), 0)) as noncust_dest_files,
            trunc(nvl(avg(d.dest_bytes - d.cust_dest_bytes), 0)) as noncust_dest_bytes,
            trunc(nvl(avg(d.src_files), 0)) as src_node_files,
            trunc(nvl(avg(d.src_bytes), 0)) as src_node_bytes
        from
            t_history_dest d,
            t_adm_node n
        where
            n.id = d.node and
            d.timebin >= :STARTTIME and
            d.timebin < :ENDTIME
    };

    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        NODE => 'n.name'));

    $sql .= " and ($filters) " if ($filters);

    if ($full_extent)
    {
        $sql .= qq {\ngroup by n.name, n.id, n.se_name };
        $sql .= qq {\norder by n.name };
    }
    else
    {
        $sql .= qq {\ngroup by trunc(timebin / :BINWIDTH) * :BINWIDTH, n.name, n.id, n.se_name };
        $sql .= qq {\norder by 1 asc, 2 };
    }

    $q = execute_sql($core, $sql, %p);

    # spooling?
    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref())
    {
        if ($_->{'TIMEBIN'} and exists $h{CTIME})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime($_->{'TIMEBIN'}));
        }
        push @r, $_;
    }

    return \@r;
}

sub getRouterHistory
{
    my ($core, %h) = @_;
    my ($sql, $q, %p, @r);

    # default BINWIDTH is 1 hour
    if (exists $h{BINWIDTH})
    {
        $p{':BINWIDTH'} = $h{BINWIDTH};
    }
    else
    {
        $p{':BINWIDTH'} = 3600;
    }

    # default endtime is now
    if (exists $h{ENDTIME})
    {
        $p{':ENDTIME'} = &str2time($h{ENDTIME});
    }
    else
    {
        $p{':ENDTIME'} = time();
    }

    # default start time is 1 hour before
    if (exists $h{STARTTIME})
    {
        $p{':STARTTIME'} = &str2time($h{STARTTIME});
    }
    else
    {
        $p{':STARTTIME'} = $p{':ENDTIME'} - $p{':BINWIDTH'};
    }

    my $full_extent = ($p{':BINWIDTH'} == ($p{':ENDTIME'} - $p{':STARTTIME'}));


    $sql = qq {
        select
            fn.name from_node,
            tn.name to_node,
    };

    if ($full_extent)
    {
        $sql .= qq { :STARTTIME as timebin, };
    }
    else
    {
        $sql .= qq {
            trunc(hs.timebin / :BINWIDTH) * :BINWIDTH as timebin, };
    }

    $sql .= qq {
            :BINWIDTH as binwidth,
            trunc(nvl(avg(hs.confirm_files),0)) route_files,
            trunc(nvl(avg(hs.confirm_bytes),0)) route_bytes,
            trunc(avg(hs.param_rate)) rate,
            trunc(avg(hs.param_latency)) latency,
            trunc(nvl(avg(hd.request_files),0)) request_files,
            trunc(nvl(avg(hd.request_bytes),0)) request_bytes,
            trunc(nvl(avg(hd.idle_files),0)) idle_files,
            trunc(nvl(avg(hd.idle_bytes),0)) idle_bytes
        from
            t_history_link_stats hs
            full join t_history_dest hd
                on hd.timebin = hs.timebin
                and hd.node = hs.to_node
            join t_adm_node tn on tn.id = nvl(hs.to_node,hd.node)
            left join t_adm_node fn on fn.id = hs.from_node
        where
            hs.timebin >= :STARTTIME and
            hs.timebin < :ENDTIME
    };


    my $filters = '';

    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM => 'fn.name',
        TO => 'tn.name'));

    $sql .= " and ($filters) " if ($filters);

    if ($full_extent)
    {
        $sql .= qq {\ngroup by fn.name, tn.name };
        $sql .= qq {\norder by tn.name, fn.name };
    }
    else
    {
        $sql .= qq {\ngroup by trunc(hs.timebin / :BINWIDTH) * :BINWIDTH, fn.name, tn.name};
        $sql .= qq {\norder by 2, 3, 1 };
    }

    $q = execute_sql($core, $sql, %p);

    if (exists $h{'__spool__'})
    {
        return $q;
    }

    while ($_ = $q->fetchrow_hashref())
    {
        if ($_->{'TIMEBIN'} and exists $h{CTIME})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime($_->{'TIMEBIN'}));
        }
        push @r, $_;
    }

    return \@r;
}

sub getPendingRequests
{
    my ($core, %h) = @_;

    my $sql = qq {
        select
            distinct r.id
        from
            t_req_request r
            join t_req_node n on r.id = n.request
            join t_adm_node n2 on n2.id = n.node
            join t_adm_client c on c.id = r.created_by
            join t_adm_identity i on i.id = c.identity
            left join t_req_decision d on d.request = n.request and d.node = n.node
        where
            d.node is null };
    my %p;
    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        USERNAME => 'i.username',
        NODE => 'n2.name'));

    $sql .= " and ($filters) " if $filters;

    if (exists $h{CREATE_SINCE})
    {
        $sql .= " and r.time_create >= :create_since ";
        $p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    $sql .= " order by r.id ";

    # my $q = execute_sql($core, $sql, %p);
    my $r = select_single($core, $sql, %p);
    my $type;
    if (exists $h{TYPE})
    {
        $type = $h{TYPE};
    }
    else
    {
        $type = 'xfer';
    }
    my %param = ( TYPE => $type, REQUEST => $r );
    if (not @{$r})
    {
        return [];
    }
    return getRequestData($core, %param);
}

sub getRequestList
{
    my ($core, %h) = @_;

    my $join_group;
    if (exists $h{GROUP})
    {
        $join_group = qq {join t_req_xfer rx on rx.request = r.id
            join t_adm_group g on g.id = rx.user_group};
    }
    my $sql = qq {
        select
          distinct
            r.id,
            rt.name as type,
            i.name as requested_by,
            r.time_create,
            n.id as node_id,
            n.name as node_name,
            n.se_name,
            case
                when d.decision = 'y' then 'approved'
                when d.decision = 'n' then 'disapproved'
                when d.decision is NULL then 'pending'
            end as decision,
            i2.name as decided_by,
            d.time_decided
        from
            t_req_request r
            $join_group
            join t_req_type rt on rt.id = r.type
            join t_req_node rn on r.id = rn.request
            join t_adm_node n on n.id = rn.node
            join t_adm_client c on c.id = r.created_by
            join t_adm_identity i on i.id = c.identity
            left join t_req_decision d on d.request = rn.request and d.node = rn.node
            left join t_adm_client c2 on c2.id = d.decided_by
            left join t_adm_identity i2 on i2.id = c2.identity
        where
            1 = 1 
    };

    my %p;
    my $filters = '';
    my %filter_args = (
        REQUESTED_BY => 'i.name',
        REQUEST => 'r.id',
        TYPE => 'rt.name',
        DECIDED_BY => 'i2.name' );
    if (exists $h{GROUP})
    {
        $filter_args{GROUP} = 'g.name';
    }

    build_multi_filters($core, \$filters, \%p, \%h, %filter_args);

    $sql .= " and ($filters) " if $filters;

    if (exists $h{CREATE_SINCE})
    {
        $sql .= " and r.time_create >= :create_since ";
        $p{':create_since'} = &str2time($h{CREATE_SINCE});
    }

    if (exists $h{CREATE_UNTIL})
    {
        $sql .= " and r.time_create <= :create_until ";
        $p{':create_until'} = &str2time($h{CREATE_UNTIL});
    }

    if (exists $h{DECIDE_SINCE})
    {
        $sql .= " and d.time_decided >= :decide_since ";
        $p{':decide_since'} = &str2time($h{DECIDE_SINCE});
    }

    if (exists $h{DECIDE_UNTIL})
    {
        $sql .= " and d.time_decided <= :decide_until ";
        $p{':decide_until'} = &str2time($h{DECIDE_UNTIL});
    }


    if (exists $h{APPROVAL})
    {
        my $sql2 = qq {
            and r.id in (
            select id from
                (select
                    r.id,
                    count(*) as nodes,
                    sum(
                        case d.decision
                            when 'y' then 1
                            else 0
                        end) as yes,
                    sum(
                        case d.decision
                            when 'n' then 1
                            else 0
                        end) as no
                 from
                    t_req_request r
                    join t_req_node rn on rn.request = r.id
                    left join t_req_decision d on d.request = r.id and d.node = rn.node
                 group by r.id)
            where };

        # do this only if $h{APPROVAL} is one of the followings
        if ($h{APPROVAL} eq 'approved')
        {
            $sql .= $sql2 . " yes = nodes ) ";
        }
        elsif ($h{APPROVAL} eq 'disapproved')
        {
            $sql .= $sql2 . " no = nodes ) ";
        }
        elsif ($h{APPROVAL} eq 'pending')
        {
            $sql .= $sql2 . " yes + no < nodes ) ";
        }
        elsif ($h{APPROVAL} eq 'mixed')
        {
            $sql .= $sql2 . " yes + no = nodes and yes > 0 and no > 0 ) ";
        }
    }

    # take care of node and/or decision
    #
    # if $h{NODE} exists, the requests are limited to those that have
    #    NODE in them
    # if $h{DECISION} exists, the requests are limited to those that
    #    have a NODE with that decision
    # if $h{NODE} and $h{DECISION} both exist, the request are limited
    #    to that that have NODE with DECISION
    #
    # in any case, the final result contains complete requests
    #
    if (exists $h{NODE} and exists $h{DECISION})
    {
        my $filters = '';
        build_multi_filters($core, \$filters, \%p, \%h, (
            NODE => 'n2.name'));

        # make the code readable
        if ($filters)
        {
            $sql .= qq {
                and r.id in
                (select
                    rn2.request
                from
                    t_req_node rn2
                    join t_adm_node n2 on rn2.node = n2.id
                    left join t_req_decision d2 on d2.request = rn2.request and d2.node = rn2.node
                where } . " ( $filters ) " ;
            if ($h{DECISION} eq 'approved')
            {
                $sql .= qq { and d2.decision = 'y' ) };
            }
            elsif ($h{DECISION} eq 'disapproved')
            {
                $sql .= qq { and d2.decision = 'n' ) };
            }
            elsif ($h{DECISION} eq 'pending')
            {
                $sql .= qq { and d2.decision is NULL ) };
            }
        }
    }
    elsif (exists $h{NODE})
    {
        my $filters = '';
        build_multi_filters($core, \$filters, \%p, \%h, (
            NODE => 'n.name'));

        # make the code readable

        $sql .= qq {
            and r.id in
            (select
                rn.request
            from
                t_req_node rn
                join t_adm_node n on rn.node = n.id
            where } . " ( $filters )) " if $filters;
    }
    elsif (exists $h{DECISION})
    {
            my $sql2 = qq {
                and r.id in
                (select
                    rn2.request
                from
                    t_req_node rn2
                    join t_adm_node n2 on rn2.node = n2.id
                    left join t_req_decision d2 on d2.request = rn2.request and d2.node = rn2.node
                where };
            if ($h{DECISION} eq 'approved')
            {
                $sql .= $sql2 . qq { d2.decision = 'y' ) };
            }
            elsif ($h{DECISION} eq 'disapproved')
            {
                $sql .= $sql2 . qq { d2.decision = 'n' ) };
            }
            elsif ($h{DECISION} eq 'pending')
            {
                $sql .= $sql2 . qq { d2.decision is NULL ) };
            }
    }

    # take care of DATASET and BLOCK

    my ($dataset_sql, $block_sql);

    if (exists $h{DATASET})
    {
        my $filters = '';
        build_multi_filters($core, \$filters, \%p, \%h, (
            DATASET => 'ds.name'));

        if ($filters)
        {
            $dataset_sql = qq {
                (select
                    ds.request
                from
                    t_req_dataset ds
                where
                    $filters
                union
                select
                    rb.request
                from
                    t_req_block rb
                    join t_dps_block b on b.id = rb.block_id
                    join t_dps_dataset ds on ds.id = b.dataset
                where
                    $filters
                )
            };
        }
    }

    if (exists $h{BLOCK})
    {
        my $filters = '';
        build_multi_filters($core, \$filters, \%p, \%h, (
            BLOCK => 'b.name'));

        if ($filters)
        {
            $block_sql = qq {
                (select
                    b.request
                from
                    t_req_block b
                where
                    $filters
                union
                select
                    rd.request
                from
                    t_req_dataset rd
                    join t_dps_block b on b.dataset = rd.dataset_id
                where
                    $filters
                )
            };
        }
    }

    if ($dataset_sql and $block_sql)	# both, -or-
    {
        $sql .= qq {
            and (
                r.id in $dataset_sql or
                r.id in $block_sql
            )
        };
    }
    elsif ($dataset_sql)
    {
        $sql .= qq {
            and r.id in $dataset_sql
        };
    }
    elsif ($block_sql)
    {
        $sql .= qq {
            and r.id in $block_sql
        };
    }

    $sql .= " order by r.id ";
    my $q = execute_sql($core, $sql, %p);
    my @r;

    while ($_ = $q->fetchrow_hashref())
    {
        push @r, $_;
    }

    return \@r;
}


1;
