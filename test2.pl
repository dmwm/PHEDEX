use strict;
use warnings;
use Data::Dumper;
# Global vars: 
my $level;
my $rules={}; # hashref

# Functions: 
sub hr {
    print '-' x 80;
    print "\n";
}

sub printrules {
    $level++; 
    print "********* LEVEL: $level \n";
    my @level;
    foreach my $name (keys %{$_[0]}) {
	if ( $name !~ /subdirs/ ){
	    my $depth = $_[0]->{$name};
	    push @level, $name  . " => " . $depth;
	}
    }
    print join(', ', @level) . "\n";
    if (exists $_[0]->{subdirs}) {
	printrules( $_[0]{subdirs} );
    }
}

sub addnode {
    my ($r, $p, $d) = @_;
    return unless  $p;
    my ($dirname, $remainder) = split(/\//, $p, 2);
    $dirname .= "/";
    if ( not exists $r->{$dirname}) {
	$r->{$dirname} = "blah" ;
    }
    if ( not exists $r->{$dirname}) {
	$r->{$dirname} = "blah" ;
    }
    if (not exists $r->{subdirs}){
	$r->{subdirs}={};
    }
    addnode ($r->{subdirs}, $remainder, $d);
}

sub addrule {
    my $rule = shift;
    is_an_integer ($rule->{depth}) 
	or die "ERROR: depth value is not an integer: \"$rule->{depth}\"";
    my $depth =  int($rule->{depth});
    print "*** Adding rule: \"$rule->{path}=" .$depth."\"\n";
    # Ensure trailing slash in every dirname:
    my $path = $rule->{path} . "/";
    $path =~ tr/\///s;
    addnode($rules, $path, $depth);
}

sub is_an_integer {
    # Accepts negative integers
    my $val = shift;    
    return $val =~ m/^[-]*\d+$/;
}

# Define and print the configuration example:
my $example = {
    '/' => 0,
    'subdirs' => {
	'a/' => 0,
	'subdirs' => {
	    'b/' => 0,
	    'subdirs' => {
		'c/' => 1,
		'd/' => -1
	    }
	}
    }
};

&hr();
print Data::Dumper->Dump([ $example ],[qw(*example)]) ;
&hr();
$level = 0;  # used recursively in printrules
&printrules( $example ); 
$level = 0;
&hr();
my %config = ();
while ( <DATA>) {
# Create path/depth hash for each rule and add rule 
# to the config tree structure:
    chomp;
    my $rule;
    ($rule->{path}, $rule->{depth}) = split(/=/);
    addrule($rule);
}
&hr();
print Data::Dumper->Dump([ $rules ],[qw(rules)]) ;
&hr();

#my $curdir = {};
#my $name;
#print Data::Dumper->Dump([ $curdir ],[qw(*curdir)]) ;

#map {print $_ . "/\n"} @dirnames;

__DATA__
/a/b/c/=1
/a/b/=0
/a/b/d/=-1
