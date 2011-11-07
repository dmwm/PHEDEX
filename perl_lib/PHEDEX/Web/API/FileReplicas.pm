package PHEDEX::Web::API::FileReplicas;
use warnings;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;
use PHEDEX::Web::Core;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::FileReplicas - file replicas, the purpose of PhEDEx!

=head2 DESCRIPTION

Serves the file replicas known to PhEDEx.

=head2 Options

 block          block name, with '*' wildcards, can be multiple (*).  required when no lfn is specified. Block names must follow the syntax /X/Y/Z#, i.e. have three /'s and a '#'. Anything else is rejected.
 dataset        dataset name. Syntax: /X/Y/Z, all three /'s obligatory. Wildcads are allowed.
 node           node name, can be multiple (*)
 se             storage element name, can be multiple (*)
 update_since   unix timestamp, only return replicas updated since this
                time
 create_since   unix timestamp, only return replicas created since this
                time
 complete       y or n. if y, return only file replicas from complete block
                replicas.  if n only return file replicas from incomplete block
                replicas.  default is to return either.
 dist_complete  y or n.  if y, return only file replicas from blocks
                where all file replicas are available at some node. if
                n, return only file replicas from blocks which have
                file replicas not available at any node.  default is
                to return either.
 subscribed     y or n, filter for subscription. default is to return either.
 custodial      y or n. filter for custodial responsibility.  default is
                to return either.
 group          group name.  default is to return replicas for any group.
 lfn            logical file name

 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <block>
     <file>
       <replica/>
       <replica/>
       ...
     </file>
     ...
  </block>
   ...

Where <block> represents a block of files, <file> represents a file
and <replica> represents a copy of that file at some node.  <block>
and <file> will always be present if any file replicas match the given
options.  <file> elements with no <replica> children represent files
which are part of the block, but no file replicas match
the given options.  An empty response means no file replicas matched
the given options.

=head3 <block> attributes

 name     block name
 id       PhEDEx block id
 files    files in block
 bytes    bytes in block
 is_open  y or n, if block is open

=head3 <file> attributes

 name         logical file name
 id           PhEDEx file id
 bytes        bytes in the file
 checksum     checksum of the file
 origin_node  node name of the place of origin for this file
 time_create  time that this file was born in PhEDEx

=head3 <replica> attributes

 node         PhEDEx node name
 node_id      PhEDEx node id
 se           storage element name
 time_create  unix timestamp
 subscribed   y or n, if subscribed
 custodial    y or n, if custodial
 group        group the replica is allocated for, can be undefined

=cut

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK_NAME',
    files => 'BLOCK_FILES',
    bytes => 'BLOCK_BYTES',
    is_open => 'IS_OPEN',
    file => {
        _KEY => 'FILE_ID',
        id => 'FILE_ID',
        name => 'LOGICAL_NAME',
        bytes => 'FILESIZE',
        checksum => 'CHECKSUM',
        time_create => 'TIME_CREATE',
        original_node => 'ORIGINAL_NODE',
        replica => {
            _KEY => 'NODE_ID',
            node_id => 'NODE_ID',
            node => 'NODE_NAME',
            se => 'SE_NAME',
            time_create => 'REPLICA_CREATE',
            subscribed => 'SUBSCRIBED',
            custodial => 'IS_CUSTODIAL',
            group => 'USER_GROUP'
        }
    }
};

sub duration{ return 5 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }

my $sth;
our $limit = 1000;
my @keys = ('BLOCK_ID');

sub spool
{
    my ($core,%h) = @_;
    my %p;

    if (!$sth)
    {
      eval {
        %p = &validate_params(\%h,
                           uc_keys => 1,
			   allow => [qw(block node se update_since create_since
					complete dist_complete subscribed custodial group lfn)],
			   require_one_of => [ qw(block lfn dataset) ],
			   spec => {
			       block         => { using => 'block_*', multiple => 1 },
			       dataset       => { using => 'dataset' },
			       complete      => { using => 'yesno' },
			       dist_complete => { using => 'yesno' },
			       subscribed    => { using => 'yesno' },
			       custodial     => { using => 'yesno' },
                               create_since  => { using => 'time'  },
                               lfn           => { using => 'lfn', multiple => 1 },
                               node          => { using => 'node', multiple => 1 },
                               se            => { using => 'text'   },
                               group         => { using => 'text'   },
			   });
      };
      if ( $@ ) {
        die PHEDEX::Web::Util::http_error(400,$@);
      }
      $p{'__spool__'} = 1;
      $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getFileReplicas($core, %p), $limit, @keys);
    }

    my $r;
    $r = $sth->spool();
    if ($r)
    {
        return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        return $r;
    }
}
				
1;
