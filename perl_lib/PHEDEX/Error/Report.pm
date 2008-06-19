#/usr/bin/perl -w

# a module for output of error summary in variouse formats
# first user is ErrorSiteQuery
# Then InspectPhedexLog will also be ported

package PHEDEX::Error::Report;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(XMLout);

use PHEDEX::Error::ErrorOrigin;

sub XMLout() {
    my $errinfo = shift;
    my $fname = shift;
    my %options = @_;

    open OUT, ">".$fname or die "can not open $fname for writing: $!\n";
    
    print OUT "<ErrorPerSite>\n";
    
    foreach my $from (sort {$a <=> $b} keys %$errinfo) {
	print OUT "<fromsite name=\"$from\">\n";
	foreach my $to (sort {$a <=> $b} keys %{$errinfo->{$from}}) {
	    my $toh = $errinfo->{$from}{$to};
	    print OUT "<tosite name=\"$to\">\n";
	    foreach my $reason (sort { $toh->{$b}{num} <=> $toh->{$a}{num} } keys %$toh ) {
		print OUT "<reason n=\"$errinfo->{$from}{$to}{$reason}{num}\"";
		if ($options{GETERRORORIGIN}) {
		    my $origin = &getErrorOrigin($reason);
		    print OUT " origin=\"$origin\"";
		}
		print OUT " >\n";
		print OUT "$reason\n";
		foreach my $t (@{$errinfo->{$from}{$to}{$reason}{time}}) {
		    print OUT "<time t=\"$t\"/>\n";
		}
		print OUT "</reason>\n";
	    }
	    print OUT "</tosite>\n";
	}
	print OUT "</fromsite>\n";
    }
    
    print OUT "</ErrorPerSite>";
}

1;
