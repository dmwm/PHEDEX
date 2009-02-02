package PHEDEX::Web::API::LinkStat;
# use warning;
use strict;
use PHEDEX::Web::SQL;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return linkstat(@_); }

sub linkstat
{
    my ($core, %h) = @_;

    my $r = PHEDEX::Web::SQL::getLinkStat($core, %h);
    return { linkStat => $r };
}

1;
