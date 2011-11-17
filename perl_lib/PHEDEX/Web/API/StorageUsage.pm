package PHEDEX::Web::API::StorageUsage;
use warnings;
use strict;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::StorageUsage - simple interface to query 

=head2 DESCRIPTION

GET data from storage usage db

=cut

sub methods_allowed { return ('GET'); }
sub duration { return 0; }
sub invoke { return storageusage(@_); }
sub storageusage 
{
  my ($core,%args) = @_;
  warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);
  my ($method,$conn,$db,$table,$data,@records,$cursor,%dir,$site);
  $site = $args{collName};
  delete($args{collName});

  $method = $core->{REQUEST_METHOD};
  $conn = MongoDB::Connection->new(host => 'localhost', port => 8230);
  $db = $conn->SiteSpace;
  $table = $db->$site();

  my %temp;
  if(!$args{time_since} && !$args{time_until}) {
    # return latest one
    $cursor = $table->find()->skip($table->find()->count()-1);
  }
  else {
    if (!$args{time_since}) {
      $temp{'$lt'} = $args{time_until} + 0.0;
    }
    elsif (!$args{time_until}) {
      $temp{'$gt'} = $args{time_since} + 0.0;
    }  
    else {
      $temp{'$gt'} = $args{time_since} + 0.0;
      $temp{'$lt'} = $args{time_until} + 0.0;
    }
    $dir{_id} = \%temp;
    warn "dumping converted arguments ",Data::Dumper->Dump([ \%dir ]);
    $cursor = $table->find(\%dir);
    #$cursor = $table->find({_id =>{'$gt' => 0,'$lt' => 11}});
  }
  while ($data = $cursor->next) {
    warn Data::Dumper->Dump([ $data ]);
    push @records,$data;
  }
  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { storageusage => \@records };
}

1;
