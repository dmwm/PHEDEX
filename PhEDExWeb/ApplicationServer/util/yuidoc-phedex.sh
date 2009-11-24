#!/bin/sh
# The location of your yuidoc install
cd `dirname $0`
cd ..
yuidoc_home=~/YUI/yuidoc

# The location of the files to parse.  Parses subdirectories, but will fail if
# there are duplicate file names in these directories.  You can specify multiple
# source trees:
[ -d tmp ] || mkdir tmp || exit 0
parser_in=tmp

# The location to output the parser data.  This output is a file containing a 
# json string, and copies of the parsed files.
parser_out=/tmp/$USER/parser
[ -d $parser_out ] && rm -rf $parser_out && mkdir $parser_out

# The directory to put the html file outputted by the generator
generator_out=docs
[ -d $generator_out ] && rm -rf $generator_out && mkdir $generator_out

# Copy only the modules I have documented so far.
cp js/phedex-{core,datasvc,loader,module,sandbox,datatable}.js tmp
cp js/phedex-module-dummy.js tmp
cp js/phedex-component-{control,contextmenu,splitbutton}.js tmp

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

rm -rf tmp
