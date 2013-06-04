package PHEDEX::Web::API::ComponentStatus;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::ComponentStatus -- show status of PhEDEx components

=head1 DESCRIPTION

Return status known to PhEDEx.

=head2 Options

 required inputs: none

=head2 Output

  <infraestructure/>
  ...

=head3 <infraestructure> elements

  node             node name
    agent            agent name
    uptime           agent uptime 

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

sub duration { return 60 * 60; }
sub invoke { return componentstatus(@_); }

sub componentstatus
{
    my ($core, %h) = @_;
    my $rows = PHEDEX::Web::SQL::getComponentStatus($core);

    my (%agents, %status);
    foreach (@{$rows})
    {   
       my ($node, $agent, $label, $contact) = @$_;
       $status{$node}{$agent}{$label} = $contact;
       $agents{$agent} = 1;
    }

    return { componentstatus => {node => 'T3_MX_Cinvestav', {agent => 'FileDownload', uptime => 100}}};
}

1;
