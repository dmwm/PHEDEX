package PHEDEX::Core::SQLPLUS;
use strict;
use PHEDEX::Core::DB;
use POE qw( Wheel::Run Filter::Line );

require Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
# Deliberately export sqlplus to make one-line scripts easier. E.g:
# perl -MPHEDEX::Core::SQLPLUS -e 'sqlplus("/path/to/DBParam:Section","select sysdate from dual;",1);'
# or even...
# echo 'select sysdate from dual;' | perl -MPHEDEX::Core::SQLPLUS -e 'sqlplus("/path/to/DBParam:Section",undef,1);'
@EXPORT = qw / sqlplus /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = { @_ };
  bless $self, $class;

  POE::Session->create(
    object_states => [
      $self => {
        _start		 => '_start',
        got_child_stdout => 'got_child_stdout',
        got_child_stderr => 'got_child_stderr',
        got_child_close	 => 'got_child_close',
        got_sigchld	 => 'got_sigchld',
        get_stdin	 => 'get_stdin',
      },
    ],
  );

  return $self;
}

sub _start {
  my ($kernel, $heap, $session, $self) = @_[KERNEL, HEAP, SESSION, OBJECT];
  $self->{SESSION} = $session;

  PHEDEX::Core::DB::parseDatabaseInfo($self);
  my $connect = $self->{DBH_DBUSER} . '/' . $self->{DBH_DBPASS} . '@' . $self->{DBH_DBNAME};

  $heap->{child} = POE::Wheel::Run->new(
    Program => ['sqlplus','-L','-S',$connect],
    StdioFilter  => POE::Filter::Line->new(),    # Child speaks in lines.
    StderrFilter => POE::Filter::Line->new(),    # Child speaks in lines.
    StdoutEvent  => "got_child_stdout",          # Child wrote to STDOUT.
    StderrEvent  => "got_child_stderr",          # Child wrote to STDERR.
    CloseEvent   => "got_child_close",           # Child stopped writing.
  );
  $kernel->sig_child($heap->{child}->PID, "got_sigchld");
  $kernel->delay('get_stdin',0.01);
}

sub start {
  my $self = shift;

  if ( ! $self->{written} ) {
    die "Call 'write' before 'start' in ",__PACKAGE__," object\n";
  }
  POE::Kernel->post( $self->{SESSION}, 'get_stdin', "\nquit\n" );
  if ( !$self->{started}++ ) {
    POE::Kernel->run();
  }
};

sub write {
  my $self = shift;
  return unless @_;
  $self->{written}++;
  foreach ( @_ ) {
    POE::Kernel->post( $self->{SESSION}, 'get_stdin', $_ );
  }
  return;
};

sub get_stdin {
  my ($kernel, $heap, $text) = @_[KERNEL, HEAP, ARG0];
  return unless defined($text);
  if ( !defined $heap->{child} ) {
    if ( $text ) {
      print "Got '$text' after child exited\n";
    }
    return;
  }

  $heap->{child}->put($text);
  $kernel->delay('get_stdin',0.01);
}

sub got_child_stdout {
  my ($self,$stdout) = @_[OBJECT,ARG0];
  print "$stdout\n" if $self->{VERBOSE};
}

sub got_child_stderr {
  my $stderr = $_[ARG0];
  $stderr =~ tr[ -~][]cd;
  print "STDERR: $stderr\n";
}

sub got_child_close {
  my $heap = $_[HEAP];
  delete $heap->{child};
}

sub got_sigchld {
# print "SIGCHLD reaped.\n";
}

# Wrap it all up in one convenient package
sub run {
  my %h = @_;
  my $script = delete $h{SCRIPT};

  defined $h{DBCONFIG} or die "No DBCONFIG in PHEDEX::Core::SQLPLUS::run\n";
  defined $script      or die "No SCRIPT in PHEDEX::Core::SQLPLUS::run\n";

  my $sqlplus = PHEDEX::Core::SQLPLUS->new( %h );
  $sqlplus->write($script);
  $sqlplus->start();
}

# and an even more convenient form...
sub sqlplus {
  my %h;
  $h{DBCONFIG} = shift;
  $h{SCRIPT}   = shift;
  $h{VERBOSE}  = shift;
  if ( !$h{SCRIPT} ) {
    $h{SCRIPT} = <STDIN>;
  }
  PHEDEX::Core::SQLPLUS::run( %h );
}

1;
