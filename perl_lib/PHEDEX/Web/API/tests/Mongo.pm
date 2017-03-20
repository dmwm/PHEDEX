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

PUT the posted object

=cut

sub methods_allowed { return ('POST'); }
sub duration { return 0; }
sub invoke { return mongo(@_); }
sub mongo
{
  my ($core,%args) = @_;
  warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);
  my ($method,$conn,$db,$table,$data,@records,$cursor,@dirarray,%dir,%test,$site,%word);
  my ($overwrite, $returnid, $nospecify);
  $overwrite = 1;
  $site = $args{collName};
  if ($args{overwrite}) {
     $overwrite = $args{overwrite};
  } 
  else {
     $nospecify = 1;
  }
  $word{connect} = "Begin to connect db........\n";
  $method = $core->{REQUEST_METHOD};
  $conn = MongoDB::Connection->new(host => 'localhost', port => 8230);
  $db = $conn->SiteSpace;
  $table = $db->$site();
  $word{connected} = "Successfully connect db........\n";

  $dir{_id} = $args{_id} + 0.0;
  $dir{rootdir} = $args{rootdir};
  $dir{totalsize} = $args{totalsize} + 0.0;
  $dir{totalfiles} = $args{totalfiles} + 0.0;
  $dir{totaldirs} = $args{totaldirs} + 0.0;
  foreach ( qw / _id rootdir totalsize totaldirs totalfiles collName overwrite/ )
  {
       delete($args{$_});
  }
  foreach  (keys %args) {
    my %temp;
    $temp{size} = $args{$_} + 0.0;
    $temp{name} = $_;
    push(@dirarray, \%temp);
  }
  $dir{dir} =\@dirarray;
  warn "dumping converted arguments ",Data::Dumper->Dump([ \%dir ]);
  $returnid = $table->insert(\%dir);

  if (($returnid == $dir{_id}) && !$overwrite) {
     die "You duplicate the entry with the same timestamp!\n"
  }
  elsif (($returnid == $dir{_id}) && $overwrite) {
     $table->save(\%dir);
     if ($nospecify) {
         $word{duplicate} = "Duplicate the same entry........\n";
     }
  }
  $word{inserted} = "Successfully insert an entry........\n";
  push @records, \%word;
  push @records, \%dir;

  warn "dumping records ",Data::Dumper->Dump([ \@records ]);
  return { mongo => \@records };
}

1;
