package PHEDEX::Core::XML;

use warnings;
use strict;

use XML::Parser;

sub parseDataNew
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

1;
