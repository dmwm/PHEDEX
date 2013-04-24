package PHEDEX::Web::DataService;

use warnings;
use strict;

use CGI qw(header path_info url param Vars remote_host user_agent request_method);

use PHEDEX::Web::Config;
use PHEDEX::Web::Core;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Loader;
use PHEDEX::Web::Format;
use PHEDEX::Web::Util;
use Data::Dumper;

our ($TESTING, $TESTING_MAIL);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;

  my $self;
  map { $self->{$_} = $h{$_}  if defined($h{$_}) } keys %h;

  # Read PhEDEx web server configuration
  my $config_file = $self->{PHEDEX_SERVER_CONFIG} ||
		       $ENV{PHEDEX_SERVER_CONFIG} ||
    die "ERROR:  Web page config file not set (PHEDEX_SERVER_CONFIG)";

  my $dev_name = $self->{PHEDEX_DEV_NAME} || $ENV{PHEDEX_DEV_NAME};

  my $config = PHEDEX::Web::Config->read($config_file, $dev_name);
  $self->{CONFIG} = $config;
  $self->{CONFIG_FILE} = $config_file;

  # Set debug mode
  $TESTING = $$config{TESTING_MODE} ? 1 : 0;
  $TESTING_MAIL = $$config{TESTING_MAIL} || undef;

  eval "use CGI::Carp qw(fatalsToBrowser)" if $TESTING;

  bless $self, $class;
  return $self;
}

sub handler
{
    local $| = 1;
    my $r = shift;
 
    my $service = PHEDEX::Web::DataService->new(REQUEST_HANDLER=>$r);
    my $service_path = $service->{CONFIG}{SERVICE_PATH};
    ($service->{PATH_INFO} = $r->uri()) =~ s%^$service_path%%;
    my $result = $service->invoke();
#   The call will return an undefined value if all went well, or for the comboLoader.
#   Or it will return a textual error message, formatted correctly, if something went wrong
#   If there was an error that was detected and handled upstream, the return value here is undefined
#   N.B. Need to make sure the webapp code handles errors properly before returning HTTP errors here
    return Apache2::Const::OK if (!defined $result);
    return Apache2::Const::OK if (!$result);
    my ($error, $message);
    if ( ref($result) eq 'ARRAY' ) {
      ($error,$message) = @{$result};
    } else {
      ($error,$message) = PHEDEX::Web::Util::decode_http_error($result);
    }

    $message =~ s% at /\S+/perl_lib/PHEDEX/\S+pm line \d+%%;

    my $error_document = PHEDEX::Web::Util::error_document( $error, $message);

    # return html error message only if the browser is Mozilla-like
    my $user_agent = user_agent() || '';
    if ($error_document and ($user_agent =~ m/Mozilla/))
    {
        $r->custom_response($error, $error_document);
    }
    else
    {
        $r->custom_response($error, $message);
    }
    $r->status($error);
    return $error;
}

sub parse_path {
  my $self = shift;
  my ($format,$db,$call,$path,$package); # = ("xml", "prod", undef);
  $package = lc $ENV{PHEDEX_PACKAGE_NAME} || 'phedex';

  $path = lc $self->{PATH_INFO}; # || "xml/prod";
  if ( $package eq 'phedex' ) {
    $format = $1 if ($path =~ m!\G/([^/]+)!g);
    $db =     $1 if ($path =~ m!\G/([^/]+)!g);
    $call =   $1 if ($path =~ m!\G/(.+)$!g);
  } elsif ( $package eq 'dmwmmon' ) {
    $format = $1 if ($path =~ m!\G/([^/]+)!g);
    $call =   $1 if ($path =~ m!\G/(.+)$!g);
    if ( $call ) {
      if ( $call eq 'storageinsert' ) {
        $db = 'write';
      }
      if ( $call eq 'storageusage' ||
           $call eq 'auth' ||
           $call eq 'secmod' ||
           $call eq 'bounce' ) {
        $db = 'read';
      }
    }
    if ( $call && !$db ) {
      warn "Using default DB access for '$call' API\n";
      $db = 'read';
    }
  }

  return ($format,$db,$call);
}

sub invoke
{
  my $self = shift;

  # Interpret the trailing path suffix: /FORMAT/DB/API?QUERY

  my ($format, $db, $call) = $self->parse_path();

  # Print documentation and exit if we have the "doc" path
  if ($format eq 'doc') {
      $self->print_doc();
      return;
  }

  if ($format eq 'combo') {
      return $self->comboLoader();
  }

  my $type;
  if    ($format eq 'xml')  { $type = 'text/xml'; }
  elsif ($format eq 'json') { $type = 'text/javascript'; }
  elsif ($format eq 'cjson') { $type = 'text/javascript'; }
  elsif ($format eq 'perl') { $type = 'text/plain'; }
  else {
      &error($format, "Unsupported format '$format'");
      return;
  }

  if (!$call) {
# TW TODO This is another hack for DMWMMON
      my $package = lc $ENV{PHEDEX_PACKAGE_NAME} || 'phedex';
      my $msg = 'API call was not defined.  Correct URL format is /FORMAT/';
      if ( $package eq 'phedex' ) { $msg .= 'INSTANCE/'; }
      $msg .= 'CALL?OPTIONS';
      &error($format,$msg);
      return;
  }

  return [400,"No DB defined for this API"] unless $db;

  my $http_now = &formatTime(&mytimeofday(), 'http');

  # Get the query string variables. Protect against bad client-code with undefined argument-values
  my @args = Vars();
  if ( scalar(@args)%2 ) {
    &error($format,"Malformed arguments (odd number of elements for hash)");
    return;
  }
  my %args = @args;
# Reformat multiple value variables into name => [ values ]
  foreach my $key (keys %args) {
      my @vals = split("\0", $args{$key});
      $args{$key} = \@vals if ($#vals > 0);
  }

  # create the core
  my $config = $self->{CONFIG};
  my ($core,$map,$newDB);

  if ( ! $config->{INSTANCES}->{$db} ) {
    $map = {
      testbed   => 'tbedi',
      testbed2  => 'tbedii',
      dev       => 'test',
      tbedi     => 'testbed',
      tbedii    => 'testbed2',
      test      => 'dev',
    };
    if ( $newDB = $map->{lc $db} ) {
      $config->{INSTANCES}{$db} = $config->{INSTANCES}{$newDB};
      $config->{INSTANCES}{$db}{ID} = $db;
    }
    if ( ! $config->{INSTANCES}->{$db} ) {
      return [404,"Invalid instance: The instance you requested is not known to this installation of the data-service\n"];
    }
  }

  eval {
      $core = new PHEDEX::Web::Core(CALL => $call,
				    VERSION => $config->{VERSION},
				    DBCONFIG => $config->{INSTANCES}->{$db}->{DBCONFIG},
				    INSTANCE => $db,
				    REQUEST_URL => url(-full=>1, -path=>1),
				    REMOTE_HOST => remote_host(), # TODO:  does this work in reverse proxy?
                                    REQUEST_METHOD => request_method(),
				    USER_AGENT => user_agent(),
				    DEBUG => 0, # DEBUG printout screws the returned data structure
				    CONFIG_FILE => $self->{CONFIG_FILE},
				    CONFIG => $self->{CONFIG},
				    CACHE_CONFIG => $config->{CACHE_CONFIG} || {},
				    SECMOD_CONFIG => $config->{SECMOD_CONFIG},
				    AUTHZ => $config->{AUTHZ},
                                    REQUEST_HANDLER => $self->{REQUEST_HANDLER},
                                    HEADERS_IN => $self->{REQUEST_HANDLER}->headers_in(),
				    );
  };
  if ($@) {
      warn "$@\n";
      return [404,"failed to initialize data service API '$call': error loading/compiling module"];
  }

  my %cache_headers;
  unless (param('nocache')) {
      # getCacheDuration needs re-implementing.
      my $duration = $core->getCacheDuration();
      $duration = 300 if !defined $duration;
      %cache_headers = (-Cache_Control => "public, must-revalidate, max-age=$duration",
		        -Date => $http_now,
		        -Last_Modified => $http_now,
		        -Expires => "+${duration}s");
      warn "cache duration for '$call' is $duration seconds\n" if $TESTING;
  }

  my $result = $core->prepare_call($format, %args);
  if ($result)
  {
      &error($format, $result);
      return;
  }

  # handle cookie(s) here
  if ($core->{SECMOD}->{COOKIE})
  {
      print header(-type => $type, -cookie => $core->{SECMOD}->{COOKIE}, %cache_headers );
  }
  else
  {
      print header(-type => $type, %cache_headers );
  }
  return $core->call($format, %args);
}

# For printing errors before we know what the error format should be
sub xml_error
{
    my $msg = shift;
    print header(-type => 'text/xml');
    &PHEDEX::Web::Format::error(*STDOUT, 'xml', $msg);
}

sub error
{
    my ($format, $msg) = @_;
    my $type;
    if    ($format eq 'xml')  { $type = 'text/xml'; }
    elsif ($format eq 'json') { $type = 'text/javascript'; }
    elsif ($format eq 'cjson') { $type = 'text/javascript'; }
    elsif ($format eq 'perl') { $type = 'text/plain'; }
    else # catch all
    {
        $type = 'text/xml';
        $format = 'xml';
    }

    print header(-type => $type);
    &PHEDEX::Web::Format::error(*STDOUT, $format, $msg);
}

sub print_doc
{
    my $self = shift;
    chdir '/tmp';
    my $service_path = $self->{CONFIG}{SERVICE_PATH};
    my $call = $self->{PATH_INFO};
    $call =~ s%^/doc/$%%;
    $call =~ s%^/doc%%;
    $call =~s%\?.*$%%;
    $call =~s%^/+%%;
    $call =~s%/+$%%;
    $call =~s%//+%/%;

    my $duration = 3600;
    my $http_now = &formatTime(&mytimeofday(), 'http');
    my %cache_headers =(-Cache_Control => "public, must-revalidate, max-age=$duration",
		        -Date => $http_now,
		        -Last_Modified => $http_now,
		        -Expires => "+${duration}s");
    print header(-type => 'text/html',%cache_headers);
    my ($module,$module_name,$loader,@lines,$line);
    $loader = PHEDEX::Core::Loader->new ( NAMESPACE => 'PHEDEX::Web::API' );
    $module_name = $loader->ModuleName($call);
    $module = $module_name || 'PHEDEX::Web::Core';

    my $package = $ENV{PHEDEX_PACKAGE_NAME} || 'phedex';
    my $package_lc = lc $package;

    # This bit is ugly. I want to add a section for the commands known in this installation,
    # but that can only be done dynamically. So I have to capture the output of the pod2html
    # command and print it, but intercept it and add extra stuff at the appropriate point.
    # I also need to check that I am setting the correct relative link for the modules.
    @lines = `perldoc -m $module |
                pod2html --header -css /$package_lc/datasvc/static/phedex_pod.css`;

    my ($commands,$count,$version);
    $version = $self->{CONFIG}{VERSION} || '';
    $version = '&nbsp;(v.' . $version . ')' if $version;
    $count = 0;
    foreach $line ( @lines ) {
        next if $line =~ m%<hr />%;
        if ( $line =~ m%^</head>% ) {
          my $meta_tag = '<meta name="PhEDEx-tag" content="PhEDEx-datasvc ' . $self->{CONFIG}{VERSION} . '" />';
          $meta_tag =~ s%PhEDEx%$package%g if $package;
          print $meta_tag,"\n";
        }
	if ( $line =~ m%<span class="block">% ) {
	  $line =~ s%</span>%$version</span>%;
	}

#       Massage PHEDEX::Web::Core output into DMWMMON or something else...
        next if $line =~ m%^\s*instance\s+%i && $package eq 'DMWMMON'; # TW TODO Yeuck!
        $line =~ s%PHEDEX%$package%g if $package;
        $line =~ s%PhEDEx%$package%g if $package;
        if ( $line =~ m%/phedex/datasvc% ) {
          $line =~ s%/phedex/datasvc%/$package_lc/datasvc%;
          if ( $package eq 'DMWMMON' ) { # TW TODO This is ugly!
            $line =~ s%xml/prod/foobar%xml/foobar%;
            $line =~ s%FORMAT/INSTANCE/CALL%FORMAT/CALL%;
          }
        }
        $line =~ s%phedex%$package_lc%g;

        if ( $line =~ m%^<table% ) {
	    $count++;
	    if ( $count != 2 ) { print $line; next; }
	    print qq{
		<h1><a name='See Also'>See Also</a></h1>
		<p>
		Documentation for the commands known in this installation<br>
		<br/>
		<table>
		<tr> <td> Command </td> <td> Module </td> </tr>
		};

	    $commands = $loader->Commands();
	    foreach ( sort keys %{$commands} ) {
		$module = $loader->ModuleName($_);
                $module =~ s%PHEDEX%$package%g if $package;
		print qq{
		     <tr>
  		     <td><strong>$_</strong></td>
		     <td><a href='$service_path/doc/$_'>$module</a></td>
		     </tr>
		    };
	    }
	    print qq{
		</table>
		</p>
		<br/>
		and <a href='.'>PHEDEX::Web::Core</a> for the core module documentation<br/>
		<br/>
		};
        }
        print $line;
    }
}

# comboLoader($core)
sub comboLoader
{
    my $core = shift;
    my ($msg,@efiles);

    # Where do I get DocumentRoot for ApplicationServer ?
    my $r = $core->{REQUEST_HANDLER};
    my $root = $r->document_root();
    my $path = $core->{CONFIG}{SERVICE_PATH} . '/app';

    my %args = Vars();
    my $files = $args{f};
    if (not $files)
    {
        return PHEDEX::Web::Util::http_error(204, undef);
    }

    my @file = split(/,/, $files);

    # resolve absolute path
# TW hack!
    foreach ( @file ) {
      s%^$path/yui%$ENV{PHEDEX_YUI_ROOT}%;
      s%^/yui%$ENV{PHEDEX_YUI_ROOT}%;
      s%^$path/protovis%$ENV{PHEDEX_PROTOVIS_ROOT}%;
      s%^/protovis%$ENV{PHEDEX_PROTOVIS_ROOT}%;
      s%^$path/(css|examples|html|images|js)%$root/ApplicationServer/$1%;
      if ( !m%^/% ) { $_ = '/' . $_; }
      push @efiles, $_;
    }

    # check suffix and consistency
    my @token = split('\.', $file[0]);
    my $type = $token[$#token];
    if (not ($type eq 'css' or $type eq 'js'))
    {
        return PHEDEX::Web::Util::http_error(415, "unknown type $file[0]. Only *.css or *.js are supported.");
    }

    my (@wrong_type, @not_found);
    my $idx = 0;
    # print Dumper(\@efiles);
    foreach (@file)
    {
        @token = split('\.', $_);
        if ($token[$#token] ne $type)
        {
            push @wrong_type, $_;
        }
    
        if (! -r $efiles[$idx])
        {
            push @not_found, $_;
        }
        $idx++;
    }

    if (@wrong_type)
    {
        $msg = qq{Wrong file type: (looking for *.$type)<br>} . join("<br>", @wrong_type);
        return PHEDEX::Web::Util::http_error(415, $msg);
    }

    if (@not_found)
    {
        $msg = qq{Not found:<br>} . join("<br>", @not_found);
        return PHEDEX::Web::Util::http_error(404, $msg);
    }

    #suppose everything is fine


    # print header
    print header(-type => "text/" . (($type eq "js")?"javascript":$type));
    # read the files
    foreach my $file (@efiles)
    {
        open FILE, $file;
	if ( $type eq 'css' ) { # CSS background URL properties may need adjusting to the local filesystem
          my ($text,$start,$end,$newUrl,$url,$tmp);
          while ( $text = <FILE>)
          {
	    while ( $text =~ m%^(.*?url\s*\(\s*)(\S+)(\s*\).*)$% ) {
	      $start = $1;
	      $url   = $2;
	      $end   = $3;
	      print $start;
	      if ( $url =~ m%^/% ) { # Absolute URL, use as-is
		print $url;
	      } elsif ( $url =~ m%^http(s)?://% ) { # Likewise, use as-is
		print $url;
	      } else { # relative URL, calculate path...
		$newUrl = $file;
		$newUrl =~ s%/[^/]+$%/%;
		$newUrl .= $url;
		do {
		  $newUrl =~ m%(/[^/.]+/\.\./)%;
		  if ( $tmp=$1 ) {
		    $newUrl =~ s%$tmp%/%;
		  }
		} while ( $tmp );
		$newUrl =~ s%^$ENV{PHEDEX_YUI_ROOT}%/yui%;
		$newUrl =~ s%^$ENV{PHEDEX_PROTOVIS_ROOT}%/protovis%;
		$newUrl =~ s%^$root/ApplicationServer%%;
	        print $path,$newUrl;
	      }
	      $text = $end;
	    }
            print $text if $text;
	  }
        } else { # type is javascript, no mangling required
          while ( <FILE> ) { print; }
        }
    }
    return undef;
}

1;
