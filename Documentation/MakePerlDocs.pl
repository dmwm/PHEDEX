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
our $cssfile = "cpan_min.css";
our $csslink = "$htmldir/$cssfile";
our $docexts = qr/\.(pm|sql|pod)$/;
our $base_title = "PhEDEx Code Documentation";
our @title_hide = qw(Infrastructure);

our ($fileok, $nopod, $errors) = (0,0,0);

my @config = (
    "--podroot=$podroot",
    "--podpath=$podpath",
    "--htmldir=$htmldir",
    "--css=$csslink"
    );

my @dirs = map { catfile($podroot, $_) } split(/:/, $podpath);
my @index;

sub makehtml
{
  my $file = $_;
  
  # return if the file doesn't exist or isn't one we're interested in
  return unless ($file
		 && -f $file
		 && $file =~ $docexts);

  # path of the file relative to $podroot
  my $path = abs2rel($file, $podroot);

  # check the pod documentation, skip the file if there's some problem
  my $status = podchecker($file);
  print "$file status=$status";
  if ($status) {
      print ", skipping\n";
      push @index, [ undef, $path ];
      if    ($status < 0) { $nopod++;  }
      elsif ($status > 0) { $errors++; }
      return;
  }
  print "\n";
  $fileok++;
  
  my ($vol, $reldir, $name) = splitpath($path);             # split directory and filename
  $name =~ s/$docexts//;                                    # remove the extension from the name
  make_path( catdir($htmldir, $reldir) );                   # make a path in the doc tree
  my $relfile = catfile($reldir, $name.'.html');            # the relative location of the file
  my $outfile = catfile($htmldir, $relfile);                # full output file name
  my $title = "$base_title: ".&make_title($relfile);
  
  my @cmd = (@config, "--title=$title", "--infile=$file", "--outfile=$outfile");
  print join ' ', @cmd, "\n";
  pod2html(@cmd);
  print "\n";

  # add the HTML to our index
  push @index, [$relfile, $path];
}

sub make_title
{
    my $relfile = shift; # relative path to an html file
    my $title;
    my ($vol, $reldir, $name) = &splitpath($relfile);
    $name =~ s/\.html$//;
    if ($reldir =~ m|^perl_lib/PHEDEX/|) {
	$title = $reldir;
	$title =~ s|^perl_lib/PHEDEX/||;
	foreach my $hide (@title_hide) {
	    $title =~ s|^$hide||;
	}
	$title =~ s|/||g;
	$title .= " $name";
    }
    $title = $name if !$title;
    return $title;
}

# Iterate through all sources, building HTML
find( { wanted=>\&makehtml, no_chdir=>1 }, @dirs);

# Clean up the litter
unlink('pod2htmd.tmp', 'pod2htmi.tmp');

# Copy the css
`cp $podroot/Documentation/$cssfile $csslink`;

# Make an index.html file
open INDEX, ">$htmldir/index.html" || die "couldn't create index file: $!\n";
print INDEX<<END_HTML;
<html>
  <head><title>$base_title</title></head>
   <link rel="stylesheet" href="$cssfile" type="text/css" />
  <body>
    <h1>$base_title</h1>
    <ul>
END_HTML
foreach my $i (@index) {
#    my $title = &make_title($file);
    my ($html, $source) = @$i;
    if ($html) {
	print INDEX "      <li><a href='$html'/>$source</a></li>\n";
    } else {
	print INDEX "      <li>$source</li>\n";
    }
}
print INDEX<<END_HTML;
    </ul>
  </body>
</html>
END_HTML
close INDEX;

print "\nAll finished: $fileok docs made, $errors skipped with errors, $nopod files without pod\n";
exit;
