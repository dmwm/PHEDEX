package PHEDEX::Namespace::Factory;

use strict;
use warnings;

use PHEDEX::Namespace::SRM;
use PHEDEX::Namespace::SRMv2;
use PHEDEX::Namespace::dCache;
use PHEDEX::Namespace::direct;
use PHEDEX::Namespace::dpm;


sub newns
{
    my $self = shift;
    my $proto = shift;

    if ($proto eq 'rfio') {
#	return PHEDEX::Namespace::Castor;
    }
    elsif ($proto eq 'srm') {
	return PHEDEX::Namespace::SRM->new(protocol=>$proto, @_);
    }
    elsif ($proto eq 'srmv2') {
	return PHEDEX::Namespace::SRMv2->new(protocol=>$proto, @_);
    }
    elsif ($proto eq 'dcache') {
	return PHEDEX::Namespace::dCache->new(protocol=>$proto, @_);
    }
    elsif ($proto eq 'direct') {
	return PHEDEX::Namespace::direct->new(protocol=>$proto, @_);;
    }
    elsif ($proto eq 'dpm') {
	return PHEDEX::Namespace::dpm->new(protocol=>$proto, @_);;
    }
    else {
	die "Protocol $proto is not known to the NS Factory\n";
    }
}

1;
