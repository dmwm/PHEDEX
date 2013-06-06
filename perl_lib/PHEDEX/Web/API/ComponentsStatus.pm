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

  <infraestructure>
  ...

=head3 <infraestructure> elements

  node                node name
    agent             agent name
      label = uptime  label uptime
  ...

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

sub duration { return 1 * 60; }
sub invoke { return componentsstatus(@_); }

sub componentsstatus
{
    my ($core, %h) = @_;
    my $rows = PHEDEX::Web::SQL::getComponentsStatus($core);
    my (%agents, %status,%r);
    foreach my $row (@$rows) {   
       my $node   = $$row{'NODE_NAME'};
       my $agent  = $$row{'AGENT_NAME'};
       my $label  = $$row{'LABEL'};
       my $uptime = $$row{'TIME_UPDATE'};
       $status{$node}{$agent}{$label} = $uptime;
       $agents{$agent} = 1;
    }

    my @infrastructure = grep exists $agents{$_},qw(FileRouter FileIssue FilePump);
    my @workflow       = grep exists $agents{$_},qw(RequestAllocator BlockAllocator BlockMonitor BlockDelete BlockActivate BlockDeactivate);
    my @support        = grep exists $agents{$_},qw(BlockDownloadVerifyInjector InfoFileSize InfoStatesClean InvariantMonitor PerfMonitor LoadTestInjector LoadTestCleanup);
    my @site           = grep exists $agents{$_},qw(FileDownload FileExport FileStager FileRemove BlockDownloadVerify Watchdog AgentFactory);
    my @other;
    foreach my $agent (keys %agents) {
       push @other, $agent unless grep $agent eq $_, @infrastructure, @workflow, @support, @site;
    }

    foreach my $item ( [ "Infrastructure", @infrastructure ], [ "Workflow", @workflow ], ["Support", @support],
		       [ "Site", @site ], ["Other", @other] ) {
       my ($type, @agents) = @{$item};
       next unless @agents;

       my @nodes;
       if ($type =~ /(Site|Other)/) { @nodes = sort keys %status; } 
       else { push @nodes, 'PhEDEx Central'; }
       foreach my $node (@nodes) { 
	  next if $type =~ /(Site|Other)/ && ! grep (defined $status{$node}{$_}, @agents);

	  foreach my $agent (@agents) {
	     my $check_node;
	     if ($node eq 'PhEDEx Central') {
	        my @running_for;
		foreach my $n (sort keys %status) {
		   push @running_for, $n if exists $status{$n}{$agent};
		}
		$check_node = shift @running_for;
	     } else { $check_node = $node; }

	     foreach my $label ( keys %{$status{$check_node}{$agent}} ) { 
                $r{$type}{$node}{$agent}{$label} = $status{$check_node}{$agent}{$label}; 
             }
          }
        }
    }
    return { componentsstatus => \%r };
}

1;
