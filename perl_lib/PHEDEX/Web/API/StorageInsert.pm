package PHEDEX::Web::API::StorageInsert;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use Data::Dumper;
use PHEDEX::Web::Util;

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

=head2 Output

If successful:
  Insert records successfully!
If failed with overwrite and strict=1:
  The record already exists

=cut

sub methods_allowed { return ('POST'); }
sub duration { return 0; }
sub invoke { return storageinsert(@_); }
sub storageinsert 
{
  my ($core,%args) = @_;
  #warn "dumping arguments ",Data::Dumper->Dump([ \%args ]);

  my ($timestamp,$method,@records,%test,$node,%word,%input);
  my ($strict, $find, $nospecify, $status, %h, $k, $v);

  $method = $core->{REQUEST_METHOD};

  foreach ( qw / node timestamp strict/ )
  {
       $h{$_} = $args{$_};
       delete($args{$_});
  }

  my %args_former;
  eval {
        %args_former= &validate_params(\%h,
                allow => [ qw ( node timestamp strict ) ],
                required => [ qw ( node timestamp ) ],
                spec =>
                {
                    node => { using => 'node' },
                    timestamp => { using => 'pos_int' },
                    strict => { using => 'pos_int' },
                });
        };
  if ( $@ )
  {
        return PHEDEX::Web::Util::http_error(400, $@);
  }

  foreach ( keys %args_former ) {
     $args_former{lc($_)} = delete $args_former{$_};
  }

  $strict  = defined $args_former{strict}  ? $args_former{strict}  : 1;

  $node = $args_former{node};

  $timestamp = $args_former{timestamp};

  while ( ($k,$v) = each %args ) {
    #warn "dumping k ",Data::Dumper->Dump([ $k ]);
    $k =~ m%^/[A-Za-z0-9_.\-/]*$% || return PHEDEX::Web::Util::http_error(400,'directory name not allowed');
    $v =~ m%^\d+$%              || return PHEDEX::Web::Util::http_error(400,'directory size not numerical');
  } 

  $status = 0 ;
  foreach  (keys %args) {
    $input{time} = $timestamp;
    $input{node} = $node;
    $input{size} = $args{$_} + 0.0;
    $input{dir} = $_;
    $input{strict} = $strict;
    #warn "dumping converted arguments ",Data::Dumper->Dump([ \%input ]);
    eval {
      $status = PHEDEX::Web::SQLSpace::insertSpace($core, %input);
    };
    if ( $@ ) {
      die PHEDEX::Web::Util::http_error(400,$@);
    }
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
