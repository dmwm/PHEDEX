package PHEDEX::Namespace::gfal;

use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common';
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

our $default_protocol_version = '2';
our $default_proxy_margin     = 60;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my %h     = @_;
	my ( %params, %options );

	# Params and options are module-specific
	%params = (
		VERSION      => $default_protocol_version,
		PROXY_MARGIN => $default_proxy_margin,
	);
	%options = (
		'version=s'      => \$params{VERSION},
		'proxy_margin=i' => \$params{PROXY_MARGIN},
	);
	PHEDEX::Namespace::Common::getCommonOptions( \%options, \%params );

	GetOptions(%options);
	my $self = \%params;
	bless( $self, $class );
	$self->{PROXY_CHECK} = 0;
	map { $self->{$_} = $h{$_} } keys %h;

	# do not use 'direct' protocol to look up in tfc for gfal requests!
	my $protocol;
	if    ( $h{PROTOCOL} )            { $protocol = $h{PROTOCOL}; }
	elsif ( $self->{VERSION} !~ /2/ ) { $protocol = 'srm'; }
	else                              { $protocol = 'srmv2'; }

	$self->SUPER::_init(
		NAMESPACE => __PACKAGE__,
		CATALOGUE => $h{CATALOGUE},
		PROTOCOL  => $protocol
	);
	$self->{ENV} = '';

	$self->SUPER::_init_commands;
	$self->proxy_check if $self->{DEBUG};

	$self->Help if $params{HELP};
	return $self;
}

sub Help {
	my $self = shift;
	print "\n Usage for ", __PACKAGE__, "\n";
	print <<EOF;

 This module takes the standard options:
 --help, --debug, --(no)verbose

 as well as these:
 --nocache      to disable the caching mechanism
 --version      specifies the protocol version. Default='$default_protocol_version'
 --proxy_margin require a proxy to be valid for at least this long or die.
	        Default=$default_proxy_margin

 Commands known to this module:
EOF

	$self->SUPER::_help();
}

sub proxy_check {
	my $self = shift;
	my $t    = time;
	return if $self->{PROXY_CHECK} > $t;

	my $timeleft = 0;
	open VPI, "voms-proxy-info -timeleft 2>/dev/null |"
	  or die "voms-proxy-info: $!\n";
	while (<VPI>) {
		chomp;
		m%^\d+$% or next;
		$timeleft = $_;
	}
	close VPI;    # don't care about RC, rely on output value instead
	if ( $timeleft < $self->{PROXY_MARGIN} ) {
		die
"Insufficient time left on proxy ($timeleft < $self->{PROXY_MARGIN})\n";
	}
	$self->{PROXY_CHECK} = $t + $timeleft - $self->{PROXY_MARGIN};
	if ( $self->{DEBUG} ) {
		print "Proxy valid for another $timeleft seconds\n",
		  "Will bail out by ", scalar localtime $self->{PROXY_CHECK}, "\n";
	}
}

sub Command {
	my ( $self, $call, $file ) = @_;
	my ( $h, $r, @opts, $env, $cmd );
	return unless $h = $self->{COMMANDS}{$call};

	my $protocol;
	if ( $self->{COMMANDS}{$call}->can('Protocol') ) {
		# for GridFTP protocal run without xattr (not supported)
		$protocol = $self->{COMMANDS}{$call}->Protocol();
	}
	else {
		$protocol = $self->Protocol();
	}
	my $pfn = $self->{CATALOGUE}->lfn2pfn( $file, $protocol );
	if ( not defined $pfn ) {
		print "lfn2pfn failed for lfn $file with protocol $protocol\n"
		  if $self->{DEBUG};
		return;
	}

	if ( $file =~ 'gsiftp://' ) {
		# drop the xattr option as it is not supported for GridFTP protocol
		@opts = ( $h->{opts}[0], $pfn );
	}
	else {
		@opts = ( @{ $h->{opts} }, $pfn );
	}
	$env = $self->{ENV} || '';
	$cmd = "$env $h->{cmd} @opts";
	print "Prepare to execute $cmd\n" if $self->{DEBUG};
	open CMD, "$cmd |" or die "$cmd: $!\n";
	@{ $r->{STDOUT} } = <CMD>;
	close CMD or return;

	my $cksum_cmd = "$env gfal-sum $pfn adler32";
	print "Prepare to execute $cksum_cmd\n" if $self->{DEBUG};
	open CMD, "$cksum_cmd |" or die "$cksum_cmd: $!\n";

	@{ $r->{STDOUT_CKSUM} } = <CMD>;
	close CMD or return;

	if ( $self->{COMMANDS}{$call}->can('parse') ) {
		$r = $self->{COMMANDS}{$call}->parse( $self, $r, $file );
	}

	if ( $self->{COMMANDS}{$call}->can('parse_cksum') ) {
		$r = $self->{COMMANDS}{$call}->parse_cksum( $self, $r, $file );
	}

	return $r;
}

1;
