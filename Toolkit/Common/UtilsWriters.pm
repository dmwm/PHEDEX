sub genXMLPreamble
{
    return ("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
	    . "<!DOCTYPE POOLFILECATALOG SYSTEM \"InMemory\"><POOLFILECATALOG>\n"
	    . '  <META name="Content" type="string"/>' . "\n"
	    . '  <META name="DBoid" type="string"/>' . "\n"
	    . '  <META name="DataType" type="string"/>' . "\n"
	    . '  <META name="FileCategory" type="string"/>' . "\n"
            . '  <META name="Flags" type="string"/>' . "\n"
	    . '  <META name="dataset" type="string"/>' . "\n"
       	    . '  <META name="jobid" type="string"/>' . "\n"
	    . '  <META name="owner" type="string"/>' . "\n"
	    . '  <META name="runid" type="string"/>' . "\n");
}

sub genXMLTrailer
{
    return "</POOLFILECATALOG>\n";
}

sub genXMLCatalogue
{
    my @files = @_;

    my $content = &genXMLPreamble();
    foreach my $file (@files)
    {
	$content .= "  <File ID=\"$file->{GUID}\">\n";

	$content .= "    <physical>\n";
	foreach my $pfn (@{$file->{PFNS}}) {
	    $content .= "      <pfn filetype=\"ROOT_All\" name=\"$pfn\"/>\n";
	}
	$content .= "    </physical>\n";

	$content .= "    <logical>\n";
	foreach my $lfn (@{$file->{LFNS}}) {
	    $content .= "      <lfn name=\"$lfn\"/>\n";
	}
	$content .= "    </logical>\n";

	foreach my $m (keys %{$file->{META}}) {
	    $content .= "   <metadata att_name=\"$m\" att_value=\"$file->{META}{$m}\"/>\n";
	}
    }

    $content .= &genXMLTrailer();
    return $content;
}

sub outputCatalog
{
    my ($file, $content) = @_;
    return &output ($file, &genXMLPreamble() . $content . &genXMLTrailer());
}

1;
