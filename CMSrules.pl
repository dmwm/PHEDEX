use strict;
use warnings;
use Data::Dumper;
# Global vars: 
my $level;
my $rules={}; # hashref
my $count=0;
my $trace;

sub hr {print '-' x 80; print "\n"}
sub replace_node (\%$$) { $_[0]->{$_[2]} = delete $_[0]->{$_[1]}}
sub showrules {
    shift;
    print "\n", $_;
    print Data::Dumper->Dump([ $rules ],[qw (rules)]), "\n";
}

sub addrule {
    # rule is a hashref with two keys: path and depth.
    my $rule = shift;
    is_an_integer ($rule->{depth})
	or die "ERROR: depth value is not an integer: \"$rule->{depth}\"";
    my $depth =  int($rule->{depth});
    print "============ Processing rule  $rule->{path}=$depth\n";
    my $path = $rule->{path} . "/";
    $path =~ tr/\///s;
    #showrules ("BEFORE:  ");
    addnode($rules, $path, $depth);
    #showrules ("AFTER:  ");
}

sub addnode {
    my ($r, $p, $d) = @_; # rule hash, path and depth
    return unless $p;
    my ($nodename, $remainder) = split(/\//, $p, 2);
    # Assign real depth to the leaves only, otherwise use zero:
    my $newrule = $nodename . ($remainder ? "/=0" : "/=$d");
    #print "newrule = $newrule\n"; # key for the new node
    # Check for existing rules matching our dirname: 
    my ($newn, $newd) = split("=", $newrule);
    # Add the very first rule on the new level w/o checking for conflicts
    keys %{$r} or $r->{$newrule} = {};
    foreach ( keys %{$r} ) {
	my ($oldn, $oldd) = split("=", $_);
	($newn ne $oldn) and next;	
	($newd eq $oldd) and next;
	if ( int($oldd) == 0 ) {
	    print "Overriding a weak rule $_  with a new rule $newrule\n";
	    replace_node %{$r}, $_ => $newrule;
	}else{
	    print "Overriding a new rule $newrule with a strong rule $_\n";
	    $newrule = $_;
	}
    }
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

while ( <DATA>) {
# Create path/depth hash for each rule and add rule 
# to the config tree structure:
    chomp;
    my $rule;
    ($rule->{path}, $rule->{depth}) = split(/=/);
    addrule($rule);
}
&hr();
print Data::Dumper->Dump([ $rules ],[qw(FINAL-RESULT)]) ;
&hr();
__DATA__
/store/local/private/=-1
/store/group/=1
/store/temp/=0
/store/temp/user/=1
/store/backfill/1/=0
/store/backfill/2/=0
/store/local=0
/=0
/store/=2
/store/user=0
/store/user/cmsprod/=0
/store/user/samtests/=0
