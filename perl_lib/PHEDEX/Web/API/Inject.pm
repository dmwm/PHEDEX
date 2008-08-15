package PHEDEX::Web::API::Inject;
use warnings;
use strict;
use PHEDEX::Core::XML;
use PHEDEX::Core::Inject;
use PHEDEX::Web::Util;

=pod
=head1 NAME

PHEDEX::Web::API::Inject - Inject data into TMDB, returning the statistics
on how many files, blocks, and datasets were injected etc.

=head1 DESCRIPTION

=head2 inject

=cut

sub invoke { return inject(@_); }
sub inject
{
  my ($self,$core,%args) = @_;
  &checkRequired(\%args, 'node');

  my ($auth,$node,$nodeid,$result,$stats,$verbose,$strict);
  $core->{SECMOD}->reqAuthnCert();
  $auth = $core->getAuth();
  $node = $args{node};

  $nodeid = $auth->{NODES}->{$node} || 0;
  die("You are not authorised to inject data to node $node") unless $nodeid;
  $result = PHEDEX::Core::XML::parseData( XML => $args{data} );

  $verbose = defined $args{verbose} ? $args{verbose} : 0;
  $strict  = defined $args{strict}  ? $args{strict}  : 1;

  eval
  {
    $stats = PHEDEX::Core::Inject::injectData ($core, $result, $nodeid,
				    		VERBOSE => $verbose,
				    		STRICT  => $strict);
  };
  if ( $@ )
  {
    $core->DBH->rollback; # Processes seem to hang without this!
    die $@;
  }
  $core->DBH->commit() if $stats;

  return {
	   data   => $args{data},
	   node   => $args{node},
	   nodeid => $nodeid,
	   stats  => $stats
	 };
}

1;
