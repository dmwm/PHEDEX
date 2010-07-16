#!/bin/sh

echo "Copy this file and fill in the first two variables to use"
exit 1

# The location of your yuidoc install
yuidoc_home=FILL_ME_IN

# The location of your webapp install
webapp_home=FILL_ME_IN

# The location of the files to parse.  Parses subdirectories, but will fail if
# there are duplicate file names in these directories.  You can specify multiple
# source trees:
parser_in=$webapp_home/js

output_root=$PWD/docs
[[ -d $output_root ]] || mkdir -p $output_root

# The location to output the parser data.  This output is a file containing a 
# json string, and copies of the parsed files.
parser_out=$output_root/parser

# The directory to put the html file outputted by the generator
generator_out=$output_root/generator

# The location of the template files.  Any subdirectories here will be copied
# verbatim to the destination directory.
#template=$yuidoc_home/template
template=$webapp_home/util/yuidoc/template

# The name of your project
project='PhEDEx WebApp'

# The url for your project
url='http://cmssw.cvs.cern.ch/cgi-bin/cmssw.cgi/COMP/PHEDEX/PhEDExWeb/ApplicationServer/'

# The version of your project to display within the documentation.
version=BETA.0.2

# The version of YUI the project is using.  This effects the output for
# YUI configuration attributes.  This should start with '2' or '3'.
yuiversion=2

##############################################################################
# add -s to the end of the line to show items marked private

$yuidoc_home/bin/yuidoc.py $parser_in -p $parser_out -o $generator_out \
  -t $template -m "$project" -u "$url"  -v $version -Y $yuiversion -s

echo $parser_out
