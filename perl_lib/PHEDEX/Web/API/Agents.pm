package PHEDEX::Web::API::Agents;
# use warning;
use strict;
use PHEDEX::Web::SQL;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return agent(@_); }

sub agent
{
    my ($core, %h) = @_;

    my $r = PHEDEX::Web::SQL::getAgents($core, %h);
    return { node => $r };
}

1;
