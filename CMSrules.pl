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
    my ($r, $p, $d) = @_;  # rul hash, path and depth.
    return unless $p;
    my ($dirname, $remainder) = split(/\//, $p, 2);
    $dirname .= "/";
    if ( not exists $r->{$dirname}) {
	$r->{$dirname} = $remainder ? 0 : $d ; 
    }
    $r->{$dirname} = $d unless $remainder;
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
		'd/' => -1,
		'subdirs' => {}
	    }
	}
    }
};

#&hr();
#print Data::Dumper->Dump([ $example ],[qw(*example)]) ;
#&hr();
#$level = 0;  # used recursively in printrules
#&printrules( $example ); 
#$level = 0;
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

## This is a basic example:
#/a/b/d/=-1
#/a/b/=4
#/a/b/c/=2


## This is a CMS real example taken from:
#       https://twiki.cern.ch/twiki/bin/viewauth/CMS/DMWMPG_Namespace
#
### Here are all  directories mentioned in CMS namespace conventions: 
#/store/data/
#/store/hidata/
#/store/mc/
#/store/relval/
#/store/hirelval/ 
#/store/user 
#/store/group/ 
#/store/results/ 
#/store/unmerged/ 
#/store/temp/ 
#/store/temp/user/ 
#/store/backfill/1/ 
#/store/backfill/2/ 
#/store/generator 
#/store/local 
#/store/dqm/ 
#/store/lumi/ 
#/store/data/HcalLocal/ 
#/store/t0temp/ 

# 
# I consider the use cases:
# * Show all sub-directories under /store up to three levels deep, 
#   unless there is another explicit rule
# * Do not show any sub-directories in /store/temp, /store/local 
#   /backfill/1 and /store/backfill/2
# * In /store/temp only show /store/temp/user one level deep, and no other sub-directories
# * In /store/group/ show only immediate sub-directories
# * Do not show any sub-directories under /store/user except for 
#   /store/user/cmsprod and /store/user/samtests
# * Do not show /store/local/private and do not include its size 
#   into storage usage report


__DATA__
/store/=3
/store/user=0
/store/user/cmsprod/=0
/store/user/samtests/=0
/store/group/=1
/store/temp/=0
/store/temp/user/=1
/store/backfill/1/=0
/store/backfill/2/=0
/store/local=0
/store/local/private/=-1
