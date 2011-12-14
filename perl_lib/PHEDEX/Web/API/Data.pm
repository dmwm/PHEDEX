package PHEDEX::Web::API::Data;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Data - show data which is registered (injected) to PhEDEx

=head1 DESCRIPTION

Show data which is registered (injected) to PhEDEx

=head2 Options

  dataset                  dataset name to output data for (wildcard support)
  block                    block name to output data for (wildcard support)
  file                     file name to output data for (wildcard support)
  level                    display level, 'file' or 'block'. when level=block
                           no file details would be shown. Default is 'file'.
  create_since *           when level = 'block', return data of which blocks were created since this time;
                           when level = 'file', return data of which files were created since this time

  * when no parameters are given, default create_since is set to one day ago
 ** WARNING, even with just 24 hours ago, level=file may return huge among of results. Please be more specific.

=head2 Output

  <dbs>
    <dataset>
      <block>
        <file/>
      </block>
       ....
    </dataset>
    ....
  </dbs>
  ....

=head3 <dbs> elements

  name             dbs name
  time_create      creation time

=head3 <dataset> elements

  name             dataset name
  is_open          if the dataset is open
  is_transient     if the dataset is transient
  time_create      creation time
  time_update      update time

=head3 <block> elements

  name             block name
  files            number of files
  bytes            number of bytes
  is_open          if the block is open
  time_create      creation time
  time_update      update time

=head3 <file> attributes

  name             logical file name
  node             name of the node
  checksum         checksum
  size             filesize
  time_create      creation time

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

my $map = {
    _KEY => 'DBS',
    name => 'DBS',
    time_create => 'DBS_TIME_CREATE',
    dataset => {
        _KEY => 'DATASET',
        name => 'DATASET',
        is_open => 'DATASET_IS_OPEN',
        is_transient => 'DATASET_IS_TRANSIENT',
        time_create => 'DATASET_TIME_CREATE',
        time_update => 'DATASET_TIME_UPDATE',
        block => {
            _KEY => 'BLOCK',
            name => 'BLOCK',
            files => 'FILES',
            bytes => 'BYTES',
            is_open => 'BLOCK_IS_OPEN',
            time_create => 'BLOCK_TIME_CREATE',
            time_update => 'BLOCK_TIME_UPDATE',
            file => {
                _KEY => 'LOGICAL_NAME',
                lfn => 'LOGICAL_NAME',
                size => 'FILESIZE',
                checksum => 'CHECKSUM',
                time_create => 'FILE_TIME_CREATE',
                node => 'NODE'
            }
        }
    }
};

sub duration { return  5 * 60; }
sub invoke { return data(@_); }

sub data
{
    my ($core, %h) = @_;
    my %p;

    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw / create_since dataset block file level / ],
                spec =>
                {
                     create_sinc => { using => 'time' },
                     dataset => { using => 'dataset', multiple => 1 },
                     block => { using => 'block_*', multiple => 1},
                     file => { using => 'lfn', multiple => 1 },
                     level => { using => 'block_or_file' }
                }
        );
    };
    if ( $@ )
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    # default level = file
    $p{LEVEL} = 'file' if ! $p{LEVEL};

    # set create_since
    if (exists $p{CREATE_SINCE})
    {
        if ($p{LEVEL} eq 'block')
        {
            $p{BLOCK_CREATE_SINCE} = delete $p{CREATE_SINCE};
        }
        else
        {
            $p{FILE_CREATE_SINCE} = delete $p{CREATE_SINCE};
        }
    }
    elsif ((!$p{FILE}||($p{FILE} =~ m/(\*|%)/)) &&
           (!$p{DATASET}||($p{DATASET} =~ m/(\*|%)/)) &&
           (!$p{BLOCK}||($p{BLOCK} =~ m/(\*|%)/)))
    {
	if ($p{LEVEL} eq 'block')
	{
	    $p{BLOCK_CREATE_SINCE} = time() - 86400;
	}
	else
	{
            $p{FILE_CREATE_SINCE} = time() - 86400;
        }
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getData($core, %p));

    return { dbs => $r };
}

1;
