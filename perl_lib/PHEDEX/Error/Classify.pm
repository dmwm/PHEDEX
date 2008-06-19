package PHEDEX::Error::Classify;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ErrorClassify DateToUnixEpochSeconds);

use POSIX qw(strftime);

use strict;
use warnings;

# classifies errors, mostly by substitution of non-generic parts
# arguments:
#            detail: an error string
#            errmsglen: maximal string length to consider
sub ErrorClassify {
  my $detail=shift;
  my $errmsglen=shift;

  $errmsglen=200 if $errmsglen<1;


  return "[undefined error message]" if ! defined $detail;

  my $firstcut=$errmsglen+80;
  $detail = substr($detail,0,$firstcut) if length($detail) > $firstcut;

  if ( $detail=~/^\s*$/) {
    return "-";
  }

  my $tmp;
  my $reason;

  # First some general substitution patterns to remove IDs, etc.
  $detail =~ s/\sid=[\d-]+\s/id=\[id\] /;
  $detail =~ s/\sauthRequestID \d+\s/authRequestID \[id\] /;
  $detail =~ s/RequestFileStatus#[\d-]+/RequestFileStatus#\[number\]/g;
  $detail =~ s/srm:\/\/[^\s]+/\[srm-URL\]/g;
  $detail =~ s/at\s+\w{3}\s+\w{3}\s+\d+\s+\d+:\d+:\d+\s+[A-Z]+\s+\d+/at \[date\]/g;
  $detail =~ s/jobId = [-\d]+\s/jobId = \[ID] /;
  $detail =~ s/\s+request\s+\[\d+\]/ request [ID]/g;
  $detail =~ s/\s+id\s+:?\s*\d+/ id [ID] /g;

  if ( (($reason) = $detail =~ m/.*(Failed DESTINATION error during FINALIZATION phase: \[GENERAL_FAILURE\] failed to complete PrepareToPut request.*)/) ) {
    $reason =~ s/request \[(-|\d)+\]/request [reqid]/;
  } elsif ( (($reason) = $detail =~ m/.*(the server sent an error response: 425 425 Can\'t open data connection).*/)) {
  } elsif ( (($reason) = $detail =~ m/.*(the gridFTP transfer timed out).*/) ) {
  } elsif ( (($reason) = $detail =~ m/.*(Failed SRM get on httpg:.*)/) ) {
  } elsif ( (($reason) = $detail =~ m/.*(Failed on SRM put.*)/) ) {
    $reason =~ s!srm://[^\s]+!\[srm-url\]!;
  } elsif ( (($reason,$tmp) = $detail =~ m/.*( the server sent an error response: 553 553)\s*[^\s]+:(.*)/) ) {
    $reason .= " [filename]: " . $tmp;
  } elsif ( (($reason) = $detail =~ m/(.*Cannot retrieve final message from)/) ) {
    $reason .= "[filename]";
  }
  #elsif( $detail =~ /.*RequestFileStatus.* failed with error.*state.*/)
  # {$reason = $detail; $reason =~ s/(.*RequestFileStatus).*(failed with error:).*(state.*)/$1 [Id] $2 $3/;}
  elsif ( $detail =~ /copy failed/ ) {
    $reason = $detail; $reason =~ s/at (\w{3} \w{3} \d+ \d+:\d+:\d+ \w+ \d+)/at \[date\]/g;
  } elsif ( $detail =~ /state Failed : file not found/ ) {
    $reason = "file not found";
  } elsif ( $detail =~ /transfer expired in the PhEDEx download agent queue after [\d.]*h/ ) {
    $reason= "transfer expired in the PhEDEx download agent queue after [hours] h";
  } else {
    $reason = $detail;
  }

  $reason = substr($reason,0,$errmsglen) . "...[error cut]"
    if length($reason) > $errmsglen;

  return $reason;
}


# helper function to convert date
sub DateToUnixEpochSeconds {
    my $date = shift;

    my $unixs=undef;
    my ($Y,$M,$D,$h,$m,$s)=(0,0,0,0,0,0);

    if( (($Y,$M,$D,$h,$m,$s) = $date =~ m/\s*(\d+)-(\d+)-(\d+)\s*(\d+)?:?(\d+)?:?(\d+)?/) ) {
        die "strange month number in date ($M)? Date was: $date\n"if $M < 0 or $M >12;
        $unixs=strftime("%s",$s, $m, $h, $D, $M-1, $Y-1900, -1, -1, -1);
    } elsif( (($D) = $date =~ m/\s*-\s*(\d+)\s*days?/) ) {
        $unixs = time() - 24*3600*$D;
    } elsif( (($h) = $date =~ m/\s*-\s*(\d+)\s*hour/) ) {
        $unixs = time() - 3600*$h;
    } elsif( (($m) = $date =~ m/\s*-\s*(\d+)\s*min/) ) {
        $unixs = time() - 60*$m;
    } elsif( $date =~ /^\s*now\s*$/) {
        $unixs = time();
    } elsif( $date =~ /^\s*yesterday\s*$/) {
        $unixs = time() - 24*3600;
    } else {
        die "Error: Unknown date format: $date\n";
    }
    return $unixs;
}


1;
