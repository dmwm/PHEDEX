#!/usr/bin/env perl

use warnings;
use strict;
$|=1;
use Pod::Html;
use Pod::Checker;
use File::Find;
use File::Spec::Functions qw(catdir catfile abs2rel splitpath splitdir);
use File::Path qw(make_path);
use Cwd qw(abs_path);
use File::Basename;

our $phedexroot;
BEGIN {
    $phedexroot = abs_path( catdir( dirname($0), '..') );
}

our $podroot = $phedexroot;
our $podpath = join ':', qw(perl_lib Schema);
our $htmldir = catdir($podroot, "Documentation/html");
our $docexts = qr/\.(pm|sql)$/;

our ($fileok, $nopod, $errors) = (0,0,0);

my @config = (
    "--podroot=$podroot",
    "--podpath=$podpath",
    "--htmldir=$htmldir",
#    "--css=$podroot/perl_lib/phedex_pod.css"
    );

my @dirs = map { catfile($podroot, $_) } split(/:/, $podpath);

sub makehtml
{
  my $file = $_;
  return unless ($file
		 && -f $file
		 && $file =~ $docexts);

  my $status = podchecker($file);
  print "$file status=$status";
  if ($status) {
      print ", skipping\n";
      if    ($status < 0) { $nopod++;  }
      elsif ($status > 0) { $errors++; }
      return;
  }
  print "\n";
  $fileok++;
  
  my $path = abs2rel($file, $podroot);                      # path of the file relative to $podroot
  my ($vol, $reldir, $name) = splitpath($path);             # split directory and filename
  $name =~ s/$docexts//;                                    # remove the extension from the name
  make_path( catdir($htmldir, $reldir) );                   # make a path in the doc tree
  my $outfile = catfile($htmldir, $reldir, $name.'.html');  # output file name

  my $title;
  if ($reldir =~ m|^perl_lib/PHEDEX/|) {
      $title = $reldir;
      $title =~ s|^perl_lib/PHEDEX/||;
      foreach my $hide (qw(Infrastructure)) {
	  $title =~ s|^$hide||;
      }
      $title =~ s|/||g;
      $title .= " $name";
  }
  $title = $name if !$title;
  

  my @cmd = (@config, "--title=$title", "--infile=$file", "--outfile=$outfile");
  print join ' ', @cmd, "\n";
  pod2html(@cmd);
  print "\n";
}

find( { wanted=>\&makehtml, no_chdir=>1 }, @dirs);

# clean up the litter
unlink('pod2htmd.tmp', 'pod2htmi.tmp');

print "\nAll finished: $fileok docs made, $errors skipped with errors, $nopod files without pod\n";
exit;
