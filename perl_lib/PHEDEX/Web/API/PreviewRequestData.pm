package PHEDEX::Web::API::PreviewRequestData;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;
use PHEDEX::RequestAllocator::Core;
use PHEDEX::Core::Util;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::PreviewRequestData - get detailed information about a request before approving it

=head2 Options

 data		the data to be subscribed. May contain '*' wildcard, can be multiple
 type           'xfer' or 'delete'. Used to analyse possible warning or error conditions.
 node		destination node names, can be multiple
 static         'y' or 'n', for 'static' or 'growing' subscription.  Default is 'n' (growing)
 move           'y' or 'n', if the data is subscribed and is a move or not
 custodial      'y' or 'n', if the data is subscribed and is custodial or not
 time_start     starting time for dataset-level request. Default is undefined (all blocks in dataset)
 dbs            which DBS the data is expected to be in

 Only 'data' and 'type' are mandatory. The other arguments either narrow down the request, or assist
in checking for errors.

 This API will also silently accept all the arguments that the Subscriptions API accepts. That way,
you can call both with exactly the same data-structure.

=head3 Output

  <preview>
    <src_info>
      <node> ... </node>
    </src_info>
    ...
  </preview>
  ...

=head3 <preview> attributes

  id		Request ID
  level		BLOCK or DATASET, specifying what level this item corresponds to
  dataset	name of dataset, if level = DATASET. Undefined otherwise
  block		name of block, if level = BLOCK. Undefined otherwise
  item		name of dataset or block, whatever the value of 'level'
  dbs		name of the DBS this item is found in
  bytes		number of bytes in this item
  files		number of files in this item
  dps_isknown	y or n, if this item is known to PhEDEx
  dbs_isknown	y or n, if this item is known to DBS
  comment	additional information, if any, for this item
  warn		additional warning information, suggesting possible errors that may apply to this item
  problem	description of problem, if any, with this item

=head3 <src_info> attributes

  none

=head3 <node> attributes

  files		number of files at this node for this item
  bytes		number of bytes at this node for this item
  node		node-name for this replica of this item
  is_move	y, n, or null, if the data is subscribed and is a move or not
  custodial	y, n, or null, if the data is subscribed and is custodial or not
  is_subscribed y or n, if the data is subscribed or not
  time_start	if not null, only data after this time (epoch seconds) is subscribed
  user_group	if subscribed, gives the user-group the data belongs to
  subs_level	BLOCK or DATASET, specifies the subscription level

=cut

=head2 DESCRIPTION

This API takes the same input as the Subscribe API, and returns a data-structure with information about
the data that matches that input. This allows you to see if other subscriptions are being overridden,
how much data you are requesting for transfer, where the files and data already reside, and other
things that you may want to know before finally placing the subscription request.

Although this API does not need all the arguments it accepts, it is specifically designed to accept
identically the same input as the Subscribe API, so that a script or tool that calls it can then
pass the same structure to that API, thereby simplifying coding. The only mandatory arguments are
'data' and 'type'.

Other arguments are used in the analysis to spot potential problems, which are reported as
'comment's, 'warn'ings, or 'problem's, according to their severity. A comment is purely for
information, a warning suggests that the request may fail, or may not be what you want, and a
problem is something that will definitely cause the request to fail.  

=cut

sub duration { return 0; }
sub invoke { return previewrequestdata(@_); }
sub previewrequestdata {
  my ($core,%params_in) = @_;
  my ($type,$response,%p,%params);

# We allow all sorts of parameters, for compatibility with the Subscribe API. But we only
# validate and use the ones we explicitly want. So pick them out here
  foreach ( qw / data type node static move custodial time_start dbs / ) {
    $params{$_} = $params_in{$_} if exists $params_in{$_};
  }
  eval
  {
      %p = &validate_params(\%params,
              allow => [ qw( data type node static move custodial time_start dbs ) ],
              required => [ qw( data type ) ],
              spec =>
              {
                  data => { using => 'dataitem_*', multiple => 1 },
                  type => { using => 'request_type' },
                  node => { using => 'node', multiple => 1 },
                  static => { using => 'yesno' },
                  move => { using => 'yesno' },
                  custodial => { using => 'yesno' },
                  time_start => { using => 'time' },
                  dbs => { using => 'text' }
              }
      );
  };
  if ($@)
  {
      return PHEDEX::Web::Util::http_error(400,$@);
  }

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
 
  if ( !defined($params{move}) ) { $params{move} = 'n'; }
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
        if ($params{dbs} && $$res{DBS} ne $params{dbs})  {
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
        if ($$res{LEVEL} eq 'BLOCK' && $params{move} eq 'y') {
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
        if ($params{move} eq 'y') {
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

        if (exists($params{custodial}) && $params{custodial} eq 'y') {
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
          $res->{SRC_INFO}{$_->{NODE_NAME}}{IS_CUSTODIAL} = $_->{IS_CUSTODIAL} ? 'y' : 'n';
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
    my ($re,$like);
    foreach $userglob (@userdata) {
	$$resolved{$userglob} ||= [];

	$level = ($userglob =~ m/\#/ ? 'BLOCK' : 'DATASET');

	$re = $like = $userglob;
	$re =~ s:(\.)*\*+:.*:g;                 # simple glob to regex, only * is supported
	$like =~ s:(\.)*\*+:%:g;                # glob to sql like, only * is supported
	if ( $static && $level eq 'DATASET' ) { # turn dataset match into block match if static
	  $re .= '#[^/\#]+';
          $level = 'BLOCK';
          if ( $like !~ m/#/ ) {
            $like .= '%#%';
          }
        }
	$has{$level}++;
	$userglob_re{$userglob} = qr/^$re$/;                 # compile regexp

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
	}
    }

    my ($subs,%h);
    foreach $userglob (@userdata) {
	foreach my $item (grep $_->{DPS_ISKNOWN} eq 'y', @{$$resolved{$userglob}}) {
	    $item->{REPLICAS} = $all_replicas->{$item->{LEVEL}}->{$item->{ID}};
            push @{$h{$item->{LEVEL}}}, $item->{$item->{LEVEL}};
	}
    }
    $subs = PHEDEX::Web::SQL::getDataSubscriptions($dbh,%h);
    foreach $userglob (@userdata) {
	foreach my $item (grep $_->{DPS_ISKNOWN} eq 'y', @{$$resolved{$userglob}}) {
	    foreach ( @{$subs} ) {
	      push @{$item->{SUBSCRIPTIONS}},
		{
		  NODE_ID      => $_->{NODE_ID},
		  IS_MOVE      => $_->{MOVE},
		  NODE_NAME    => $_->{NODE},
		  SUBS_ITEM_ID => $_->{ITEM_ID},
		  IS_CUSTODIAL => $_->{CUSTODIAL},
		  TIME_START   => $_->{TIME_START},
		  USER_GROUP   => $_->{GROUP},
		  SUBS_LVL     => uc $_->{LEVEL},
		  $_->{LEVEL} . '_ID' => $_->{ITEM_ID}
		};
	    }
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
