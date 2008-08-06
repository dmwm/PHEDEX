package PHEDEX::Core::XML;

use warnings;
use strict;
use vars qw ($VERSION);
$VERSION = "2.0";

use XML::Parser;

sub parseData
{
    my %h = @_;

    my $verbose = $h{VERBOSE};

    my $info;
    if ($h{FILE}) {
	# Ensure file is readable
	-r $h{FILE} || die "$h{FILE}: cannot read: $!\n";

	print "Reading file information from $h{FILE}\n" if $verbose;
	$info = (new XML::Parser (Style => "Tree"))->parsefile ($h{FILE});
    } elsif ($h{XML}) {
	$info = (new XML::Parser (Style => "Tree"))->parse ($h{XML});
    } else {
	die "parseData requires either FILE or XML to parse\n";
    }

    my $version = 0;
# Can use this hack to get to older versions if we want to. We don't...
#    if ( $info->[0] eq 'data' ) { $version = $info->[1][0]{version} || 0; }
#    if ( $version < $VERSION )
#    {
#      my $parseData = "PHEDEX::Core::XML::parseData_$version";
#      no strict 'refs';
#      return $parseData->(%h);
#    }
    $version = $info->[1][0]{version};
    if ( ! $version || $version != $VERSION )
    {
      $version = '(undefined)' unless defined $version;
      my $m = " Require XML version=$VERSION, but version=$version";
      $m .= ' in ' . $h{FILE} if $h{FILE};
      die __PACKAGE__ . $m . "\n";
    }

    my $result = {};
    while (my ($dataattrs, @datacontent) = next_element($info, 'data'))
    {
	print "Processing data\n" if $verbose;
        while (my ($dbsattrs, @dbscontent) = next_element(\@datacontent, 'dbs'))
        {
	    die "parseData: <dbs name=''> attribute missing or empty\n"
	    if ! defined $$dbsattrs{'name'} || $$dbsattrs{'name'} eq '';
	    my $dbsname = $$dbsattrs{'name'};
	    $result->{DBS}->{$dbsname} = { NAME => $dbsname,
				           DLS  => $$dbsattrs{'dls'} || 'unknown' };

	    while (my ($dsattrs, @dscontent) = next_element(\@dbscontent, 'dataset'))
	    {
	        die "parseData: <dataset name=''> attribute missing or empty\n"
		    if ! defined $$dsattrs{'name'} || $$dsattrs{'name'} eq '';
	        die "parseData: <dataset is-open=''> attribute missing or empty\n"
		    if ! defined $$dsattrs{'is-open'} || $$dsattrs{'is-open'} eq '';
#	        die "parseData: <dataset is-transient=''> attribute missing or empty\n"
#		    if ! defined $$dsattrs{'is-transient'} || $$dsattrs{'is-transient'} eq '';

	        my $dsname = $dsattrs->{'name'};
	        $result->{DBS}->{$dbsname}
	        ->{DATASETS}->{$dsname} = { NAME => $$dsattrs{'name'},
					    IS_OPEN => $$dsattrs{'is-open'},
					    IS_TRANSIENT => 'n',
#					    IS_TRANSIENT => $$dsattrs{'is-transient'}
					  };
	    
	        print " Processing dataset $dsname\n" if $verbose;
	        while (my ($battrs, @bcontent) = next_element(\@dscontent, 'block'))
	        {
		    die "parseData: <block name=''> attribute missing or empty\n"
		        if ! defined $$battrs{'name'} || $$battrs{'name'} eq '';
		    die "parseData: <block is-open=''> attribute missing or empty\n"
		        if ! defined $$battrs{'is-open'} || $$battrs{'is-open'} eq '';

		    my $bname = $battrs->{'name'};
		    $result->{DBS}->{$dbsname}
		    ->{DATASETS}->{$dsname}
		    ->{BLOCKS}->{$bname} ={ NAME => $$battrs{'name'},
					    IS_OPEN => $$battrs{'is-open'} };

		    while (my ($fattrs, @fcontent) = next_element(\@bcontent, 'file'))
		    {
		        die "parseData: <file> may not have content\n"
			    if @fcontent;
		        die "parseData: <file name=''> attribute missing or empty\n"
			    if ! defined $$fattrs{'name'} || $$fattrs{'name'} eq '';
		        die "parseData: <file bytes=''> attribute missing or bad value\n"
			    if ! defined $$fattrs{'bytes'} || $$fattrs{'bytes'} !~ /^\d+$/;
		        die "parseData: <file checksum=''> attribute missing or bad value\n"
			    if ! defined $$fattrs{'checksum'} || $$fattrs{'checksum'} !~ /^cksum:\d+$/;

		        my $fname = $fattrs->{'name'};
		        $result->{DBS}->{$dbsname}
		        ->{DATASETS}->{$dsname}
		        ->{BLOCKS}->{$bname}
		        ->{FILES}->{$fname} = {
#						NAME => $fattrs->{'name'},
					        LOGICAL_NAME => $fattrs->{'name'},
#					        BYTES => $fattrs->{'bytes'},
					        SIZE => $fattrs->{'bytes'},
					        CHECKSUM => $fattrs->{'checksum'} };
		    } # /files
	        } # /blocks
	    } # /datasets
        } # /dbses
    } # /datas
    return $result;
}

sub parseData_0
{
    my %h = @_;

    my $verbose = $h{VERBOSE};

    my $info;
    if ($h{FILE}) {
	# Ensure file is readable
	-r $h{FILE} || die "$h{FILE}: cannot read: $!\n";

	print "Reading file information from $h{FILE}\n" if $verbose;
	$info = (new XML::Parser (Style => "Tree"))->parsefile ($h{FILE});
    } elsif ($h{XML}) {
	$info = (new XML::Parser (Style => "Tree"))->parse ($h{XML});
    } else {
	die "parseData requires either FILE or XML to parse\n";
    }

    my $result = {};
    while (my ($dbsattrs, @dbscontent) = next_element($info, 'dbs'))
    {
	die "parseData: <dbs name=''> attribute missing or empty\n"
	    if ! defined $$dbsattrs{'name'} || $$dbsattrs{'name'} eq '';
	
	my $dbsname = $$dbsattrs{'name'};
	$result->{DBS}->{$dbsname} = { NAME => $dbsname,
				       DLS  => $$dbsattrs{'dls'} };
	
	print "Processing dbs $dbsname\n" if $verbose;
	while (my ($dsattrs, @dscontent) = next_element(\@dbscontent, 'dataset'))
	{
	    die "parseData: <dataset name=''> attribute missing or empty\n"
		if ! defined $$dsattrs{'name'} || $$dsattrs{'name'} eq '';
	    die "parseData: <dataset is-open=''> attribute missing or empty\n"
		if ! defined $$dsattrs{'is-open'} || $$dsattrs{'is-open'} eq '';
	    die "parseData: <dataset is-transient=''> attribute missing or empty\n"
		if ! defined $$dsattrs{'is-transient'} || $$dsattrs{'is-transient'} eq '';

	    my $dsname = $dsattrs->{'name'};
	    $result->{DBS}->{$dbsname}
	    ->{DATASETS}->{$dsname} = { NAME => $$dsattrs{'name'},
					IS_OPEN => $$dsattrs{'is-open'},
					IS_TRANSIENT => $$dsattrs{'is-transient'} };
	    
	    print " Processing dataset $dsname\n" if $verbose;
	    while (my ($battrs, @bcontent) = next_element(\@dscontent, 'block'))
	    {
		die "parseData: <block name=''> attribute missing or empty\n"
		    if ! defined $$battrs{'name'} || $$battrs{'name'} eq '';
		die "parseData: <block is-open=''> attribute missing or empty\n"
		    if ! defined $$battrs{'is-open'} || $$battrs{'is-open'} eq '';

		my $bname = $battrs->{'name'};
		$result->{DBS}->{$dbsname}
		->{DATASETS}->{$dsname}
		->{BLOCKS}->{$bname} ={ NAME => $$battrs{'name'},
					IS_OPEN => $$battrs{'is-open'} };

		while (my ($fattrs, @fcontent) = next_element(\@bcontent, 'file'))
		{
		    die "parseData: <file> may not have content\n"
			if @fcontent;
		    die "parseData: <file lfn=''> attribute missing or empty\n"
			if ! defined $$fattrs{'lfn'} || $$fattrs{'lfn'} eq '';
		    die "parseData: <file size=''> attribute missing or bad value\n"
			if ! defined $$fattrs{'size'} || $$fattrs{'size'} !~ /^\d+$/;
		    die "parseData: <file checksum=''> attribute missing or bad value\n"
			if ! defined $$fattrs{'checksum'} || $$fattrs{'checksum'} !~ /^cksum:\d+$/;

		    my $fname = $fattrs->{'lfn'};
		    $result->{DBS}->{$dbsname}
		    ->{DATASETS}->{$dsname}
		    ->{BLOCKS}->{$bname}
		    ->{FILES}->{$fname} = { LOGICAL_NAME => $fattrs->{'lfn'},
					    SIZE => $fattrs->{'size'},
					    CHECKSUM => $fattrs->{'checksum'} };
		} # /files
	    } # /blocks
	} # /datasets
    } # /dbses
    return $result;
}

sub next_element
{
    my ($ary_ref, $tag_wanted) = @_;

    my ($tag, $val) = splice(@$ary_ref, 0, 2);
    return () unless defined $tag;
	
    # Skip leading white space
    return next_element($ary_ref, $tag_wanted) 
	if ($tag eq '0' && $val =~ /^\s+$/so);

    # Scream if the format is wrong
    die "parseData: unexpected character data\n" if $tag eq '0';
    die "parseData: expected <$tag_wanted> entry, found <$tag>\n"
	if $tag ne $tag_wanted;

    return @$val;
}

sub makeData
{
  my %h = @_;
  my ($dbs,$open,$dataset,$blocks,$files,$mean_size,$sdev_size);
  my (@xml);

  $dbs = $h{dbs} || "test";
# $dls = $h{dls} || "lfc:unknown";
  $open      = $h{open} || 'n';
  $dataset   = $h{dataset};
  $blocks    = $h{blocks} || 1;
  $files     = $h{files}  || 1;
  $mean_size = $h{mean_size} || 1;
  $sdev_size = $h{sdev_size} || 0;
  $open = lc $open;
  if ( $open !~ m%^[y,n]$% ) { $open = $open ? 'y' : 'n'; }

  push @xml, qq{<data version="$PHEDEX::Core::XML::VERSION">\n};
  push @xml, qq{  <dbs name="$dbs">\n};
  push @xml, qq{    <dataset name="$dataset" is-open="y">\n};
  for my $n_block (1..$blocks) {
    my $block = $dataset . "#" . &makeGUID();
    push @xml, qq{      <block name="$block" is-open="$open">\n};
    for my $n_file (1..$files) {
	my $lfn = $block;
	$lfn =~ s/\#/-/;  $lfn .= '-'. &makeGUID();
	my $filesize;
	if ($sdev_size == 0) {
	    $filesize = int($mean_size * (1024**3));
	} else {
	    $filesize = int(gaussian_rand($mean_size, $sdev_size) *  (1024**3));
	}
	my $cksum = 'cksum:'. int(rand() * (10**10));
	push @xml, qq{        <file name="$lfn" bytes="$filesize" checksum="$cksum"/>\n};
    }
    push @xml, qq{      </block>\n};
  }
  push @xml, qq{    </dataset>\n};
  push @xml, qq{  </dbs>\n};
  push @xml, qq{</data>\n};

  return @xml;
}

sub makeGUID
{
    my $size = shift || 8;
    my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9);
    return join("", @chars[ map { rand @chars } ( 1 .. $size )]);
}

# From the perl cookbook
# http://www.unix.org.ua/orelly/perl/cookbook/ch02_11.htm

sub gaussian_rand {
    my ($mean, $sdev) = @_;
    $mean ||= 0;  $sdev ||= 1;
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;

    $g1 = $g1 * $sdev + $mean;
    $g2 = $g2 * $sdev + $mean;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}
1;
