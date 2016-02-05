package DMWMMON::SpaceMon::ConfigTreeNode;
use strict;
use warnings;
use Data::Dumper;

our %params = ( 
    DEBUG => 1,
    VERBOSE => 1,
    );

sub new {
    my $class = shift;
    my %args = (@_);
    my $self = {};
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} 
	  else { $self->{$_} = $params{$_}} } keys %params;
    bless $self, $class;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    #print "Arguments: \n";
    #print Data::Dumper::Dumper %args;    
    print "Validating directory name \"$args{name}\"\n" if $self->{VERBOSE};
    $self->{name} = validate_dirname($args{name});
    print "Adding node \"$self->{name}\"\n"  if $self->{VERBOSE};
    is_integer ($args{depth}) or die "ERROR: depth value is not an integer: \"$args{depth}\" ";
    $self->{depth} = $args{depth};
    #$self->{mother} = $args{mother} or die;
    $self->{daughters} = {}; # no children at initialization
    return $self;
}

sub validate_dirname {
    my $dirname = shift;
    # Squash multiple consequitive slashes:
    $dirname =~ tr/\///s;
    # Only one trailing slash is allowed:
    my $count;
    $count = $dirname =~ tr/\/// ;
    if ( $count == 0 ) {
	return $dirname . "/" ;
    }
    $count > 1 and die "More than one slash found in $dirname\n";
    # make sure single slash is at the end of dirname:
    my $last = chop($dirname);
    if ( $last eq "/" ) {
	return $dirname . "/";
    } else {
	die "ERROR: bad directory name: \"" . $dirname . $last . "\"\n";
    }
}
sub is_integer {    
    # Accepts negative integers
    my $val = shift;    
    return $val =~ m/^[-]*\d+$/
}
sub add_daughter {
}
sub dump {
}
sub print_askii_tree {
}
sub match_path {
}

sub module_test {
# For testing only:
    my %input = (name => 'aa//', depth => "-10");
    my $root = DMWMMON::SpaceMon::ConfigTreeNode->new (%input);
    
#$root -> add_daughter(new({name => 'one', attributes => {uid => 1} }) );
#$root -> add_daughter(Tree::DAG_Node -> new({name => 'two', attributes => {} }) );
#$root -> add_daughter(Tree::DAG_Node -> new({name => 'three'}) ); # Attrs default to {}.
    
    print Data::Dumper::Dumper $root;
}

&module_test();
# 1;
