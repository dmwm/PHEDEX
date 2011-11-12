package PHEDEX::Web::API::Mongo;
use warnings;
use strict;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::Mongo - simple mongodb interface

=head2 DESCRIPTION

GET data, or PUT the posted object

=cut

sub methods_allowed { return ('GET','POST'); }
sub duration { return 0; }
sub invoke { return mongo(@_); }
sub mongo
{
  my ($core,%args) = @_;
  warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);
  my ($method,$conn,$db,$table,$data,@records,$cursor,@dirarray,%dir,%test,$site);
  $site = $args{collName};
  delete($args{collName});

  $method = $core->{REQUEST_METHOD};
  $conn = MongoDB::Connection->new(host => 'localhost', port => 8230);
  $db = $conn->SiteSpace;
  $table = $db->$site();

  if ( $method eq 'POST' ) {
    $dir{_id} = $args{_id} + 0.0;
    delete($args{_id});
    $dir{rootdir} = $args{rootdir};
    delete($args{rootdir});
    $dir{totalsize} = $args{totalsize} + 0.0;
    delete($args{totalsize});
    foreach  (keys %args) {
      my %temp;
      $temp{size} = $args{$_} + 0.0;
      $temp{name} = $_;
      push(@dirarray, \%temp);
    }
    $dir{dir} =\@dirarray;
    warn "dumping converted arguments ",Data::Dumper->Dump([ \%dir ]);
    $table->insert(\%dir);
    push @records, \%dir;
  } else {
    my %temp;
    $temp{'$gt'} = $args{time_since} + 0.0;
    $temp{'$lt'} = $args{time_until} + 0.0;
    $dir{_id} = \%temp;
    warn "dumping converted arguments ",Data::Dumper->Dump([ \%dir ]);
    $cursor = $table->find(\%dir);
    #$cursor = $table->find({_id =>{'$gt' => 0,'$lt' => 11}});
    while ($data = $cursor->next) {
      warn Data::Dumper->Dump([ $data ]);
      push @records,$data;
    }
  }
  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { mongo => \@records };
}

1;
