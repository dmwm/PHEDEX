#!/usr/bin/perl -w
use strict;
use warnings;
my ($colour,$colours,$file,$cmd);
$colours = {
		red	=> '#ff0000',
		green	=> '#00ff00',
		blue	=> '#0000ff',
		cyan	=> '#00ffff',
		magenta	=> '#ff00ff',
		yellow	=> '#ffff00',
		black	=> '#000000',
		orange	=> 'orange',
	   };

foreach $colour ( keys %{$colours} )
{
  $cmd = "convert +antialias -size 16x16 xc:none -fill '".$colours->{$colour}."' -draw 'circle 8,8 4,4'  file1.png";
  print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print; }
  close CMD or die "close: $!\n";

  $cmd = "convert file1.png \\( +clone -fx A +matte -blur 0x12 -shade 110x0 -normalize -sigmoidal-contrast 16,60% -evaluate multiply 0.8 -roll +1+2 +clone -compose Screen -composite \\) -compose In -composite file2.png";
  print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print; }
  close CMD or warn "close: $!\n";

  $cmd = "convert -size 16x16 xc:none -fill black -draw 'circle 8,8 4,5' \\( +clone -background black -shadow 100x1+1+1 \\) +swap -background none      -mosaic file3.png";
  print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print; }
  close CMD or warn "close: $!\n";

  $cmd = "composite file2.png file3.png file4.png";
  print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print; }
  close CMD or warn "close: $!\n";

  unlink 'file1.png';
  unlink 'file2.png';
  unlink 'file3.png';
  rename 'file4.png', "icon-circle-$colour.png";
}
