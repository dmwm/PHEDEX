package PHEDEX::Debug;
#
# Utility package to make debugging easier. Overrides warn and die handlers,
# making warnings fatal for a start. Also adds a tweak to agent functionality
# to reduce sleep intervals.
#
# If you die( { Object => $ref, Message => $@ } ); , you will get a full
# dump of the object you are dying from.
#
use strict;
use warnings;

our $die_on_warn = 1;
our $stop_on_warn = 0;

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
    die(@_) if $die_on_warn;

    print "WARN Handler:\n";
    die(@_) if ! defined(&cluck);

    cluck(@_);
    if ( $stop_on_warn )
    {
      $DB::single=1;
      print "Stopping in WARN handler...\n";
    }
  };

  my $pdb = 'perldbg';
  if ( -f $pdb ) { push @DB::typeahead, "source $pdb"; }
}

1;
