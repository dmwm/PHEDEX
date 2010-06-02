package PHEDEX::Namespace::tmdb;
use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common'; # All interface packages must do this
use PHEDEX::Core::Loader;
use PHEDEX::Core::DB;
use PHEDEX::Core::SQL;
use PHEDEX::Core::Catalogue;
use Data::Dumper;
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my ($help,%params,%options);

  %params = (
		VERBOSE			=> 0,
		DEBUG			=> 0,
		DBCONFIG		=> undef,
		DBH			=> undef,
		NODE			=> undef,
		INCOMPLETE_BLOCKS	=> undef,
            );
  %options = (
		'help'			=> \$help,
		'verbose!'		=> \$params{VERBOSE},
		'debug+'		=> \$params{DEBUG},
		'dbconfig=s'		=> \$params{DBCONFIG},
		'dbh=s'			=> \$params{DBH},
#                'node=s'                => sub { push(@{$params{NODE}}, split(/,/, $_[1])) },
		'node=s@'		=> \$params{NODE},
		'incomplete_blocks'	=> \$params{INCOMPLETE_BLOCKS},
             );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ );
  $DB::single=1;

  connectToDatabase($self) if $self->{DBCONFIG};

# Parse the node argument
  my @n = split m|[,\s*]|, "@{$params{NODE}}";
  #my @n = @{$params{NODE}};
  foreach my $n ( @n )
  {
    $self->{DEBUG} && print "Getting buffers with names like '$n'\n";
    my $tmp = PHEDEX::Core::SQL::getBuffersFromWildCard($self,$n);
    map { $self->{Buffers}{ID}{$_} = $tmp->{$_};
	  $self->{Buffers}{Name}{$tmp->{$_}{NAME}} = $_ } keys %$tmp;
  }
  $self->{DEBUG} && exists($self->{Buffers}{ID}) && print "done getting buffers!\n";
  my @bufferIDs = sort keys %{$self->{Buffers}{ID}};
  @bufferIDs or die "No buffers found matching \"@{$params{NODE}}\", typo perhaps?\n";


  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
  $self->Help if $help;
  return $self;
}

sub Help
{
  my $self = shift;
  print "\n Usage for ",__PACKAGE__,"\n";
  print <<EOF;

 This module takes the standard options:
 --help, --(no)debug, --(no)verbose

 and also:
 --dbconfig          contact information for TMDB. Can be omitted if the application
                     provides a valid DBH instead (--dbh).
 --dbh               to set the DBH
 --node              (repeatable) wild-card node(s) to search.
 --incomplete_blocks to test for incomplete blocks

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
