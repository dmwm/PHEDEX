package PHEDEX::Web::Format::CJSON;

use warnings;
use strict;
use JSON::XS;
use Data::Dumper;
use PHEDEX::Web::Util;

our (%params);

%params = ( );

sub new
{
    my $proto = shift;
    my $file = shift;
    if (! defined $file)
    {
        $file = *STDOUT;
    }
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    $self->{FILE} = $file;
    $self->{POS} = 0;
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    bless $self, $class;
    return $self;
}

sub error
{
    my ($self, $message) = @_;
    $message ||= "no message";
    chomp $message;
    print { $self->{FILE} } encode_json({ error => $message });
};

# header() -- output just the header
sub header
{
    my ($self, $obj) = @_;
    PHEDEX::Web::Util::lc_keys($obj);
    my $s = encode_json($obj);
    print { $self->{FILE} } substr($s, 0, rindex($s, "}", rindex($s, "}")-1)),",";
}

# footer() -- output just the footer
sub footer
{
    my ($self, $obj, $call_time) = @_;
    print ']' if ($self->{POS} > 0);
    if (defined $call_time)
    {
        print ',' if ($self->{POS} > 0);
        print { $self->{FILE} } sprintf('"call_time":"%.5f"}}', $call_time);
    }
    else
    {
        print { $self->{FILE} } "}}";
    }
    $self->{POS} = 0;
}

# separator between spooling
sub separator
{
    my $self = shift;
    print { $self->{FILE} } ",";
    return 1;
}

sub output
{
    my ($self, $obj) = @_;
    return if ( ! defined $obj );
    PHEDEX::Web::Util::lc_keys($obj);
    my $s = encode_json($obj);
    my ($start, $end);
    if (! $self->{POS})
    {
        $start = index($s, "{") + 1;
        $self->{POS} = 1
    }
    else
    {
        $start = index($s, "[") + 1;
    }
    $end = rindex($s, "]");
    print { $self->{FILE} } substr($s, $start, $end - $start);
}

1;
