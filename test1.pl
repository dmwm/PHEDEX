use strict;
use warnings;
use Data::Dumper;
my ($name,$depth);
my $count = 0;
my %nodes = ();

# Initialize the configuration tree from root dir: 
my $config = {
    name => "/",
    #level => 0,
    subdirs => {},
    depth => 0,   # subdirs must override 0 by 1 to be shown
    rule => "weak"
};

while (<DATA>) {
    ($name,$depth) = (split /=/);
    #print "RULE: " . $name . " = " . $depth . "\n";
    &add_nodes_for_rule($name, $depth);
}
print Data::Dumper::Dumper ($config);

sub add_nodes_for_rule {
    my $path = shift;
    my $depth = shift;
    my @dirnames;
    my $parent;
    my %self;
    # TO prevent infinite loop during debugging: 
    #print  "Count = ". $count . "\n";
    $count++;
    ($count == 100 ) and die "Stop after " . $count . " calls of add_nodes_for_rule.\n";
    #print "Checking " . $path . "\n";
    if ($nodes{$path}) {
	#print "INFO: rule already exists for: " . $path . "\n";
	#print Data::Dumper::Dumper ($nodes{$path});
	# TODO: if it is a strong rule, apply to all children
    }else{
	print "Adding node " . $path . "\n";
	$nodes{$path} = 1; # to ensure no duplicates
	$self{name} = $path;
	$self{depth} = $depth; # TODO: validate to distinguish zero integer from non-integer. 
	#$config->{subdirs}->{name} = \%self;
	$config->{subdirs}->{name} = \%self;
	# Add all parent dirs: 
	@dirnames = split /\//, $path;
	while (pop @dirnames) {
	    $parent = (join '/', @dirnames ) . "/";
	    #print "Processing parent: ", $parent, "\n";
	    &add_nodes_for_rule($parent);
	}
    }    
}

sub is_integer {    
    # Accepts negative integers
    my $val = shift;    
    return $val =~ m/^[-]*\d+$/
}

#/a/b/d/=-1

__DATA__
/a/b/c/=1
/a/b/=0
