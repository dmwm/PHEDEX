package PHEDEX::Web::Util;

use warnings;
use strict;

use PHEDEX::Core::DB;
use PHEDEX::Core::Util qw( arrayref_expand);
use PHEDEX::Web::Format;
use PHEDEX::Core::Timing;

use HTML::Entities; # for encoding XML
use Params::Validate qw(:all);
use Carp;
use Clone;

our @ISA = qw(Exporter);
our @EXPORT = qw ( process_args validate_params checkRequired error auth_nodes );

# process arguments used for common features
sub process_args
{
    my $h = shift;

    # get rid of empty keys
    foreach my $arg (keys %$h) {
	delete $h->{$arg} unless defined $h->{$arg} && $h->{$arg} ne '';
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

# Common validation for web applications.  A name pointing to either a
# *compiled* regexp of a function which returns true if $_[0] is valid
# NOTE:  Do not add anything here without making a test case for it in
# PHEDEX/Testbed/Tests/Web-Util.t
our %COMMON_VALIDATION = 
(
 'dataset'      => qr|^(/[^/\#]+){3}$|,
 'block'        => qr|^(/[^/\#]+){3}\#[^/\#]+$|,
 'block_*'      => qr!(^(/[^/\#]+){3}\#[^/\#]+$)|\*!,
 'lfn'          => qr|^/|,
 'wildcard'     => qr|\*|,
 'node'         => qr|^T\d|,
 'yesno'        => sub { $_[0] eq 'y' || $_[0] eq 'n' ? 1 : 0 },
 'onoff'        => sub { $_[0] eq 'on' || $_[0] eq 'off' ? 1 : 0 },
 'boolean'      => sub { $_[0] eq 'true' || $_[0] eq 'false' ? 1 : 0 },
 'andor'        => sub { $_[0] eq 'and' || $_[0] eq 'or' ? 1 : 0 },
 'time'         => sub { PHEDEX::Core::Timing::str2time($_[0], 0) ? 1 : 0 },
 'regex'        => sub { eval { qr/$_[0]/; }; return $@ ? 0 : 1; }, # this might be slow...
 'pos_int'      => qr/^\d+$/,
 'pos_int_list' => sub { return 1 if ! $_[0]; # allow empty list and '0'
			 foreach (split(/\s*[, ]+/, $_[0])) {
			     return 0 unless /^\d+$/;
			 }
			 return 1; },

);

# Validates parameters using Param::Validate, along with a few
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
# allow: an arrayref for a list of params to allow.  Parameters
# specified in 'required', 'require_one_of', and 'spec' are
# automatically added to the list of allowed parameters.
#
# allow_empty: if true, empty string values ('') are allowed.  The
# default is not to allow empty strings.
#
# required: an arrayref for a list of args to require.  By default
# anything that is allowed is optional.
#
# require_one_of: an arrayref for a list of params to require at least
# one of.
#
# uc_keys: if true, validated params in the output will have uppercase keys
#
# full_trace: if true, failed validations will generate a full stack trace
#
# stack_skip: if true, failed validations will appear to come from
# this many call frames above the actual calling function.
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
# argument.
#
# Parameters which are allowed to have multiple values should set the
# multiple => 1 in their spec.  In this case SCALAR | ARRAYREF is the
# allowed type for the spec, and each value in an arrayref will be
# tested with the validation conditions.
#
# Here is an example call to validate_args:
#
#     my %p = &validate_args(\%h,
# 			   allow => [qw(block lfn time_update)],
# 			   require_one_of => qw(block lfn),
# 			   spec => {
# 			       block => { using => ['block', '!wildcards'] },
# 			       lfn   => { using => 'lfn', multiple => 1 }
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
#
# TODO: from Params::Validate: "Asking for untainting of a reference
# value will not do anything, as Params::Validate will only attempt to
# untaint the reference itself." => need to untaint "multiple" values
# ourselves.
sub validate_params
{
    # what to do when validation fails
    &validation_options(on_fail => sub { Carp::croak shift });

    # first we validate the use of this function!
    my ($params, %h) = @_;
    %h = %{ Clone::clone(\%h) }; # do not clobber the input spec

    &validate_with(params => [$params], spec => [{ type => HASHREF, optional => 0 }]);
    &validate_with(params => \%h,
		   spec => { allow          => { type => ARRAYREF, optional => 1 },
			     required       => { type => ARRAYREF, optional => 1 },
			     require_one_of => { type => ARRAYREF, optional => 1 },
			     spec           => { type => HASHREF,  optional => 1 },
			     allow_empty    => { type => SCALAR,   optional => 1 },
			     allow_undef    => { type => SCALAR,   optional => 1 },
			     delete_empty   => { type => SCALAR,   optional => 1 },
			     uc_keys        => { type => SCALAR,   optional => 1 },
			     full_trace     => { type => SCALAR,   optional => 1 },
			     stack_skip     => { type => SCALAR,   optional => 1 },
			 });

    # use Data::Dumper; warn "input spec: ", Dumper(\%h), "\n"; # XXX Debug

    # deal with nocache
    # FIXME:  remove nocache from params when it is needed, before it goes to APIs
    my $nocache = delete $params->{nocache} || 0;

    # get a pre-defined spec, or create an empty one
    my $spec = delete $h{spec} || {};

    # get the list of allowed parameters
    my $allow = delete $h{allow} || [];
        
    # get the list of required parameters
    my $required = delete $h{'required'} || [];

    # get the list of OR required parameters
    my $require_one_of = delete $h{require_one_of} || [];

    # option to  not change key case
    my $uc_keys = delete $h{uc_keys} || 0;

    # option to give a full trace on validation failure
    my $full_trace = delete $h{full_trace} || 0;

    # optionally allow empty params (value of '') by default
    my $allow_empty = delete $h{allow_empty} || 0;

    # optionally allow undef params by default
    my $allow_undef = delete $h{allow_undef} || 0;

    # optionally undefine empty params (value of '') in order to let "default" work
    my $delete_empty = delete $h{delete_empty} || 0;
    if ($delete_empty) {
	foreach (keys %$params) { 
	    delete $$params{$_} if ( (!defined $$params{$_} && !$allow_undef)
				     || $$params{$_} eq '');
	}
    }

    # add to the stack_skip option
    my $stack_skip = delete $h{stack_skip} || 0;

    # add all params defined in spec, required, and require_one_of to @$allow
    my %allow_uniq;
    foreach my $a (@$allow, keys(%$spec), @$required, @$require_one_of) {
	$allow_uniq{$a} = 1;
    }
    @$allow = keys %allow_uniq;

    # require_one_of is not supported by Param::Validate, so we check that here:
    my $ok = 0;
    foreach my $req (@$require_one_of) {
	if (exists $params->{$req} && defined $params->{$req}) {
	    $ok = 1; last;
	}
    }
    die "invalid parameters: one of (",join(', ',@$require_one_of),") are required\n" 
	if @$require_one_of and not $ok;

    # check that we have something to validate
    if (scalar @$allow == 0) {
	die "developer error: no parameter validation defined\n";
    }

    # now build the spec with some defaults.  a provided spec key has precedence
    foreach my $a (@$allow) {
	# check if there is an existing spec for this param
	my $s = exists $spec->{$a} && ref $spec->{$a} eq 'HASH' ? $spec->{$a} : {};
	
	# now we set the defaults
	if (!defined $s->{type}) {
	    if   (!$allow_undef) { $s->{type} = SCALAR; }         # default type is scalar
	    else                 { $s->{type} = SCALAR | UNDEF; } # unless we allow undefs
	}
	$s->{regex}    = qr/./    unless defined $s->{regex} || $allow_empty || $allow_undef; # no empty string
	$s->{optional} = defined $s->{optional} ? $s->{optional} : 1;  # all params are optional
	$s->{optional} = 0        if grep $a eq $_, @$required;        # ...unless specified otherwise
	$s->{untaint}  = 1        unless defined $s->{untaint};        # we untaint by default

	# check for a special key for using common validation functions
	if (exists $s->{using}) {
	    my $common = delete $s->{using};
	    foreach my $c (arrayref_expand($common)) {
		# check for a negation symbol
		my $negate = 0;
		if (substr($c,0,1) eq '!') {
		    $negate = 1;
		    $c = substr($c,1);
		}
		my $val = $COMMON_VALIDATION{$c} ||
		    die "developer error: '$c' is not a known validation function\n";
		
		if (ref $val eq 'CODE') { 
		    $s->{callbacks}{$c} = $negate ? sub { return !&$val(@_) } : $val;
		} elsif (ref $val eq 'Regexp') {
		    # note: we could have used $s->{regex}, but doing it
		    # this way allows us to easily use both a common
		    # validation and another, more specific regex at
		    # the same time
		    $s->{callbacks}{$c} = $negate ? 
			sub { return $_[0] !~ $val ? 1 : 0 } :  # negative match
			sub { return $_[0] =~ $val ? 1 : 0 } ;  # positive match
		} else {
		    die "developer error: unknown type of validation for '$c'\n";
		}
	    }
	}

	# check for a special key for validating a list of values
	if (exists $s->{allowing}) {
	    my $allowing = delete $s->{allowing};
	    if (ref $allowing ne 'ARRAY') {
		die "developer error: 'allowing' validation should be an array reference\n";
	    }
	    $s->{callbacks}{__allowing} = 
		sub {
		    if    (!defined($_[0])) { return $allow_undef ? 1 : 0; } # possibly allow undef
		    elsif (grep $_[0] eq $_,  @$allowing)   { return 1; }    # allow known values
		    return 0;                                                # otherwise it's bad
		}
	}

	# check to see if we should allow (and validate) multiple values, i.e 'a' or [qw(a b c)]
	if (exists $s->{multiple} && delete $s->{multiple} && ref $params->{$a} eq 'ARRAY' ) {
	    $s->{type} |= ARRAYREF;

	    # turn a regex into a callback
	    if (my $re = delete $s->{regex}) {
		$s->{callbacks}{__regex} = sub { return defined $_[0] && $_[0] =~ $re ? 1 : 0 };
	    }

	    # only allow scalar values in the array
	    $s->{callbacks}{__type} = sub { return defined $_[0] && !ref $_[0] ? 1 : 0 };

	    # turn all callbacks into a multi-value check
	    foreach my $c (keys %{$s->{callbacks}}) {
		my $subref = $s->{callbacks}{$c};  # original callback
		$s->{callbacks}{$c} =              # multi-value check callback
		    sub {        
			foreach (arrayref_expand($_[0])) {
			    return 0 if ! $subref->($_, @_[1..$#_]);
			}
			return 1;
		    };
	    }
	}
	
	# set the spec for this parameter
	$spec->{$a} = $s;
    }

    # build the arguments for the validation function
    my %val_args = (params => $params, spec => $spec);
    # use use confess if we want a full trace
    $val_args{on_fail} = sub { Carp::confess shift } if $full_trace;
    # uppercase keys
    $val_args{normalize_keys} = sub { return uc shift } if $uc_keys;
    # set the caller one frame up + (optional) stack_skip
    $val_args{stack_skip} = 2 + $stack_skip;

    # use Data::Dumper;  warn "final validate spec: ", Dumper(\%val_args), "\n"; # XXX Debug

    # now validate the arguments
    my %good_params = &validate_with( %val_args );
    # FIXME:  Untaint ARRAYREF values here?

    # nocache?
    if ($nocache)
    {
        $good_params{nocache} = 1;
    }

    return %good_params;
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

# lowercase all hash keys
sub lc_keys
{
    my $o = shift;
    
    if (ref $o eq 'HASH') {
	foreach my $k (keys %$o) {
	    lc_keys($o->{$k}) if ref $o->{$k}; # recurce if ref
	    $o->{lc $k} = delete $o->{$k};
	}
    } elsif (ref $o eq 'ARRAY') {
	foreach my $e (@$o) { lc_keys($e); }   # recurse if array
    }
    return $o;
}

# uppercase all hash keys
# FIXME: same as above... how do I get a subref of a builtin and the
# function I'm in to reduce the duplicate?
sub uc_keys
{
    my $o = shift;
    
    if (ref $o eq 'HASH') {
	foreach my $k (keys %$o) {
	    uc_keys($o->{$k}) if ref $o->{$k}; # recurce if ref
	    $o->{uc $k} = delete $o->{$k};
	}
    } elsif (ref $o eq 'ARRAY') {
	foreach my $e (@$o) { uc_keys($e); }   # recurse if array
    }
    return $o;
}

1;
