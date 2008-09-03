package PHEDEX::Web::Util;

=pod
=head1 NAME

PHEDEX::Web::Util - utility functions for the PHEDEX::Web::API::* and
PHEDEX::Web::Core modules

=cut

use warnings;
use strict;

use PHEDEX::Core::DB;
use PHEDEX::Core::Util qw( arrayref_expand );
use PHEDEX::Web::Format;
use HTML::Entities; # for encoding XML

our @ISA = qw(Exporter);
our @EXPORT = qw ( process_args checkRequired error fetch_nodes );

# process arguments used for common features
sub process_args
{
    my $h = shift;

    # multiply occuring option operators go to OPERATORS
    if (exists $h->{op}) {
	my %ops;
	my @ops = arrayref_expand($h->{op});
	delete $h->{op};

	foreach my $pair (@ops) {
	    my ($name, $value) = split /:/, $pair;
	    next unless defined $name && defined $value && $value =~ /^(and|or)$/;
	    $ops{$name} = $value;
	}
	
	$h->{OPERATORS} = \%ops;
    }
    
}

sub error
{
    my $self = shift;
    my $msg = shift || "no message";
    chomp $msg;
    print "<error>\n", encode_entities($msg),"\n</error>";
}

# just dies if the required args are not provided or if they are unbounded
sub checkRequired
{
    my ($provided, @required) = @_;
    foreach my $arg (@required) {
	if (!exists $provided->{$arg} ||
	    !defined $provided->{$arg} ||
	    $provided->{$arg} eq '' ||
	    $provided->{$arg} =~ /^\*+$/
	    ) {
	    die "The arguments ", 
	    join(', ', map { "'$_'" } @required) ,
	    " are required\n";
	}
    }
}

# Fetch the list of nodes this user is authenticated to act on
# TODO: Get authorized actions from a configuration file instead of
#   hard-coded here.  It is expected that new roles will be created with
#   different prviileges, and we will need to quickly adapt to that
sub fetch_nodes
{
    my ($self, %args) = @_;

    my @auth_nodes;
    if (exists $args{web_user_auth} && $args{web_user_auth}) {
	my $roles = $self->{SECMOD}->getRoles();
	my @to_check = split /\|\|/, $args{web_user_auth};
	my $roles_ok = 0;
	foreach my $role (@to_check) {
	    if (grep $role eq $_, keys %{$roles}) {
		$roles_ok = 1;
	    }
	}

	my $global_admin = (exists $$roles{'Global Admin'} &&
			    grep $_ eq 'phedex', @{$$roles{'Global Admin'}}) || 0;

	# Special "global admin" role only if explicitly specified
	$global_admin = 1 if (grep($_ eq 'PADA Admin', @to_check) &&
			      exists $$roles{'PADA Admin'} &&
			      grep($_ eq 'phedex', @{$$roles{'PADA Admin'}}));

	return unless ($roles && ($roles_ok || $global_admin));
	
	# If the user is not a global admin, make a list of sites and
	# nodes they are authorized for.  If they are a global admin
	# we continue below where all nodes will be returned.
	if (!$global_admin) {
	    my %node_map = $$self{SECMOD}->getPhedexNodeToSiteMap();
	    my %auth_sites;
	    foreach my $role (@to_check) {
		if (exists $$roles{$role}) {
		    foreach my $site (@{$$roles{$role}}) {
			$auth_sites{$site} = 1;
		    }
		}
	    }
	    foreach my $node (keys %node_map) {
		foreach my $site (keys %auth_sites) {
		    push @auth_nodes, $node if $node_map{$node} eq $site;
		}
	    }
	}
    }

    my $sql = qq{select name, id from t_adm_node where name not like 'X%'};
    my $q = &PHEDEX::Core::DB::dbexec($$self{DBH}, $sql);
    
    my %nodes;
    while (my ($node, $node_id) = $q->fetchrow()) {
	# Filter by auth_nodes if there are any
	if (!@auth_nodes || grep $node eq $_, @auth_nodes) {
	    $nodes{$node} = $node_id;
	}
    }
    if (exists $args{with_ids} && $args{with_ids}) {
	return \%nodes;
    } else {
	return keys %nodes;
    }
}

1;
