package UtilsDownloadGlobus; use strict; use warnings; use base 'UtilsDownloadCommand';

# Command back end defaulting to Globus tools.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Initialise myself
    my $self = $class->SUPER::new($master, @_);
    my $defcmd = [ qw(globus-url-copy -p 5 -tcp-bs 2097152) ];
    my %default= (COMMAND	=> $defcmd,		# Transfer command
	    	  PROTOCOLS	=> [ "gsiftp" ]);	# Accepted protocols

    $$self{$_} ||= $default{$_} for keys %default;
    bless $self, $class;
    return $self;
}

1;
