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
our @EXPORT = qw ( process_args checkRequired error auth_nodes );

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

# Fetch the list of nodes this user is authenticated to act on.  This
# is based on the configuration file and the SecurityModule roles
# See PHEDEX::Web::Config for a description of the AUTHZ hash
sub auth_nodes
{
    my ($self, $authz, $ability, %args) = @_;

    return unless $authz;

    # Check that we know about the ability
    my @abilities;
    foreach my $a (keys %$authz) {
	if ($a eq '*' || (defined $ability && $a eq $ability)) {
	    push @abilities, @{$authz->{$a}};
	}
    }
    return unless @abilities; # quick exit if the ability is unknown
   
    # Check the roles and authorization for matches to the configuration
    my $roles = $self->{SECMOD}->getRoles();
    my $authn = $self->{SECMOD}->getAuthnState();
    my $global_scope = 0; # if true, then the user has global scope power for this ability
    my @auth_sites;       # a list of sites that the user has site scope power for this ability
    my @auth_nodes;       # a list of node regexps for which the user has node scope power for this ability
    foreach my $a (@abilities) {
	# Check authentication
	next unless  ( ($a->{AUTHN} eq '*' && ($authn eq 'cert' || $authn eq 'passwd') ) ||
		       ($a->{AUTHN} eq 'passwd' && ($authn eq 'cert' || $authn eq 'passwd') ) ||
		       ($a->{AUTHN} eq 'cert' && $authn eq 'cert') );
	
	my $anygroup = $a->{GROUP} eq '*' ? 1 : 0;
	if ($a->{SCOPE} eq '*' &&
	    exists $roles->{ $a->{ROLE} } &&
	    ($anygroup || grep $_ eq $a->{GROUP}, @{$roles->{ $a->{ROLE} }}) ) {
	    $global_scope = 1;
	} elsif ($a->{SCOPE} eq 'site' &&
		 exists $roles->{ $a->{ROLE} }) {
	    push @auth_sites, @{ $roles->{ $a->{ROLE} } };
	} elsif (exists $roles->{ $a->{ROLE} } &&
		 ($anygroup || grep $_ eq $a->{GROUP}, @{$roles->{ $a->{ROLE} }}) ) {
	    push @auth_nodes, qr/$a->{SCOPE}/;
	}
    }
    return unless $global_scope || @auth_sites || @auth_nodes; # quick exit if user has no auth

    # If the user doesn't have a global scope role but has a site
    # scope role, then build a list of nodes to check for based on the
    # site->node mapping in the SecurityModule
    if (!$global_scope && @auth_sites) {
	my %node_map = $$self{SECMOD}->getPhedexNodeToSiteMap();
	foreach my $node (keys %node_map) {
	    foreach my $site (@auth_sites) {
		push @auth_nodes, qr/^$node$/ if $node_map{$node} eq $site;
	    }
	}
    }

    # Get a list of nodes from the DB. 'X' nodes are obsolete nodes
    # hidden from all users
    my $sql = qq{select name, id from t_adm_node where name not like 'X%'};
    my $q = &PHEDEX::Core::DB::dbexec($$self{DBH}, $sql);
    
    my %nodes;
    while (my ($node, $node_id) = $q->fetchrow()) {
	# Filter by auth_nodes if there are any
	if ($global_scope || grep $node =~ $_, @auth_nodes) {
	    $nodes{$node} = $node_id;
	}
    }
    if (exists $args{with_ids} && $args{with_ids}) {
	return \%nodes;
    } else {
	return keys %nodes;
    }
}

=pod

=head1 NAME

PHEDEX::Web::Util::formatter -- format SQL output into a hierachical

=head1 DESCRIPTION

Turn SQL result in a flat hash into hierachical structure defined by
the mapping

=head2 Syntax

=head3 input: a flat hash

        INPUT ::= { ELEMENT_LIST }
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= identifier
        VALUE ::= string | number

=head3 mapping:

          MAP ::= { _KEY => KEY, ELEMENT_LIST }
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= identifier
        VALUE ::= string | number | MAP

=head3 output:

 OUTPUT ::= [ ELEMENT_LIST ]
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
 ELEMENT ::= HASH
 HASH ::= { HASH_ELEMENT_LIST }
 HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
 HASH_ELEMENT ::= KEY => VALUE
 KEY ::= identifier
 VALUE ::= string | number | OUTPUT

=cut

# build_hash -- according to the map, build a structure out of input
# 
#  input: a flat hash
# 
#         INPUT ::= { ELEMENT_LIST }
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
#       ELEMENT ::= KEY => VALUE
#           KEY ::= identifier
#         VALUE ::= string | number
# 
#  mapping:
# 
#           MAP ::= { _KEY => KEY, ELEMENT_LIST }
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
#       ELEMENT ::= KEY => VALUE
#           KEY ::= identifier
#         VALUE ::= string | number | MAP
# 
#  output:
# 
#  OUTPUT ::= [ ELEMENT_LIST ]
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
#  ELEMENT ::= HASH
#  HASH ::= { HASH_ELEMENT_LIST }
#  HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
#  HASH_ELEMENT ::= KEY => VALUE
#  KEY ::= identifier
#  VALUE ::= string | number | OUTPUT
# 
sub build_hash
{
    my ($map, $input, $output) = @_;
    my $k;

    # the $map must be a hash reference
    if (ref($map) eq "HASH")
    {
        # if there is an element witht the key
        my $key = $input->{$map->{_KEY}};

        if (exists $output->{$key})
        {
            foreach $k (keys %{$map})
            {
                if (ref($map->{$k}) eq "HASH")
                {
                    build_hash($map->{$k}, $input, $output->{$key}->{$k});
                }
            }
        }
        else
        {
            $output->{$key} = {};
            foreach $k (keys %{$map})
            {
                if ($k ne "_KEY")
                {
                    if (ref($map->{$k}) eq "HASH")
                    {
                        $output->{$key}->{$k} = {};
                        build_hash($map->{$k}, $input, $output->{$key}->{$k});
                    }
                    else
                    {
                        $output->{$key}->{$k} = $input->{$map->{$k}};
                    }
                }
            }

        }
    }
    else
    {
        # this is an error
        die "error parsing structure definition";
    }
}

# hash2list -- recurrsively turn hash into a list of its values
sub hash2list
{
    my $h = shift;
    my ($k, $v, $k1);
    my @r;

    while (($k, $v) = each (%$h))
    {
        foreach $k1 (keys %$v)
        {
            if (ref($v->{$k1}) eq "HASH")
            {
                $h->{$k}->{$k1} = hash2list($v->{$k1});
            }
        }
        push @r, $h->{$k};
    }
    return \@r;
}

# formatter -- turn list of flat hash into list of structed list of hash        
sub formatter
{
    my ($map, $input) = @_;
    my $out = {};
    foreach(@$input)
    {
        build_hash($map, $_, $out);
    }
    return hash2list($out);
}


1;
