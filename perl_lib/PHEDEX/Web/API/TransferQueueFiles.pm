package PHEDEX::Web::API::TransferQueueFiles;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueFiles - files currently queued for transfer

=head1 DESCRIPTION

Serves files in the transfer queue, along with their state.

=head2 Options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority, block

  from             from node name, could be multiple
  to               to node name, could be multiple
  block            a block name, could be multiple
  dataset          dataset name, could be multiple
  priority         one of the following:
                     high, normal, low
  state            one of the following:
                     assigned, exported, transferring, done

=head2 Output

 <link>
   <transfer_queue>
     <block>
       <file/>
       ...
     </block>
     ....
   </transfer_queue>
   ....
 </link>

=head3 <link> elements

  from             name of the source node
  from_id          id of the source node
  from_se          se of the source node
  to               name of the destination node
  to_id            id of the to node
  to_se            se of the to node

=head3 <transfer_queue> elements

  priority         priority of this queue
  state            one of the following:
                     transferred, transfering, exported

=head3 <block> elements

  name             block name
  id               block id
  files            number of files in this block in this queue
  bytes            total bytes in this block in this queue
  time_assign      minimum assignment time for a file in the block
  time_expire      minimum expiration time for a file in the block
  time_state       minimum time a file achieved its current state

=head3 <file> elements

  name             files logical name
  id               file id
  checksum         checksums of the file
  bytes            file size
  is_custodial     is it custodial? 'y' or 'n'
  time_assign      time the transfer task was created
  time_expire      time the transfer task will expire
  time_state       time the task achieved its current state

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'FROM_ID+TO_ID',
    from => 'FROM_NAME',
    from_id => 'FROM_ID',
    from_se => 'FROM_SE',
    to => 'TO_NAME',
    to_id => 'TO_ID',
    to_se => 'TO_SE',
    transfer_queue => {
        _KEY => 'STATE+PRIORITY',
        state => 'STATE',
        priority => 'PRIORITY',
        block => {
            _KEY => 'BLOCK_ID',
            name => 'BLOCK_NAME',
            id => 'BLOCK_ID',
            file => {
                _KEY => 'FILEID',
                id => 'FILEID',
                name => 'LOGICAL_NAME',
                bytes => 'FILESIZE',
                checksum => 'CHECKSUM',
                is_custodial => 'IS_CUSTODIAL',
                time_assign => 'TIME_ASSIGN',
                time_expire => 'TIME_EXPIRE',
                time_state => 'TIME_STATE'
            }
        }
    }
};


sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { 
#    my ($core, %h) = @_;
#
#    # convert parameter key to upper case
#    foreach ( qw / from to state priority block dataset / )
#    {
#	$h{uc $_} = delete $h{$_} if $h{$_};
#    }
#    
#    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getTransferQueue($core, %h, LEVEL => 'FILE'));
#
#    # make up stats for blocks
#    foreach my $link (@$r)
#    {
#        foreach my $transfer_queue (@{$link->{transfer_queue}})
#        {
#            foreach my $block (@{$transfer_queue->{block}})
#            {
#                my $bytes = 0;
#                my $files = 0;
#                my $time_state;
#                my $time_assign;
#                my $time_expire;
#                foreach my $file (@{$block->{file}})
#                {
#                    $bytes += $file->{bytes};
#                    $files += 1;
#                    if ((! defined $time_state) or
#                        (int($time_state) > int($file->{time_state})))
#                    {
#                        $time_state = $file->{time_state};
#                    }
#
#                    if ((! defined $time_assign) or
#                        (int($time_assign) > int($file->{time_assign}))) 
#                    {
#                        $time_assign = $file->{time_assign};
#                    }
#
#                    if ((! defined $time_expire) or
#                        (int($time_expire) > int($file->{time_expire})))
#                    {
#                        $time_expire = $file->{time_expire};
#                    }
#                    $block->{files} = $files;
#                    $block->{bytes} = $bytes;
#                    $block->{time_state} = $time_state;
#                    $block->{time_assign} = $time_assign;
#                    $block->{time_expire} = $time_expire;
#                }
#            }
#        }
#    }
#
#    return { link => $r };
#}

my $sth;
our $limit = 1000;
my @keys = ('FROM_ID', 'TO_ID');
my %p;

sub spool{ 
    my ($core, %h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [ qw / from to state priority block dataset / ],
                    spec =>
                    {
                        from => { using => 'node', multiple => 1 },
                        to   => { using => 'node', multiple => 1 },
                        block => { using => 'block_*', multiple => 1 },
                        dataset => { using => 'dataset', multiple => 1 },
                        priority => { using => 'priority' },
                        state => { using => 'transfer_state' }
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getTransferQueue($core, %p, LEVEL => 'FILE'), $limit, @keys);
    }
    
    my $r2 = $sth->spool();
    if ($r2)
    {
        my $r = PHEDEX::Core::Util::flat2tree($map, $r2);

        # make up stats for blocks
        foreach my $link (@$r)
        {
            foreach my $transfer_queue (@{$link->{transfer_queue}})
            {
                foreach my $block (@{$transfer_queue->{block}})
                {
                    my $bytes = 0;
                    my $files = 0;
                    my $time_state;
                    my $time_assign;
                    my $time_expire;
                    foreach my $file (@{$block->{file}})
                    {
                        $bytes += $file->{bytes};
                        $files += 1;
                        if ((! defined $time_state) or
                            (int($time_state) > int($file->{time_state})))
                        {
                            $time_state = $file->{time_state};
                        }
    
                        if ((! defined $time_assign) or
                            (int($time_assign) > int($file->{time_assign}))) 
                        {
                            $time_assign = $file->{time_assign};
                        }
    
                        if ((! defined $time_expire) or
                            (int($time_expire) > int($file->{time_expire})))
                        {
                            $time_expire = $file->{time_expire};
                        }
                        $block->{files} = $files;
                        $block->{bytes} = $bytes;
                        $block->{time_state} = $time_state;
                        $block->{time_assign} = $time_assign;
                        $block->{time_expire} = $time_expire;
                    }
                }
            }
        }

        return { link => $r };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r2;
    }
}

1;
