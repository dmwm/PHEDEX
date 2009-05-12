package PHEDEX::Web::API::LinkTasks;
use warnings;
use strict;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::LinkTasks - return the set of link tasks

=head1 DESCRPTION

Show current link tasks

=head2 Options

 No options

=head2 Output

 <linktasks>
   <status/>
   ........
 </linktasks>

=head3 <status> attributes

 src_node          name of the source node
 dest_node         name of the destination node
 priority          priority
 bytes             number of transfering bytes
 files             number of transfering files
 time_update       last update time
 state             link state

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
