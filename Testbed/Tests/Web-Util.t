#!/usr/bin/env perl
use warnings;
use strict;
$|++;

use Test::More ( qw / no_plan / );

BEGIN 
{
    ( # test that it compiles
      use_ok    ( 'PHEDEX::Web::Util' ) and
      require_ok( 'PHEDEX::Web::Util' )
      )	or BAIL_OUT('testing prerequisites failed');
}

our @missed;
BEGIN
{
  my %tested_fields;
  open ME, "<$0" or BAIL_OUT('cannot open myself for reading');
  while ( <ME> ) {
    m%^#\s+'(\S+)'\s+checking\s*$% && $tested_fields{$1}++;
  }
  close ME;
  scalar keys %tested_fields or BAIL_OUT('cannot determine which fields we have tests for');
  scalar keys %PHEDEX::Web::Util::COMMON_VALIDATION or BAIL_OUT('cannot determine which fields need testing');
  foreach ( keys %PHEDEX::Web::Util::COMMON_VALIDATION ) {
    defined($tested_fields{$_}) || push @missed, $_;
  }
}

# returns 1 if passed subref and args die, 0 otherwise
sub dies {
    my $subref = shift;
    eval { $subref->(@_); };
    return $@ ? 1 : 0;
}
sub lives {  return !&dies(@_); }
sub whydie { diag("died because: $@"); }

# test the test functions
(
 ok( dies(sub { die "dying"; }), 'test dies') and
 ok( lives(sub { return "I'm alive!" }),'test lives')
) or BAIL_OUT('testing utility functions fail');

# test to see if all items in COMMON_VALIDATION have tests defined
sub missed_something {
  return 0 if @missed;
  return 1;
}
ok( missed_something, 'missing tests for "' . join('", "',sort @missed) . '"');

# tests for developers who didn't read the docs
ok( dies(\&valiate_params),                                                      'no arguments');
ok( dies(\&valiate_params, {}),                                                  'no specification');
ok( dies(\&valiate_params, {}, fullof => 'crap'),                                'junk specification');
ok( dies(\&validate_params, {}, allow => []),                                    'nothing allowed');

# basic checking - good params
ok( lives(\&validate_params, {}, allow => ['foo']),                              'zero of one allowed') or whydie;
ok( lives(\&validate_params, { foo => 1 }, allow => ['foo']),                    'one of one allowed') or whydie;
ok( lives(\&validate_params, {}, allow => [qw(foo bar)]),                        'zero of two allowed') or whydie;
ok( lives(\&validate_params, { foo => 1  }, allow => [qw(foo bar)]),             'one of two allowed') or whydie;
ok( lives(\&validate_params, { foo => 1, bar => 1 }, allow => [qw(foo bar)]),    'two of two allowed') or whydie;
ok( lives(\&validate_params, { foo => 1 }, required => ['foo']),                 'one of one required') or whydie;
ok( lives(\&validate_params, { foo => 1, bar => 1 }, required => [qw(foo bar)]), 'two of two required') or whydie;
ok( lives(\&validate_params, { foo => 1, bar => 1, baz => 1 }, 
	  allow => [qw(foo bar baz)], required => [qw(foo bar)]),                'required plus one') or whydie;
ok( lives(\&validate_params, { foo => 1 }, 
	  require_one_of => [qw(foo bar)]),                                      'one of two options') or whydie;
ok( lives(\&validate_params, { foo => 1, bar => 1 }, 
	  require_one_of => [qw(foo bar)]),                                      'two of two options') or whydie;
ok( lives(\&validate_params, { foo => 1, baz => 1 }, 
	  allow => [qw(foo bar baz)], require_one_of => [qw(foo bar)]),          'option plus one') or whydie;

# basic checking - bad params
ok( dies (\&validate_params, { foo => undef }, allow => ['foo']),                'bad undef param');
ok( dies (\&validate_params, { foo => '' }, allow => ['foo']),                   'empty string param');
ok( dies (\&validate_params, { foo => {} }, allow => ['foo']),                   'bad type param');
ok( dies (\&validate_params, { bar => 1 }, allow => ['foo']),                    'unknown param');
ok( dies (\&validate_params, { foo => [qw(one two)] }),                          'no arrays');
ok( dies (\&validate_params, {},           required => [qw(foo)]),               'missing requirement 1');
ok( dies (\&validate_params, { foo => 1 }, required => [qw(foo bar)]),           'missing requirement 2');
ok( dies (\&validate_params, { foo => 1 }, 
	  allow => [qw(foo bar)],  required => [qw(bar)]),                       'missing requirement 3');
ok( dies (\&validate_params, {},
	  allow => [qw(foo bar)],  required_one_of => [qw(bar baz)]),            'missing option 1');
ok( dies (\&validate_params, { foo => 1 },
	  allow => [qw(foo bar)],  required_one_of => [qw(bar baz)]),            'missing option 2');

# options which affect the defaults
ok( lives(\&validate_params, { foo => '' },    allow => ['foo'], allow_empty => 1), 'empty string allowed') or whydie;
ok( lives(\&validate_params, { foo => undef }, allow => ['foo'], allow_undef => 1), 'undef allowed') or whydie;

# spec checking
my $optional_spec = { foo => { optional => 0 }};
ok( lives(\&validate_params, { foo => 1},  spec => $optional_spec),              'good optional override') or whydie;
ok( dies (\&validate_params, { },  spec => $optional_spec),                      'bad optional override');

my $type_spec = { foo => { type => Params::Validate::HASHREF } };
ok( lives(\&validate_params, { foo => {} }, spec => $type_spec),                 'good type override') or whydie;
ok( dies (\&validate_params, { foo => [] }, spec => $type_spec),                 'bad type override');

# 'regex' checking
my $regex_spec = { foo => { regex => qr/foo/ } };
ok( lives(\&validate_params, { foo => 'foo' }, spec => $regex_spec),             'good regex override') or whydie;
ok( dies (\&validate_params, { foo => 'bar' }, spec => $regex_spec),             'bad regex override');

my $callback_spec = {
    foo => { 
	callbacks => { 'TheOne' => sub { return $_[0] eq 'one' } }
    } 
};
ok( lives(\&validate_params, { foo => 'one' }, spec => $callback_spec),             'good callback') or whydie;
ok( dies (\&validate_params, { foo => 'two' }, spec => $callback_spec),             'bad callback');

# 'using' checking
my $using_spec;

# 'dataset' checking
$using_spec = { foo => { using => 'dataset' } };
ok( lives(\&validate_params, { foo => '/a/b/c' }, spec => $using_spec),             'good dataset') or whydie;
ok( dies (\&validate_params, { foo => '/a/b/c/d' }, spec => $using_spec),           'bad dataset: 1');
ok( dies (\&validate_params, { foo => '/a/b/c#d' }, spec => $using_spec),           'bad dataset: 2');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad dataset: 3');

# 'block' checking
$using_spec = { foo => { using => 'block' } };
ok( lives(\&validate_params, { foo => '/a/b/c#d' }, spec => $using_spec),           'good block') or whydie;
ok( dies (\&validate_params, { foo => '/a/b/c' }, spec => $using_spec),             'bad block: 1');
ok( dies (\&validate_params, { foo => '/a/b/c/d' }, spec => $using_spec),           'bad block: 2');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad block: 3');
ok( dies (\&validate_params, { foo => '*' }, spec => $using_spec),                  'bad block: 4');

# 'block_*' checking
$using_spec = { foo => { using => 'block_*' } };
ok( lives(\&validate_params, { foo => '/a/b/c#d' }, spec => $using_spec),           'good block_*: 1') or whydie;
ok( lives (\&validate_params, { foo => '*' }, spec => $using_spec),                 'good block_*: 2');
ok( lives (\&validate_params, { foo => '/a/b/c*#d' }, spec => $using_spec),         'good block_*: 3');
ok( lives (\&validate_params, { foo => '/*/*/*#*' }, spec => $using_spec),          'good block_*: 4');
ok( dies (\&validate_params, { foo => '/a/b/c' }, spec => $using_spec),             'bad block_*: 1');

# 'transfer_state' checking
$using_spec = { foo => { using => 'transfer_state' } };
ok( lives(\&validate_params, { foo => 'assigned' }, spec => $using_spec),           'good transfer_state 1') or whydie;
ok( lives(\&validate_params, { foo => 'exported' }, spec => $using_spec),           'good transfer_state 2') or whydie;
ok( lives(\&validate_params, { foo => 'transferring' }, spec => $using_spec),       'good transfer_state 3') or whydie;
ok( lives(\&validate_params, { foo => 'done' }, spec => $using_spec),               'good transfer_state 4') or whydie;
ok( dies(\&validate_params, { foo => 'bleargle' }, spec => $using_spec),            'bad transfer_state 1') or whydie;
ok( dies(\&validate_params, { foo => 'deassigned' }, spec => $using_spec),          'bad transfer_state 2') or whydie;
ok( dies(\&validate_params, { foo => 'as*igned' }, spec => $using_spec),            'bad transfer_state 3') or whydie;
ok( dies(\&validate_params, { foo => '*' }, spec => $using_spec),                   'bad transfer_state 4') or whydie;

# 'priority' checking
$using_spec = { foo => { using => 'priority' } };
ok( lives(\&validate_params, { foo => 'high' }, spec => $using_spec),               'good priority 1') or whydie;
ok( lives(\&validate_params, { foo => 'normal' }, spec => $using_spec),             'good priority 2') or whydie;
ok( lives(\&validate_params, { foo => 'low' }, spec => $using_spec),                'good priority 3') or whydie;
ok( dies(\&validate_params, { foo => 'higher' }, spec => $using_spec),              'bad priority 1') or whydie;
ok( dies(\&validate_params, { foo => 'slow' }, spec => $using_spec),                'bad priority 2') or whydie;
ok( dies(\&validate_params, { foo => '*' }, spec => $using_spec),                   'bad priority 3') or whydie;
ok( dies(\&validate_params, { foo => 'l*w' }, spec => $using_spec),                 'bad priority 4') or whydie;
ok( dies(\&validate_params, { foo => '2' }, spec => $using_spec),                   'bad priority 5') or whydie;

# 'lfn' checking
$using_spec = { foo => { using => 'lfn' } };
ok( lives(\&validate_params, { foo => '/store/foo' }, spec => $using_spec),         'good lfn') or whydie;
ok( dies (\&validate_params, { foo => 'srm:examle.com/a' }, spec => $using_spec),   'bad lfn: 1');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad lfn: 2');

# 'wildcard' checking
$using_spec = { foo => { using => '!wildcard' } };
ok( lives(\&validate_params, { foo => '/store/foo' }, spec => $using_spec),         'good !wildcard') or whydie;
ok( dies (\&validate_params, { foo => '/store/foo*' }, spec => $using_spec),        'bad !wildcard');

# 'node' checking
$using_spec = { foo => { using => 'node' } };
ok( lives(\&validate_params, { foo => 'T1_Example' }, spec => $using_spec),         'good node') or whydie;
ok( dies (\&validate_params, { foo => '/a/b/c' }, spec => $using_spec),             'bad node: 1');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad node: 2');

# 'yesno' checking
$using_spec = { foo => { using => 'yesno' } };
ok( lives(\&validate_params, { foo => 'y' }, spec => $using_spec),                  'good yesno: y') or whydie;
ok( lives(\&validate_params, { foo => 'n' }, spec => $using_spec),                  'good yesno: n') or whydie;
ok( dies (\&validate_params, { foo => 'yes' }, spec => $using_spec),                'bad yesno: 1');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad yesno: 2');

# 'onoff' checking
$using_spec = { foo => { using => 'onoff' } };
ok( lives(\&validate_params, { foo => 'on' }, spec => $using_spec),                 'good onoff: y') or whydie;
ok( lives(\&validate_params, { foo => 'off' }, spec => $using_spec),                'good onoff: n') or whydie;
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad onoff: 1');

# 'boolean' checking
$using_spec = { foo => { using => 'boolean' } };
ok( lives(\&validate_params, { foo => 'true' }, spec => $using_spec),               'good boolean: true') or whydie;
ok( lives(\&validate_params, { foo => 'false' }, spec => $using_spec),              'good boolean: false') or whydie;
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad boolean: 1');

# 'andor' checking
$using_spec = { foo => { using => 'andor' } };
ok( lives(\&validate_params, { foo => 'and' }, spec => $using_spec),                'good andor: and') or whydie;
ok( lives(\&validate_params, { foo => 'or' }, spec => $using_spec),                 'good andor: or') or whydie;
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad andor: 1');

# 'time' checking
$using_spec = { foo => { using => 'time' } };
ok( lives(\&validate_params, { foo => time() }, spec => $using_spec),               'good time: time()') or whydie;
ok( lives(\&validate_params, { foo => '2000-01-01' }, spec => $using_spec),         'good time: date') or whydie;
ok( lives(\&validate_params, { foo => '2000-01-01:01:01:01' }, spec => $using_spec),'good time: datetime') or whydie;
ok( lives(\&validate_params, { foo => 'last_hour' }, spec => $using_spec),          'good time: hour') or whydie;
ok( lives(\&validate_params, { foo => 'last_day' }, spec => $using_spec),           'good time: day') or whydie;
ok( lives(\&validate_params, { foo => 'last_7days' }, spec => $using_spec),         'good time: 7days') or whydie;
ok( lives(\&validate_params, { foo => 'P20H12M' }, spec => $using_spec),            'good time: ISO8601') or whydie;
ok( dies (\&validate_params, { foo => 'yesterday'  }, spec => $using_spec),         'bad time: 1');
ok( dies (\&validate_params, { foo => ';rm -rf /;' }, spec => $using_spec),         'bad time: 2');
$using_spec = { foo => { using => 'regex' } };
ok( lives(\&validate_params, { foo => 'abc' }, spec => $using_spec),                'good regex: abc') or whydie;
ok( lives(\&validate_params, { foo => 'a[b](c)' }, spec => $using_spec),            'good regex: a(b)[c]') or whydie;
ok( dies (\&validate_params, { foo => '[' }, spec => $using_spec),                  'bad  regex: [');
ok( lives(\&validate_params, { foo => 'Could not submit' }, spec => $using_spec),   'good regex: Could not submit') or whydie;

# 'pos_int' checking
$using_spec = { foo => { using => 'pos_int' } };
ok( lives(\&validate_params, { foo => 1 }, spec => $using_spec),                    'good pos_int: 1') or whydie;
ok( dies (\&validate_params, { foo => -2 }, spec => $using_spec),                   'bad pos_int: -2');
ok( dies (\&validate_params, { foo => 1.1 }, spec => $using_spec),                  'bad pos_int: 1.1');
ok( dies (\&validate_params, { foo => 'hello' }, spec => $using_spec),              'bad pos_int: hello');

# 'pos_int_list' checking
$using_spec = { foo => { using => 'pos_int_list' } };
ok( lives(\&validate_params, { foo => 1 }, spec => $using_spec),                    'good pos_int_list: 1') or whydie;
ok( lives(\&validate_params, { foo => '1 2 3' }, spec => $using_spec),              'good pos_int_list: 1 2 3') or whydie;
ok( lives(\&validate_params, { foo => '1,2,3' }, spec => $using_spec),              'good pos_int_list: 1,2,3') or whydie;
ok( dies (\&validate_params, { foo => -2 }, spec => $using_spec),                   'bad pos_int_list: -2');
ok( dies (\&validate_params, { foo => 1.1 }, spec => $using_spec),                  'bad pos_int_list: 1.1');
ok( dies (\&validate_params, { foo => 'hello' }, spec => $using_spec),              'bad pos_int_list: hello');
ok( dies (\&validate_params, { foo => '1 doh! 3' }, spec => $using_spec),           'bad pos_int_list: doh!');

# 'pos_float' checking
$using_spec = { foo => { using => 'pos_float' } };
ok( lives(\&validate_params, { foo => 1.1 }, spec => $using_spec),                  'good pos_float 1.1');
ok( lives(\&validate_params, { foo => 1. }, spec => $using_spec),                   'good pos_float 1.');
ok( dies(\&validate_params, { foo => '.1' }, spec => $using_spec),                  'bad pos_float .1');
ok( dies(\&validate_params, { foo => -1.1 }, spec => $using_spec),                  'bad pos_float -1.1');
ok( dies(\&validate_params, { foo => '1.1e3' }, spec => $using_spec),               'bad pos_float 1.1e3');
ok( dies(\&validate_params, { foo => '2MB/s' }, spec => $using_spec),               'bad pos_float 2MB/s');

# 'int' checking
$using_spec = { foo => { using => 'int' } };
ok( lives(\&validate_params, { foo => 1 }, spec => $using_spec),                    'good int: 1') or whydie;
ok( lives(\&validate_params, { foo => -2 }, spec => $using_spec),                   'good int: -2') or whydie;
ok( dies (\&validate_params, { foo => 1.1 }, spec => $using_spec),                  'bad int: 1.1');
ok( dies (\&validate_params, { foo => 'hello' }, spec => $using_spec),              'bad int: hello');

# 'float' checking
$using_spec = { foo => { using => 'float' } };
ok( lives(\&validate_params, { foo => 1.1 }, spec => $using_spec),                  'good float 1.1');
ok( lives(\&validate_params, { foo => 1. }, spec => $using_spec),                   'good float 1.');
ok( lives(\&validate_params, { foo => -1.1 }, spec => $using_spec),                 'good float -1.1');
ok( dies(\&validate_params, { foo => '.1' }, spec => $using_spec),                  'bad float .1');
ok( dies(\&validate_params, { foo => '1.1e3' }, spec => $using_spec),               'bad float 1.1e3');
ok( dies(\&validate_params, { foo => '2MB/s' }, spec => $using_spec),               'bad float 2MB/s');

# 'hostname' checking
$using_spec = { foo => { using => 'hostname' } };
ok( lives(\&validate_params, { foo => 'www.cern.ch' }, spec => $using_spec),        'good hostname www.cern.ch');
ok( lives(\&validate_params, { foo => 'a.b.cern.ch' }, spec => $using_spec),        'good hostname a.b.cern.ch');
ok(  dies(\&validate_params, { foo => '_.b.cern.ch' }, spec => $using_spec),        'bad hostname _.b.cern.ch');
ok(  dies(\&validate_params, { foo =>    '.cern.ch' }, spec => $using_spec),        'bad hostname    .cern.ch');
ok(  dies(\&validate_params, { foo =>     'cern.ch' }, spec => $using_spec),        'bad hostname     cern.ch');
ok(  dies(\&validate_params, { foo =>  '3a.cern.ch' }, spec => $using_spec),        'bad hostname  3a.cern.ch');

# 'allowing' checking
my $allowing_spec = { foo => { allowing => [qw(one two three)] } };
ok( lives(\&validate_params, { foo => 'one' }, spec => $allowing_spec),             'good allowing: one') or whydie;
ok( lives(\&validate_params, { foo => 'three' }, spec => $allowing_spec),           'good allowing: three') or whydie;
ok( dies (\&validate_params, { foo => 1 }, spec => $allowing_spec),                 'bad allowing: 1');
ok( dies (\&validate_params, { foo => undef }, spec => $allowing_spec),             'bad allowing: undef');
ok( lives (\&validate_params, { foo => undef }, 
	   allow_undef => 1, spec => $allowing_spec),                               'good allowing: undef') or whydie;

# 'subscribe_id' checking
$using_spec = { foo => { using => 'subscribe_id' } };
ok( lives(\&validate_params, { foo => 'BLOCK:12:43' }, spec => $using_spec), 'good subscribe_id BLOCK:12:43');
ok( lives(\&validate_params, { foo => 'DATASET:12:43' }, spec => $using_spec), 'good subscribe_id DATASET:12:43');
ok( dies(\&validate_params, { foo => 'DATASET::' }, spec => $using_spec), 'bad subscribe_id DATASET::');
ok( dies(\&validate_params, { foo => 'DATASET:1:' }, spec => $using_spec), 'bad subscribe_id DATASET:1:');
ok( dies(\&validate_params, { foo => 'DATASET::1' }, spec => $using_spec), 'bad subscribe_id DATASET::1');
ok( dies(\&validate_params, { foo => 'dodosit:23:23' }, spec => $using_spec), 'bad subscribe_id dodosit:23:23');
ok( dies(\&validate_params, { foo => 'DATASET 23 23' }, spec => $using_spec), 'bad subscribe_id DATASET 23 23');

# 'loadtestp_id' checking
$using_spec = { foo => { using => 'loadtestp_id' } };
ok( lives(\&validate_params, { foo => '01:12:43' }, spec => $using_spec), 'good loadtestp_id 01:12:43');
ok( dies(\&validate_params, { foo => '1::' }, spec => $using_spec), 'bad loadtestp_id 1::');
ok( dies(\&validate_params, { foo => ':1:' }, spec => $using_spec), 'bad loadtestp_id :1:');
ok( dies(\&validate_params, { foo => '::1' }, spec => $using_spec), 'bad loadtestp_id ::1');
ok( dies(\&validate_params, { foo => 'a:23:23' }, spec => $using_spec), 'bad loadtestp_id a:23:23');
ok( dies(\&validate_params, { foo => '12 34 56' }, spec => $using_spec), 'bad loadtestp_id 12 34 56');

# 'create_dest' checking
$using_spec = { foo => { using => 'create_dest' } };
ok( lives(\&validate_params, { foo => 'T0' }, spec => $using_spec), 'good create_dest T0');
ok( lives(\&validate_params, { foo => 'T123_xyz' }, spec => $using_spec), 'good create_dest T123_xyz');
ok( lives(\&validate_params, { foo => 'T2_MV_Mirihi' }, spec => $using_spec), 'good create_dest T2_MV_Mirihi');
ok( lives(\&validate_params, { foo => -1 }, spec => $using_spec), 'good create_dest -1');
ok( lives(\&validate_params, { foo => 234 }, spec => $using_spec), 'good create_dest 234');
ok( dies(\&validate_params, { foo => 'T' }, spec => $using_spec), 'bad create_dest T');
ok( dies(\&validate_params, { foo => 'TX' }, spec => $using_spec), 'bad create_dest TX');
ok( dies(\&validate_params, { foo => '-2' }, spec => $using_spec), 'bad create_dest -2');
ok( dies(\&validate_params, { foo => '1a' }, spec => $using_spec), 'bad create_dest 1a');
ok( dies(\&validate_params, { foo => '' }, spec => $using_spec), 'bad create_dest ');

# 'create_source' checking
$using_spec = { foo => { using => 'create_source' } };
ok( lives(\&validate_params, { foo => -1 }, spec => $using_spec), 'good create_source -1');
ok( lives(\&validate_params, { foo => '/asdf/ghjk/zxcv' }, spec => $using_spec), 'good create_source -1');
ok( lives(\&validate_params, { foo => 343 }, spec => $using_spec), 'good create_source 343');
ok( dies(\&validate_params, { foo => -2 }, spec => $using_spec), 'bad create_source -2');
ok( dies(\&validate_params, { foo => '/asdf/ghjk/' }, spec => $using_spec), 'bad create_source /asdf/ghjk/');
ok( dies(\&validate_params, { foo => '/asdf/ghjk/er#w' }, spec => $using_spec), 'bad create_source /asdf/ghjk/er#w');

# 'text' checking
$using_spec = { foo => { using => 'text' } };
ok( lives(\&validate_params, { foo => 'something' }, spec => $using_spec),          'good text: 1') or whydie;
ok( lives(\&validate_params, { foo => 'something else' }, spec => $using_spec),     'good text: 2') or whydie;
ok( lives(\&validate_params, { foo => '123' }, spec => $using_spec),                'good text: 3') or whydie;
ok( lives(\&validate_params, { foo => '64-53' }, spec => $using_spec),              'good text: 4') or whydie;
ok( lives(\&validate_params, { foo => 'a _ and a -' }, spec => $using_spec),        'good text: 5') or whydie;
ok( lives(\&validate_params, { foo => 'an asterisk *' }, spec => $using_spec),      'good text: 6') or whydie;
ok( lives(\&validate_params, { foo => ' ' }, spec => $using_spec),                  'good text: 7') or whydie;
ok( lives(\&validate_params, { foo => '*' }, spec => $using_spec),                  'good text: 8') or whydie;
ok( lives(\&validate_params, { foo => ';' }, spec => $using_spec),                  'good text: 9') or whydie;
ok( lives(\&validate_params, { foo => '?' }, spec => $using_spec),                  'good text: 10') or whydie;
ok( dies(\&validate_params, { foo => '<' }, spec => $using_spec),                   'dies text: 1') or whydie;
ok( dies(\&validate_params, { foo => 'abc<def' }, spec => $using_spec),             'dies text: 2') or whydie;
ok( dies(\&validate_params, { foo => '<script>' }, spec => $using_spec),            'dies text: 3') or whydie;
ok( dies(\&validate_params, { foo => '"!@#$%^*()+=[]{}:' }, spec => $using_spec),   'dies text: 4') or whydie;
ok( dies(\&validate_params, { foo => '!<' }, spec => $using_spec),                  'dies text: 5') or whydie;

# 'view_level' checking
$using_spec = { foo => { using => 'view_level' } };
ok( lives(\&validate_params, { foo => 'dbs' }, spec => $using_spec),              'good view_level: 1') or whydie;
ok( lives(\&validate_params, { foo => 'dataset' }, spec => $using_spec),          'good view_level: 2') or whydie;
ok( lives(\&validate_params, { foo => 'block' }, spec => $using_spec),            'good view_level: 3') or whydie;
ok( lives(\&validate_params, { foo => 'file' }, spec => $using_spec),             'good view_level: 4') or whydie;
ok( dies(\&validate_params, { foo => 'adbs' }, spec => $using_spec),              'bad view_level: 1') or whydie;
ok( dies(\&validate_params, { foo => 'blockade' }, spec => $using_spec),          'bad view_level: 2') or whydie;
ok( dies(\&validate_params, { foo => 'bl*' }, spec => $using_spec),               'bad view_level: 3') or whydie;
ok( dies(\&validate_params, { foo => '*' }, spec => $using_spec),                 'bad view_level: 4') or whydie;
ok( dies(\&validate_params, { foo => ' ' }, spec => $using_spec),                 'bad view_level: 5') or whydie;
ok( dies(\&validate_params, { foo => '' }, spec => $using_spec),                  'bad view_level: 6') or whydie;

# multiple-value checking
my $multiple_spec = { foo => { multiple => 1 } };
ok( lives(\&validate_params, { foo => 'one' }, spec => $multiple_spec),          'good multiple: single') or whydie;
ok( lives(\&validate_params, { foo => [qw(one two)] },  spec => $multiple_spec), 'good multiple: multiple') or whydie;
ok( dies (\&validate_params, { foo => ['one', undef] }, spec => $multiple_spec), 'bad multiple: undef');
ok( dies (\&validate_params, { foo => ['one', ''] }, spec => $multiple_spec),    'bad multiple: empty string');
ok( dies (\&validate_params, { foo => ['one', {}] }, spec => $multiple_spec),    'bad multiple: type');

my $multiple_regex = { foo => { multiple => 1, regex => qr/one/ } };
ok( lives(\&validate_params, { foo => 'one' }, spec => $multiple_regex),           'good multiple: re x 1') or whydie;
ok( dies (\&validate_params, { foo => 'two' }, spec => $multiple_regex),           'bad multiple: re x 1');
ok( lives(\&validate_params, { foo => [qw(one onety)] }, spec => $multiple_regex), 'good multiple: re x 2') or whydie;
ok( dies (\&validate_params, { foo => [qw(one two)] },  spec => $multiple_regex),  'bad multiple: re x 2');

my $multiple_call = {
    foo => { 
	multiple => 1,
	callbacks => { 'TheOne' => sub { return $_[0] eq 'one' } }
    } 
};
ok( lives(\&validate_params, { foo => 'one' }, spec => $multiple_call),          'good multiple: call x 1') or whydie;
ok( dies (\&validate_params, { foo => 'two' }, spec => $multiple_call),          'bad multiple: call x 1');
ok( lives(\&validate_params, { foo => [qw(one one)] }, spec => $multiple_call),  'good multiple: call x 2') or whydie;
ok( dies (\&validate_params, { foo => [qw(one two)] },  spec => $multiple_call), 'bad multiple: call x 2');

# 'block_or_file' checking
$using_spec = { foo => { using => 'block_or_file' } };
ok( lives(\&validate_params, { foo => 'block' }, spec => $using_spec), 'good block_or_file block');
ok( lives(\&validate_params, { foo => 'file' }, spec => $using_spec), 'good block_or_file file');
ok( dies(\&validate_params, { foo => 'unblocked' }, spec => $using_spec), 'bad block_or_file unblocked');

# 'approval_state' checking
$using_spec = { foo => { using => 'approval_state' } };
ok( lives(\&validate_params, { foo => 'approved' }, spec => $using_spec), 'good approval_state approved');
ok( lives(\&validate_params, { foo => 'disapproved' }, spec => $using_spec), 'good approval_state disapproved');
ok( lives(\&validate_params, { foo => 'pending' }, spec => $using_spec), 'good approval_state pending');
ok( dies(\&validate_params, { foo => 'not-approved' }, spec => $using_spec), 'bad approval_state not-approved');

# 'dataitem_*' checking
$using_spec = { foo => { using => 'dataitem_*' } };
ok( lives(\&validate_params, { foo => '/' }, spec => $using_spec), 'good dataitem_* /');
ok( lives(\&validate_params, { foo => '/*asd' }, spec => $using_spec), 'good dataitem_* /*asd');
ok( lives(\&validate_params, { foo => '/a/b/c#2_3-4' }, spec => $using_spec), 'good dataitem_* /a/b/c#2_3-4');
ok( lives(\&validate_params, { foo => '///' }, spec => $using_spec), 'good dataitem_* ///');
ok( dies(\&validate_params, { foo => 'a/file/spec' }, spec => $using_spec), 'bad dataitem_* a/file/spec');
ok( dies(\&validate_params, { foo => '/a/;file/spec' }, spec => $using_spec), 'bad dataitem_* /a/;file/spec');

# 'link_kind' checking
$using_spec = { foo => { using => 'link_kind' } };
ok( lives(\&validate_params, { foo => 'WAN' }, spec => $using_spec), 'good link_kind WAN');
ok( lives(\&validate_params, { foo => 'Local' }, spec => $using_spec), 'good link_kind Local');
ok( lives(\&validate_params, { foo => 'Staging' }, spec => $using_spec), 'good link_kind Staging');
ok( lives(\&validate_params, { foo => 'Migration' }, spec => $using_spec), 'good link_kind Migration');
ok( dies(\&validate_params, { foo => 'other' }, spec => $using_spec), 'bad link_kind other');

# 'link_status' checking
$using_spec = { foo => { using => 'link_status' } };
ok( lives(\&validate_params, { foo => 'ok' }, spec => $using_spec), 'good link_status ok');
ok( lives(\&validate_params, { foo => 'deactivated' }, spec => $using_spec), 'good link_status deactivated');
ok( lives(\&validate_params, { foo => 'to_excluded' }, spec => $using_spec), 'good link_status to_excluded');
ok( lives(\&validate_params, { foo => 'from_excluded' }, spec => $using_spec), 'good link_status from_excluded');
ok( lives(\&validate_params, { foo => 'to_down' }, spec => $using_spec), 'good link_status to_down');
ok( lives(\&validate_params, { foo => 'from_down' }, spec => $using_spec), 'good link_status from_down');
ok( dies(\&validate_params, { foo => 'other' }, spec => $using_spec), 'bad link_status other');

# 'no_check' checking
$using_spec = { foo => { using => 'no_check' } };
ok( lives(\&validate_params, { foo => 'an;yth<>in${}g' }, spec => $using_spec), 'good no_check ok');

# 'request_type' checking
$using_spec = { foo => { using => 'request_type' } };
ok( lives(\&validate_params, { foo => 'xfer' }, spec => $using_spec), 'good request_type xfer');
ok( lives(\&validate_params, { foo => 'delete' }, spec => $using_spec), 'good request_type delete');
ok( dies(\&validate_params, { foo => 'other' }, spec => $using_spec), 'bad request_type other');

# 'xml' checking
$using_spec = { foo => { using => 'xml' } };
ok( lives(\&validate_params, { foo => 'abcDEF123--__##..\'\'""::==,,  >><<' }, spec => $using_spec), 'good xml lots of stuff');
# For some reason, this doesn't work. Don't worry about it ...
#ok( lives(\&validate_params, { foo => "\n" }, spec => $using_spec), 'good xml *\n*');
ok( lives(\&validate_params, { foo => "a
b" }, spec => $using_spec), 'good xml *a
b*');
ok( lives(\&validate_params, { foo => "	" }, spec => $using_spec), 'good xml *	*');
ok( dies(\&validate_params, { foo => ';' }, spec => $using_spec), 'bad xml ;');
ok( dies(\&validate_params, { foo => '${}' }, spec => $using_spec), 'bad xml ${}');
ok( dies(\&validate_params, { foo => '[]' }, spec => $using_spec), 'bad xml []');
ok( dies(\&validate_params, { foo => '%^&*()+' }, spec => $using_spec), 'bad xml %^&*()+');
ok( dies(\&validate_params, { foo => '`!@' }, spec => $using_spec), 'bad xml `!@');
