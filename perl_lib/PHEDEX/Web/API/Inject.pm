package PHEDEX::Web::API::Inject;
use warnings;
use strict;
use PHEDEX::Core::XML;
use PHEDEX::Core::Inject;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::Inject - let PhEDEx know data exists

=head1 DESCRIPTION

Inject data into TMDB, returning the statistics
on how many files, blocks, and datasets were injected etc.

=head2 options

 node		Required node-name as injection site.
 data		XML structure representing the data to be injected. See
		PHEDEX::Core::XML (an example follows)
 strict		throw an error if it can't insert the data exactly as
		requested. Otherwise simply return the statistics. The
		default is to be strict, you can turn it off with 'strict=0'.

=head2 Input

This API accepts POST'ed XML with the key name 'data' in the following
format:

  <data version="2.0">
    <dbs name="https://cmsweb.cern.ch/dbs/prod/global/DBSReader" dls="dbs">
      <dataset name="/sample/dataset" is-open="y">
        <block name="/sample/dataset#1" is-open="y">
          <file name="file1" bytes="10" checksum="cksum:1234,adler32:5678"/>
          <file name="file2" bytes="22" checksum="cksum:456"/>
        </block>
        <block name="/sample/dataset#2" is-open="y">
          <file name="file3" bytes="1" checksum="cksum:2"/>
        </block>
      </dataset>
      <dataset name="/sample/dataset2" is-open="n">
        <block name="/sample/dataset2#1" is-open="n"/>
        <block name="/sample/dataset2#2" is-open="n"/>
      </dataset>
    </dbs>
  </data>

The XML file may identify the each dataset and block many times.
The union of all files of each block are added to the database.
However in the end each file must belong to exactly one DBS,
dataset and block.

The C<< <data> >> element must have a C<version> attribute, which
specifies the version of the injection XML format.  The current
C<version> is 2.0.

The C<< <dbs> >> element must have an attribute C<name>, which is the
canonical name of the dataset bookkeeping system which owns the
files.  Usually this should be the contact address of the DBS.

The C<< <dataset> >> element must have an attribute C<name>, the name
of the dataset in the DBS, and the attribute C<is-open> which must
have value 'y' or 'n'.  The options are checked before processing and
new values are applied at the end of the processing, allowing datasets
and blocks to be closed by injecting them with these attributes set,
possibly not including any files in the injection.

A dataset must be open if any of its blocks are open.  Only open
datasets can have blocks added to them; similarly with blocks and
files.  Closed blocks and datasets cannot be made open with this
utility.

Each C<< <block> >> must have attribute C<name>, the canonical and
unique name of the block as known to the C<< <dbs> >>, and C<is-open>
boolean, either 'y' or 'n'.  If C<is-open> is 'n', the block will
be marked closed at the end of the processing; this still allows
one to add files to new and previously open blocks, then close
the blocks.  If the block is already closed in the database, new
files cannot be added to it; setting C<is-open> to 'y' won't help.
New blocks cannot be introduced to closed datasets.  If the
dataset is closed, all its blocks must be closed too.

Each C<< <file> >> must have attributes C<name>, the logical file name
which must be unique, C<bytes>, the size of the file in bytes, and
C<checksum>, a comma-separatied list of checksums for the file data
in colon-separated name-value pairs.  Currently 'cksum' (CRC) and
'adler32' checksums are supported.  See the example below for how
the C<checksum> attribute should be formated.

All elements may contain other attributes; they will be ignored.
Only white-space character data is allowed. Only information from
the attributes of the above elements are added.

=head2 Output

Returns an C<< <injected> >> element, with the following attributes:

 new_datasets		number of new datasets created
 new_blocks		number of new blocks created
 new_files		number of new files created
 closed_datasets	number of closed datasets injected
 closed_blocks		number of closed blocks injected

If 'strict=0' is specified, attempting to re-inject already-injected data will
not give an error, but all the stats values will be zero.

=cut

sub duration  { return 0; }
sub need_auth { return 1; }
sub methods_allowed { return 'POST'; }
sub invoke { return inject(@_); }
use URI::Escape;
sub inject
{
  my ($core,%args) = @_;
  my %p;
  eval
  {
      %p = &validate_params(\%args,
              allow => [ qw( node data strict ) ],
              required => [ qw( data node ) ],
              spec =>
              {
                  node => { using => 'node' },
                  data => { using => 'xml' },
                  strict => { regex => qr/^[01]$/ },
                  dummy => { using => 'text' }
              }
      );
  };
  if ($@)
  {
      return PHEDEX::Web::Util::http_error(400,$@);
  }

  $args{data} = uri_unescape($args{data});

  my ($auth,$node,$nodeid,$result,$stats,$strict);
  $core->{SECMOD}->reqAuthnCert();
  $auth = $core->getAuth('datasvc_inject');
  $node = $args{node};

  $nodeid = $auth->{NODES}->{$node} || 0;
  die PHEDEX::Web::Util::http_error(403,"You are not authorised to inject data to node $node") unless $nodeid;
  $result = PHEDEX::Core::XML::parseData( XML => $args{data} );

  $strict  = defined $args{strict}  ? $args{strict}  : 1;

  eval
  {
    $stats = PHEDEX::Core::Inject::injectData ($core, $result, $nodeid,
				    		STRICT  => $strict);
  };
  if ( $@ )
  {
    $core->{DBH}->rollback(); # Processes seem to hang without this!
    die PHEDEX::Web::Util::http_error(400,$@);
  }

  # determine if we commit
  my $commit = 0;
  if (%$stats) {
      $commit = 1;
  } else {
      die PHEDEX::Web::Util::http_error(400,"no injection was done");
      $core->{DBH}->rollback();
  }
  $commit = 0 if $args{dummy};
  $commit ? $core->{DBH}->commit() : $core->{DBH}->rollback();

  return { injected => { stats => $stats } };
}

1;
