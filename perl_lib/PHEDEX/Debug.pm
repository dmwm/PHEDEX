package PHEDEX::Debug;
#
# Utility package to make debugging easier. Overrides warn and die handlers,
# making warnings fatal for a start. Also adds a tweak to agent functionality
# to reduce sleep intervals.
#
use strict;
use warnings;

BEGIN
{
  if ( defined $^S ) # i.e. if not simply parsing code
  {
    use Carp qw / cluck confess /;
    use Data::Dumper;
  }

  $SIG{__DIE__} = sub 
  {
    return unless defined $^S && ! $^S; # i.e. executing...
    print "DIE Handler:\n";
    foreach my $x ( @_ ) { print Dumper($x) if ref($x); }
    confess(@_) if defined &confess ;
    die "Something wrong, but could not load Carp to give backtrace...
                 To see backtrace try starting Perl with -MCarp switch";
  };

  $SIG{__WARN__} = sub
  { 
    return unless defined $^S && ! $^S; # i.e. executing...
    print "WARN: -> Die...\n";
    confess(@_) if defined &confess;
#   cluck(@_) if defined &cluck;
    die "Something wrong, but could not load Carp to give backtrace...
                 To see backtrace try starting Perl with -MCarp switch";
  };
}

sub daemon
{
  my $self = shift;
  if ( defined($main::Interactive) && $main::Interactive )
  { 
    print "Stub the daemon() call\n";

#   Can't do this, because daemon is called from the base class, before
#   the rest of me is initialised. Hence the messing around...
#   $self->{WAITTIME} = 2;
    my $x = ref $self;
    no strict 'refs';
    ${$x . '::params'}{WAITTIME} = 2;

    return;
  }
  
  my $me = $0; $me =~ s|.*/||;
  $self->SUPER::daemon($me);
}

1;
