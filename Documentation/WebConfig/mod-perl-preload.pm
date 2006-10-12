#!/usr/bin/env perl

# Setup environment for PhEDEx web server under mod_perl.
# Most of the additional modules are in $PERL5LIB already
# via the environment set in httpd-env.sh at server start.
use ModPerl::Util ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Connection ();
use Apache2::Log ();
use APR::Table ();
use ModPerl::Registry ();
use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

use CGI ();
CGI->compile(':all');
use Apache::DBI ();
use DBD::Oracle ();
use POSIX ();

1;
