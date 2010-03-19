package PHEDEX::Web::Spooler;

# spooling facility

# spool($func, $limit, @keys) -- generic spooling function
#
# $func: reference to the data fetching function
#        it returns a hash reference or undef (end of data)
# $limit: limit for each batch
# @keys: names of the keys that identify the top level objects
#
# spool returns a reference to a list of results
# if the result is less than the limit, just returns whatever there are
# if the result is more than the limit, return that many plus a few
# more until the values of the keys change
# 


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

    my ($sth, $limit, @keys) = @_;
    if (! $limit)
    {
        $limit = 1000;
    }

    $self->{sth} = $sth;
    $self->{limit} = $limit;
    $self->{EndOfData} = 0;
    $self->{last} = undef;
    $self->{keys} = \@keys;

    bless $self, $class;
    return $self;
}

sub spool
{
    my $self = shift;
    # do nothing if it already reached the end of Data
    if ($self->{EndOfData})
    {
        return undef;
    }

    my @r = ();
    my $data;
    my $count = 0;

    # take care of $last
    if (defined $self->{last})
    {
        push @r, $self->{last};
        $count++;
    }

    $self->{last} = undef;

    while ($count < $self->{limit})
    {
        $data = $self->{sth}->fetchrow_hashref();
        $count++;
        if (defined $data)
        {
            push @r, $data;
        }
        else
        {
            $self->{EndOfData} = 1;
            return (\@r);
        }
    }

    # now it's over the limit
    $self->{last} = $data;
    while ($data = $self->{sth}->fetchrow_hashref())
    {
        if (same_keys($self->{last}, $data, @{$self->{keys}}))
        {
            push @r, $data;
            $self->{last} = $data;
        }
        else
        {
            # save it
           $self->{last} = $data;
           return (\@r);
        }
    }

    # exhausted all
    $self->{last} = undef;
    $self->{EndOfData} = 1;
    return(\@r); 
}

sub same_keys
{
    my ($item1, $item2, @keys) = @_;

    foreach (@keys)
    {
        if ($item1->{$_} ne $item2->{$_})
        {
            return 0;
        }
    }
    return 1;
}
	
1;
