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
    RULES => undef,
    );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %args = (@_);
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} 
	  else { $self->{$_} = $params{$_}} } keys %params;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
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
    $self->convertRulesToTree(); 
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

sub convertRulesToTree {
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
    print "============ Processing rule  $rule->{path}=$depth\n";
    my $path = $rule->{path} . "/";
    $path =~ tr/\///s;
    $self->addNode($path, $depth);
}

sub find_top_parents {
    my $self = shift;
    my $path = shift;
    my @topparents = ();
    my @all_dirs = split "/", $path;
    # calculate based on STARTPATH and LEVEL parameters.
    my @levels = split "/", $path; 
    my $depth = @levels;
    $depth--;
    if ($self->{VERBOSE}){
	print "NRDEBUG 000: path = $path\n      Top parents:\n";
	foreach (@topparents) {
	    print "           " . $_ . "\n";
	}
    }
    return @topparents;
}

sub lfn2pfn {
    # If we ever need to do this conversion, it should go here. 
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lfn2pfn()\n" if $self->{VERBOSE};
    
}

1;
