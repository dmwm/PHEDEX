package PHEDEX::Web::API::Agents;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Agents - currently running agents

=head1 DESCRIPTION

Serves information about running (or at least recently running) PhEDEx
agents.

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, se, agent

  node             node name, could be multiple
  se               storage element name, could be multiple
  agent            agent name, could be multiple
  version          PhEDEx version
  update_since     updated since this time
  detail           show "code" information at file level *

=head2 Output

  * without option "detail"

  <node>
    <agent/>
  </node>
  ...

  * with option "detail"

  <node>
    <agent>
      <code/>
      ...
    </agent>
  </node>
  ...

=head3 <node> elements

  name             agent name
  node             node name
  host             host name

=head3 <agent> elements

  label            label
  state_dir        directory path ot the states
  version          rpm release or 'CVS'
  pid              process id
  time_update      time it was updated

=head3 <code> elements

  filename         file name
  filesize         file size (bytes)
  checksum         checksum
  rivision         CVS revision
  tag              CVS tag

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;

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

my $code_map = {
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
        time_update => 'TIME_UPDATE',
        code => {
            _KEY => 'FILENAME',
            filename => 'FILENAME',
            filesize => 'FILESIZE',
            checksum => 'CHECKSUM',
            revision => 'REVISION',
            tag => 'TAG'
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { return agents(@_); }

sub agents
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node se agent version detail update_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $map2 = $map;
    if (exists $h{DETAIL})
    {
        $map2 = $code_map;
    }

    my $r = PHEDEX::Core::Util::flat2tree($map2, PHEDEX::Web::SQL::getAgents($core, %h));

    return { node => $r };
}

1;
