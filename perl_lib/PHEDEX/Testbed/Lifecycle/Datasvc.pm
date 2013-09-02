package PHEDEX::Testbed::Lifecycle::Datasvc;
use strict;
use warnings;
use base 'PHEDEX::Testbed::Lifecycle::UA', 'PHEDEX::Core::Logging';
use POE;
use Clone qw(clone);
use Data::Dumper;
use PHEDEX::CLI::UserAgent;
use POSIX qw(strftime);

our %params = (
#	  cert_file => undef,
#	  key_file  => undef,
	  url       => 'https://cmsweb.cern.ch/phedex/datasvc',
	  instance  => 'prod',
	  format    => 'perl',
	  timeout   => 60,
#	  proxy     => undef,
#	  ca_file   => undef,
#	  ca_dir    => undef,
#	  nocert    => undef,
#	  Verbose   => undef,
#	  Debug     => undef,
	);

sub new {
  my $proto = shift;
  my $parent = shift;
  my $workflow = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new( $parent );

  my $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;

  my $p = $workflow->{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};
  $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );
  
  bless $self, $class;

  return $self;
}

sub getFromDatasvc {
  my ($self,$kernel,$session,$payload,$args) = @_;
  my ($target,$workflow,$api,$callback,$params,$method);
  $self->{PARENT_SESSION} = $session unless $self->{PARENT_SESSION};
  $method = $args->{method} || 'get';
  $params = $args->{params} || {};
  $callback = $args->{callback};
  $workflow = $payload->{workflow};

  # Setting the user agent instance to default value
  $self->{UA}->INSTANCE($self->{params}->{INSTANCE});
  
  # If an override instance has been specified, use that one
  if (my $instanceOverride = $args->{instance}) {
      $self->Logmsg("Overriding instance specified: $instanceOverride");      
      $self->{UA}->INSTANCE($instanceOverride);
  }
  
  $self->{UA}->CALL($args->{api});
  if ( $callback && ! $self->{_callbacks}{$callback}++ ) {
    $kernel->state($callback,$self);
  }
  
  $target = $self->{UA}->target;
  
  $self->Logmsg("Calling: $target\n");
  $kernel->post($self->{Alias},'start_task',{
				  payload	=> $payload,
				  method	=> $method,
				  target	=> $target,
				  params	=> $params,
				  callback	=> $callback,
				});
}

sub makeXML {
  my ($self,$data) = @_;
  my (@xml,$dbs,$i,$j,$k,$dataset,$block,$file,%h);

  $dbs = $dbs || $data->[0]{dataset}{dbs_name} || $data->[0]{dbs_name} || $dbs;
  @xml = (
            "<data version=\"2.0\">",
            "  <dbs name=\"$dbs\" dls=\"dbs\">"
          );
  foreach $i ( @{$data} ) {
    $dataset = $i->{dataset};
    $self->Alert("Duplicate dataset name $dataset->{name}") if $h{$dataset->{name}}++;
    push @xml, "    <dataset name=\"$dataset->{name}\" is-open=\"$dataset->{'is-open'}\">";
    foreach $j ( @{$dataset->{blocks}} ) {
      $block = $j->{block};
      $self->Alert("Duplicate block name $block->{name}") if $h{$block->{name}}++;
      push @xml, "      <block name=\"$block->{name}\" is-open=\"$block->{'is-open'}\">";
      foreach $k ( @{$block->{files}} ) {
        $file = $k->{file};
        $self->Alert("Duplicate file name $file->{name}") if $h{$file->{name}}++;
        push @xml, "      <file name=\"$file->{name}\" bytes=\"$file->{bytes}\" checksum=\"$file->{checksum}\" />";
      }
      push @xml, "      </block>";
    }
    push @xml, "    </dataset>";
  } 
  push @xml, "  </dbs>";
  push @xml, "</data>";

  return join("\n",@xml);
}

sub Agents {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'agents',
			 callback => 'gotAgents',
			 params	  => { node => $payload->{workflow}{Node} }
			}
			);
}

sub gotAgents {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($agents,$agent,$re,$tmp);

  $self->Logmsg("got: Agents($target,",Data::Dumper->Dump([$params]),")\n");
  $agents = $obj->{PHEDEX}{NODE};
  foreach $agent (@{$agents}) {
    next if ( $agent->{AGENT}[0]{LABEL} =~ m%^mgmt-%  && $agent->{NODE} ne 'T0_CH_CERN_Export' );
    foreach ( @{$agent->{AGENT}} ) {
      $tmp = clone $payload;
      $tmp->{workflow}{Agent} = $_;
      $self->Logmsg('Agent: ',$agent->{NAME},' for ',$agent->{NODE});
      foreach ( qw/ HOST NAME NODE / ) { $tmp->{workflow}{Agent}{$_} = $agent->{$_}; }
      $kernel->yield('nextEvent',$tmp);
    }
  }
}

sub Auth {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'auth',
			 callback => 'gotAuth',
			 method	  => 'post',
			}
			);
}

sub gotAuth {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($auth,$node,$re,$tmp);

  $self->Logmsg("got: Auth($target,",Data::Dumper->Dump([$params]),")\n");
  $auth = $obj->{PHEDEX}{AUTH};
  $payload->{workflow}{auth} = $auth;
  $self->Logmsg("Auth=,",Data::Dumper->Dump([$auth]),")\n");
  $kernel->yield('nextEvent',$payload);
}

sub Nodes {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'nodes',
			 callback => 'gotNodes'
			}
			);
}

sub gotNodes {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($nodes,$re,$tmp);

  $self->Logmsg("got: Nodes($target,{})\n");
  $nodes = $obj->{PHEDEX}{NODE};
  $re = $payload->{workflow}{NodeFilter};
  $self->Logmsg('Nodes: ',join(', ',sort map { $_->{NAME} } @{$nodes}));
  foreach (@{$nodes}) {
    next if ( $re && !($_->{NAME} =~ m%$re%) );
    $tmp = clone $payload;
    $tmp->{workflow}{Node} = $_->{NAME};
    $kernel->yield('nextEvent',$tmp);
  }
}

sub Inject {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};

  $self->Dbgmsg("Injecting: ",Data::Dumper->Dump([$workflow]));

  $workflow->{XML} = $self->makeXML($workflow->{data});
  $params = {
	node	=> $workflow->{InjectionSite},
	strict	=> $workflow->{StrictInjection} || 0,
	data	=> $workflow->{XML},
  };
  
  $self->Logmsg("Attempting to inject at site $params->{node}");
  $self->getFromDatasvc($kernel,
                        $session,
               	        $payload,
			  {
			   api	  => 'inject',
			   method   => 'post',
			   callback => 'doneInject',
			   params   => $params,
			  }
		         );
}

sub doneInject {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  delete $payload->{workflow}{XML};
  my $p = $obj->{PHEDEX}{INJECTED}{STATS};
  if ( $p ) {
    $self->Logmsg("Injection: New data: $p->{NEW_DATASETS} datasets, $p->{NEW_BLOCKS} blocks, $p->{NEW_FILES} files. Closed: $p->{CLOSED_DATASETS} datasets, $p->{CLOSED_BLOCKS} blocks");
  } else {
    if ( $self->{Debug} ) {
      $self->Alert("Injected: cannot understand output: ",Dumper($obj));
    } else {
      $self->Alert("Injected: cannot understand output.",);
    }
    $payload->{report} = {
      status => 'error',
      reason => 'not recorded',
    };
  }
  $kernel->yield('nextEvent',$payload);
}

sub T1Subscribe {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->Subscribe('T1',$kernel,$session,$payload);
}

sub T2Subscribe {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->Subscribe('T2',$kernel,$session,$payload);
}

sub Subscribe {
  my ($self, $type, $kernel, $session, $payload) = @_;
  my ($params,$workflow,%map,$subscribe);
  $workflow = $payload->{workflow};

  $subscribe = $type . 'Subscribe';
  if ( ! defined $workflow->{$subscribe} ) {
    $self->Alert("No \"$subscribe\" defined for \"$workflow->{Name}\"");
    $kernel->yield('nextEvent',$payload);
    return;
  }

  %map = (
        node	   => 'Nodes',
        data	   => 'data',
        group	   => 'Group',
        priority   => 'Priority',
        move	   => 'IsMove',
        custodial  => 'IsCustodial',
        static     => 'IsStatic',
        time_start => 'TimeStart',
        level      => 'Level',
  );
  $workflow->{$subscribe}{TimeStart}   ||=  0;
  $workflow->{$subscribe}{IsStatic}    ||= 'n';
  $workflow->{$subscribe}{IsMove}      ||= 'n';
  $workflow->{$subscribe}{IsCustodial} ||= 'n';
  $workflow->{$subscribe}{Priority}    ||= 'normal';
  $workflow->{$subscribe}{Level}       ||= 'dataset';
  foreach ( keys %map ) {
    $params->{$_} = $workflow->{$subscribe}{$map{$_}};
    $params->{$_} = $workflow->{$map{$_}} unless defined $params->{$_};
    $self->Fatal("No $map{$_} defined for $type in \"$workflow->{Name}\"")
	 unless defined $params->{$_};
  }
  $params->{data} = $self->makeXML($workflow->{data});
  $self->Dbgmsg("Subscribing: ",Data::Dumper->Dump([$params]));
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api      => 'subscribe',
			 method   => 'post',
			 callback => 'doneSubscribe',
			 params   => $params,
			}
			);
}

sub doneSubscribe {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  my $p = $obj->{PHEDEX}{REQUEST_CREATED};
  if ( $p ) {
    foreach ( @{$p} ) {
      $self->Logmsg("$payload->{workflow}{Event}: New request: $_->{ID}");
    }
  } else {
    $self->Fatal("Injected: cannot understand output: ",Dumper($obj));
  }
  $kernel->yield('nextEvent',$payload);
}

sub UpdateSubscription {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};

  $params = shift @{$workflow->{UpdateSubscription}};
  if ( !$params ) {
    $kernel->yield('nextEvent',$payload);
    return;
  }
  if ( ! $params->{dataset} ) {
    $params->{dataset} = $workflow->{data}[0]{dataset}{name};
  }
  if ( ! $params->{node} ) {
    $self->Fatal("UpdateSubscription: no 'node' specified");
  }

  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'UpdateSubscription',
			 method   => 'post',
			 callback => 'doneUpdateSubscription',
			 params   => $params,
			}
			);
}

sub doneUpdateSubscription {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
# TW Take the first dataset
  my $result = $obj->{PHEDEX}{DATASET}[0];
# TW and the first subscription
  my $subscription = $result->{SUBSCRIPTION}[0];

  $self->Logmsg("UpdateSubscription: ",Dumper($params));
# PHEDEX::Testbed::Lifecycle::Agent::post_push($self,'UpdateSubscription',$payload);
  foreach ( qw / suspend_until group priority / ) {
    next unless $params->{$_};
    if ( $params->{$_} ne $subscription->{uc $_} ) {
      $self->Fatal("UpdateSubscription: $_ should be ",$params->{$_}," but is ",$subscription->{uc $_}," instead!");
    }
  }
  unshift @{$payload->{workflow}{Events}}, 'UpdateSubscription';
  $kernel->yield('nextEvent',$payload);
}

# Calls the dataservice API and asks (nicely) for the RouterHistory
# Needs to have "RouterHistoryInstances" specified in the workflow
sub RouterHistory {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0];
  my ($params, $workflow, $rhInstances, $rhInstance);
  $workflow = $payload->{workflow};
  $rhInstances = $workflow->{RouterHistoryInstances};

  # No instances defined, no business sticking around    
  if (! defined($rhInstances)) {
    $kernel->yield('nextEvent',$payload);
  }
  
  if ($rhInstance = shift @$rhInstances) {
    # Get instance from the array and call the data service API
    # while using the appropiate instance
    $self->Logmsg("Getting router history for instance: $rhInstance\n"); 
    $self->getFromDatasvc($kernel,
	                  $session,
	                  $payload,
                        	{
				instance => $rhInstance,  # override default instance
                        	api      => 'routerhistory',                          
                        	method   => 'get',
                        	callback => 'gotRouterHistory',
                        	params   => $params,
                        	}
                          );
  } 
}

# Adds the data received from the API call to the $payload 
# Also checks to see if other instances remain to be checked
# - if yes, also re-add the RouterHistory event to the WF
sub gotRouterHistory {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($workflow, $phedex, $links);  
  $self->Logmsg("Got router history\n");
  $workflow = $payload->{workflow};
  $phedex = $obj->{PHEDEX};
  
  if ($phedex) {
    # Routing information that we got from the instance
    $links = {
        date			=> 		$phedex->{REQUEST_DATE},
	timestamp		=> 		$phedex->{REQUEST_TIMESTAMP},	
	source			=>		$phedex->{INSTANCE},
	linkData		=>		$phedex->{LINK},	
    };

    if (!defined($payload->{RoutingHistory})) {
	$payload->{RoutingHistory} = [];
    }      

    # Add link definitions to routing history
    push (@{$payload->{RoutingHistory}}, $links);    
  } else {
    $self->Logmsg("API call didn\'t go according to plan: ",Data::Dumper->Dump([$obj]),"\n");
  }
  
  # If there are remaining instances to be checked,
  # then put the RoutingHistory event back in the queue and check that instance as well
  if (scalar @{$workflow->{RouterHistoryInstances}}) {
    unshift @{$workflow->{Events}}, 'RouterHistory';  
  }
  
  $kernel->yield('nextEvent',$payload);
}

sub DumpHistory {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($workflow, $rhOutput, $externalRates, $history, $openedHistory, $openedExternal); 
  $workflow = $payload->{workflow};
  $rhOutput = $workflow->{RouterHistoryOutputFile}; # Output routing history file
  $externalRates = $workflow->{ExternalRatesFile}; # Output a file that could be read by FileRouter
  $history = $payload->{RoutingHistory};
  $openedHistory = open RHISTORY, ">$rhOutput";
  $openedExternal = open EXTERNAL, ">$externalRates";

  # Let others do work if bad stuff happened
  # We don't really care (but we could) about the external rates file
  if (!defined($history) || !$openedHistory) {
    $kernel->yield('nextEvent',$payload);
  }
  
  
  my $externalData = {}; # Data in a suitable format for FileRouter
  my $linkKeys = {}; # String(FROM-TO) -> array [FROM, TO]
  my $allLinkData = {}; # String(FROM-TO) -> Route information
  
  # Go through all the history for every instance
  foreach my $routerEvent (@$history) {
    # For each instance go through all the link infos that they provided
    foreach my $link (@{$routerEvent->{linkData}}) {

	my $strKey = $link->{FROM}."-".$link->{TO};
	my $key = [$link->{FROM}, $link->{TO}];
	
        if (!exists($allLinkData->{$strKey})) {
            $self->Logmsg("Setting set of nodes $strKey");
	    $allLinkData->{$strKey} = $link->{ROUTE}->[0];
	    $linkKeys->{$strKey} = $key;
	} else {
	    $self->Logmsg("Duplicate set of nodes found - merging stats");
	    
	    my $oldRoute = $allLinkData->{$strKey};
	    my $route = $link->{ROUTE}->[0];
	    	    
	    foreach ( qw / IDLE_BYTES IDLE_FILES PEND_BYTES PEND_FILES
	                   REQUEST_BYTES REQUEST_FILES ROUTE_BYTES ROUTE_FILES LATENCY RATE / ) {
	                 $oldRoute->{$_} += $route->{$_};
	    }
	}
    }	
  }  
  
  $Data::Dumper::Terse = 1;
  $Data::Dumper::Indent = 2;
  
  print RHISTORY Dumper($allLinkData);    
  close RHISTORY;

  # Also print out a file compatible for the FileRouter
  # For now the names of the nodes (instead of the DB IDs) are used
  if (defined($externalRates) && $openedExternal) {
    while ((my $key, my $value) = each %$allLinkData) {
	my ($from, $to) = ($linkKeys->{$key}->[0],$linkKeys->{$key}->[1]);
        $externalData->{$from}->{$to}->{"XFER_RATE"} = $value->{RATE};
    }
 
    print EXTERNAL Dumper($externalData);  
    close EXTERNAL;
  }
   
  $kernel->yield('nextEvent',$payload);
}

sub TransferQueueStats {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'transferqueuestats',
			 method   => 'get',
			 callback => 'doneTransferQueueStats',
			 params   => $params,
			}
			);
}

sub doneTransferQueueStats {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  $self->Logmsg("done: TransferQueueStats($target,",Data::Dumper->Dump([$params]),"\n");
  my ($workflow,$TransferQueueStats,$h,$i,$j,$q,$units);
  $TransferQueueStats = $obj->{PHEDEX}{LINK};
  if ( $workflow->{Debug} ) {
    $self->Logmsg("TransferQueueStats=,",Data::Dumper->Dump([$TransferQueueStats]),")\n");
  }

  $workflow = $payload->{workflow};
  $workflow->{transferqueuestats} = $TransferQueueStats;
  foreach $i ( @{$TransferQueueStats} ) {
    $h->{$i->{TO}} = 0;
    foreach $j ( @{$i->{TRANSFER_QUEUE}} ) {
      if ( $j->{STATE} eq 'assigned' ||
           $j->{STATE} eq 'exported' ||
           $j->{STATE} eq 'transferring' ) {
        $h->{$i->{TO}} += $j->{BYTES};
      }
    }
  }
  $Lifecycle::Lite{TransferQueueStats} = $h;
  if ( $workflow->{Verbose} ) {
    foreach ( sort keys %{$h} ) {
      $q = $h->{$_};
      if ( $q > 1024 ) { $q /= 1024; $units = 'kB'; }
      if ( $q > 1024 ) { $q /= 1024; $units = 'MB'; }
      if ( $q > 1024 ) { $q /= 1024; $units = 'GB'; }
      if ( $q > 1024 ) { $q /= 1024; $units = 'TB'; }
      if ( $q > 1024 ) { $q /= 1024; $units = 'PB'; }
      if ( $q > 1024 ) { $q /= 1024; $units = 'EB'; }
      $q = int(100*$q)/100;
      $self->Logmsg("TransferQueueStats: $_ -> $q $units");
    }
  }

  $kernel->yield('nextEvent',$payload);
}

sub Template {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'inject',
			 method   => 'post',
			 callback => 'doneTemplate',
			 params   => $params,
			}
			);
}

sub doneTemplate {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  $self->Logmsg("done: Template($target,",Data::Dumper->Dump([$params]),"\n");
  $kernel->yield('nextEvent',$payload);
}

1;
