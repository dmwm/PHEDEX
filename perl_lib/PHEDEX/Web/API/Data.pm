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
  file_create_since        returns files which were created since this time *
  block_create_since       return blocks which were created since this time
  dataset_create_since     returns datasets which were created since this time

 * when no parameters are given, default file_create_since or
   block_create_since is set to one day ago depending on the level

 ** WARNING, even with just 24 hours ago, level=file may return huge
   among of results. Please be more specific.

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

    if (!$h{dataset}&&!$h{block}&&!$h{file})
    {
	if (($h{level} eq 'block') && !$h{block_create_since})
	{
	    $h{block_create_since} = time() - 86400;
	}
	elsif (!$h{file_create_since})
	{
            $h{file_create_since} = time() - 86400;
        }
    }

    # check for time format
    foreach ( qw / file_create_since block_create_since dataset_create_since / )
    {
        if ($h{$_} && (not defined PHEDEX::Core::Timing::str2time($h{$_})))
        {
            die "Bad value for '$_'\n";
        }
    }

    # check for level
    if (exists $h{level} && $h{level} ne 'file' && $h{level} ne 'block')
    {
        die "level has to be either 'file' or 'block'\n";
    }

    # convert parameter keys to upper caseq
    foreach ( qw / dataset block file level file_create_since block_create_since dataset_create_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    if (not exists $h{LEVEL})
    {
        $h{LEVEL} = 'file';
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getData($core, %h));

    return { dbs => $r };
}

1;
