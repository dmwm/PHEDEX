package PHEDEX::Web::API::StorageInsert;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use PHEDEX::Core::Inject;
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::StorageInsert - simple storageInsert interface

=head2 DESCRIPTION

PUT the posted object

=cut

sub methods_allowed { return ('POST'); }
sub duration { return 0; }
sub invoke { return storageinsert(@_); }
sub storageinsert 
{
  my ($core,%args) = @_;
  warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);

  my ($timestamp,$method,@records,%test,$site,%word,%input);
  my ($strict, $find, $nospecify, $status);

  $method = $core->{REQUEST_METHOD};
  $strict  = defined $args{strict}  ? $args{strict}  : 1;

  $site = $args{sitename};

  $timestamp = $args{timestamp};
  foreach ( qw / totalsize totaldirs totalfiles sitename timestamp strict/ )
  {
       delete($args{$_});
  }

  $status = 0 ;
  foreach  (keys %args) {
    $input{time} = $timestamp;
    $input{site} = $site;
    $input{size} = $args{$_} + 0.0;
    $input{dir} = $_;
    $input{strict} = $strict;
    warn "dumping converted arguments ",Data::Dumper->Dump([ \%input ]);
    $status = PHEDEX::Web::SQLSpace::insertSpace($core, %input);
    #$status = PHEDEX::Web::SQLSpace::insertDirectory($core, %input);
  }
 
  $word{inserted} = "get insert status: $status........\n";
  push @records, \%word;

  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { storageinsert => \@records };
}

1;
