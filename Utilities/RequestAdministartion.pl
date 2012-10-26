#!/usr/bin/env perl
##H Interactive CLI to manage request permissions.
##H
##H Usage:
##H   RequestAdministration.pl -db FILE[:SECTION]
##H
use strict;
use warnings;
use PHEDEX::Core::Loader;
use Data::Dumper;
use PHEDEX::Core::DB;
use Getopt::Long;
use PHEDEX::Core::Help;

my ($conn,$dbh, $db);
my ($types, $transitions, $abilities);
my ($input, $found, $agree);

# Process command line arguments.
&GetOptions ("db=s"        => \$db,
	     "help|h"      => sub { &usage() });

# Check arguments.
if (@ARGV || !$db)
{
    die "Insufficient parameters, use -h for help.\n";
}

sub hr {
  my $length = shift;
  for (1.. $length) { print "_"; }; print "\n"; 
}

sub confirm() {
  print "Confirm with 'yes' or 'no' :  ";
  if ((my $answer = <STDIN>) =~ /^yes$/i) {
      print "user_agrees\n";
      return 1;
    } elsif ($answer =~ /^no$/i) {
      print "user_disagrees\n";
      return 0;
    } else {
      chomp $answer;
      die "'$answer' is neither 'yes' nor 'no'";
    }
}

sub getNames {
  # Returns a list of state names defined in  t_req2_state table:
  my $db = shift;
  my $table = shift;
  my @result;
  my $types = $db->selectall_arrayref(qq{select name from $table order by name});
  for my $i ( 0 .. @$types-1) {
    push @result, $types-> [$i][0];
  }
  return \@result;
}

########## Here interface logic starts 
$conn =  { DBCONFIG => $db };
$dbh = &connectToDatabase ($conn);

# Select Request type:
$types = $dbh->selectall_arrayref(qq{select id, name from t_req2_type order by id});
printf(" %-15s%-15s\n",   
       "TYPE ID |", "REQUEST TYPE");
&hr(45);
for my $i ( 0 .. @$types-1 ) {
  printf(" %-15d%-15s\n", $types->[$i][0],  $types->[$i][1] );
}
&hr(45);
print "Enter desired TYPE ID: ";
$input = <>;
chomp $input;
$found = '';
for my $i ( 0 .. @$types-1 ) {
  if ( $types->[$i][0] eq $input) {
    $found = $input;
    print "You selected request type: :\n";
    &hr(45);
    printf(" %-15d%-15s\n", $types->[$i][0],  $types->[$i][1] );
    &hr(45);
    $agree = &confirm();
    last;
  }
}
$found or die "Your input '$input' does not match any request TYPE ID \n EXITING\n";
&disconnectFromDatabase($conn, $dbh, 1);
exit;
$transitions = $dbh->selectall_arrayref(qq{
               select rt.id, rsf.name, rst.name 
               from t_req2_transition rt, t_req2_state rsf, t_req2_state rst
               where rt.from_state=rsf.id and rt.to_state=rst.id
               order by rsf.name});

my ($id, $from_state, $to_state);
my ($aref, $output, $n, $i, $j);
printf(" %-15s%-15s%-15s\n",   
       "TRANSITION ID |", "INITIAL STATE |", "NEW STATE");
&hr(45);
for $i ( 0 .. @$transitions-1 ) {
  $aref = $transitions->[$i];
  ($id, $from_state, $to_state) = @$aref;
  printf(" %-15d%-15s%-15s\n", $id, $from_state, $to_state);
  #printf "$output\n";
  #print Dumper($aref);
  #$n = @$aref - 1;
  #for $j ( 0 .. $n ) {
  #  print "elt $i $j is $transitions->[$i][$j]\n";
  #}
}
&hr(45);
print "Enter desired TRANSITION ID: ";
$input = <>;
chomp $input;
$found = 0;
for $i ( 0 .. @$transitions-1 ) {
  $aref = $transitions->[$i];
  ($id, $from_state, $to_state) = @$aref;
  if ( "$id" eq $input) {
    print "You are going to allow transition:\n";
    &hr(45);
    printf("    %-15d%-15s%-15s\n", $id, $from_state, $to_state);	
    &hr(45);
    &confirm();
    last;
  }
}

sub addType {
  my $db = shift;
  my $name = shift;
  # Oracle will give an error for already existing type
  # due to uniqueness constraint.
  &dbexec ($db, qq{
               insert into t_req2_type 
               (id, name)
               values (seq_req2_type.nextval, :name)},
	   ":name" => $name);
  $db-> commit();
}

sub addRule {
  #pass;
}

sub addTransition {
  my $db = shift;
  my ($from, $to) = @_;
  my @states = &getNames($dbh, 't_req2_state');
  if (grep {$_ eq $from} @states) {
    print "Initial state '$from' is OK \n";
  } else {
    print "ERROR: State  '$from' does not exist! Choose state from the list:\n      " ;
    print join (", ",  @states) .  "\n";
  }
  if (grep {$_ eq $to} @states) {
    print "Transition final state '$to' is OK \n";
  } else {
    print "ERROR: Final state '$to' does not exist! Choose state from the list:\n      " ;
    print join (", ",  @states) .  "\n";
  }
  
  &dbexec ( $dbh, qq{insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name=:blah and rt.name=:blob },  ":blah" => $from, ":blob" => $to);
  $db-> commit();
}

sub addPermission {
}

print "Request States: " . join (" ",  &getNames($dbh, 't_req2_state')) .  "\n";
print "Request Types: " . join (" ",  &getNames($dbh, 't_req2_type')) .  "\n";
print "Abilities: " . join (" ",  &getNames($dbh, 't_adm2_ability')) .  "\n";
#&addType ($dbh, 'NewType');
#&addTransition($dbh, 'suspended', 'denied');

#print "Request Types: " . join (" ",  &getNames($dbh, 't_req2_type')) .  "\n";

&disconnectFromDatabase($conn, $dbh, 1);
exit;

#my ($id, $name) = &dbexec($dbh,
#   qq{select id, name from t_req   2_type  t where t.name=:pat },
#   ":pat" => 'delete') -> fetchrow;
#print "ID: $id\nNAME: $name\n";

