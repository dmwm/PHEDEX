package PHEDEX::Web::API::ComponentsStatus;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::ComponentsStatus -- show status of PhEDEx components

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
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return componentsstatus(@_); }

sub componentsstatus
{
    my ($core, %h) = @_;
    my $rows = PHEDEX::Web::SQL::getComponentsStatus($core);

    my (%agents, %status);
    foreach (@{$rows})
    {   
       my ($node, $agent, $label, $contact) = @$_;
       $status{$node}{$agent}{$label} = $contact;
       $agents{$agent} = 1;
    }
    print Data::Dumper($status);
    return { componentsstatus => 1 };

    my @infrastructure = grep exists $agents{$_}, 
                         qw(FileRouter FileIssue FilePump);
    my @workflow       = grep exists $agents{$_}, 
                         qw(RequestAllocator BlockAllocator BlockMonitor BlockDelete BlockActivate BlockDeactivate);
    my @support        = grep exists $agents{$_}, 
                         qw(BlockDownloadVerifyInjector InfoFileSize InfoStatesClean InvariantMonitor PerfMonitor LoadTestInjector LoadTestCleanup);
    my @site           = grep exists $agents{$_}, 
                         qw(FileDownload FileExport FileStager FileRemove BlockDownloadVerify Watchdog AgentFactory);
    my @other;

    foreach my $agent (keys %agents) {
       push @other, $agent unless grep $agent eq $_, @infrastructure, @workflow, @support, @site;
    }

    return { componentsstatus => {
                                    Infraestructure => { 
                                                         'PhEDEx Central' => {
                                                                               FileRouter => 100,
                                                                               FileIssue => 100,
                                                                             },
                                                       },
                                    Site => { 
                                              'T3_MX_Cinvestav' => { 
                                                                     'FileDownload' => 100,
                                                                    }
                                            },
                                 }
           };
}

1;
