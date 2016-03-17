package DMWMMON::SpaceMon::NamespaceConfig;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;

=head1 NAME

    DMWMMON::SpaceMon::NamespaceConfig - defines aggregation rules

=cut

#########################  Service functions #####################
# Accepts negative integers, used  to validates depth parameters
sub is_an_integer { my $val = shift; return $val =~ m/^[-]*\d+$/};
# Substitutes keys in a hash, used for conflicts resolution
sub replace_node (\%$$) { $_[0]->{$_[2]} = delete $_[0]->{$_[1]}};
##################################################################

our %params = ( 
    DEBUG => 1,
    VERBOSE => 1,
    STRICT => 1,
    DEFAULTS => 'DMWMMON/SpaceMon/defaults.rc',
    USERCONF => $ENV{SPACEMON_CONFIG_FILE} || $ENV{HOME} . '/.spacemonrc',
    );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %args = (@_);
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}}
	  else { $self->{$_} = $params{$_}} } keys %params;
    bless $self, $class;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    # Read default configuration rules:
    our %rules;
    my $return;
    unless ($return = do $self->{DEFAULTS}) {
	warn "couldn't parse $self->{DEFAULTS}: $@" if $@;
	warn "couldn't do $self->{DEFAULTS}: $!"    unless defined $return;
	warn "couldn't run $self->{DEFAULTS}"       unless $return;
    }
    print "Namespace default rules:\n" if $self->{VERBOSE};
    foreach (sort keys %rules) {
	print "Rule: " . $_ . " ==> " . $rules{$_} . "\n" if $self->{VERBOSE};
    }
    $self->{RULES} = \%rules;
    print $self->dump() if $self->{DEBUG};
    $self->readNamespaceConfigFromFile();
    $self->{NAMESPACE} = {};
    $self->convertRulesToNamespaceTree();
    print $self->dump() if $self->{DEBUG};
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }


# Default rules coming with the client are applied during initialization.
# The rules found in the user's config file will override the defaults.
# The resulting set of rules is reorganized into a tree resolving conflicts
# in permissive or restrictive way depending on the STRICT flag value.

=head2 NAME

 readNamespaceConfigFromFile - reads user defined aggregation rules and converts
 into Namespace tree

=head2 Description

 Each rule is represented as a Tree::DAG_Node object, named as the directory path.
 The depth attribute defines how many subdirectory levels under this path are monitored.
 The depth value is absolute, i.e. counted from the root dir.
 If depth is undefined, all subdirectories are monitored. 

=cut

sub readNamespaceConfigFromFile {
    my $self = shift;
    if ( -f $self->{USERCONF}) {
	warn "WARNING: user settings in " . $self->{USERCONF} . 
	    " will override the default rules." if  $self->{VERBOSE};
    } else {
	die "Configuration file does not exist: " . $self->{USERCONF};
    }
    our %USERCFG;
    print "I am in ",__PACKAGE__,"->readNamespaceConfigFromFile(), file="
	. $self->{USERCONF} . "\n"
	if $self->{VERBOSE};
    unless (my $return = do $self->{USERCONF}) {
	warn "couldn't parse $self->{USERCONF}: $@" if $@;
	warn "couldn't do $self->{USERCONF}: $!"    unless defined $return;
	warn "couldn't run $self->{USERCONF}"       unless $return;
    }
    foreach (sort keys %USERCFG) {
	print "WARNING: added user defined rule: " . 
	    $_ . " ==> " . $USERCFG{$_} . "\n"
	    if $self->{VERBOSE};
	$self->{RULES}{$_} = $USERCFG{$_};
    }
    print $self->dump() if $self->{VERBOSE};
}

sub convertRulesToNamespaceTree {
    my $self = shift;
    print "********** Converting Rules to a Tree: ***********\n" 
	if $self->{VERBOSE};
    foreach ( keys %{$self->{RULES}}) {
	# Create path/depth hash for each rule and add rule 
	# to the config tree structure:
	my $rule;
	$rule->{path} = $_;
	$rule->{depth} = $self->{RULES}{$_};
	$self->addRule($rule);
    }
}

sub addRule {
    my $self = shift;
    # rule is a hashref with two keys: path and depth.
    my $rule = shift;
    is_an_integer ($rule->{depth})
	or die "ERROR: depth value is not an integer: \"$rule->{depth}\"";
    my $depth =  int($rule->{depth});
    print "\n============ Processing rule  $rule->{path}=$depth\n";
    my $path = $rule->{path} . "/";
    $path =~ tr/\///s;
    $self->addNode($self->{NAMESPACE}, $path, $depth);
}

sub addNode {
    # Recursively adds nodes to the tree for each given rule.
    # Resolves conflicting rules, see more comments inline.
    my $self = shift;
    my ($n, $p, $d) = @_; # path and depth
    print "ARGUMENTS passed to addNode:\n  path = $p\n  depth = $d\n";
    return unless $p;
    my ($nodename, $remainder) = split(/\//, $p, 2);
    # Assign real depth to the leaves only, otherwise use zero:
    my $newrule = $nodename . ($remainder ? "/=0" : "/=$d");
    print "newrule = $newrule\n"; # key for the new node
    # Check for existing rules matching our dirname:
    my ($newn, $newd) = split("=", $newrule);
    # Add the very first rule on the new level w/o checking for conflicts
    keys %{$n} or $n->{$newrule} = {};
    foreach ( keys %{$n} ) {
	my ($oldn, $oldd) = split("=", $_);
	($newn ne $oldn) and next;
	($newd eq $oldd) and next;
	if ( int($oldd) == 0 ) {
	    print "Overriding a weak rule $_  with a new rule $newrule\n";
	    replace_node %{$n}, $_ => $newrule;
	}else{
	    print "Overriding a new rule $newrule with a strong rule $_\n";
	    $newrule = $_;
	}
    }
    if ( not exists $n->{$newrule}) {
	$n->{$newrule} = {};
    }
    $self->addNode($n->{$newrule}, $remainder, $d);
}

sub find_top_parents {
    my $self = shift;
    my $path = shift;
    #print "In find_top_parents: argument path = \"$path\"\n" if $self->{DEBUG};
    my @topparents = ();
    # Select top parents based on namespace configuration
    # starting from the top of the namespace rules tree:
    my $node = $self->{NAMESPACE};
    my @parent;
    my $depth;
    # Get all existing parents:
    my @allparents = split "/", $path;
    # drop last element – the file name:
    pop @allparents; 
    foreach my $dirname (@allparents) {
	if (keys %{$node}) {
	    # Look for any matching rules:
	    foreach ( keys %{$node} ) {
		my ($n,$d) = split("=", $_);
		if ($n eq $dirname."/") {
		    if ($d < 0) {return ()}
		    push @parent, $dirname;
		    push @topparents, join ('/',@parent);
		    $node = $node->{$_};
		    $depth = $d;
		}
	    }
	} else {
	    # When all matching rules are exhausted, continue to add parents
	    # up to a last matching depth:
	    if ( $depth >= 0 ) {
		push @parent, $dirname;
		push @topparents, join ('/',@parent);
	    }
	}
	$depth -= 1;
    }
    if ($self->{DEBUG}) {
	print "=== List of top parents for path " . $path . ": ===\n";
	map {print $_ . "/\n"} @topparents;
	print "=== End of top parents list ===\n";
    }
    # Fix top parent dir : 
    $topparents[0] = "/";
    return @topparents;
}

sub lfn2pfn {
    # If we ever need to do this conversion, it should go here. 
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lfn2pfn()\n" if $self->{VERBOSE};
    
}

1;
