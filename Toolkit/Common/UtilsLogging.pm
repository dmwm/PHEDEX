# Produce an alert message
sub logmsg
{
    my $date = `date +"%Y-%m-%d %H:%M:%S"`;
    my $me = $0; $me =~ s|.*/||;
    chomp ($date);
    print STDERR "$date: $me[$$]: ", @_, "\n";
}

sub alert
{
    &logmsg ("alert: ", @_);
}

sub warn
{
    &logmsg ("warning: ", @_);
}

sub note
{
    &logmsg ("note: ", @_);
}

1;
