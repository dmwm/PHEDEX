package PHEDEX::Namespace::dpm;

=head1 NAME

PHEDEX::Namespace::dpm - implement namespace functions for DPM 

=head1 SYNOPSIS

The following commands are implemeted:

=over

=item size of a file

=item delete a file

=back

Not implemeted due to protocol limitation:

=over

=item bring online

=item check if a file is cached on disk

=item verify a file: check size, optionally checksum - N/A

=item check if a file is migrated to tape

=back

=cut

#use strict;
use warnings;
use Data::Dumper;

#Parent Class
use base PHEDEX::Namespace::direct; 


#NS functions implemented,
# how many we can run in parallel etc
#put own command like this. For unknow command
#the default number is used

my %commands = (
                stat=>{cmd=>"dpls",opts=>["-l"],tfcproto=>"direct",n=>10},
                delete=>{cmd=>"dprm",opts=>["-f"],tfcproto=>"direct",n=>9},
                default=>{tfcproto=>'direct',n=>8},
		);

sub new
{
    my $class  = shift;

    my $self = { };
    bless($self, $class);
    $self->_init(@_, COMMANDS=>\%commands); #values from the base class
    
    print Dumper($self);
    return $self;
}


1;
