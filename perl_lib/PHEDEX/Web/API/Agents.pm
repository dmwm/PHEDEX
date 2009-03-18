package PHEDEX::Web::API::Agents;
#use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Agents - return information regarding the Agents

=head2 agents

Return agent information in the following structure:

  <node>
    <agent/>
    ...
  </node>
  ...

=head3 options

 required inputs: none
 optional inputs: (as filters) node, se, agent

  node             node name, could be multiple
  se               storage element name, could be multiple
  agent            agent name, could be multiple

=head3 output

  <node>
    <agent/>
    ...
  </node>
  ...

=head3 <node> elements:

  name             agent name
  node             node name
  host             host name
  agent            list of the agents on this node

=head3 <agent> elements:

  label            label
  state_dir        directory path ot the states
  version          cvs release
  cvs_version      cvs revision
  cvs_tag          cvs tag
  pid              process id
  time_update      time it was updated

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return agents(@_); }

sub agents
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node se agent / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getAgents($core, %h);
    return { node => $r };
}

1;
