package PHEDEX::Web::API::StorageInsert;
use warnings;
use strict;
use PHEDEX::Web::SQLSpace;
use Data::Dumper;
use URI::Escape;
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
sub need_auth { return 1; }
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
  $h{strict} = 0 unless defined $h{strict};

  my %args_former;
  eval {
        %args_former= &validate_params(\%h,
                allow => [ qw ( node timestamp strict ) ],
                required => [ qw ( node timestamp ) ],
                spec =>
                {
                    node => { using => 'node' },
                    timestamp => { using => 'time' },
                    strict => { regex => qr/^[01]$/ },
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

  $timestamp = PHEDEX::Core::Timing::str2time($args_former{timestamp});

  while ( ($k,$v) = each %args ) {
    #warn "dumping k ",Data::Dumper->Dump([ $k ]);
    $k =~ m%^/.*$% || return PHEDEX::Web::Util::http_error(400,'directory full pathname should start with slash');
    $v =~ m%^\d+$%              || return PHEDEX::Web::Util::http_error(400,'directory size not numerical');
  } 

  die PHEDEX::Web::Util::http_error(401,"Certificate authentication failed") unless $core->{SECMOD}->isCertAuthenticated();

  my $isAuthorised = 0;
  if ( $core->{SECMOD}->hasRole('Developer','phedex') || $core->{SECMOD}->hasRole('Admin','phedex')) {
    $isAuthorised = 1;
  } else {
    # user has no developer or admin role, die if they are not a site-admin for $node
    my %auth_nodes = PHEDEX::Web::Util::fetch_nodes($core, web_user_auth => 'Site Admin', with_ids => 1); # get hash of nodes the user is a Site Admin for...
    die PHEDEX::Web::Util::http_error(400,"You are not authorised to approve data to node $node") unless $auth_nodes{$node}; # compare to the $node they are inserting data for...
    $isAuthorised = 1;
  }
  die PHEDEX::Web::Util::http_error(400,"You need to be a PhEDEx Admin, or a Site Admin for this site, to use this API") unless $isAuthorised;

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
