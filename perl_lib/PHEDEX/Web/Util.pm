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
use Params::Validate;

our @ISA = qw(Exporter);
our @EXPORT = qw ( process_args validate_args checkRequired error auth_nodes );

# process arguments used for common features
sub process_args
{
    my $h = shift;

    # get rid of empty keys
    foreach my $arg (keys %$h) {
	delete $h->{$arg} unless defined $h->{$arg} && $_->{$arg} ne '';
    }

    # multiply occuring option operators go to OPERATORS
    if (exists $h->{op}) {
	my %ops;
	my @ops = arrayref_expand($h->{op});
	delete $h->{op};

	foreach my $pair (@ops) {
	    my ($name, $value) = split /:/, $pair;
	    next unless defined $name && defined $value && $value =~ /^(and|or)$/;
	    $ops{uc $name} = $value;
	}
	
	$h->{OPERATORS} = \%ops;
    }
    
}

# Validates arguments using Param::Validate, along with a few
# convenience defaults and capability to use common validation
# patterns (defined in $COMMON_VALIDATION package global) the first
# argument should be a hashref to the argumnetns to validate, the
# remaining arguments are a hash of options, including:
#
# spec: a hashref for a Params::Validate spec to use for validation.
# The spec must use the 'name' => { } hashref form, or it will be
# overridden by defaults.  Any specification parameter which exists
# will override the defaults described below.
#
# allow: an arrayref for a list of args to allow.  Anything that
# is not in this list or with an explicit spec entry will trigger an
# error.
#
# require: an arrayref for a list of args to require.  By default
# anything that is allowed is optional.
#
# require_one_of: an arrayref for a list of args to require at least
# one of.
#
# Param::Validate spec defaults:
# By default, each parameter is an optional non-empty scalar.  Specifically:
#
#   type     => SCALAR
#   regexp   => qr/./   # (filter out empty strings)
#   optional => 1       # evertying is optional, unless reqired (above)
#   untaint  => 1       # untaint output
#
# Providing another value for these will override the default.  There
# is no default 'callback'.
#
# In addition, commonly used validations can be referenced by a simple
# name (or list of names) and the "using" key in the spec for that
# argument.  (See below for valid "using" keys)
#
# Here is an example call to validate_args:
#
#     my %p = &validate_args(\%h,
# 			   allow => [qw(block lfn time_update)],
# 			   require_one_of => qw(block lfn),
# 			   spec => {
# 			       block => { using => ['block', '!wildcards'] },
# 			       lfn   => { using => 'lfn' }
# 			   });
#
# In this example, 'block', 'lfn', and 'time_update' are allowed.  One
# of 'block' or 'lfn' is required, and 'block' and 'lfn' are using
# common validation routines.  Also, 'block' may not have
# wildcards. 'time_update' uses the default validation.  Passing
# 'foobar' or anything else will be rejected.
#
# This function returns the validated parameters as a normal hash, but
# with the keys turned to uppercase.  All parameters are untainted.
# If one of the args did not pass the validation, this function will
# die() with an appropriate error message.
sub validate_args
{
    my ($args, %h) = @_;

    # get a pre-defined spec, or create an empty one
    my $spec = delete $h{spec} || {};

    # get the list of allowed parameters
    my $allow = delete $h{allow} || [];
    
    # add all args defined in %$spec to @$allow
    my %allow_uniq = map { $_ => 1 } @$allow;
    foreach my $a (keys %$spec) {
	$allow_uniq{$a} = 1;
    }
    @$allow = keys %$allow_uniq;
    
    # get the list of required parameters
    my $require = delete $h{'require'} || [];

    # get the list of OR required parameters
    my $require_one_of = delete $h{require_one_of} || [];

    # do not change key case
    my $no_upper = delete $h{no_upper} || 0;

    # require_one is supported by Param::Validate, so we check that here:
    my $ok = 0;
    foreach my $req (@$require_one_of) {
	if (exists $args->{$req} && defined $args->{$req}) {
	    $ok = 1; last;
	}
    }
    die "invalid parameters: one of (",join(', ',@$require_one_of),") are required\n";

    # check that we have something to validate
    if (scalar @$allow == 0) {
	die "developer error: no parameter validation defined\n";
    }

    # now build the spec with some defaults.  a provided spec key has precedence
    foreach my $a (@$allow) {
	# check if there is an existing spec for this param
	my $s = exists $spec->{$a} && ref $spec->{$a} eq 'HASH' ? $spec->{$a} : {};
	
	# now we set the defaults
	$s->{type}     = SCALAR   unless defined $s->{type};        # default type is scalar
	$s->{regexp}   = qr/./    unless defined $s->{regexp};      # no empty string
	$s->{optional} = 1        unless defined $s->{optional} ||  # all params are optional
	                                 grep $a eq $_, @$require;  # ... unless otherwise specified
	$s->{untaint}  = 1        unless defined $s->{untaint};     # we untaint by default
	
	# check for a special key for using common validation functions
	if (exists $s->{using}) {
	    my $common = delete $s->{using};
	    foreach my $c (arrayref_expand($common) {
		my $val = $COMMON_VALIDATION{$c} ||
		    die "developer error: '$c' is not a known validation function\n";
		
		if (ref $val eq 'CODEREF') { 
		    $s->{callbacks}->{$c} = $val;
		} elsif (ref $val eq 'Regexp') {
		    # note: we could have used $s->{regexp}, but doing it
		    # this way allows us to easily use both a common
		    # validation and a more specific one
		    $s->{callbacks}->{$c} = 
			sub { if (substr($c,0,1) ne '!') { return $_[0] =~ $val ? 1 : 0 }    # positive match
			      else                       { return $_[0] !~ $val ? 1 : 0 } }; # negative match
		} else {
		    die "developer error: unknown type of validation for '$c'\n";
		}
	    }
	}
    }

    # build the arguments for the validation function
    my %val_args = (params => %args, spec   => $spec);
    # use die instead of confess, suppress any stack trace or line number
    $val_args{on_fail} = sub { die shift, "\n" });
    # uppercase keys
    $val_args{normalize_keys} = sub { return uc shift } unless $no_upper;

    # now validate the arguments
    my %good_args = &Params::Validate::validate_with( %val_args );

    return %good_args;
}

# Common validation for web applications.  A name pointing to either a
# *compiled* regexp of a function which returns true if $_[0] is valid
# TODO: import some regexps from Regexp::Common (e.g. integer) and
# make them available here.
our $COMMON_VALIDATION = (
    'dataset'      => qr|^(/[^/\#]+){3}$|,
    'block'        => qr|^(/[^/\#]+){3}\#[^/\#]+$|,
    'lfn'          => qr|^/|,
    '!wildcard'    => qr|\*|,
    'yesno'        => sub { $_[0] eq 'y' || $_[0] eq 'n' ? 1 : 0 }
);

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

1;
