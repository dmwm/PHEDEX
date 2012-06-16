package PHEDEX::Web::API::StorageInsert;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Core::Inject;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::StorageInsert - insert node storage info 

=head1 DESCRIPTION

insert node storage info into Oracle for later query

=head2 Options

 required inputs: node, timestamp, dirinfo 
 optional inputs: strict

  node             node name
  timestamp        the date for the storage info(unix time)
  strict           allow overwrite or not(0 or 1), the default is strict(1)
  dirinfo          the directory and its size, could be multiple, the format:
                   "/store/mc"=1000000000

=cut

sub methods_allowed { return ('POST'); }
sub duration { return 0; }
sub invoke { return storageinsert(@_); }
sub storageinsert 
{
  my ($core,%args) = @_;
  #warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);

  my ($timestamp,$method,@records,%test,$node,%word,%input);
  my ($strict, $find, $nospecify, $status);

  $method = $core->{REQUEST_METHOD};
  $strict  = defined $args{strict}  ? $args{strict}  : 1;

  $node = $args{node};

  $timestamp = $args{timestamp};
  foreach ( qw / totalsize totaldirs totalfiles node timestamp strict/ )
  {
       delete($args{$_});
  }

  $status = 0 ;
  foreach  (keys %args) {
    $input{time} = $timestamp;
    $input{node} = $node;
    $input{size} = $args{$_} + 0.0;
    $input{dir} = $_;
    $input{strict} = $strict;
    #warn "dumping converted arguments ",Data::Dumper->Dump([ \%input ]);
    $status = PHEDEX::Web::SQLSpace::insertSpace($core, %input);
    #$status = PHEDEX::Web::SQLSpace::insertDirectory($core, %input);
  }
  if ($status) {
    $word{inserted} = "Insert records successfully!........\n";
  }
  push @records, \%word;

 # warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { storageinsert => \@records };
}

1;
