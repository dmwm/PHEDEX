#/usr/bin/perl -w

# a module for output of error summary in variouse formats
# first user is ErrorSiteQuery
# Then InspectPhedexLog will also be ported

package PHEDEX::Error::Report;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(XMLout);

use strict;

use PHEDEX::Error::ErrorOrigin;

sub XMLout() {
    my $errinfo = shift;
    my $fname = shift;
    my %options = @_;

    #check if we got a filehandle?
    open OUT, ">".$fname or die "can not open $fname for writing: $!\n";
    
    print OUT "<ErrorPerSite";
    
    foreach my $time (qw(STARTTIME ENDTIME STARTLOCALTIME ENDLOCALTIME)) {
	print OUT " ", lc($time), "=\"",$options{$time},"\"" if exists $options{$time};
    }

    print OUT " >\n";

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
		#need to encode here
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

__END__

#I moved xml-printing code away from InspectPhedexLog
#but ported only ErrorPerSite info
#the rest is here in a raw form, to be debugged

    open XML, ">$logx" or die "Cannot open $logx";
print XML "<InspectPhedexLog start=\"",strftime("%Y-%m-%d %H:%M:%S",localtime($datestart)),"\" end=\"",strftim\e("%Y-%m-%d %H:%M:%S",localtime($dateend)), "\">\n";

#database errors with Entitied encoding
$err = HTML::Entities::encode($err);
print XML "<error n=\"$dberrinfo{$err}{num}\">\n$err\n</error>\n";
