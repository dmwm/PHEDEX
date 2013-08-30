package PHEDEX::Testbed::Lifecycle::SelfSigned;

use strict;
use warnings;
use POE;
use base 'PHEDEX::Testbed::Lifecycle::UA', 'PHEDEX::Core::Logging'; # 'PHEDEX::Testbed::Lifecycle::Datasvc';
use Clone qw(clone);
use Data::Dumper;
use PHEDEX::CLI::UserAgent;
use JSON::XS;

our %params = (
	       url       => 'https://cmsweb.cern.ch/phedex/datasvc',
	       instance  => 'prod',
	       format    => 'perl',
  timeout   => 60,
);

sub new {
    my $proto = shift;
    my $parent = shift;
    my $workflow = shift;
    my $class = ref($proto) || $proto;
    my $self;

    if($workflow->{__PACKAGE__}){
	$self = $workflow->{__PACKAGE__};
    }
    else{
	$self = $class->SUPER::new( $parent );

	my $package = __PACKAGE__;
	$package =~ s%^$workflow->{Namespace}::%%;

	my $p = $workflow->{$package};
	map { $self->{params}{uc $_} = $params{$_} } keys %params;
	map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
	map { $self->{$_} = $p->{$_} } keys %{$p};
    }

    $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );

    bless $self, $class;

    $workflow->{__PACKAGE__} = $self;

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
    $self->{UA}->CALL($args->{api});
    $target = $self->{UA}->target;
    if ( $callback && ! $self->{_callbacks}{$callback}++ ) {
	$kernel->state($callback,$self);
    }
    $kernel->post($self->{Alias},'start_task',{
	payload=> $payload,
	method=> $method,
	target=> $target,
	params=> $params,
	callback=> $callback,
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

sub SelfInject {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    my ($params,$workflow);
  
    $workflow = $payload->{workflow};
    $workflow->{XML} = $self->makeXML($workflow->{data});

    $params->{node} = $workflow->{InjectionSite};
    $params->{strict}= $workflow->{StrictInjection} || 0;
    $params->{data} = $workflow->{XML};

  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			    api  => 'inject',
			        method   => 'post',
			        callback => 'doneSelfInject',
			    params   => {
				strict => $params->{strict} ,
				data => $params->{data} ,
				node => $params->{node} ,
			    }
			}
			);
}

sub doneSelfInject {
    my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
    delete $payload->{workflow}{XML};
    my $p = $obj->{PHEDEX}{INJECTED}{STATS};
    if ( $p ) {
	$self->Logmsg("Injection: New data: $p->{NEW_DATASETS} datasets, $p->{NEW_BLOCKS} blocks, $p->{NEW_FILES} files. Closed: $p->{CLOSED_DATASETS} datasets, $p->{CLOSED_BLOCKS} blocks");
    } else {
	exit 100;
	$self->Fatal("Injected: cannot understand output: ",Dumper($obj));
    }
    $kernel->yield('nextEvent',$payload);
}


sub SetCertA {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    $self->SetCert('A',$kernel,$session,$payload);
}

sub SetCertB {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    $self->SetCert('B',$kernel,$session,$payload);
}

sub SetCert {
    my ($self, $type, $kernel,$session,$payload,$args) = @_;
    my ($target,$workflow,$api,$callback,$params,$method);
    
    my $cert_file = 'cert_file_' . $type;
    my $key_file = 'key_file_' . $type;

    $workflow = $payload->{workflow};
    $params->{cert_file} = $workflow->{$cert_file};
    $params->{key_file} = $workflow->{$key_file};

    $self->Logmsg("SetCert: Change cert_file to $params->{cert_file}");
    $self->Logmsg("SetCert: Change key_file to $params->{key_file}");

    $self->{params}->{CERT_FILE} = $params->{cert_file};
    $self->{params}->{KEY_FILE} = $params->{key_file};
 
    $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );
    $workflow->{__PACKAGE__} = $self;
   
    $kernel->yield('nextEvent',$payload);
    return $self;
}

sub SelfT1Subscribe {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    $self->SelfSubscribe('T1',$kernel,$session,$payload);
}

sub SelfT2Subscribe {
    my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    $self->SelfSubscribe('T2',$kernel,$session,$payload);
}

sub SelfSubscribe {
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
	  node       => 'Nodes',
	  data       => 'data',
	  group       => 'Group',
	    priority     => 'Priority',
	  move       => 'IsMove',
	    custodial    => 'IsCustodial',
	    static       => 'IsStatic',
	    time_start   => 'TimeStart',
	    level        => 'Level',
	  );
    $workflow->{$subscribe}{TimeStart}   ||=  0;
    $workflow->{$subscribe}{IsStatic}    ||= 'n';
    $workflow->{$subscribe}{IsMove}      ||= 'n';
    $workflow->{$subscribe}{IsCustodial} ||= 'n';
    $workflow->{$subscribe}{Priority}    ||= 'normal';
    $workflow->{$subscribe}{Level}       ||= 'dataset';
 
    foreach ( keys %map ) {
	$self->Log("Subscribe $_($subscribe): ",$map{$_},', ',$workflow->{$subscribe}{$map{$_}},', ',$workflow->{$map{$_}});
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
			      callback => 'doneSelfSubscribe',
			      params   => $params,
			 }
			);

}

sub doneSelfSubscribe {
    my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
    $self->Logmsg("Start doneSubscribe $obj->{error}");
    my $p = $obj->{PHEDEX}{REQUEST_CREATED};
    if ( $p ) {
	foreach ( @{$p} ) {
	    $self->Logmsg("$payload->{workflow}{Event}: New request: $_->{ID}");
	}
    } else {
	exit 100;      
    }
    $kernel->yield('nextEvent',$payload);  
}


sub StopLC {
    exit 123;
}

1;
