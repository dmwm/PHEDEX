package PHEDEX::Web::API::RequestActions;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::RequestActions - possible actions for reqests

=head1 DESCRIPTION

Returns a list of possible actions that can be done to a request according to the user's ability and the request's current state

=head2 Options

 optional inputs: <have not thought about>

  request          request id, could be multiple
  node             node name, could be multiple
  create_since     since this time
  decided_since    decided 
  

=head2 Output

  <request>
      <node>
          <action/>
          ...
      <node>
          <action/>
          ...
      ...
  ...

=head3 <request> attributes

  id               request id
  type             request type
  state            current approval state
  requeste_by      the human name of the person who made the request
  time_created     creation timestamp


=head3 <node> attributes

  id               node id
  name             node name
  se               node se name
  decision         decision at the node
  decided_by       the human name of the person who made the decision
  time_decided     timestamp when the decision was made

=head3 <action> attributes 

  name             action name
  from_state       transition from state
  to_state         transition to state
  role             role name
  domain           domain for this role
  ability          ability

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;
use PHEDEX::Core::SQL;
use Data::Dumper;

my $sql = qq {
select
    r.id as "request_id",
    rt.name as "type",
    r.time_create,
    r.state,
    i.name as "request_by",
    n.id as "node_id",
    n.name as "node_name",
    n.se_name,
    rd.decision,
    i2.name as "decided_by",
    rd.time_decided,
    rs1.name as "from_state",
    rs2.name as "to_state",
    ar.role,
    ar.domain,
    a.name as "ability",
    ra.name as "action"
from
    t_req2_request r
    join t_req_node rn on rn.request = r.id
    join t_adm_node n on n.id = rn.node
    join t_adm_client c on c.id = r.created_by
    join t_adm_identity i on i.id = c.identity
    left join t_req_decision rd on rd.node = rn.node and rd.request = r.id
    left join t_adm_client c2 on c2.id = rd.decided_by
    left join t_adm_identity i2 on i2.id = c2.identity
    join t_req_type rt on rt.id = r.type
    join t_req2_rule rr on rr.type = r.type
    join t_req2_transition t on t.id = rr.transition
    join t_req2_permission p on rr.id = p.rule
    join t_adm2_ability_map am on am.id = p.ability
    join t_adm2_ability a on a.id = am.ability
    join t_adm2_role ar on ar.id = am.role
    join t_req2_state rs1 on rs1.id = t.from_state
    join t_req2_state rs2 on rs2.id = t.to_state
    join t_req2_action ra on ra.desired_state = t.to_state
};

my $sql2 = qq {
select
    *
from
    t_adm_node
};

my $map = {
    _KEY => 'NAME+HOST+NODE+PID',
    node => 'NODE',
    name => 'NAME',
    host => 'HOST',
    agent => {
        _KEY => 'PID',
        label => 'LABEL',
        state_dir => 'STATE_DIR',
        version => 'VERSION',
        pid => 'PID',
        time_update => 'TIME_UPDATE'
    }
};

my $map = {
    _KEY => 'REQUEST_ID',
    id => 'REQUEST_ID',
    type => 'TYPE',
    state => 'STATE',
    requested_by => 'REQUESTED_BY',
    time_created => 'TIME_CREATE',
    node => {
        _KEY => 'NODE_ID',
        id => 'NODE_ID',
        name => 'NODE_NAME',
        se => 'SE_NAME',
        decision => 'DECISION',
        decided_by => 'DECIDED_BY',
        time_decided => 'TIME_DECIDED',
        action => {
            _KEY => 'ACTION',
            name => 'ACTION',
            from_state => 'FROM_STATE',
            to_state => 'TO_STATE',
            domain => 'DOMAIN',
            role => 'ROLE',
            ability => 'ABILITY'
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { return requestaction(@_); }

sub requestaction
{
    my ($core, %h) = @_;
    my %p;

my $hide = qq {
    eval {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [qw(node se agent version detail update_since)],
                spec => {
                    node => { using => 'node', multiple => 1 },
                    se   => { using => 'text' , multiple => 1 },
                    agent => { using => 'text' , multiple => 1 },
                    version => { using => 'text' },
                    detail => { using => 'yesno' },
                    update_since => { using => 'time' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }
};


    my $q = PHEDEX::Core::SQL::execute_sql($core, $sql);

    my @r;
    while ($_ = $q->fetchrow_hashref())
    {
        push @r, $_;
    }

    my $r1 = PHEDEX::Core::Util::flat2tree($map, \@r);
    return { request => $r1};
}

1;
