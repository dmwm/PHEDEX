package DMWMMON::SpaceMon::NamespaceConfig;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Tree::DAG_Node;

=head1 NAME

    DMWMMON::SpaceMon::NamespaceConfig - defines aggregation rules

=cut

our %params = ( 
    DEBUG => 1,
    VERBOSE => 1,
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
    print "Namespace default rules:\n";
    foreach (sort keys %rules) {
	print "Rule: " . $_ . " ==> " . $rules{$_} . "\n";
    }
    $self->{RULES} = \%rules;
    $self->convertRulesToTree();
    print $self->dump() if $self->{DEBUG};
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub setConfigFile {
    my $self = shift;
    my $file = shift;
    if ( -f $file) {
	$self->{USERCONF} = $file;
    } else {
	die "Configuration file does not exist: $file";
    }
    print "I am in ",__PACKAGE__,"->setConfigFile() and file is: " . $file . "\n" 
	if $self->{VERBOSE};
}

sub readNamespaceConfigFromFile {
    my $self = shift;
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
	print "Rule: " . $_ . " ==> " . $USERCFG{$_} . "\n";
	$self->{RULES}{$_} = $USERCFG{$_};
    }
    print "WARNING: user settings override default rules.\n" 
	if  $self->{VERBOSE};
    print $self->dump();
}

=head2 NAME

 convertRulesToTree - translates aggregation rules into Namespace tree

=head2 Description

 Each rule is represented as a Tree::DAG_Node object, named as the directory path.
 The depth attribute defines how many subdirectory levels under this path are monitored.
 The depth value is absolute, i.e. counted from the root dir.
 If depth is undefined, all subdirectories are monitored. 

=cut

sub convertRulesToTree {
    my $self = shift;
    my ($NSRulesTree) = Tree::DAG_Node -> new({name => '/', attributes => {depth => undef} });
    print "Dereference Rules: \n";
    #print Data::Dumper::Dumper %$self->{RULES};
    foreach ( keys %{$self->{RULES}}) {
	print "RULE: " . $_ . " ==>>" . $self->{RULES}->{$_} . "\n";  
    }
#$root -> add_daughter(Tree::DAG_Node -> new({name => 'one', attributes => {uid => 1} }) );
#$root -> add_daughter(Tree::DAG_Node -> new({name => 'two', attributes => {} }) );
#$root -> add_daughter(Tree::DAG_Node -> new({name => 'three'}) ); # Attrs default to {}.

#print Data::Dumper::Dumper ($root);
}

sub lfn2pfn {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lfn2pfn()\n" if $self->{VERBOSE};
    
}
sub setLevels {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->setLevels()\n" if $self->{VERBOSE};
    
}
sub getLevels {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->getLevels()\n" if $self->{VERBOSE};
}

1;
