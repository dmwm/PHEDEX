package PHEDEX::Web::Format::PERL;

use warnings;
use strict;
use Data::Dumper;

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
    $self->{POS} = 0; # position of first '[', double as opening
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
    print { $self->{FILE} } Dumper({ error => $message });
};

# header() -- output just the header
sub header
{
    my ($self, $obj) = @_;
    my $s = Dumper($obj);
    my $end = rindex(substr($s, 0, rindex($s, "}\n")), "\n");
    print { $self->{FILE} } substr($s, 0, $end), ",\n";
}

# footer() -- output just the footer
sub footer
{
    my ($self, $obj, $call_time) = @_;
    my $s = Dumper($obj);
    my $start = rindex(substr($s, 0, rindex($s, "}\n")), "\n")+1;
    print { $self->{FILE} } "\n"." "x$self->{POS} . "]";
    # taking care of the call_time
    if (defined $call_time)
    {
        separator($self);
        my $s1 = Dumper({ phedex =>{ 'call_time' => sprintf('%.5f', $call_time)}});
        my $st1 = index($s1, "=> {")+5;
        my $st2 = rindex($s1, "'");
        print { $self->{FILE} } substr($s1, $st1, $st2 - $st1 + 1);
    }
    print { $self->{FILE} } "\n".substr($s, $start);
    $self->{POS} = 0;
}

# separator between spooling
sub separator
{
    my $self = shift;
    print { $self->{FILE} } ",\n";
    return 1;
}

sub output
{
    my ($self, $obj) = @_;
    my $s = Dumper({phedex => $obj}); # fake the indentation
    my ($start, $end);
    if (! $self->{POS})
    {
        $start = index($s, "=> {\n") + 5;
        my $p1 = index($s, "[");
        my $p2 = rindex(substr($s, 0, $p1), "\n");
        $self->{POS} = $p1 - $p2 - 1;
    }
    else
    {
        $start = index($s, "=> [\n") + 5;
    }
    $end = rindex(substr($s, 0, rindex($s, "]")), "\n");
    print { $self->{FILE} } substr($s, $start, $end - $start);
}

1;
