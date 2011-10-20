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
  my ($method,$conn,$db,$table,$data,@records,$cursor);
  $method = $core->{REQUEST_METHOD};
  $conn = MongoDB::Connection->new(host => 'localhost', port => 8230);
  $db = $conn->phedex;
  $table = $db->table();

  if ( $method eq 'POST' ) {
    warn Data::Dumper->Dump([ \%args ]);
    $table->insert(\%args);
    push @records, \%args;
  } else {
    $cursor = $table->find;
    while ($data = $cursor->next) {
      warn Data::Dumper->Dump([ $data ]);
      push @records,$data;
    }
    warn Data::Dumper->Dump([ \@records ]);
  }

  return { mongo => \@records };
}

1;
