package PHEDEX::Debug;

=head1 NAME

PHEDEX::Debug - utility package to make debugging easier

=head1 SYNOPSIS

Overrides warn and die handlers, making warnings fatal and giving better
stack information.

=head1 DESCRIPTION

This module overrides the __WARN__ and __DIE__ handlers, using the Carp
module to provide full stack information. It also makes warnings fatal,
which is useful for longer-running tests where you want to trap such things
but don't know when/if/where they will occur.

As a bonus, if you die with an array reference instead of just the usual
strings, you will get a full dump of the object you are dying from. I.e.
instead of using:

=over

die "$object, $@\n";

=back

you can use

=over

die( { Object => $object, Message => $@ } );

=back

=head1 DEBUGGER OPTIONS

This module will look for a file called 'perldbg' in the current directory,
and use it's contents to initialise the perl debugger command stack. So you
can set breakpoints or watchpoints, and do all the other things you can do
from the debugger command-line in that file. This is useful if you are stopping
and restarting the debugger on a regular basis.

=head1 USAGE

Use this package directly from the command line, with no changes to your code,
either with or without the debugger:

=over

perl -MPHEDEX::Debug $script $args

perl -MPHEDEX::Debug -d $script $args

=back

If you do not want warnings converted into die()'s, but simply handled with a
stack trace and for execution to continue, you can set
$PHEDEX::Debug::die_on_warn to zero, somewhere in your script. In fact, you can
set and reset that value as you want throughout execution, it is taken into
account at runtime.

If you want to trap warnings, instead of having them die or return, you can
set $PHEDEX::Debug::stop_on_warn to a non-zero value. This will then stop the
debugger in the warn() handler, from which you can 'r' back up the stack to
the place the warning was generated from, and continue program execution.

=cut

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
