#!/bin/csh

source `dirname $0`/environ.csh

ls -d $T0_TMDB_DROP/* | xargs -i touch '{}'/stop
