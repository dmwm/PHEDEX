package PHEDEX::Web::SQL;

=head1 NAME

PHEDEX::Web::SQL - encapsulated SQL for the web data service

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item getLinkTasks($self)

returns a reference to an array of hashes with the following keys:
TIME_UPDATE, DEST_NODE, SRC_NODE, STATE, PRIORITY, FILES, BYTES.
Each hash represents the current amount of data queued for transfer
(has tasks) for a link given the state and priority

=over

=item *

C<$self> is an object with a DBH member which is a valid DBI database
handle. To call the routine with a bare database handle, use the 
procedural call method.

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';
use Carp;
use POSIX;
use Data::Dumper;
use PHEDEX::Core::Identity;

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

sub getLinkTasks
{
    my ($self, %h) = @_;
    my ($sql,$q,@r);
    
    $sql = qq{
    select
      time_update,
      nd.name dest_node, ns.name src_node,
      state, priority,
      files, bytes
    from t_status_task xs
      join t_adm_node ns on ns.id = xs.from_node
      join t_adm_node nd on nd.id = xs.to_node
     order by nd.name, ns.name, state
 };

    $q = execute_sql( $self, $sql, () );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

# FIXME:  %h keys should be uppercase
sub getNodes
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);

    $sql = qq{
        select n.name,
	       n.id,
	       n.se_name se,
	       n.kind, n.technology
          from t_adm_node n
          where 1=1
               and not n.name like 'X%' 
       };

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h,  node  => 'n.name');
    $sql .= " and ($filters)" if $filters;

    if ( $h{noempty} ) {
	$sql .= qq{ and exists (select 1 from t_dps_block_replica br where br.node = n.id and node_files != 0) };
    }

    $q = execute_sql( $self, $sql, %p );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

# FIXME:  %h keys should be uppercase
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
	       br.is_custodial,
	       g.name user_group
          from t_dps_block_replica br
	  join t_dps_block b on b.id = br.block
	  join t_dps_dataset ds on ds.id = b.dataset
	  join t_adm_node n on n.id = br.node
     left join t_adm_group g on g.id = br.user_group
	 where br.node_files != 0
               and not n.name like 'X%' 
       };

    if (exists $h{complete}) {
	if ($h{complete} eq 'n') {
	    $sql .= qq{ and (br.node_files != b.files or b.is_open = 'y') };
	} elsif ($h{complete} eq 'y') {
	    $sql .= qq{ and br.node_files = b.files and b.is_open = 'n' };
	}
    }

    if (exists $h{custodial}) {
	if ($h{custodial} eq 'n') {
	    $sql .= qq{ and br.is_custodial = 'n' };
	} elsif ($h{custodial} eq 'y') {
	    $sql .= qq{ and br.is_custodial = 'y' };
	}
    }

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h, ( node  => 'n.name',
						      se    => 'n.se_name',
						      block => 'b.name',
						      group => 'g.name' ));
    $sql .= " and ($filters)" if $filters;

    if (exists $h{create_since}) {
	$sql .= ' and br.time_create >= :create_since';
	$p{':create_since'} = $h{create_since};
    }

    if (exists $h{update_since}) {
	$sql .= ' and br.time_update >= :update_since';
	$p{':update_since'} = $h{update_since};
    }

    $q = execute_sql( $self, $sql, %p );
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
    where br.node_files != 0 
            and not ns.name like 'X%'
            and not n.name like 'X%' 
    };

    if (exists $h{complete}) {
	if ($h{complete} eq 'n') {
	    $sql .= qq{ and (br.node_files != b.files or b.is_open = 'y') };
	} elsif ($h{complete} eq 'y') {
	    $sql .= qq{ and br.node_files = b.files and b.is_open = 'n' };
	}
    }

    if (exists $h{dist_complete}) {
	if ($h{dist_complete} eq 'n') {
	    $sql .= qq{ and (b.is_open = 'y' or
			     not exists (select 1 from t_dps_block_replica br2
                                          where br2.block = b.id 
                                            and br2.node_files = b.files)) };
	} elsif ($h{dist_complete} eq 'y') {
	    $sql .= qq{ and b.is_open = 'n' 
			and exists (select 1 from t_dps_block_replica br2
                                     where br2.block = b.id 
                                       and br2.node_files = b.files) };
	}
    }

    if (exists $h{custodial}) {
	if ($h{custodial} eq 'n') {
	    $sql .= qq{ and br.is_custodial = 'n' };
	} elsif ($h{custodial} eq 'y') {
	    $sql .= qq{ and br.is_custodial = 'y' };
	}
    }

    # handle lfn
    if (exists $h{lfn}) {
        $sql .= qq { and f.logical_name = '$h{lfn}' };
    }

    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h, ( node  => 'n.name',
						      se    => 'n.se_name',
						      block => 'b.name',
						      group => 'g.name' ));
    $sql .= " and ($filters)" if $filters;

    if (exists $h{create_since}) {
	$sql .= ' and br.time_create >= :create_since';
	$p{':create_since'} = $h{create_since};
    }

    if (exists $h{update_since}) {
	$sql .= ' and br.time_update >= :update_since';
	$p{':update_since'} = $h{update_since};
    }

    $q = execute_sql( $self, $sql, %p );
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
    my $sql = qq {
        select
            n.name as node,
            n.id as id,
            a.name as name,
            s.label,
            n.se_name as se,
            s.host_name as host,
            s.directory_path as state_dir,
            v.release as version,
            v.revision as cvs_version,
            v.tag as cvs_tag,
            s.process_id as pid,
            s.time_update
        from
            t_agent_status s,
            t_agent a,
            t_adm_node n,
           (select distinct
                node,
                agent,
                release,
                revision,
                tag
             from
                t_agent_version) v
        where
            s.node = n.id and
            s.agent = a.id and
            s.node = v.node and
            s.agent = v.agent and
            not n.name like 'X%' };

    my %p;
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
    my %node;
    while ( $_ = $q->fetchrow_hashref())
    {
        if ($node{$_ -> {'NODE'}})
        {
            push @{$node{$_ -> {'NODE'}}->{agent}},{
                    name => $_ -> {'NAME'},
                    label => $_ -> {'LABEL'},
                    version =>  $_ -> {'VERSION'},
                    cvs_version => $_ -> {'CVS_VERSION'},
                    cvs_tag => $_ -> {'CVS_TAG'},
                    time_update => $_ -> {'TIME_UPDATE'},
                    state_dir => $_ -> {'STATE_DIR'},
                    pid => $_ -> {'PID'}};
        }
        else
        {
            $node{$_ -> {'NODE'}} = {
                node => $_ -> {'NODE'},
                host => $_ -> {'HOST'},
                se => $_ -> {'SE'},
                id => $_ -> {'ID'},
                agent => [{
                    name => $_ -> {'NAME'},
                    label => $_ -> {'LABEL'},
                    version =>  $_ -> {'VERSION'},
                    cvs_version => $_ -> {'CVS_VERSION'},
                    cvs_tag => $_ -> {'CVS_TAG'},
                    time_update => $_ -> {'TIME_UPDATE'},
                    state_dir => $_ -> {'STATE_DIR'},
                    pid => $_ -> {'PID'}}]
             };
        }
    }

    while (my ($key, $value) = each(%node))
    {
        push @r, $value;
    }

    return \@r;
}

my %state_name = (
    0 => 'assigned',
    1 => 'exported',
    2 => 'transferring',
    3 => 'transferred'
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

sub getTransferQueueFiles
{
    my ($self, %h) = @_;
    my ($sql, $q, %p);
    $sql = qq {
      select fn.name from_name, fn.id from_id, fn.se_name from_se, 
             tn.name to_name, tn.id to_id, tn.se_name to_se,
             b.name block_name, b.id block_id,
             f.id fileid, f.filesize, f.checksum, f.logical_name,
             xt.priority,
        case when xtd.task is not null then 'transferred'
             when xtx.task is not null then 'transferring'
             when xte.task is not null then 'exported'
             else 'assigned'
         end state
        from t_xfer_task xt
             left join t_xfer_task_export xte on xte.task = xt.id
             left join t_xfer_task_inxfer xtx on xtx.task = xt.id
             left join t_xfer_task_done   xtd on xtd.task = xt.id
             join t_xfer_file f on f.id = xt.fileid
             join t_dps_block b on b.id = f.inblock
             join t_adm_node fn on fn.id = xt.from_node
             join t_adm_node tn on tn.id = xt.to_node
       where 1=1
   };

    # from / to filters
    my $filters = '';
    build_multi_filters($self, \$filters, \%p, \%h,  from => 'fn.name');
    build_multi_filters($self, \$filters, \%p, \%h,  to   => 'tn.name');

    # priority filter
    if (exists $h{priority}) {
	my $priority = PHEDEX::Core::Util::priority_num($h{priority});
	build_filters($self, \$filters, \%p, 
		      { priority => [ $priority, $priority+1 ] },  # either local or remote
		      priority => 'xt.priority');
    }

    $sql .= " and ($filters)" if $filters;

    $q = PHEDEX::Core::SQL::execute_sql( $self, $sql);
    return $q->fetchall_arrayref({});
}

sub getTransferHistory
{
    # optional inputs are:
    #     strattime, endtime, binwidth, from_node and to_node

    my ($core, %h) = @_;
    my $sql = qq {
    select
        n1.name as from_node,
        n2.name as to_node,
        :BINWIDTH as binwidth,
        trunc(timebin / :BINWIDTH) * :BINWIDTH as timebin,
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
    my %param;
    my @r;

    # default endtime is now
    if (exists $h{ENDTIME})
    {
        $param{':ENDTIME'} = PHEDEX::Core::Util::str2time($h{ENDTIME});
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
        $param{':STARTTIME'} = PHEDEX::Core::Util::str2time($h{STARTTIME});
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
    $sql .= qq {\norder by 1 asc, 2, 3};

    # now execute the query
    my $q = PHEDEX::Core::SQL::execute_sql( $core, $sql, %param );
    while ( $_ = $q->fetchrow_hashref() )
    {
        # format the time stamp
        if ($_->{'TIMEBIN'} and exists $h{CTIME})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime( $_->{'TIMEBIN'}));
        }
        push @r, $_;
    }

    # return $sql, %param;
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
#   REQ_NUM: request number
# DEST_NODE: name of the destination node
#     GROUP: group name
#     LIMIT: maximal number of records
#
sub getRequestData
{
    my ($self, %h) = @_;

    # save LongReadLen & LongTruncOk
    my $LongReadLen = $$self{DBH}->{LongReadLen};
    my $LongTruncOk = $$self{DBH}->{LongTruncOk};

    $$self{DBH}->{LongReadLen} = 10_000;
    $$self{DBH}->{LongTruncOk} = 1;

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
            rx.data user_text};
    }
    else
    {
        $sql .= qq {
            rd.rm_subscriptions,
            rd.data user_text};
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

    if (exists $h{REQ_NUM})
    {
        $sql .= qq {\n            and r.id = $h{REQ_NUM}};
    }

    if ($h{TYPE} eq 'xfer' && exists $h{GROUP})
    {
        $sql .= qq {\n            and g.name = '$h{GROUP}'};
    }

    if (exists $h{LIMIT})
    {
        $sql .= qq {\n            and rownum <= $h{LIMIT}};
    }

    if (exists $h{SINCE})
    {
        my $t = PHEDEX::Core::Util::str2time($h{SINCE});
        $sql .= qq {\n            and r.time_create >= $t};
    }

    if (exists $h{DEST_NODE})
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
                    and an.name = '$h{DEST_NODE}')};
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
            rn.point = :point and
            not n.name like 'X%' };

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
        where rn.request = :request and
            not n.name like 'X%' };

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

    my $q = &execute_sql($$self{DBH}, $sql);

    while ($data = $q ->fetchrow_hashref())
    {
        $$data{REQUESTED_BY} = &getClientData($self, $$data{CREATOR_ID});
        delete $$data{CREATOR_ID};

        $$data{DATA}{DBS}{NAME} = $$data{DBS};
        $$data{DATA}{DBS}{ID} = $$data{DBS_ID};
        delete $$data{DBS};
        delete $$data{DBS_ID};

        if ($h{TYPE} eq 'xfer')
        {
            # take care of priority
            $$data{PRIORITY} = PHEDEX::Core::Util::priority($$data{PRIORITY});
            $$data{DESTINATIONS} = &execute_sql($$self{DBH}, $node_sql, ':request' => $$data{ID}, ':point' => 'd')->fetchall_arrayref({});
            $$data{SOURCES} = &execute_sql($$self{DBH}, $node_sql, ':request' => $$data{ID}, ':point' => 's')->fetchall_arrayref({});

            foreach my $node (@{$$data{SOURCES}}, @{$$data{DESTINATIONS}})
            {
	        $$node{APPROVED_BY} = &getClientData($self, $$node{DECIDED_BY}) if $$node{DECIDED_BY};
                delete $$node{DECIDED_BY};
            }
        }
        else
        {
            $$data{NODES} = &execute_sql($$self{DBH}, $node_sql2, ':request' => $$data{ID})->fetchall_arrayref({});
            foreach my $node (@{$$data{NODES}})
            {
	        $$node{APPROVED_BY} = &getClientData($self, $$node{DECIDED_BY}) if $$node{DECIDED_BY};
                delete $$node{DECIDED_BY};
            }
        }

        $$data{DATA}{USERTEXT} = $$data{USER_TEXT};
        delete $$data{USER_TEXT};
    
        $$data{DATA}{DBS}{DATASET} = &execute_sql($$self{DBH}, $dataset_sql, ':request' => $$data{ID})->fetchall_arrayref({});
        $$data{DATA}{DBS}{BLOCK} = &execute_sql($$self{DBH}, $block_sql, ':request' => $$data{ID})->fetchall_arrayref({});

        my ($total_files, $total_bytes) = (0, 0);

        foreach my $item (@{$$data{DATA}{DBS}{BLOCK}},@{$$data{DATA}{DBS}{DATASET}})
        {
            $total_files += $item->{FILES} || 0;
            $total_bytes += $item->{BYTES} || 0;
        }
        $$data{BYTES} = $total_bytes;
        $$data{FILES} = $total_files;

        push @r, $data;
    }

    # restore LongReadLen & LongTruncOk

    $$self{DBH}->{LongReadLen} = $LongReadLen;
    $$self{DBH}->{LongTruncOk} = $LongTruncOk;

    return \@r;
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
        $h{USER_GROUP} = $h{GROUP};
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

    # while ($_ = $q->fetchrow_hashref()) {push @r, $_;}
    while ($_ = $q->fetchrow_hashref())
    {
        if ($node{$_ -> {'NODE'}})
        {
            push @{$node{$_->{'NODE'}}->{group}},{
                name => $_->{'USER_GROUP'},
                id => $_->{GID},
                node_files => $_->{'NODE_FILES'},
                node_bytes => $_->{'NODE_BYTES'},
                dest_files => $_->{'DEST_FILES'},
                dest_bytes => $_->{'DEST_BYTES'}
            };
        }
        else
        {
            $node{$_->{'NODE'}} = {
                name => $_->{'NODE'},
                se => $_->{'SE_NAME'},
                id => $_->{'ID'},
                group => [{
                    name => $_->{'USER_GROUP'},
                    id => $_->{GID},
                    node_files => $_->{'NODE_FILES'},
                    node_bytes => $_->{'NODE_BYTES'},
                    dest_files => $_->{'DEST_FILES'},
                    dest_bytes => $_->{'DEST_BYTES'}}]
            };
        }
    }

    while (my ($key, $value) = each(%node))
    {
        push @r, $value;
    }     

    return \@r;
}

# get transfer queue block information
sub getTransferQueueBlocks
{
    my ($core, %h) = @_;
    my $sql = qq {
        select
            from_node,
            from_id,
            to_node,
            inblock,
            block_name,
            priority,
            state,
            count(fileid) files,
            sum(filesize) bytes
        from (
            select
                fn.name from_node,
                fn.id from_id,
                tn.name to_node,
                tn.id to_id,
                xt.priority,
                case when xtd.task is not null then 'transferred'
                     when xtx.task is not null then 'transferring'
                     when xte.task is not null then 'exported'
                     else 'assigned'
                end state,
                f.inblock,
                f.id fileid,
                f.filesize,
                b.name block_name
            from
                t_xfer_task xt
                left join t_xfer_task_export xte on xte.task = xt.id
                left join t_xfer_task_inxfer xtx on xtx.task = xt.id
                left join t_xfer_task_done   xtd on xtd.task = xt.id
                join t_xfer_file f on f.id = xt.fileid
                join t_adm_node fn on fn.id = xt.from_node
                join t_adm_node tn on tn.id = xt.to_node
                join t_dps_block b on b.id = f.inblock
        ) };

    my @r;
    my %p;
    my $filters = '';
    build_multi_filters($core, \$filters, \%p, \%h, (
        FROM_NODE => 'from_node',
        TO_NODE => 'to_node',
        STATE => 'state',
        PRIORITY => 'priority'));

    $sql .= " where ($filters) " if $filters;

    $sql .= qq {
            group by from_node, to_node, inblock, priority, state,
                from_id, to_id, block_name };

    my $q = execute_sql($core, $sql, %p);
    my %link;

    # while ($_ = $q->fetchrow_hashref()) {push @r, $_;}
    while ($_ = $q->fetchrow_hashref())
    {
        # decode this priority
        $_->{PRIORITY} = PHEDEX::Core::Util::priority($_ -> {'PRIORITY'}, 1);
        my $key = $_->{'FROM_NODE'}."+".$_->{'TO_NODE'};
        my $qkey = $_->{'STATE'}."+".$_->{'PRIORITY'};
        if ($link{$key})
        {
            if ($link{$key}{tqueue}{$qkey})
            {
                push @{$link{$key}{tqueue}{$qkey}->{block}}, {
                    name => $_->{'BLOCK_NAME'},
                    id => $_->{'INBLOCK'},
                    files => $_->{'FILES'},
                    bytes => $_->{'BYTES'}
                };
            }
            else
            {
                $link{$key}{tqueue}{$qkey} = {
                    priority => $_->{'PRIORITY'},
                    state => $_->{'STATE'},
                    block => [{
                        name => $_->{'BLOCK_NAME'},
                        id => $_->{'INBLOCK'},
                        files => $_->{'FILES'},
                        bytes => $_->{'BYTES'}
                    }]
                };
            }
        }
        else
        {
            $link{$key} = {
                from_node => $_->{'FROM_NODE'},
                from_id => $_->{'FROM_ID'},
                to_node => $_->{'TO_NODE'},
                to_id => $_->{'TO_ID'},
                tqueue => {
                    $qkey => {
                        priority => $_->{'PRIORITY'},
                        state => $_->{'STATE'},
                        block => [{
                            name => $_->{'BLOCK_NAME'},
                            id => $_->{'INBLOCK'},
                            files => $_->{'FILES'},
                            bytes => $_->{'BYTES'}
                        }]}
                }
            };
        }
    }

    # now deal with the array of queue
    my ($key, $value, $qkey, $qvalue);
    while (($key, $value) = each (%link))
    {
        $link{$key}{transfer_queue} = [];
        while (($qkey, $qvalue) = each (%{$link{$key}{tqueue}}))
        {
            push @{$link{$key}{transfer_queue}}, $qvalue;
        }
        delete $link{$key}{tqueue};
    }

    while (($key, $value) = each(%link))
    {
        push @r, $value;
    }

    return \@r;
}

;


1;
