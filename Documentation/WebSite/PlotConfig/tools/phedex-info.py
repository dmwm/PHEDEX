#!/usr/bin/env python
# TODO bring this back via another package for command line tools
from graphtool.tools.commandline_tool import CommandLineTool
from graphtool.tools.common import parseOpts
import sys

if __name__ == '__main__':
  keywordOpts, passedOpts, givenOpts = parseOpts( sys.argv[1:] )
  me = CommandLineTool( **keywordOpts )
  me.run()

