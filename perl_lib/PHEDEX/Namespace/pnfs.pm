package PHEDEX::Namespace::pnfs;
use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common';
use PHEDEX::Core::Loader;
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my ($help,%params,%options);

# Params and options are module-specific
  %params = (
                VERBOSE  => 0,
                DEBUG    => 0,
                CACHE    => undef,
                NOCACHE  => 0,
                INPUT_FILE => '/build/ratnik/devel/phedex/tests/bla',
            );
  %options = (
                'help'          => \$help,
                'verbose!'      => \$params{VERBOSE},
                'debug+'        => \$params{DEBUG},
                'nocache'       => \$params{NOCACHE},
                'pnfs_dump_file=s'  => \$params{INPUT_FILE},
            );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ );
  map { $self->{$_} = $h{$_} } keys %h;

  $self->SUPER::_init_commands;
  $self->Help if $help;
  return $self;
}

sub Help
{
  my $self = shift;
  print "\n Usage for ",__PACKAGE__,"\n";
  print <<EOF;

 This module takes the standard options:
 --help, --debug, --(no)verbose

 as well as these:
 --nocache           to disable the caching mechanism
 --pnfs_dump_file    to be used in place of direct calls to the dcache system.

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
