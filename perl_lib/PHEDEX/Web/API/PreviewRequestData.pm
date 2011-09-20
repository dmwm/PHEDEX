package PHEDEX::Web::API::PreviewRequestData;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;
use PHEDEX::RequestAllocator::Core;
use PHEDEX::Core::Util;
use warnings;
use strict;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::PreviewRequestData - get detailed information about a request before approving it

=head2 DESCRIPTION

=cut

sub duration { return 0; }
sub invoke { return previewrequestdata(@_); }
sub previewrequestdata {
  my ($core,%params) = @_;
  my ($type,$response);

  checkRequired(\%params,qw(data type));  
  if ( $@ ) { die PHEDEX::Web::Util::http_error(400,$@); }

  if ( !ref($params{data}) ) {
    $params{data} = [ $params{data} ];
  }
  my @nodes = PHEDEX::Core::Util::arrayref_expand($params{node});
  my ($resolved, $userdupes, $dbsdupes) = &resolve_data($core,
             $params{dbs},
             $params{type},
             (defined $params{static} && $params{static} eq 'y') ? 1 : 0,
	     $params{time_start},
             @{$params{data}});
  my @table;
  my $problems = 0;
  my %subscribed_sources;
  foreach my $userglob (sort @{$params{data}}) {
    if (! @{$$resolved{$userglob}} ) {
      push @table,({LEVEL => 'User Search',
      ITEM  => $userglob,
      DPS_ISKNOWN => 'n',
      DBS_ISKNOWN => 'n',
      COMMENT => 'Not known to PhEDEx',
      WARN => 1});
      $problems = 1;
    } else {
      foreach my $res (@{$$resolved{$userglob}}) {
        my @comments;
        my $warn = 0;
        my $row_problem = 0;

        if ($$res{FILES} == 0) {
          my $item_level = ucfirst lc $$res{LEVEL};
          push @comments, "$item_level is empty";
          $warn = 1;
        }
        if ($$res{DBS} ne $params{dbs})  {
          push @comments, 'Wrong DBS ("' . $res->{DBS} . '")';
          $warn = 1; $row_problem = 1;
        }
        if ($$userdupes{$$res{LEVEL}}{$$res{ID}}) {
          push @comments, 'User duplicated requests';
          $warn = 1;
        }
        if ($$dbsdupes{$$res{LEVEL}}{$$res{ID}})  {
          push @comments, 'Known to PhEDEx in multiple DBSes';
          $warn = 1;
        }
        if ($$res{LEVEL} eq 'BLOCK' && $params{is_move} eq 'y') {
          push @comments, "Move request includes block-level data.  Only moves of datasets are supported";
          $warn = 1; $row_problem = 1;
        }

        my $src_info = {};
        foreach my $replica (@{$$res{REPLICAS}}) {
          $$src_info{ $$replica{NODE_NAME} }{ NODE } = $$replica{NODE_NAME} ;
          $$src_info{ $$replica{NODE_NAME} }{ FILES } = $$replica{FILES};
        }
        foreach my $subsc (@{$$res{SUBSCRIPTIONS}}) {
          $$src_info{ $$subsc{NODE_NAME } }{ NODE } = $$subsc{NODE_NAME};
          $$src_info{ $$subsc{NODE_NAME } }{ IS_SUBSCRIBED } = 'y';
          $$src_info{ $$subsc{NODE_NAME } }{ IS_CUSTODIAL } = $$subsc{IS_CUSTODIAL};
          $$src_info{ $$subsc{NODE_NAME } }{ IS_MOVE } = $$subsc{IS_MOVE};
        }

        # Check subscriptions if a move or custodial request was made
        if ($params{is_move} eq 'y') {
          my @subsc_t1s;
          foreach my $s (grep $$_{IS_SUBSCRIBED}, values %$src_info) {
            if ($$s{NODE} =~ /^T1/ && !grep $_ eq $$s{NODE}, @nodes) {
              # A T1 is already subscribed that is not in this request
              push @subsc_t1s, $s;
            } elsif ($$s{NODE} =~ /^T1/) {
              # T1 overlapping request, do nothing
            } else {
              # add to list of subscribed sources
              $subscribed_sources{ $$s{NODE} } = 1;
            }
          }
          if (@subsc_t1s) {
            push @comments, 'Cannot move data subscribed to another T1';
            $row_problem = 1;
          }
        }

        if ($params{is_custodial} eq 'y') {
          my @custodial = grep ($$_{IS_CUSTODIAL} eq 'y', values %$src_info);
          if (@custodial) {
            push @comments, "Data already custodial for ".
            join(', ', sort map { $$_{NODE} } @custodial);
            $warn = 1;
          }
        }

        # prepare a list of source nodes with helpful information
        $$res{ITEM} = $$res{$$res{LEVEL}}; # Name of dataset or block, depending on which it is for
        $$res{COMMENT} = join('<br/>', @comments);
        $$res{WARN} = $warn;
        $$res{PROBLEM} = $row_problem;
        foreach ( @{$$res{SUBSCRIPTIONS}} ) {
          $res->{SRC_INFO}{$_->{NODE_NAME}}{NODE}          = $_->{NODE_NAME};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{SUBS_LEVEL}    = $_->{SUBS_LVL};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{IS_CUSTODIAL}  = $_->{IS_CUSTODIAL};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{IS_MOVE}       = $_->{IS_MOVE};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{TIME_START}    = $_->{TIME_START};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{USER_GROUP}    = $_->{USER_GROUP};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{IS_SUBSCRIBED} = 'y';
        }
        foreach ( @{$$res{REPLICAS}} ) {
          $res->{SRC_INFO}{$_->{NODE_NAME}}{NODE}  = $_->{NODE_NAME};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{BYTES} = $_->{BYTES};
          $res->{SRC_INFO}{$_->{NODE_NAME}}{FILES} = $_->{FILES};
        }
        delete $res->{REPLICAS};
        delete $res->{SUBSCRIPTIONS};
        foreach ( values %{$res->{SRC_INFO}} ) {
          $_->{IS_SUBSCRIBED} ||= 'n';
          $_->{SUBS_LEVEL}    ||= '-';
          $_->{TIME_START}    ||= undef;
          $_->{IS_CUSTODIAL}  ||= '-';
          $_->{IS_MOVE}       ||= '-';
          $_->{FILES}         ||= '-';
          $_->{BYTES}         ||= '-';
        }

        if ($$res{DPS_ISKNOWN} eq 'n' || $$res{DBS_ISKNOWN} eq 'n') { $problems = 1; }
        push @table,($res);
        $problems ||= $row_problem;
      }
    }
  }

  return { preview => \@table };
}

# Resolve user datasets;  Search DPS and DBS for glob patterns
# Fill data object with results:
# $$resolved{$userglob} = [ { params }, ... ]
# Where { params } contains:
#   DBS = dbs the data was found in PhEDEx, not necessarily the one the user specified
#   LEVEL = 'BLOCK' or  'DATASET'
#   DATASET = Dataset name
#   BLOCK = Block name.  undef if LEVEL = DATASET
#   ID = The dps unique id for item
#   FILES = Number of files
#   BYTES = Data size
#   DPS_ISKNOWN = 'y' or 'n'
#   DBS_ISKNOWN = 'y' or 'n'
sub resolve_data
{
    my ($core,$dbh,$params,$ds_ids,$b_ids, $userdbs, $type, $static, $time_create, @userdata);
    ($core,$userdbs, $type, $static, $time_create, @userdata) = @_;
    my ($level,%binds,$ds_lookup,$b_lookup,$sql,$userglob,$globlevel,$lastid,$id,$name);

    my $resolved = {};
    my $userdupes = {};
    my $dbsdupes = {};
    my $all = {};
    $dbh = $core->{DBH};

    foreach $level (qw(DATASET BLOCK)) {
	$$all{$level} = [];
    }

    # We assume the user is giving us wildcard searches
    # So first we turn the wildcard searches into compiled regexps and
    # SQL like patterns
    my %has = ( DATASET => 0, BLOCK => 0);
    my %userglob_re;
    my %userglob_like = ( DATASET => [], BLOCK => [] );
    foreach $userglob (@userdata) {
	$$resolved{$userglob} ||= [];

	$level = ($userglob =~ m/\#/ ? 'BLOCK' : 'DATASET');
	$has{$level}++;

	my $re = $userglob;
	$re =~ s:\*+:[^/\#]+:g;                              # simple glob to regex, only * is supported
	$re .= '#[^/\#]+' if $static && $level eq 'DATASET'; # turn dataset match into block match if static
	$userglob_re{$userglob} = qr/^$re$/;                 # compile regexp

	my $like = $userglob;
	$like =~ s:\*+:%:g;                                  # glob to sql like, only * is supported
	push @{$userglob_like{$level}}, $like;
    }

    # Now we look for matching data in TMDB using the SQL like patterns
    # We order by ID so we can check for redundant DBS items later
    my $all_items = {};

    if ($has{DATASET}) {
	$ds_lookup = $userglob_like{DATASET};

	$sql =  qq{
	   select dbs.id dbs_id, dbs.name dbs, ds.id dataset_id, ds.name dataset,
                  nvl(sum(b.files),0) files, nvl(sum(b.bytes),0) bytes
	     from t_dps_dataset ds
   	     join t_dps_dbs dbs on dbs.id = ds.dbs
             left join t_dps_block b on b.dataset = ds.id
	 }
	. 'where ('.&PHEDEX::Core::SQL::filter_or_like($dbh, undef, \%binds, 'ds.name', @$ds_lookup).')';
	$sql .= qq{ and b.time_create >= :time_create } if $time_create;
        $sql .= qq{ group by dbs.id, dbs.name, ds.id, ds.name order by ds.id };
	if ( $time_create ) { $binds{':time_create'} = $time_create; }
	$all_items->{DATASET} = &PHEDEX::Core::DB::dbexec($dbh, $sql, %binds)->fetchall_arrayref({});
    }

    if ($has{BLOCK}) {
	$b_lookup = $userglob_like{BLOCK};
	$ds_lookup = $userglob_like{DATASET};

	$sql = qq{
	   select dbs.id dbs_id, dbs.name dbs, ds.id dataset_id, ds.name dataset,
	          b.id block_id, b.name block, b.files, b.bytes
	     from t_dps_block b
	     join t_dps_dataset ds on b.dataset = ds.id
	     join t_dps_dbs dbs on ds.dbs = dbs.id
            where
	};

	%binds = ();
	my @filters;
	if ($has{BLOCK}) {
	    push @filters,
	    '('.&PHEDEX::Core::SQL::filter_or_like($dbh, undef, \%binds, 'b.name', @$b_lookup).')';
	}

	$sql .= join ' or ', @filters;
	$sql .= ' order by b.id';

	$all_items->{BLOCK} = &PHEDEX::Core::DB::dbexec($dbh, $sql, %binds)->fetchall_arrayref({});
    }

    # Now we go through all the data we just found and use the regexps
    # patterns we made to find what data matched what user request.
    # We need to do this because we want to be able to tell the user
    # which of their strings did not match anything
    foreach $level (keys %$all_items) {
	my $resultset = $$all_items{$level};
	$lastid = -1;
	foreach my $row (@$resultset) {
	    $id = $$row{$level.'_ID'};
	    $name = $$row{$level};

	    # DBS redundancy checking
	    if ($id == $lastid) {
		$$dbsdupes{$level}{$id} = 1;
	    }
	    $lastid = $id;

	    # Search the TMDB for the user's glob
	    foreach $userglob (@userdata) {
		$globlevel = ($userglob =~ m/\#/ ? 'BLOCK' : 'DATASET');
		next if (!$static && $level ne $globlevel);
		next unless $name =~ $userglob_re{$userglob};

		push @{$$all{$level}}, $id;

		push @{$$resolved{$userglob}},  { DBS => $$row{DBS},
						  LEVEL => $level,
						  DATASET => $$row{DATASET},
						  BLOCK   => $$row{BLOCK},
						  FILES   => $$row{FILES},
						  BYTES   => $$row{BYTES},
						  REPLICAS => [],
						  DPS_ISKNOWN => 'y',
						  DBS_ISKNOWN => 'y', # XXX This is assuming DPS and DBS are in sync
						  ID => $id };
	    }
	}
    }

    # Look for data which the user has requested in duplicate
    $lastid = -1;
    foreach $level (qw(DATASET BLOCK)) {
	foreach $id (sort @{$$all{$level}}) {
	    if ($id == $lastid) {
		$$userdupes{$level}{$id} = 1;
	    }
	    $lastid = $id;
	}
    }

    # Attach replicas and subscriptions to resolved data.  We use the IDs from the data
    # we successfully looked up in TMDB to do this efficiently
    my $all_replicas = {};
    my $all_subscriptions = {};
    foreach $level (qw(DATASET BLOCK)) {
	my @ids = @{$$all{$level}};
	while ( my @batch = splice @ids, 0, 1000 ) { # query groups of 1000 items
	    my $replicas = &fetch_replicas($dbh, $level, @batch);
	    foreach my $rep (@$replicas) {
		$all_replicas->{$level}->{ $rep->{ $level.'_ID' } } ||= [];
		push @{ $all_replicas->{$level}->{ $rep->{ $level.'_ID' } } }, $rep;
	    }
	    my $subscriptions = &fetch_subscriptions($dbh, $level, @batch);
	    foreach my $subsc (@$subscriptions) {
		$all_subscriptions->{$level}->{ $subsc->{ $level.'_ID' } } ||= [];
		push @{ $all_subscriptions->{$level}->{ $subsc->{ $level.'_ID' } } }, $subsc;
	    }
	}
    }

    foreach $userglob (@userdata) {
	foreach my $item (grep $_->{DPS_ISKNOWN} eq 'y', @{$$resolved{$userglob}}) {
	    $item->{REPLICAS} = $all_replicas->{$item->{LEVEL}}->{$item->{ID}};
	    $item->{SUBSCRIPTIONS} = $all_subscriptions->{$item->{LEVEL}}->{$item->{ID}};
	}
    }
    
    # Return our results
    if (wantarray) {
	return ($resolved, $userdupes, $dbsdupes);
    } else {
	return $resolved;
    }
}

# returns all replicas matching the given datasets or blocks
sub fetch_replicas
{
    my ($dbh, $level, @items) = @_;
    return undef unless ($dbh && $level && @items);

    my $block_select = '';
    my $block_group_by = '';
    my %binds;
    my $where;
    if ($level eq 'DATASET') {
	$where = '('.&PHEDEX::Core::SQL::filter_or_eq($dbh, undef, \%binds, 'ds.id', @items).')';
    } elsif ($level eq 'BLOCK') {
	$block_select = 'b.id block_id, ';
	$block_group_by = ', b.id';
	$where = '('.&PHEDEX::Core::SQL::filter_or_eq($dbh, undef, \%binds, 'b.id', @items).')';
    }

    my $q = &PHEDEX::Core::DB::dbexec($dbh, qq{
	select n.id node_id, n.name node_name, ds.id dataset_id,
               $block_select
               nvl(sum(br.node_files),0) files, nvl(sum(br.node_bytes),0) bytes,
	       sign(sum(decode(br.is_custodial, 'y', 1, 0))) is_custodial
         from t_dps_dataset ds
         join t_dps_block b on b.dataset = ds.id
         join t_dps_block_replica br on br.block = b.id
         join t_adm_node n on n.id = br.node
        where (br.node_files != 0)
          and $where
	  group by n.id, n.name, ds.id $block_group_by }, %binds);

    return $q->fetchall_arrayref({});
}

# returns all subscriptions matching the given datasets or blocks and
# their completion status
sub fetch_subscriptions
{
  my ($dbh, $level, @items) = @_;
  return undef unless ($dbh && $level && @items);

  my ($sql,%binds,$where);
  if ($level eq 'DATASET') {
    $where = '('.&PHEDEX::Core::SQL::filter_or_eq($dbh, undef, \%binds, 'd.id', @items).')';
    $sql = qq { select 'DATASET' subs_lvl,
		  d.id dataset_id,
		  d.id subs_item_id,
		  NULL block_id,
		  n.id node_id, n.name node_name,
		  rx.is_custodial is_custodial,
		  rx.is_move is_move,
		  rx.time_start time_start,
                  gr.name user_group
		from t_dps_dataset d
		join t_dps_subs_dataset sd on sd.dataset = d.id
		join t_dps_subs_param sp on sp.id = sd.param
		join t_adm_group gr on sp.user_group = gr.id
		join t_adm_node n on n.id = sd.destination
		join t_req_xfer rx on rx.request = sp.request
		where
	      };
  } elsif ($level eq 'BLOCK') {
    $where = '('.&PHEDEX::Core::SQL::filter_or_eq($dbh, undef, \%binds, 'b.id', @items).')';
    $sql = qq { select 'BLOCK' subs_lvl,
		  b.dataset dataset_id,
		  b.id subs_item_id,
		  b.id block_id,
		  n.id node_id, n.name node_name,
		  rx.is_custodial is_custodial,
		  rx.is_move is_move,
		  rx.time_start time_start,
                  gr.name user_group
		from t_dps_block b
		join t_dps_subs_block sb on sb.block = b.id
		join t_dps_subs_param sp on sp.id = sb.param
		join t_adm_group gr on sp.user_group = gr.id
		join t_adm_node n on n.id = sb.destination
		join t_req_xfer rx on rx.request = sb.param
		where
	      };
  }
  $sql .= $where;

  my $q = &PHEDEX::Core::DB::dbexec($dbh, $sql, %binds);
  return $q->fetchall_arrayref({});
}

1;
