package PHEDEX::Web::API::AgentLogs;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::AgentLogs -- show messages from the agents 

=head1 DESCRIPTION

Show messages from the agents 

=head2 Options

 required inputs: at least one of the optional inputs
 optional inputs: (as filters) user, host, pid, agent, update_since

  node              name of the node
  user              user name who owns agent processes
  host              hostname where agent runs
  agent             name of the agent
  pid               process id of agent
  update_since      ower bound of time to show log messages. Default last 24 h.

=head2 Output

  <node>
    <agent>
      <log>
        <message> ... </message>
      </log>
      ...
    </agent>
    ...
  </node>
  ...

=head3 <node> attributes

 name        PhEDEx node name
 se          storage element
 id          node id

=head3 <agent> attributes

  name              name of the agent
  user              user name who owns the agent process
  host              hostname where agent runs
  pid               process id of agent

=head3 <log> attributes

  time              time of log entry
  work_dir          agent work directory
  state_dir         agent state directory
  reason            reason for update

=head3 <message> element

  Contains the log message.

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

sub duration { return 60 * 60; }
sub invoke { return agentlogs(@_); }

my $map = {
    _KEY => 'NODE',
    name => 'NODE',
    id => 'NODE_ID',
    se => 'SE',
    agent => {
        _KEY => 'HOST+USER+PID',
        host => 'HOST',
        user => 'USER',
        pid => 'PID',
        name => 'AGENT',
        log => {
            _KEY => 'TIME_UPDATE',
            working_dir => 'WORKING_DIRECTORY',
            state_dir => 'STATE_DIRECTORY',
            reason => 'REASON',
            message => 'MESSAGE',
            time => 'TIME_UPDATE'
        }
    }
};
        
sub agentlogs
{
    my ($core, %h) = @_;

    # need at least one of the input
    if (! keys %h)
    {
        die "need at least one of the input arguments: node host user pid agent update_since\n";
    }

    # convert parameter keys to upper case
    foreach ( qw / node host user pid agent update_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getAgentLogs($core, %h);
    return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

# spooling

my $sth;
my $limit = 1000;
my @keys = ('NODE');

sub spool
{
    my ($core, %h) = @_;

    # need at least one of the input
    if (! keys %h)
    {
        die "need at least one of the input arguments: node host user pid agent update_since\n";
    }

    # convert parameter keys to upper case
    foreach ( qw / node host user pid agent update_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }
    $h{'__spool__'} = 1;

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getAgentLogs($core, %h), $limit, @keys) if !$sth;
    my $r = $sth->spool();
    if ($r)
    {
        foreach (@{$r})
        {
            $_->{MESSAGE} = {'$t' => delete $_->{MESSAGE}};
        }
        return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        return $r;
    }
}



1;
