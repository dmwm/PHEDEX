package PHEDEX::Web::STH;

=pod

=head1 NAME

PHEDEX::Web::STH - DBI statement handle wrapper

=head1 DESCRIPTION

This is a wrapper for BDI statement handle object.
DBD::Oracle returns all data in string format,
which causes problem for json conversion,
resulting in numbers being rendered as strings.

Though we may know the type of each field through statement handle and its
database handle, it would be costly if we have to do it for every row.
Saving the type information in statement handle is the way to go.
It is very hard (and messy, too) to accomplish this through inheritance
since DBD::Oracle instentiates from DBI explicitly and DBD::Oracle is
loaded by DBI.

PHEDEX::Web::STH is a simple solution.
It is instentiated with a statement handler object.
The statement handler object is kept inside.
The type information is determined and saved.

Two methods, fetchrow_arrayref() and fetchrow_hashref() are
implemented to emulate those in statement handler object,
and they numify the numbers..
If other methods are needed, they could be implemented in the same way.

=head2 Usage

  $sth = PHEDEX::Web::STH::new($sth);

  The reset of the code should work the same

=cut

use warnings;
use strict;

sub new
{
    my $proto = shift;
    my $sth = shift or return;
    my $self = {
        sth => $sth,
        NUM_OF_FIELDS => $sth->{NUM_OF_FIELDS},
        TYPE => $sth->{TYPE},         # types of the fields
        NAME => $sth->{NAME},         # name of the fields
        Database => $sth->{Database}, # for type names
        numberField => [],            # remember the number field names
        numberFieldID => []           # remember the number field position
    };

    for (my $i = 0; $i < $self->{NUM_OF_FIELDS}; $i++)
    {
        my $tn = $self->{Database}->type_info($self->{TYPE}[$i])->{TYPE_NAME};
        if ($tn eq 'DECIMAL' || $tn eq 'DOUBLE PRECISION')
        {
            push @{$self->{numberField}}, $self->{NAME}[$i];
            push @{$self->{numberFieldID}}, $i;
        }
    }
    bless $self, $proto;
    return $self;
}

# fetchrow_hashref() -- $sth->fetchrow_hashref() with numification
sub fetchrow_hashref
{
    my $self = shift;
    my $r = $self->{sth}->fetchrow_hashref(@_) or return;
    foreach (@{$self->{numberField}})
    {
        if (defined $r->{$_})
        {
            # force it to be a number
            $r->{$_} = $r->{$_} + 0;
        }
    }
   return $r;
}

# fetchrow_arrayref() -- $sth->fetchrow_arrayref() with numification
sub fetchrow_arrayref
{
    my $self = shift;
    my $r = $self->{sth}->fetchrow_arrayref(@_) or return;
    foreach (@{$self->{numberFieldID}})
    {
        # force it to be a number
        $r->[$_] = $r->[$_] + 0;
    }
    return $r;
}

# execute() -- just call $sth->execute()
sub execute
{
    my $self = shift;
    return $self->{sth}->execute(@_);
}

1;
