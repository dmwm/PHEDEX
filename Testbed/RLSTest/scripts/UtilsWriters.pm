sub outputCatalog
{
    my ($file, $content) = @_;
    $content = ("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
		. "<!DOCTYPE POOLFILECATALOG SYSTEM \"InMemory\"><POOLFILECATALOG>\n"
		. '  <META name="Content" type="string"/>' . "\n"
		. '  <META name="DBoid" type="string"/>' . "\n"
		. '  <META name="DataType" type="string"/>' . "\n"
		. '  <META name="FileCategory" type="string"/>' . "\n"
       		 . '  <META name="Flags" type="string"/>' . "\n"
		. '  <META name="dataset" type="string"/>' . "\n"
       		 . '  <META name="jobid" type="string"/>' . "\n"
		. '  <META name="owner" type="string"/>' . "\n"
		. '  <META name="runid" type="string"/>' . "\n"
		. $content. "\n"
		. "</POOLFILECATALOG>\n");

    return &output ($file, $content);
}

1;
