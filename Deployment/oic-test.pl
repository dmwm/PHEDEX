#!/usr/bin/perl

use DBI;

$dbh=DBI->connect("DBI:Oracle:cms","cms_transfermgmt_reader",$ARGV[0]) || die "Whoops: $DBI::errstr";

$dbh->disconnect();
