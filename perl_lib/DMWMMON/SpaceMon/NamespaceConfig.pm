package DMWMMON::SpaceMon::NamespaceConfig;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;

=head1 NAME

DMWMMON::SpaceMon::NamespaceConfig - defines aggregation rules for space monitoring

=cut

our %params = ( DEBUG => 1,
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
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;
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
    print "WARNING: user settings will override default rules. UPDATED CONFIGURATION: \n";
    print $self->dump();
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
