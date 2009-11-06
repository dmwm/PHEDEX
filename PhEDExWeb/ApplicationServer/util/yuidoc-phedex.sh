#!/bin/sh
# The location of your yuidoc install
yuidoc_home=~/YUI/yuidoc

# The location of the files to parse.  Parses subdirectories, but will fail if
# there are duplicate file names in these directories.  You can specify multiple
# source trees:
parser_in="/home/wildish/PHEDEX_CVS/PhEDExWeb/ApplicationServer/js"

# The location to output the parser data.  This output is a file containing a 
# json string, and copies of the parsed files.
parser_out=~/html/phedex/parser

# The directory to put the html file outputted by the generator
generator_out=~/html//phedex/docs

# The location of the template files.  Any subdirectories here will be copied
# verbatim to the destination directory.
template=$yuidoc_home/template

# The version of your project to display within the documentation.
version=1.0.0

# The version of YUI the project is using.  This effects the output for
# YUI configuration attributes.  This should start with '2' or '3'.
yuiversion=2

##############################################################################
# add -s to the end of the line to show items marked private

$yuidoc_home/bin/yuidoc.py $parser_in \
	--parseroutdir	$parser_out \
	--outputdir	$generator_out \
	--template	$template \
	--version	$version \
	--yuiversion	$yuiversion \
	--showprivate
