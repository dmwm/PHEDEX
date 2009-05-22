# This is what I use when I'm debugging from home

util/phedex-proxy.pl --die_on_reject --cache $HOME/datasvc_cache/ --cache_only --map yui=$HOME/public/yui --verbose --debug --cache_ro --host cmswttest.cern.ch:80 --expires 600 --redirect_to http://localhost:30002
