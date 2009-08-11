package PHEDEX::Web::API::AgentHistory;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::AgentHistory -- show history of agents

=head1 DESCRIPTION

Show history of agents

=head2 Options

 required inputs: none
 optional inputs: (as filters) user, host

  user              user name who owns agent processes
  host              hostname where agent runs

=head2 Output

  <host>
    <user>
      <history/>
      ...
    </user>
    ...
  </block>
  ...

=head3 <host> elements

  name              host name

=head3 <user> elements

  name              user name

=head3 <history> elements

  reason            reason for update
  pid               process id
  working_directory working directory
  state_driectory   state directory
  time_update       update time

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

sub duration { return 60 * 60; }
sub invoke { return agenthistory(@_); }

my $map = {
    _KEY => 'HOST_NAME',
    name => 'HOST_NAME',
    user => {
        _KEY => 'USER_NAME',
        name => 'USER_NAME',
        history => {
            _KEY => 'PID',
            pid => 'PID',
            working_directory => 'WORKING_DIRECTORY',
            state_directory => 'STATE_DIRECTORY',
            reason => 'REASON'
        }
    }
};
        
sub agenthistory
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / host user update_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getAgentHistory($core, %h);
    return { host => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

1;
