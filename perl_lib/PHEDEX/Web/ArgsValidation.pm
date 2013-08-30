package PHEDEX::Web::ArgsValidation;

use warnings;
use strict;

# TODO: Add descriptions and true and false cases for all arguments! 

# Used for common validation for web applications.  A name pointing to either a
# *compiled* regex or a function which returns true if $_[0] is valid
# NOTE:  Do not add anything here without making a test case for it in
# PHEDEX/Testbed/Tests/Web-Util.t

#
our %ARG_DEFS = (
		 'xml'		=> { 
		     'coderef' => qr|^[A-Za-z0-9\-_\#\.\'*%?"/:=,\n\r \t<>]*$|,
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'dataitem_*'	=> { 
		     'coderef' => qr|^/[A-Za-z0-9\-_\#\.*%?/]*$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'dataset'      => { 
		     'coderef' => qr|^(/[^/\#<>]+){3}$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'block'        => { 
		     'coderef' => qr|^(/[^/\#<>]+){3}\#[^/\#<>]+$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'block_*'      => { 
		     'coderef' => qr!(^(/[^/\#<>]+){3}\#[^/\#<>]+$)|^[*%]$!, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'lfn'          => { 
		     'coderef' => qr|^/[A-Za-z-_\d#\.\/*%?]*$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'wildcard'     => { 
		     'coderef' => qr|[*%?]|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'node'         => { 
		     'coderef' => qr/^(T[\d]?[A-Za-z0-9_*%?]+|\d+)$/, 
		     'true' => ["T1_Test1_Buffer", "T1_Test2_Buffer", "T1_Test3_Buffer"],
		     'false' => ["*","any"],
		     'description' => 'valid node name T[digit]...'
		     },
		 'yesno'        => { 
		     'coderef' => sub { $_[0] eq 'y' || $_[0] eq 'n' ? 1 : 0 }, 
		     'true' => ["y","n"],
		     'false' => ["1","0"],
		     'description' => ''
		     },
		 'onoff'        => { 
		     'coderef' => sub { $_[0] eq 'on' || $_[0] eq 'off' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'boolean'      => { 
		     'coderef' => sub { $_[0] eq 'true' || $_[0] eq 'false' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'andor'        => { 
		     'coderef' => sub { $_[0] eq 'and' || $_[0] eq 'or' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'time'         => { 
		     'coderef' => sub { return defined(PHEDEX::Core::Timing::str2time($_[0])) ? 1 : 0; }, 
		     'true' => ["20010101","20010102"],
		     'false' => ["today","yesterday"],
		     'description' => 'valid time format'
		     },
		 'regex'        => { 
		     'coderef' => sub { eval { qr/$_[0]/; }; return $@ ? 0 : 1; }, # this might be slow... 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		 'pos_int'      => { 
		     'coderef' => qr/^\d+$/, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                 'pos_int_list' => { 
		     'coderef' => sub { return 1 if ! $_[0]; # allow empty list and '0'			
                                        foreach (split(/\s*[, ]+/, $_[0])) {
			                return 0 unless /^\d+$/;
			                 }
			                return 1; }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                 'pos_float'	=> { 
		     'coderef' => qr|^\d+\.?\d*$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                 'int'          => { 
		     'coderef' => qr/^-?\d+$/, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                 'float'        => { 
		     'coderef' => qr|^-?\d+\.?\d*$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'hostname'	=> { 
		     'coderef' => qr!^([a-zA-Z*%?][a-zA-Z0-9_.?*%]+|[%*])\.[a-zA-Z0-9_?%*]+\.[a-zA-Z0-9_?%*]+$!, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'unchecked'	=> { 
		     'coderef' => qr|.*|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'subscribe_id'	=> { 
		     'coderef' => qr%^(DATASET|BLOCK):\d+:\d+$%, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'loadtestp_id'	=> { 
		     'coderef' => qr|^\d+:\d+:\d+$|, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'create_dest'	=> { 
		     'coderef' => qr/^(T\d[A-Za-z0-9_]*|-1|\d+)$/, # Name, ID, or -1. Ugh... 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'create_source'=> { 
		     'coderef' => qr%^(-1|(/[^/\#]+){3}|\d+)$%, # name, ID, or -1. Blearg! 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'text'         => { 
		     'coderef' => qr|^[A-Za-z0-9_\-\., :/*'"#@=+?!^%;&\(\)~\n\r]*$|, 
		     'true' => ["grid-se3.desy.de" , "grid-se2.desy.de"],
		     'false' => ["!","!"],
		     'description' => 'valid text'
		     },
                  'priority'     => { 
		     'coderef' => sub { $_[0] eq 'high' || $_[0] eq 'normal' || $_[0] eq 'low' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'transfer_state' => { 
		     'coderef' => sub { $_[0] eq 'assigned' || $_[0] eq 'exported' || $_[0] eq 'transferring' || $_[0] eq 'done' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'view_level'   => { 
		     'coderef' => sub { $_[0] eq 'dbs' || $_[0] eq 'dataset' || $_[0] eq 'block' || $_[0] eq 'file' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'block_or_file' => { 
		     'coderef' => sub { $_[0] eq 'block' || $_[0] eq 'file' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'approval_state' => { 
		     'coderef' => sub { $_[0] eq 'approved' || $_[0] eq 'disapproved' || $_[0] eq 'pending' || $_[0] eq 'mixed' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'link_status' => { 
		     'coderef' => sub { $_[0] eq 'ok' || $_[0] eq 'deactivated' || $_[0] eq 'to_excluded' || $_[0] eq 'from_excluded' || $_[0] eq 'to_down' || $_[0] eq 'from_down' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'link_kind' => { 
		     'coderef' => sub { $_[0] eq 'WAN' || $_[0] eq 'Local' || $_[0] eq 'Staging' || $_[0] eq 'Migration' ? 1 : 0 }, 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'request_type' => { 
		     'coderef' => sub { $_[0] eq 'xfer' || $_[0] eq 'delete' ? 1 : 0 },  
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
                  'no_check' => {
		     'coderef' =>  sub { 1 }, # use with care 
		     'true' => [],
		     'false' => [],
		     'description' => ''
		     },
		   'show' => {
		     'coderef' => qr/^match$|^diff$|^neither$/,
                     'true' => ["match","diff","neither"],
                     'false' => ["any","multiple"],
                     'description' => 'type either match, diff or neither',
		     },
                   'value' => {
                     'coderef' => qr/^files$|^bytes$|^subscribed$|^group$|^custodial$/,
                     'true' => ["files","bytes","subscribed","group","custodial"],
                     'false' => ["any","multiple"],
                     'description' => 'type either files, bytes, subscribed, group or custodial',
		     },
		   'kind' => {
                     'coderef' => qr/^cksum$|^size$|^dbs$|^migration$/,
                     'true' => ["cksum","size","dbs","migration"],
                     'false' => ["any","multiple"],
                     'description' => 'type cksum, size, dbs and/or migration',
		     },   
		   'status' => {
                     'coderef' => qr/^OK$|^Fail$|^Queued$|^Active$|^Timeout$|^Expired$|^Suspended$|^Error$/,
                     'true' => ["OK","Fail","Queued","Active","Timeout","Expired","Suspended","Error"],
                     'false' => ["any","multiple"],
                     'description' => 'type OK, Fail, Queued, Active, Timeout, Expired, Suspended and/or Error',
		     },
		    'level' => {
                     'coderef' => qr/^BLOCK$|^DATASET$/,
                     'true' => ["BLOCK","DATASET"],
                     'false' => ["any","multiple"],
                     'description' => 'type either BLOCK or DATASET',
		     },
		    'strict' => {
                     'coderef' => qr/^[01]$/,
                     'true' => ["0","1"],
                     'false' => ["any","multiple"],
                     'description' => 'type either 0 or 1',
		     },   	    
		    'decision' => {
                     'coderef' => qr/^approve$|^disapprove$/,
                     'true' => ["approve","disapprove"],
                     'false' => ["any","multiple"],
                     'description' => 'type either approve or disapprove',
		     },   	    

);


1;
