package PHEDEX::Core::Logging;

# This is a replacement of PHEDEX::Core::Logging, using Log4perl
# The original code is kept in the comment -- will be removed later

=head1 NAME

PHEDEX::Core::Logging - a drop-in replacement for Toolkit/UtilsLogging

Departing from its previous incarnation, this module has been
implemented using Log4perl. Its interface is backward compatible with
previous implementation.

Mapping to Log4perl logging levels:
Logmag() -> INFO
 Alert() -> ERROR
  Warn() -> WARN
Dbgmsg() -> DEBUG
 Fatal() -> FATAL
  Note() -> INFO

Default configuration file "phedex_logger.conf" is located at where
this module is found. It could be, but not necessarily have to be,
overridden by $ENV{PHEDEX_LOG4PERL_CONFIG}.

To change logging level, modify the LOG_LEVEL in the config file and
send SIG-HUP to the agent.

=cut

# Log4perl stuff
use Log::Log4perl qw(get_logger :levels);

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw( Hdr new Logmsg Notify Alert Warn Dbgmsg Fatal Note get_log_level set_log_level logger_stat); # logmsg alert dbgmsg fatal note
use POSIX;
use File::Basename;

# 'new' is declared as a dummy routine, just in case it ever gets called...
sub new {}

my $config_file;
BEGIN
{
  # As a demonstration, prepare to throw out UDP messages if required.
  if ( defined($ENV{PHEDEX_NOTIFICATION_PORT}) )
  {
    eval("use IO::Socket");
    if ( $@ ) { undef $ENV{PHEDEX_NOTIFICATION_PORT}; }
  };

  # initiailze PhEDEx logger
  if ( defined($ENV{PHEDEX_LOG4PERL_CONFIG}) )
  {
    $config_file = $ENV{PHEDEX_LOG4PERL_CONFIG};
    Log::Log4perl->init_and_watch($ENV{PHEDEX_LOG4PERL_CONFIG}, 'HUP');
  }
  else
  {
    # default log config is at same place where this package is
    foreach (@INC)
    {
      my $path = $_ . "/PHEDEX/Core/Logging.pm";
      if ( -e $path )
      {
        my $dir = dirname($path);
        $config_file = $dir."/phedex_logger.conf";
        last;
      }
    }

    Log::Log4perl->init_and_watch($config_file, 'HUP');
  };
}

# sub Logmsg
# {   
#   my $self = shift;
#   print PHEDEX::Core::Logging::Hdr($self),@_,"\n";
# }

# Logmsg(msg) -- log as INFO
sub Logmsg
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->info(PHEDEX::Core::Logging::Hdr($self),@_);
}

# Notify(msg) -- log through socket to remote -- not using Log4perl
sub Notify
{
  my $self = shift;
  my $port = $self->{NOTIFICATION_PORT} || $ENV{PHEDEX_NOTIFICATION_PORT};
  return unless defined $port;
  my $server = $self->{NOTIFICATION_HOST} || $ENV{PHEDEX_NOTIFICATION_HOST} || '127.0.0.1';

  my $message = join('',PHEDEX::Core::Logging::Hdr($self),@_);
  my $socket = IO::Socket::INET->new( Proto	=> 'udp',
				      PeerPort	=> $port,
				      PeerAddr	=> $server );
  $socket->send( $message );
}

# sub Alert
# {   
#   my $self = shift;
#   PHEDEX::Core::Logging::Logmsg ($self,"alert: ", @_);
#   PHEDEX::Core::Logging::Notify ($self,"alert: ", @_,"\n");
# }

# Alert(msg) -- log as ERROR
sub Alert
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->error(PHEDEX::Core::Logging::Hdr($self), "alert: ",@_);
}

# sub Warn
# {   
#   my $self = shift;
#   PHEDEX::Core::Logging::Logmsg ($self,"warning: ", @_);
#   PHEDEX::Core::Logging::Notify ($self,"warning: ", @_,"\n");
# }   

# Warn(msg) -- log as WARN
sub Warn
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->warn(PHEDEX::Core::Logging::Hdr($self), "warning: ", @_);
}

# sub Dbgmsg
# {
#   my $self = shift;
#   PHEDEX::Core::Logging::Logmsg ($self,"debug: ", @_);
# }

# Dbgmsg(msg) -- log as DEBUG
sub Dbgmsg
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->debug(PHEDEX::Core::Logging::Hdr($self), "debug: ", @_);
}

# sub Fatal
# {
#   my $self = shift;
#   PHEDEX::Core::Logging::Logmsg ($self,"fatal: ", @_);
#   PHEDEX::Core::Logging::Notify ($self,"fatal: ", @_,"\n");
#   exit(1);
# }

# fatal(msg) -- log as FATAL and exit
sub Fatal
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->fatal(PHEDEX::Core::Logging::Hdr($self), "fatal: ", @_);
  exit(1);
}

# sub Note
# {
#   my $self = shift;
#   print PHEDEX::Core::Logging::Hdr($self)," note: ", @_, "\n";
# }

# Note(msg) -- log as INFO
sub Note
{
  my $self = shift;
  my $logger = get_logger("PhEDEx");
  $logger->info(PHEDEX::Core::Logging::Hdr($self), "note: ", @_);
}

# Hdr() -- make up header
sub Hdr
{ 
  my $self = shift;
  my $me;
  if ( $self ) { $me  = $self->{ME} };
  if ( !$me ) { $me = $0; $me =~ s|.*/||; }
  # my $date = strftime ("%Y-%m-%d %H:%M:%S ", gmtime);
  my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
  return "$date: $me\[$$]: ";
}

# get_log_level -- get current logging level
sub get_log_level
{
  my $logger = get_logger("PhEDEx");

  if ( $logger->level == $DEBUG ) { return "DEBUG" }
  elsif ( $logger->level == $INFO ) { return "INFO" }
  elsif ( $logger->level == $WARN ) { return "WARN" }
  elsif ( $logger->level == $ERROR ) { return "ERROR" }
  elsif ( $logger->level == $FATAL ) { return "FATAL" }
  return "UNKNOWN";
}

# set_log_level -- set current logging level
sub set_log_level
{
  # only interested in level
  if ($#_ > 0)
  {
     # called as a method
     shift;
  }

  my $level = shift;
  my $logger = get_logger("PhEDEx");

  if ( $level eq "DEBUG" ) { $logger->level($DEBUG) }
  elsif ( $level eq "INFO" ) { $logger->level($INFO) }
  elsif ( $level eq "WARN" ) { $logger->level($WARN) }
  elsif ( $level eq "ERROR" ) { $logger->level($ERROR) }
  elsif ( $level eq "FATAL" ) { $logger->level($FATAL) }
}

# logger_stat -- dump internal information of the logger
sub logger_stat
{
	use Data::Dumper;
	my $logger = get_logger("PhEDEx");
	my $appender;
	print "Dumping internal state of the logger ...\n";
	print "config_file =", $config_file, "\n";
	print Dumper($logger);
	foreach $appender (@{$logger->{'appender_names'}})
	{
		print "Appender: ", $appender, "\n";
		print Dumper($Log::Log4perl::Logger::APPENDER_BY_NAME{$appender});
	}
}

1;
