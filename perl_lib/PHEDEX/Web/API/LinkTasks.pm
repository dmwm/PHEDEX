package PHEDEX::Web::API::LinkTasks;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::LinkTasks - return the set of link tasks

=cut

sub duration{ return 10 * 60; }
sub invoke { return linktasks(@_); }
sub linktasks
{
    my ($core,%h) = @_;
    
    my $r = PHEDEX::Web::SQL::getLinkTasks($core, %h);
    return { linkTasks => { status => $r } };
}

1;
