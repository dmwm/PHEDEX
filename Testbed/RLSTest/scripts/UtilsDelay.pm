# Read a delay model
sub readDelayModel
{
    my ($file) = @_;
    open (IN, "< $file") || die "$file: cannot read: $!\n";
    my $model = { SUM => 0, WEIGHTS => {}, INTEGRATED => [] };

    # Read in the weighted histogram
    while(<IN>)
    {
	chomp;

	# Skip empty or comment lines
	s/\#.*//;
	s/^\s+//;
	s/\s+$//;
	s/\s+/ /;
	next if /^$/;

	if (/^(\d+) (\d+)$/) {
	    $model->{WEIGHTS}{$1} = $2;
        }
	else
	{
	    die "$file:$.: unrecognised delay model line\n";
	}
    }
    close (IN);

    # Integrate the histogram to get the probability distribution
    foreach my $x (sort { $a <=> $b } keys %{$model->{WEIGHTS}}) {
	$model->{SUM} += $model->{WEIGHTS}{$x};
    }

    my ($low, $high) = (0, 0);
    foreach my $x (sort { $a <=> $b } keys %{$model->{WEIGHTS}}) {
	$low = $high;
	$high = $low + $model->{WEIGHTS}{$x} / $model->{SUM};
	push (@{$model->{INTEGRATED}}, [ $low, $high, $x ]);
    }

    return $model;
}

# Determine a time that's distributed according to a statistical model
sub sampleDelayModel
{
    my ($model) = @_;
    my ($time, $randval) = (0, rand (1));
    foreach my $bin (@{$model->{INTEGRATED}}) {
	return $bin->[2] if ($randval >= $bin->[0] && $randval < $bin->[1]);
    }
    return 0;
}

# Sleep a time that's distributed according to a statistical model
sub delayStatistically
{
    sleep (&sampleDelayModel (@_));
}

1;
