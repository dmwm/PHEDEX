*** Generating drops for DC04 data

for a in 5270 5272 5273 5274 5275 5276 5278 \
         5439 5440 5441 5442 5443 5444 5445 \
	 5449 5450 5452 5453 5454 5455 5457; do
  PHEDEX/Toolkit/Request/TRNew DC04Sample.$a
  PHEDEX/Toolkit/Request/TRNewData -a DC04Sample.$a $a
  PHEDEX/Toolkit/Request/TRSyncDrops DC04Sample.$a
done

*** Adding checksum information

for f in $(rfdir /castor/cern.ch/cms/DSTs_801a | awk '{print $NF}'); do
  rfdir /castor/cern.ch/cms/DSTs_801a/$f | awk '{print -1, $5, $9}'
done > all-checksums

echo DC04Sample.*/Drops/Pending/*/XML* |
  xargs perl -IPHEDEX/Toolkit/Common -e '
    use UtilsReaders;
    %info = ();
    open (CK, "< all-checksums") or die;
    while (<CK>) {
        ($sum, $size, $lfn) = /(\S+)/g;
	$info{$lfn} = [ $sum, $size ];
    }
    close (CK);
    foreach $cat (@ARGV) {
      my $s = $cat; $s =~ s|XMLCatFragment|Checksum|; $s =~ s|xml$|txt|;
      my $c = eval { &readXMLCatalogue ($cat) };
      do { print $@; close (CK); next } if $@;
      my @lfns = map { @{$_->{LFN}} } @$c;
      open (CK, "> $s") or die "$s: $!\n";
      print CK map { exists $info{$_}
      		     ? "$info{$_}[0] $info{$_}[1] $_\n"
		     : "" } @lfns;
      close (CK);
    }'

for f in DC04Sample.*/Drops/Pending/*; do touch $f/go; done

*** Setup an agent chain

The "Config" file specifies the agent configuration to use for a file
merging test.  It assumes you want to run the agents in a specific
location with a specific checked out version of PHEDEX (/u/dev/PHEDEX,
/u/dev/MergeTest).  Adjust the paths as appropriate.

Start: PHEDEX/Utilities/Master -config PHEDEX/Testbed/FileMerging/Config start
Stop:  PHEDEX/Utilities/Master -config PHEDEX/Testbed/FileMerging/Config stop

*** Feed data to the agents

echo DC04Sample.*/Drops/Pending/* |
  xargs cp -rp --target-directory=MergeTest/state/merge/inbox
