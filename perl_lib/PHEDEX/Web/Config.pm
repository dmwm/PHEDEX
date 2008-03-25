#!/usr/bin/env perl

package PHEDEX::Web::Config;

use warnings;
use strict;

sub read
{
    my $self = shift;
    my $config_file = shift
	|| die "No server configuration.\n";

    my $dev_name = shift;
    if ($dev_name) {
	$config_file =~ s/DEVNAME/$dev_name/;
    }

    open (CONFIG, "< $config_file")
	|| die "$config_file: cannot read server configuration: $!\n";

    my $config = {};
    my $instance_rank = 0;
    while (1)
    {
	my $line = &parse_line($config_file);
	if (! defined $line)
	{
	    last;
	}
	elsif ($line =~ /^$/)
	{
	    next;
	}
	elsif ($line =~ /^([-a-zA-Z0-9]+):\s+(\S+)$/)
	{
	    my $name = uc $1;
	    my $value = $2;
	    $name =~ s/-/_/g;
	    
	    $$config{$name} = $value;
	}
	elsif ($line =~ /^instance:\s+([\S\s]+)$/)
	{
	    my $rest = $1;
	    my $info = {};
	    while ($rest =~ /\G([-a-z]+)\s*=\s*(\S+)\s*/g)
	    {
		my $name = uc($1);
		my $value = $2;
		$name =~ s/-/_/g;
		$$info{$name} = $value;
	    }

	    my @required = qw(ID TITLE CONNECTION);
	    my @missing = map { s/_/-/g; lc; } grep(! exists $$info{$_}, @required);
	    die "$config_file: instance is missing parameters '@missing'\n" if @missing;
	 
	    $$info{DBCONFIG} = $$config{DBPARAM}.':'.$$info{CONNECTION};
	    $$info{RANK} = $instance_rank++;
	    $$config{INSTANCES}{$$info{ID}} = $info;
	}
	else
	{
	    die "$config_file: unexpected parameters '$line'\n";
	}
    }

    close (CONFIG);
    return $config;
}

sub input_line
{
    my $line = <CONFIG>;
    return undef if ! defined $line;

    chomp($line);
    $line =~ s/#.*//;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    $line =~ s/\s+/ /;
    return $line;
}

sub parse_line
{
    my ($file) = @_;
    my $line = &input_line();
    return undef if ! defined $line;

    while (substr($line,-1,1) eq '\\')
    {
	chop($line);
	my $next = &input_line();
	die "$file: file ends in '\\', expected continued line\n"
	    if ! defined $next;
	$line .= " ";
	$line .= $next;
    }

    return $line;
}

1;
