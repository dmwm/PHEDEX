package PHEDEX::Namespace::pnfs;
use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common';
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my (%params,%options);

# Params and options are module-specific
  %params = (
                INPUT_FILE => undef,
            );
  %options = (
                'pnfs_dump_file=s'  => \$params{INPUT_FILE},
            );
  PHEDEX::Namespace::Common::getCommonOptions(\%options,\%params);

  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  if ( exists($self->{AGENT}) ) {
    if ( exists($self->{AGENT}->{INPUT_FILE}) ) { $self->{INPUT_FILE} = $self->{AGENT}->{INPUT_FILE}; }
    if ( exists($self->{AGENT}->{VERBOSE}) )    { $self->{VERBOSE}    = $self->{AGENT}->{VERBOSE}; }
    if ( exists($self->{AGENT}->{DEBUG}) )      { $self->{DEBUG}      = $self->{AGENT}->{DEBUG}; }
  }
  $self->SUPER::_init( NAMESPACE => __PACKAGE__,
		       CATALOGUE => $h{CATALOGUE},
		       PROTOCOL => $h{PROTOCOL} );
  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
  $self->Help if $params{HELP};
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
