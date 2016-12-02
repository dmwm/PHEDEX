#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;

use PHEDEX::Core::DB;
use base 'PHEDEX::RequestAllocator::Core', 'PHEDEX::RequestAllocator::SQL';
use PHEDEX::Core::SQL;
use PHEDEX::Core::Timing;

my %args;
&GetOptions ("db=s"            => \$args{DBCONFIG});
die "Need -db !" unless $args{DBCONFIG};
my $self = { DBCONFIG => $args{DBCONFIG} };
bless $self;
my $dbh = &connectToDatabase ($self);
my $now = &mytimeofday();

#my %h = (REQUEST => 108062, PRIORITY => '6', IS_CUSTODIAL => 'y', ORIGINAL => '1', TIME_CREATE => '2234234', USER_GROUP => '18');

#my %h = (PARAM => 42, TIME_START => undef, BLOCK => 1, IS_MOVE => 8, DESTINATION => 266, TIME_CREATE => 3242);

my $reqid = [103912,108191];

#my %h = (REQUESTS => $reqid);

#my %h = (NOW => $now, TYPE => "xfer");

my %h = (BLOCK => 2, TIME_SUSPEND_UNTIL => 3553334, DESTINATION => 1);

print "parameters: ",join(', ', map { "$_=>$h{$_}" } sort keys %h), "\n";

#&test_createSubscriptionParam(%h);
#&test_createSubscription(%h);
#&test_createSubscriptionFromRequest(33,%h);
#&test_createRequest(%h);
#&test_updateSubscription(%h);
&test_validateRequest(%h);                                                                                                                         

exit;

sub test_validateRequest{

#    &PHEDEX::RequestAllocator::Core::validateRequest($self);

    my $ds_ids = [     97421,
		       97422,
		       97422,
		       97422,
		       97423,
		       97441,
		       97466];
    my %sources;
#    my $sql = qq{ select distinct n.name, sp.is_custodial                                                                                            
 #                             from t_adm_node n                                                                                                              
 #                             join t_dps_subs_dataset s on s.destination = n.id                                                                              
 #                             join t_dps_subs_param sp on s.param=sp.id                                                                                      
 #                             where s.dataset = :dataset                                                                                                     
 #3                         UNION                                                                                                                              
 #3                         select distinct n.name, sp.is_custodial                                                                                            
 #                             from t_adm_node n                                                                                                              
  #                            join t_dps_subs_block s on s.destination = n.id                                                                                
  #                            join t_dps_subs_param sp on s.param=sp.id                                                                                      
  #                            where s.dataset = :dataset                                                                                                     
  #                        };                                                                                                                                 
  #  foreach my $ds (@$ds_ids) {   
	#print $ds,"\n";
	#my $other_subs = &PHEDEX::Core::SQL::select_hash($self, $sql, 'NAME', ':dataset' => $ds);                                                                       
	#foreach my $other (keys %$other_subs) { 
	#    print $other,"\n";
	#    print $other_subs->{$other}->{IS_CUSTODIAL};
	#    $sources{$other} = $other_subs->{$other}->{IS_CUSTODIAL};
	 #   print $sources{$other},"\n";
	#}                                                                                                                                            
#    }
    my %h;
    $h{IS_CUSTODIAL}='y';
    my $nodes = [ 'T1_UK_RAL_MSS' ];
    my $sql = qq{ select distinct n.name, ds.name dataitem, sp.is_custodial
                              from t_adm_node n
                              join t_dps_subs_dataset s on s.destination = n.id
                              join t_dps_dataset ds on ds.id=s.dataset
                              join t_dps_subs_param sp on s.param=sp.id
                              where s.dataset = :dataset
                          UNION
                          select distinct n.name, ds.name dataitem, sp.is_custodial
                              from t_adm_node n
                              join t_dps_subs_block s on s.destination = n.id
                              join t_dps_block bk on bk.id=s.block
                              join t_dps_dataset ds on ds.id=s.dataset
                              join t_dps_subs_param sp on s.param=sp.id
                              where s.dataset = :dataset
                              and bk.time_create>nvl(:time_start,-1)
                          };
    foreach my $ds (@$ds_ids) {
	my $other_subs = &execute_sql($self, $sql, ':dataset' => $ds, ':time_start' => $h{TIME_START});
                while (my $r = $other_subs->fetchrow_hashref())
                {
                    print (keys %$r),"\n";
		    foreach (keys %$r) {
			print $r->{$_},"\n";
		    }
                    if ((grep (/^$r->{NAME}$/, @$nodes)) && ($r->{IS_CUSTODIAL} ne $h{IS_CUSTODIAL})) {  
                        die "cannot request transfer: $r->{DATAITEM} already subscribed to $r->{NAME} with different custodiality\n";
                    }
                    $sources{$r->{NAME}}=1;
                }
    }


    print (keys %sources),"\n";
    foreach (keys %sources) {
	print $sources{$_},"\n";
    }

     #                         from t_adm_node n                                                                                                              
     #                         join t_dps_subs_dataset s on s.destination = n.id                                                                              
      #                        join t_dps_subs_param sp on s.param=sp.id                                                                                      
      #                        where s.dataset = :dataset                                                                                                     
      #                    UNION                                                                                                                              
      #                    select distinct n.name, 'DATASET', s.dataset, sp.is_custodial                                                                      
      #                        from t_adm_node n                                                                                                              
      #                        join t_dps_subs_block s on s.destination = n.id                                                                                
      #                        join t_dps_block bk on bk.id=s.block                                                                                           
     # 3                        join t_dps_subs_param sp on s.param=sp.id                                                                                      
      #3                        where s.dataset = :dataset                                                                                                     
      #3                        and bk.time_create>nvl(:time_start,-1)                                                                                         
       #                   };                                                                                                                                 
 #   foreach my $ds (@$ds_ids) {                                                                                                                      
	#my $other_subs = &PHEDEX::Core::SQL::execute_sql($self, $sql, ':dataset' => $ds, ':time_start' => $h{TIME_START});                                              
        #3        while (my $r = $other_subs->fetchrow_arrayref())                                                                                             
        #        {                                                                                                                                            
       #             print "@$r","\n";                                                                                                                          
       #3         }
    #}
}

sub test_updateSubscription{
    my $nsubs = $self->updateSubscription(@_);    
    print $nsubs,"\n";
    $self->execute_commit;                                                                                                                                   
}

sub test_createRequest
{
    print @_;
    $self->createRequest;
}

sub test_createSubscriptionParam
{
    #$self->createSubscriptionParam(%h);
    $self->execute_commit;
}

sub test_createSubscription
{
    #$self->createSubscription(%h);
    $self->execute_commit;                                                                                                                                   
}

sub test_createSubscriptionFromRequest
{
    my ($node,%u) = @_;
    print $node,"\n";
    my $requests = $self->getTransferRequests(%u);
    foreach my $xreq( values %$requests ) {
	my $reqid=$xreq->{ID};
	print $reqid,"\n";
	my $reqMove=$xreq->{IS_MOVE};
	print $reqMove, "\n";
	my $reqPriority=$xreq->{PRIORITY};
	print $reqPriority,"\n";
	my $reqCustodiality=$xreq->{IS_CUSTODIAL};
	print $reqCustodiality,"\n";
	my $reqGroup=$xreq->{USER_GROUP};
	print $reqGroup,"\n";
	my $reqTimeStart=$xreq->{TIME_START};
	print $reqTimeStart,"\n";
	my $paramId = $self->createSubscriptionParam (
						      REQUEST => $xreq->{ID},
						      PRIORITY => $xreq->{PRIORITY},
						      IS_CUSTODIAL => $xreq->{IS_CUSTODIAL},
						      USER_GROUP => $xreq->{USER_GROUP},
						      ORIGINAL => 1,
						      TIME_CREATE => $now
						      );
	print $paramId,"\n";
	&PHEDEX::RequestAllocator::SQL::addSubscriptionsForParamSet($self,$paramId, $node, $now)
    }
    $self->execute_commit;
}


1; # end TestSQL package

