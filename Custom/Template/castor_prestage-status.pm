#!/usr/bin/env perl

if (!@ARGV) {
    print STDERR "$0: No pfns given\n";
    exit 1;
}

my @args = map { "-M $_" } @ARGV;

open (QRY, "stager_qry @args |")
    or do { print STDERR "$0: cannot execute stager_qry @args: $!\n"; exit 1 };
while (<QRY>) {
    chomp;
    next if ! /^(\S+)\s+\d+\@\S+\s+(\S+)$/;
    my $status = $2;
    $status = "STAGED" if ($status && grep($status eq $_, qw(CANBEMIGR WAITINGMIGR BEINGMIGR))); 
    print STDOUT "$1\n" if ($status eq "STAGED");
}
close (QRY);

