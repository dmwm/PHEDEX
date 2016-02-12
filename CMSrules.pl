use strict;
use warnings;
use Data::Dumper;
# Global vars: 
my $level;
my $rules={}; # hashref

sub hr {print '-' x 80;print "\n";}
sub showrules {
    my $word = shift;
    print "\n", $word;
    print Data::Dumper->Dump([ $rules ],[qw (rules)]), "\n";
}

sub replace_node (\%$$) {
  $_[0]->{$_[2]} = delete $_[0]->{$_[1]};
}

sub addrule {
    # rule is a hashref with two keys: path and depth.
    my $rule = shift;
    is_an_integer ($rule->{depth})
	or die "ERROR: depth value is not an integer: \"$rule->{depth}\"";
    my $depth =  int($rule->{depth});
    print "\n============  New rule  \"$rule->{path}=" .$depth."\"\n\n";
    my $path = $rule->{path} . "/";
    $path =~ tr/\///s;
    print Data::Dumper->Dump([ $rules ],[qw(rules)]);
    addnode($rules, $path, $depth);
}

sub addnode {
    my ($r, $p, $d) = @_; # rule hash, path and depth
    return unless $p;
    print "path = $p\n";
    my ($nodename, $remainder) = split(/\//, $p, 2);
    my $newrule = $nodename . ($remainder ? "/=0" : "/=$d");
    print "newrule = $newrule\n";
    if ( not exists $r->{$newrule}) {
	$r->{$newrule} = {};
    }
    addnode ($r->{$newrule}, $remainder, $d);
}

sub is_an_integer {
    # Accepts negative integers
    my $val = shift;    
    return $val =~ m/^[-]*\d+$/;
}

# Define and print the configuration example:
my $example = {
    '/=0' => {
	"a/=0" => {
	    "b/=4" => {
		"c/=2" => {},
		"d/=-1" => {},
		"e/=0" => {
		    "f/=0" =>{}
		}
	    }
	}
    }
};

#&hr();
#print Data::Dumper->Dump([ $example ],[qw(example)]);
#&hr();
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
#/a/b/c/=2
#/a/b/e/f=0
#/a1/b1/=4
#/a/b/d/=-1
__DATA__
/=0
/a1/a2/a3/=0
/b1/b2/b3/=0
/b1/c1=0
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
