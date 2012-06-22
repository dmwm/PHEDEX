package PHEDEX::Web::STH;

=pod

=head1 NAME

PHEDEX::Web::STH - DBI statement handle wrapper

=head1 DESCRIPTION

This is a wrapper for DBI::st, BDI statement handle object.
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

  $sth = PHEDEX::Web::STH->new($sth);

  The reset of the code should work the same

=cut

use warnings;
use strict;
use Carp;

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
        #my $tn = $self->{Database}->type_info($self->{TYPE}[$i])->{TYPE_NAME};
        # DBD::Oracle does not provide all type names, such as CLOB
        my $type = $self->{Database}->type_info($self->{TYPE}[$i]);
        if (defined $type)
        {
            if ($type->{TYPE_NAME} eq 'DECIMAL' || $type->{TYPE_NAME} eq 'DOUBLE PRECISION')
            {
                push @{$self->{numberField}}, $self->{NAME}[$i];
                push @{$self->{numberFieldID}}, $i;
            }
        }
    }
    bless $self, $proto;
    return $self;
}

# catch all
sub AUTOLOAD
{
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    return $self->{sth}->$attr(@_);
}

# FIXME! does not do slice yet

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

# fetchall_arrayref() -- $sth->fetchall_arrayref() with numification
sub fetchall_arrayref
{
    my ($self, $slice, $max_rows) = @_;
    my $r = $self->{sth}->fetchall_arrayref($slice, $max_rows) or return \[];
    my $mode = ref($slice) || 'ARRAY';
    if ($mode eq 'ARRAY')
    {
        foreach my $i (@{$r})
        {
            foreach (@{$self->{numberFieldID}})
            {
                # force it to be a number
                $i->[$_] = $i->[$_] + 0 if defined $i->[$_];
            }
        }
    }
    elsif ($mode eq 'HASH')
    {
        foreach my $i (@{$r})
        {
            foreach (@{$self->{numberField}})
            {
                if (defined $i->{$_})
                {
                    # force it to be a number
                    $i->{$_} = $i->{$_} + 0;
                }
            }
        }
    }
    else
    {
        Carp::croak("fetchall_arrayref($mode) invalid");
    }

    return $r;
}

1;
