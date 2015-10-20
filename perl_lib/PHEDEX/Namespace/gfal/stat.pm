package PHEDEX::Namespace::gfal::stat;

# Implements the 'stat' function for gfal access
use strict;
use warnings;
use base 'PHEDEX::Namespace::gfal::Common';
use Time::Local;

# @fields defines the actual set of attributes to be returned
our @fields =
  qw / access uid gid size mtime checksum_type checksum_value lifetime_left locality space_token retention_policy_info type /;

sub new {
	my ( $proto, $h ) = @_;
	my $class = ref($proto) || $proto;

	# This shows the use of an external command to stat the file. It would be
	# possible to do this with Perl inbuilt 'stat' function, of course, but this
	# is just an example.
	my $self = {
		cmd  => 'gfal-ls',
		opts => [ '-l'],#'--xattr user.status' ],
	};
	bless( $self, $class );
	$self->{ENV} = $h->{ENV} || '';
	map { $self->{MAP}{$_}++ } @fields;
	return $self;
}

sub execute { (shift)->SUPER::execute( @_, 'stat' ); }

sub parse {

	# Parse the stat output. Each file is cached as it is seen. Returns the last
	# file cached, which is only useful in NOCACHE mode!
	my ( $self, $ns, $r, $dir ) = @_;
	# gfal-sum returns only one line
	my $c = $r->{STDOUT}[0];
	# remove \n
	chomp($c);

	# return value is of the form
	# -rw-r--r-- 1   <uid>    <gid>    <month> <day> <time or year> <size> <PFN>	ONLINE
	my @values = split( ' ', $c );
	$r->{access} = $values[0];
	$r->{access} =~ s/-//;
	$r->{uid} = $values[2];
	$r->{gid} = $values[3];
	my $month      = $values[4];
	my $day        = $values[5];
	my $timeOrYear = $values[6];
	$r->{size} = $values[7];
	my $url = $values[8];
	my ( @t, %month2num, $M, $d, $y, $h, $m, $s );
	%month2num = qw( Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6
	  Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12 );
	$M = $month2num{"$month"};
	$d = $day;

	if ( $timeOrYear =~ ':' ) {
		my @time = split( ':', $timeOrYear );
		$h    = $time[0];
		$m    = $time[1];
		$s    = 0;
		@time = localtime();
		$y    = $time[5] + 1900;
	}
	else {
		$h = 0;
		$m = 0;
		$s = 0;
		$y = $timeOrYear;
	}
	@t = ( $s, $m, $h, $d, $M, $y );
	$r->{mtime} = timelocal(@t);

	if ( @values > 9 ) {
		$r->{locality} = $values[9];
	}

	$r->{lifetime_left} = '-1';
	$r->{space_token}   = '';
	$r->{type}          = 'FILE';

	return $r;
}

sub parse_cksum {
	my ( $self, $ns, $r, $dir ) = @_;

	# gfal-sum returns only one line
	my $c = $r->{STDOUT_CKSUM}[0];

	# remove \n
	chomp($c);

	# return value is of the form "<file> <cksum>"
	$r->{checksum_value} = ( split( ' ', $c ) )[1];
	$r->{checksum_type} = 'adler32';

	return $r;
}

sub Help {
	print 'Return (', join( ',', @fields ), ")\n";
}

1;
