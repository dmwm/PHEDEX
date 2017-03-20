package PHEDEX::Web::API::RequestSetStateFake;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::RequestSetState -- set Request State

=head1 DESCRIPTION

A fake API doing nothing but returning user desired state value

=head2 Options

 optional inputs: <have not thought about>

  request          request id
  state            desired state

=head2 Output

  <request/>

=head3 <request> attributes

  id               request id
  state            current approval state

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;
use PHEDEX::Core::SQL;
use PHEDEX::Core::Timing;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return requestsetstate(@_); }

sub requestsetstate
{
    my ($core, %h) = @_;
    my %p;

    eval {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [qw(request state)],
                spec => {
                    request => { using => 'pos_int' },
                    state   => { using => 'text' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    return { request => {id => $p{REQUEST}, state => $p{STATE}}};
}

1;
