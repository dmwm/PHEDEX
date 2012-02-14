package PHEDEX::BlockAllocator::Core;

use strict;
use warnings;
use base 'PHEDEX::BlockAllocator::SQL', 'PHEDEX::BlockLatency::SQL', 'PHEDEX::Core::Logging';

our %params = (
	      );

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

# Phase 0: Add block-level subscription for new blocks where dataset-level subscription exists

sub addBlockSubscriptions
{
    my ($self, $now) = @_;

    my %stats;
    my @stats_order = ('block subs added','dataset sub watermarks moved');
    $stats{$_} = 0 foreach @stats_order;
    
    # Create block-level subscriptions for all blocks created after time_fill_after in a dataset-level subscription
    # If the block-level subscription already exists, update it to link it to the dataset-level subscription parameters

    my @rv = $self->execute_sql( qq{
	merge into t_dps_subs_block n using
	    (
	     select sd.destination, b.dataset, b.id block, sd.param, sd.is_move,
	       greatest(sd.time_create, b.time_create) time_create, sd.time_suspend_until
	     from t_dps_subs_dataset sd
	     join t_dps_block b on b.dataset = sd.dataset
	     where b.time_create > nvl(sd.time_fill_after,-1)
	     ) o on (n.destination = o.destination
		     and n.dataset = o.dataset
		     and n.block = o.block)
	     when matched then update
	      set n.param=o.param,
	          n.is_move=decode(n.is_move,'y','y','n',o.is_move)
	     when not matched then insert
	     (destination, dataset, block, param, is_move,
	      time_create, time_suspend_until)
	     values
	     (o.destination, o.dataset, o.block, o.param, o.is_move,
	      o.time_create, o.time_suspend_until)
	}, () );

    $stats{'block subs added'} = $rv[1] || 0;                       

    # Finally, update t_dps_subs_dataset.time_fill_after to the block creation time of the latest block in the subscription. 
    # We do this only for blocks which already have a block-level subscription linked to a dataset-level subscription 
    # from the previous step, to avoid moving the watermark above any new block injected in the meantime

    my @rvwm = $self->execute_sql( qq{   
	merge into t_dps_subs_dataset sd using
	    (
	     select sdi.dataset, sdi.destination, max(b.time_create) time_fill_after from t_dps_block b
	     join t_dps_subs_block sb on sb.block = b.id
	     join t_dps_subs_dataset sdi
	      on sdi.dataset=sb.dataset and sdi.destination=sb.destination and sb.param=sdi.param
	     group by sdi.dataset,sdi.destination
	     ) sdt on (sd.dataset = sdt.dataset and sd.destination=sdt.destination)
	     when matched then update
	      set sd.time_fill_after=greatest(sdt.time_fill_after,nvl(sd.time_fill_after,-1))
	});

    $stats{'dataset sub watermarks moved'} = $rvwm[1] || 0;
    			
    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
}

# Phase I: Subscription-level state changes
#   2. Mark fully transferred subscriptions as complete/done
#     2a. Block-level subs is "complete" if node_files != 0 && node_files == dest_files && node_files >= exist_files
#     2b. Block-level replica subs is "done" if it is "complete" and the block is closed
#     2c. Block-level move subs is "done" if it is "complete" and the block is closed
#          and subs is at least 1 week old and no unsubscribed block replicas exist
#     2d. Dataset-level subs is "complete" if all block-level subscriptions are "complete"
#     2e. Dataset-level replica subs is "done" if all block-level subscriptions are "done" and the dataset is closed
#     2f. Dataset-level move subs is "done" if all block-level subscriptions are "done" and the dataset is closed
#          and it is at least 1 week old
#   3. Change "done" move subscriptions into a replica subscription
#   4. Mark complete/done subscriptions as incomplete if they are not complete anymore
#   5. Clear expired suspension times (note: subscriptions of inactive blocks will remain suspended until reactivation)

sub blockSubscriptions
{

    no warnings qw(uninitialized);  # lots of undef variables expected here from empty timestamps

    my ($self, $now) = @_;

    my %stats;
    my @stats_order = ('block subs completed', 'block replica subs done',
		       'block move subs done', 'block moves pending deletion', 'block moves pending confirmation',
		       'block subs marked incomplete', 'block subs suspensions cleared', 'block subs updated');

    $stats{$_} = 0 foreach @stats_order;
    
    # Select block subscriptions that need to be updated.
    # For replica susbcriptions, only active blocks are considered.
    # For move subscriptions, all blocks are considered, since state changes for move block subscriptions 
    # are possible after the transfer is already completed and the block is deactivated
    # In the move subscription query, the number of unsubscribed non-T0/T1 block replicas is counted:
    # when this reaches zero the move flag can be removed
    my $q_blocksubs = $self->execute_sql( qq{
	select s.block subs_block_id,
	      b.name subs_block_name,
	      b.is_open subs_block_open,
              n.id destination_id, n.name destination_name,
              s.destination subs_destination, s.block subs_block,
              s.dataset subs_dataset, sp.priority, s.is_move,
              s.time_suspend_until, s.time_create,
              s.time_complete, s.time_done,
              b.files exist_files, br.node_files, br.dest_files,
              b.bytes exist_bytes, br.node_bytes, br.dest_bytes,
              NULL nunsub
        from t_dps_subs_block s
        join t_adm_node n on n.id = s.destination
        join t_dps_block b on b.id = s.block
        join t_dps_subs_param sp on sp.id = s.param
        join t_dps_block_replica br on br.node = s.destination and br.block = b.id
        where br.is_active='y' and s.is_move='n'
        UNION
        select s.block subs_block_id,
              b.name subs_block_name,
              b.is_open subs_block_open,
              n.id destination_id, n.name destination_name,
              s.destination subs_destination, s.block subs_block,
              s.dataset subs_dataset, sp.priority, s.is_move,
              s.time_suspend_until, s.time_create,
              s.time_complete, s.time_done,
              b.files exist_files, br.node_files, br.dest_files,
              b.bytes exist_bytes, br.node_bytes, br.dest_bytes,
              NVL(unsub.n,0) nunsub               
         from t_dps_subs_block s
         join t_adm_node n on n.id = s.destination
         join t_dps_block b on b.id = s.block
         join t_dps_subs_param sp on sp.id = s.param
         join t_dps_block_replica br on br.node = s.destination and br.block = b.id
         left join (select br2.block, count(*) n from t_dps_block_replica br2
		    join t_adm_node n2 on n2.id=br2.node
		    left join t_dps_subs_block s2 on br2.node = s2.destination and br2.block = s2.block
                    where br2.node_files!=0 and s2.block is null
		    and not regexp_like(n2.name,'^T[01]_')
                    group by br2.block) unsub on unsub.block=s.block
	 where s.is_move='y'
     }, () );

    # Fetch all subscription data
    my @all_block_subscriptions;
    while (my $blocksubscription = $q_blocksubs->fetchrow_hashref()) {
	push @all_block_subscriptions, $blocksubscription;
    }

    my %uargs;

  SUBSCRIPTION: foreach my $subs (@all_block_subscriptions) {
      my $subs_identifier = "$subs->{SUBS_BLOCK_NAME} to $subs->{DESTINATION_NAME}";

      my $subs_update = { 
	  IS_MOVE => $subs->{IS_MOVE},
	  TIME_SUSPEND_UNTIL => $subs->{TIME_SUSPEND_UNTIL},
	  TIME_COMPLETE => $subs->{TIME_COMPLETE},
	  TIME_DONE => $subs->{TIME_DONE}
      };
      
      # Update newly complete block subscriptions
      # Block-level subs is "complete" if node_files != 0 and node_files == dest_files
      #  and node_files >= exist_files
      if ( $subs->{NODE_FILES} !=0 &&
	   $subs->{NODE_FILES} == $subs->{DEST_FILES} &&
	   $subs->{NODE_BYTES} == $subs->{DEST_BYTES} &&
	   $subs->{NODE_FILES} >= $subs->{EXIST_FILES} &&
           $subs->{NODE_BYTES} >= $subs->{EXIST_BYTES} ) {
	  if ( ! $subs->{TIME_COMPLETE} ) { 
	      $subs_update->{TIME_COMPLETE} = $now;
	      $self->Logmsg("subscription complete for $subs_identifier");
	      $stats{'block subs completed'}++;
	  }
	  # Update newly done block subscriptions
	  # - Block-level replica subs is "done" if it is "complete" and the block is closed
	  if ( ! $subs->{TIME_DONE} && $subs->{SUBS_BLOCK_OPEN} eq 'n' ) {
	      if ( $subs->{IS_MOVE} eq 'n' ) {
		  $subs_update->{TIME_DONE} = $now;
		  $self->Logmsg("subscription is done for $subs_identifier");
		  $stats{'block replica subs done'}++;
	      }
	      # - Block-level move subs is "done" if it is "complete" and the block is closed
	      #    and no unsubscribed block replicas exist and subs is at least 1 week old
	      # Change "done" block move subscriptions into a replica subscription
	      elsif ( $subs->{IS_MOVE} eq 'y' ) {
		  if ( $now - $subs->{TIME_CREATE} >= 7*24*3600 ) {
		      
		      if ( $subs->{NUNSUB} == 0 ) {
			  $subs_update->{IS_MOVE} = 'n';
			  $subs_update->{TIME_DONE} = $now;
			  $self->Logmsg("subscription is done for $subs_identifier, ",
					"move request flag removed for $subs_identifier");
			  $stats{'block move subs done'}++;
		      }
		      elsif ( $subs->{NUNSUB} > 0 ) {
			  $self->Logmsg("waiting for $subs->{NUNSUB} unsubscribed block replicas ",
					"to be deleted before marking move of $subs->{SUBS_BLOCK_NAME} done");
			  $stats{'block moves pending deletion'}++;
		      }
		  }
		  else {
		      $self->Logmsg("waiting 1 week for move confirmations of $subs_identifier");
		      $stats{'block moves pending confirmation'}++;
		  }
	      }
	  }
      }

      # Mark complete/done block subscriptions as incomplete if they are not complete anymore
      
      if ( ($subs->{TIME_DONE} || $subs->{TIME_COMPLETE}) &&
	   ($subs->{NODE_FILES} < $subs->{EXIST_FILES} ||
	   $subs->{NODE_BYTES} < $subs->{EXIST_BYTES})) {
	  $subs_update->{TIME_COMPLETE} = undef;
	  $subs_update->{TIME_DONE} = undef;
	  $self->Logmsg("subscription is no longer done, updating for $subs_identifier");
	  $stats{'block subs marked incomplete'}++;
      }

      # Clear expired suspension times
      if ( defined $subs->{TIME_SUSPEND_UNTIL} && $subs->{TIME_SUSPEND_UNTIL} < $now ) {
	  $subs_update->{TIME_SUSPEND_UNTIL} = undef;
	  $self->Logmsg("subscription is no longer suspended, updating for $subs_identifier");
	  $stats{'block subs suspensions cleared'}++;
      }

      # Add to bulk update arrays if there are changes
      if (&hash_ne($subs_update, $subs)) {
	  $self->Logmsg("Adding changes to bulk update array for $subs_identifier");
	  my $n = 1;
	  push(@{$uargs{$n++}}, $subs_update->{TIME_SUSPEND_UNTIL});
	  push(@{$uargs{$n++}}, $subs_update->{TIME_COMPLETE});
	  push(@{$uargs{$n++}}, $subs_update->{TIME_DONE});
	  push(@{$uargs{$n++}}, $subs_update->{IS_MOVE});
	  push(@{$uargs{$n++}}, $subs->{SUBS_DESTINATION});
	  push(@{$uargs{$n++}}, $subs->{SUBS_DATASET});
	  push(@{$uargs{$n++}}, $subs->{SUBS_BLOCK});
      }
  }

    # Bulk update
    my @rv = $self->execute_sql( qq{
	update t_dps_subs_block
	   set time_suspend_until = ?,
	       time_complete = ?,
	       time_done = ?,
               is_move = ?
         where destination = ?
	   and dataset = ?
           and block = ?
       }, %uargs) if %uargs;

    $stats{'block subs updated'} = $rv[1] || 0;
    
    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
}

sub datasetSubscriptions
{
    no warnings qw(uninitialized);  # lots of undef variables expected here from empty timestamps

    my ($self, $now) = @_;

    my %stats;
    my @stats_order = ('dataset subs completed', 'dataset replica subs done',
		       'dataset move subs done', 'dataset moves pending confirmation',
		       'dataset subs marked incomplete', 'dataset subs suspensions cleared',
		       'dataset subs updated');

    $stats{$_} = 0 foreach @stats_order;
    
    # Select dataset subscriptions for update
    my $q_datasetsubs = $self->execute_sql( qq{
	select s.dataset subs_dataset_id,
              d.name subs_dataset_name,
	      d.is_open subs_dataset_open,
              n.id destination_id, n.name destination_name,
              s.destination subs_destination,
              sp.priority, s.is_move,
              s.time_suspend_until, s.time_create,
              s.time_complete, s.time_done,
	      NVL(incomplete.n,0) nincomplete,
	      NVL(notdone.n,0) nnotdone
	from t_dps_subs_dataset s
	join t_adm_node n on n.id = s.destination
        join t_dps_dataset d on d.id = s.dataset   
	join t_dps_subs_param sp on sp.id = s.param
	left join (select bs.destination, bs.dataset, bs.param, count(*) n from t_dps_subs_block bs
	        where bs.time_complete is null
	        group by bs.destination, bs.dataset, bs.param) incomplete
	  on (incomplete.destination = s.destination and incomplete.dataset = s.dataset and incomplete.param = s.param )
	left join (select bs2.destination, bs2.dataset, bs2.param, count(*) n from t_dps_subs_block bs2
	        where bs2.time_done is null
	        group by bs2.destination, bs2.dataset, bs2.param) notdone
	  on (notdone.destination = s.destination and notdone.dataset = s.dataset and notdone.param = s.param )
      }, () );
    
    # Fetch all subscription data
    my @all_dataset_subscriptions;
    while (my $datasetsubscription = $q_datasetsubs->fetchrow_hashref()) {
	push @all_dataset_subscriptions, $datasetsubscription;
    }

    my %uargs;

  SUBSCRIPTION: foreach my $subs (@all_dataset_subscriptions) {
      my $subs_identifier = "$subs->{SUBS_DATASET_NAME} to $subs->{DESTINATION_NAME}";

      my $subs_update = { 
	  IS_MOVE => $subs->{IS_MOVE},
	  TIME_SUSPEND_UNTIL => $subs->{TIME_SUSPEND_UNTIL},
	  TIME_COMPLETE => $subs->{TIME_COMPLETE},
	  TIME_DONE => $subs->{TIME_DONE}
      };
  
      # Update newly complete dataset subscriptions
      # Dataset-level subs is "complete" if all block-level subscriptions are "complete"

      if ( $subs->{NINCOMPLETE} == 0 ) {
	  if ( ! $subs->{TIME_COMPLETE} ) {
	      $subs_update->{TIME_COMPLETE} = $now;
	      $self->Logmsg("subscription complete for $subs_identifier");
	      $stats{'dataset subs completed'}++;
	  }
	  # Update newly done dataset subscriptions
	  # Dataset-level replica subs is "done" if it is complete and all block-level subscriptions are "done" and the dataset is closed
	  if ( !$subs->{TIME_DONE} &&
	       $subs->{NNOTDONE} == 0 &&
	       $subs->{SUBS_DATASET_OPEN} eq 'n' ) {
	      if ( $subs->{IS_MOVE} eq 'n' ) {
		  $subs_update->{TIME_DONE} = $now;
		  $self->Logmsg("subscription is done for $subs_identifier");
		  $stats{'dataset replica subs done'}++;
	      }
	      # Dataset-level move subs is "done" if it is done as above and if it is at least 1 week old
	      # Change "done" dataset move subscriptions into a replica subscription
	      elsif ( $subs->{IS_MOVE} eq 'y' ) {
		  if ( $now - $subs->{TIME_CREATE} >= 7*24*3600 ) {
		      $subs_update->{TIME_DONE} = $now;
		      $subs_update->{IS_MOVE} = 'n';
		      $self->Logmsg("subscription is done for $subs_identifier, ",
				    "move request flag removed for $subs_identifier");
		      $stats{'dataset move subs done'}++;
		  }
		  else {
		      $self->Logmsg("waiting 1 week for move confirmations of $subs_identifier");
		      $stats{'dataset moves pending confirmation'}++;
		  }
	      }
	  }
      }
      
      # Mark complete/done block subscriptions as incomplete if they are not complete anymore
      if (($subs->{TIME_COMPLETE} && $subs->{NINCOMPLETE}!=0) ||
	  ($subs->{TIME_DONE} && ($subs->{NINCOMPLETE}!=0 || $subs->{NNOTDONE}!=0))) {
	  $subs_update->{TIME_COMPLETE} = undef;
	  $subs_update->{TIME_DONE} = undef;
	  $self->Logmsg("subscription is no longer done, updating for $subs_identifier");
	  $stats{'dataset subs marked incomplete'}++;
      }

      # Clear expired suspension times
      if ( defined $subs->{TIME_SUSPEND_UNTIL} && $subs->{TIME_SUSPEND_UNTIL} < $now ) {
	  $subs_update->{TIME_SUSPEND_UNTIL} = undef;
	  $self->Logmsg("subscription is no longer suspended, updating for $subs_identifier");
	  $stats{'dataset subs suspensions cleared'}++;
      }

      # Add to bulk update arrays if there are changes
      if (&hash_ne($subs_update, $subs)) {
	  my $n = 1;
	  push(@{$uargs{$n++}}, $subs_update->{TIME_SUSPEND_UNTIL});
	  push(@{$uargs{$n++}}, $subs_update->{TIME_COMPLETE});
	  push(@{$uargs{$n++}}, $subs_update->{TIME_DONE});
	  push(@{$uargs{$n++}}, $subs_update->{IS_MOVE});
	  push(@{$uargs{$n++}}, $subs->{SUBS_DESTINATION});
	  push(@{$uargs{$n++}}, $subs->{SUBS_DATASET_ID});
      }
       
  }
    
    # Bulk update
    my @rv = $self->execute_sql( qq{
	update t_dps_subs_dataset
	   set time_suspend_until = ?,
	       time_complete = ?,
	       time_done = ?,
               is_move = ?
         where destination = ?
	   and dataset = ?
       }, %uargs) if %uargs;

    $stats{'dataset subs updated'} = $rv[1] || 0;
    
    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
  
}

# Phase III:  Block Destination creation/deletion
#   1.  Create block destinations where a block subscription exists
#   2.  Remove block destinations where:
#         a.  the block subscription doesn't exist
#         b.  the block is queued for deletion
sub allocate
{
    my ($self, $now) = @_;

    my %stats;
    my @stats_order = ('blocks allocated', 'blocks deallocated');
    $stats{$_} = 0 foreach @stats_order;

    my @add;
    my @rem;

    my $q_subsNoBlock = $self->execute_sql( qq{
	    select s.destination destination, n.name destination_name,
                   s.block, sb.name block_name,
	           s.dataset, sp.priority, 0 state,
		   s.time_create time_subscription,
		   sp.is_custodial
              from t_dps_subs_block s
	      join t_dps_subs_param sp
	        on s.param=sp.id
	      join t_dps_block sb on sb.id = s.block
	      join t_adm_node n on n.id = s.destination
	      where not exists (select 1 from t_dps_block_delete bdel
                                 where bdel.node = s.destination
                                   and bdel.block = s.block
                                   and bdel.time_complete is null)
	        and not exists (select 1 from t_dps_block_dest bd
				 where bd.destination = s.destination
				   and bd.block = s.block)
	  });
    while (my $block = $q_subsNoBlock->fetchrow_hashref()) {
	$self->Logmsg("adding block destination for $block->{BLOCK_NAME} to $block->{DESTINATION_NAME}");
	$block->{TIME_CREATE} = $now;
	push @add, $block;
    }

    my $n_alloc = $self->allocateBlockDestinations(\@add);
    $stats{'blocks allocated'} = $n_alloc;

    my $q_blockNoSubs = $self->execute_sql( qq{
	    select bd.destination destination, n.name destination_name,
                   b.id block, b.name block_name,
		   case when subs.destination is null then 'no subscription'
			when bdel.time_complete is null then 'queued for deletion'
			else 'no reason!'
                    end reason
	      from t_dps_block_dest bd
              join t_dps_block b on b.id = bd.block
	      join t_adm_node n on n.id = bd.destination
	      left join t_dps_subs_block subs
	        on subs.destination = bd.destination and subs.block = bd.block
              left join t_dps_block_delete bdel 
	        on bdel.node = bd.destination and bdel.block = bd.block
             where subs.destination is null
	        or (bdel.block is not null and bdel.time_complete is null)
	    });

    while (my $block = $q_blockNoSubs->fetchrow_hashref()) {
	$self->Logmsg("removing block destination for $block->{BLOCK_NAME} to $block->{DESTINATION_NAME}: ",
		"$block->{REASON}");
	push @rem, $block;
    }

    my $n_dealloc = $self->deallocateBlockDestinations(\@rem);
    $stats{'blocks deallocated'} = $n_dealloc;

    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
}

# Bulk insert of new block destinations
sub allocateBlockDestinations
{
    my ($self, $blocks) = @_;
    my $i = &dbprep($self->{DBH}, qq{
	insert into t_dps_block_dest
	(block, dataset, destination, priority, state, time_subscription, time_create, is_custodial)
        values (?, ?, ?, ?, ?, ?, ?, ?) });

    my %iargs;
    foreach my $b (@$blocks) {
	my $n = 1;
	foreach my $key (qw(BLOCK DATASET DESTINATION PRIORITY STATE TIME_SUBSCRIPTION TIME_CREATE IS_CUSTODIAL)) {
# Sanity check
	    defined($b->{$key}) or $self->Alert(
			"allocateBlockDestinations: missing key $key in ",
			join(', ', sort( map { "$_=$b->{$_}" } keys %{$b} ) )
					      );

	    push(@{$iargs{$n++}}, $b->{$key});
	}	
    }

    my $rv = &dbbindexec($i, %iargs) if %iargs;
    return $rv || 0;
}

# Bulk delete of block destinations
sub deallocateBlockDestinations
{
    my ($self, $blocks) = @_;
    my $d = &dbprep($self->{DBH}, qq{
	delete from t_dps_block_dest
         where block = ?
	 and destination = ? });

    my %dargs;
    foreach my $b (@$blocks) {
	my $n = 1;
	foreach my $key (qw(BLOCK DESTINATION)) {
	    push(@{$dargs{$n++}}, $b->{$key});
	}	
    }

    my $rv = &dbbindexec($d, %dargs) if %dargs;
    return $rv || 0;
}


# Phase II: Propagate dataset-level subs suspension to block-level subs
sub suspendBlockSubscriptions
{
    my ($self, $now) = @_;
    my %stats;
    my @stats_order = ('block subs suspended', 'block subs unsuspended', 'block subs updated');
    $stats{$_} = 0 foreach @stats_order;
    
    my $q_dataset_suspensions = $self->execute_sql( qq{
	select s.dataset subs_dataset_id,
	      d.name subs_dataset_name,
	      bs.block subs_block_id,
	      b.name subs_block_name,
	      d.is_open subs_dataset_open,
              n.id destination_id, n.name destination_name,
              s.destination subs_destination,
              sp.priority, s.is_move,
              s.time_suspend_until dataset_suspend, s.time_create,
              s.time_complete, s.time_done,
	      bs.time_suspend_until block_suspend
	from t_dps_subs_dataset s
	join t_adm_node n on n.id = s.destination
        join t_dps_dataset d on d.id = s.dataset
	join t_dps_subs_param sp on sp.id = s.param
	join t_dps_subs_block bs on 
	      bs.destination = s.destination and bs.dataset = s.dataset and bs.param = s.param 
	join t_dps_block b on b.id = bs.block
	where nvl(trunc(s.time_suspend_until),-1) != nvl(trunc(bs.time_suspend_until),-1)
	  }, () );
    

    my %uargs;
    while (my $datasetsuspensions = $q_dataset_suspensions->fetchrow_hashref()) {
     my $bsub_identifier = "$datasetsuspensions->{SUBS_BLOCK_NAME} in $datasetsuspensions->{SUBS_DATASET_NAME} at $datasetsuspensions->{DESTINATION_NAME}";
      
      # Update parameters for block subscriptions
      my $bsub_update = { 
	  BLOCK_SUSPEND => $datasetsuspensions->{DATASET_SUSPEND},
	  BLOCK => $datasetsuspensions->{SUBS_BLOCK_ID},
	  DESTINATION => $datasetsuspensions->{DESTINATION_ID}	  
      };

     { no warnings qw(uninitialized);  # lots of undef variables expected here
	if (!defined $bsub_update->{BLOCK_SUSPEND} || $bsub_update->{BLOCK_SUSPEND} <= $now) {
	    $self->Logmsg("unsuspending block subscription $bsub_identifier");
	    $stats{'block subs unsuspended'}++;
	}

	if (defined $bsub_update->{BLOCK_SUSPEND} && 
	    $bsub_update->{BLOCK_SUSPEND} > $now) {
	    $self->Logmsg("suspending block subscription $bsub_identifier");
	    $stats{'block subs suspended'}++;
	}
   }

     my $n = 1;
     push(@{$uargs{$n++}}, $bsub_update->{BLOCK_SUSPEND});
     push(@{$uargs{$n++}}, $bsub_update->{BLOCK});
     push(@{$uargs{$n++}}, $bsub_update->{DESTINATION});
     
 }

    # Bulk update
    my @rv = &dbexec($self->{DBH}, qq{
	update t_dps_subs_block
	    set time_suspend_until = ?
	    where block = ? and destination = ?
     }, %uargs) if %uargs;
    
    $stats{'block subs updated'} = $rv[1] || 0;

    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order; 
 
}

# Phase IV:  Block destination state changes
#   1.  Propagate subscription state to block destinations
#   2.  Mark completed block destinations done
#   3.  Mark undone block destinations if incomplete
sub blockDestinations
{
    my ($self, $now) = @_;
    my %stats;
    my @stats_order = ('blockdest done', 'blockdest reactivated', 'blockdest priority changed',
		       'blockdest suspended', 'blockdest unsuspended', 'blockdest updated');
    $stats{$_} = 0 foreach @stats_order;

    # Query block destinations which need to be updated
    # Careful! Selection logic here must match update logic below!
    # TODO: Combine selection and update logic into one place (the
    #       query), while still being able to log statistics
    my $q_blockdest = &dbexec($self->{DBH}, qq{
	    select
              bd.destination, n.name destination_name,
              b.dataset dataset, b.id block, b.name block_name,
	      b.is_open,
	      sp.priority subs_priority, s.is_move subs_move,
	      s.time_create subs_create, s.time_complete subs_complete,
	      s.time_done subs_done, s.time_suspend_until subs_suspend,
	      bd.priority bd_priority, bd.state bd_state,
              bd.time_subscription bd_subscrption, bd.time_create bd_create, bd.time_active bd_active,
	      bd.time_complete bd_complete, bd.time_suspend_until bd_suspend,
	      nvl(br.node_files,0) node_files, nvl(br.src_files,0) src_files, b.files exist_files
 	    from t_dps_block_dest bd
	    join t_adm_node n on n.id = bd.destination
	    join t_dps_block b on b.id = bd.block
	    join t_dps_subs_block s on s.destination = bd.destination
	                             and s.block = bd.block
	    join t_dps_subs_param sp on sp.id = s.param
	    left join t_dps_block_replica br on br.node = bd.destination and br.block = bd.block
           where 
             -- block is complete and closed, update state
             (b.is_open = 'n'
	      and br.node_files >= b.files
              and bd.state != 3)
             -- block is incomplete, update state
             or (nvl(br.node_files,0)<b.files and bd.state = 3)
             -- update priority
             or (bd.priority != sp.priority)
             -- suspension finished, update state
             or ((bd.state = 2 or bd.state = 4)
                 and 
                 (bd.time_suspend_until is null or bd.time_suspend_until <= :now))
             -- update user suspension
             or (bd.state <= 2 
                 and nvl(trunc(bd.time_suspend_until),-1) != nvl(trunc(s.time_suspend_until),-1))
             -- suspension in effect, update state
             or (bd.state < 2
                 and bd.time_suspend_until is not null
                 and bd.time_suspend_until > :now)
	  }, ':now' => $now);

    my %uargs;
    while (my $block = $q_blockdest->fetchrow_hashref()) {
      my $bd_identifier = "$block->{BLOCK_NAME} at $block->{DESTINATION_NAME}";
      
      # Update parameters for block destination
      my $bd_update = { 
	  BD_STATE => $block->{BD_STATE},
	  BD_PRIORITY => $block->{BD_PRIORITY},
	  BD_SUSPEND => $block->{BD_SUSPEND},
	  BD_COMPLETE => $block->{BD_COMPLETE}
      };

      # Mark done the block destinations which are of closed blocks and have all files fully replicated.
      if ($block->{IS_OPEN} eq 'n' &&
	  $block->{NODE_FILES} >= $block->{EXIST_FILES} &&
	  $block->{BD_STATE} != 3) {
	  $self->Logmsg("block destination done for $bd_identifier");
	  $bd_update->{BD_STATE} = 3;
	  $bd_update->{BD_COMPLETE} = $now;
	  $stats{'blockdest done'}++;
      }

      # Reactivate block destinations which do not have all files replicated (deleted data)
      if ($block->{NODE_FILES} < $block->{EXIST_FILES} &&
	  $block->{BD_STATE} == 3) {
	  $self->Logmsg("reactivating incomplete block destination $bd_identifier");
	  $bd_update->{BD_STATE} = 0;
	  $bd_update->{BD_COMPLETE} = undef;
	  $stats{'blockdest reactivated'}++;
      }

      # Update priority
      if ($block->{BD_PRIORITY} != $block->{SUBS_PRIORITY}) {
	  $self->Logmsg("updating priority of $bd_identifier");
	  $bd_update->{BD_PRIORITY} = $block->{SUBS_PRIORITY};
	  $stats{'blockdest priority changed'}++;
      }

      { no warnings qw(uninitialized);  # lots of undef variables expected here
	# Update suspended status on existing requests
	# Only update user-set suspensions (state 2)
	# when the block is not suspended by the router (state 4)
	if (($bd_update->{BD_STATE} == 2 || $bd_update->{BD_STATE} == 4) && 
	    (!defined $bd_update->{BD_SUSPEND} || $bd_update->{BD_SUSPEND} <= $now)) {
	    $self->Logmsg("unsuspending block destination $bd_identifier");
	    $bd_update->{BD_STATE} = 0;
	    $bd_update->{BD_SUSPEND} = undef;
	    $stats{'blockdest unsuspended'}++;
	}

	if ($bd_update->{BD_STATE} <= 2 &&
	    (POSIX::floor($bd_update->{BD_SUSPEND}) || 0) != (POSIX::floor($block->{SUBS_SUSPEND}) || 0)) {
	    $self->Logmsg("updating suspension status of $bd_identifier");
	    $bd_update->{BD_SUSPEND} = $block->{SUBS_SUSPEND};
	}
	      
	if ($bd_update->{BD_STATE} < 2 &&
	    defined $bd_update->{BD_SUSPEND} && 
	    $bd_update->{BD_SUSPEND} > $now) {
	    $self->Logmsg("suspending block destination $bd_identifier");
	    $bd_update->{BD_STATE} = 2;
	    $stats{'blockdest suspended'}++;
	}
    }

      if (&hash_ne($bd_update, $block)) {
	  my $n = 1;
	  push(@{$uargs{$n++}}, $bd_update->{BD_STATE});
	  push(@{$uargs{$n++}}, $bd_update->{BD_PRIORITY});
	  push(@{$uargs{$n++}}, $bd_update->{BD_SUSPEND});
	  push(@{$uargs{$n++}}, $bd_update->{BD_COMPLETE});
	  push(@{$uargs{$n++}}, $block->{BLOCK});
	  push(@{$uargs{$n++}}, $block->{DESTINATION});
      }
  }

    # Bulk update
    my @rv = &dbexec($self->{DBH}, qq{
	update t_dps_block_dest
	   set state = ?,
	       priority = ?,
	       time_suspend_until = ?,
               time_complete = ?
	 where block = ? and destination = ?
     }, %uargs) if %uargs;
    
    $stats{'blockdest updated'} = $rv[1] || 0;

    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
}

# Phase V: delete subscription parameters older than 3 days that are no longer referenced by any subscription
sub deleteSubscriptionParams
{
    my ($self, $now) = @_;
    my %stats;
    my @stats_order = ('subs params deleted');
    $stats{$_} = 0 foreach @stats_order; 
    
    my @rv = $self->execute_sql( qq{
	delete from t_dps_subs_param
	    where id not in (select param from t_dps_subs_dataset)
              and id not in (select param from t_dps_subs_block)
	      and time_create+3*86400 < :now
	  }, ':now' => $now);
    $stats{'subs params deleted'}=$rv[1] || 0;
    
    # Return statistics 
    return map { [$_, $stats{$_}] } @stats_order;
}

# returns 1 if the contents of the second hash do not match the
# contents of the first
# TODO:  put in some general library?
sub hash_ne
{
    no warnings;
    my ($h1, $h2) = @_;
    foreach (keys %$h1) {
	return 1 if exists $h1->{$_} != exists $h2->{$_};
	return 1 if defined $h1->{$_} != defined $h2->{$_};
	return 1 if $h1->{$_} ne $h2->{$_};
    }
    return 0;
}

sub printStats
{
    my ($self, $title, @stats) = @_;
    $self->Logmsg("$title:  ".join(', ', map { $_->[1] + 0 .' '.$_->[0] } @stats));
}


1;
