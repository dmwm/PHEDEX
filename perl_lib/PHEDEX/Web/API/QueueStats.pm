package PHEDEX::Web::API::QueueStats;
# use warning;
use strict;
use PHEDEX::Web::SQL;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return agent(@_); }

sub agent
{
    my ($core, %h) = @_;

    my $r = PHEDEX::Web::SQL::getQueueStats($core, %h);
    return { link => $r };
}

1;
