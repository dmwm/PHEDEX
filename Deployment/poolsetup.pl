#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use English;

my %args = (LVERSION => 'RH73');

&GetOptions("root=s"   => \$args{ROOT},
	    "linuxv=s" => \$args{LVERSION},
	    "cms"      => \$args{CMS},
	    "help"     => \$args{HELP});

if ($args{HELP} || (!$args{CMS} && !$args{ROOT}) ) {
    print "Usage: poolsetup\n";
    print "--help: provides this help text\n";
    print "--cms: You already have a working CMS softrware environment. This will use scram to setup POOL tools for you\n";
    print "--root: set the root dir for your POOL tools installation (required for standalone installation)\n";
    print "--linuxv: choose between RH73 (default) or SLC3 binaries (only useful for standalone installation)\n\n";
    exit 1;
}


if ($args{CMS}) {
    my $success = installScram();
    print "Creation of script for scram based setup finished successfully. Please execute pool_setup.[c]sh script\n" if $success;
    exit 1 if (!$success);
} else {
    my $success = installStandalone($args{ROOT}, $args{LVERSION});
    print "Your standalone installation was successful !\nPlease source pool_setup.[c]sh script to setup your environment\n" if $success;
    exit 1 if (!$success);
}

exit 0;



sub installStandalone{

    my ($InstallRoot, $Lversion) = @_;
    my $RPMSource='http://cmsdoc.cern.ch/cms/oo/repos_standalone/download';
    my $versionTag='cms101';
    my $Linux_V = undef;
    my $Xerces = undef;

    my @packetlist = ();
    if ($Lversion eq 'RH73') {
	$Linux_V = 'rh73_gcc323';
	$Xerces = 'rh73_gcc32';
	@packetlist = ("LCG.POOL_1_8_1-rh73_gcc323-cms-1.i386.rpm",
		       "LCG.SEAL_1_4_3-rh73_gcc323-cms-1.i386.rpm",
		       "LCG.PI_1_2_5-rh73_gcc323-cms-1.i386.rpm",
		       "LCG.xerces-c-rh73_gcc32-2.3.0-1-cms-1.i386.rpm");
    } elsif ($Lversion eq 'SLC3') {
	$Linux_V = 'slc3_ia32_gcc323';
	$Xerces = 'slc3_ia32_gcc32';
	@packetlist = ('LCG.POOL_1_8_1-slc3_ia32_gcc323-cms-1.i386.rpm',
		       'LCG.SEAL_1_4_3-slc3_ia32_gcc323-cms-1.i386.rpm',
		       'LCG.PI_1_2_5-slc3_ia32_gcc323-cms-1.i386.rpm',
		       'LCG.xerces-c-slc3_ia32_gcc323-2.3.0-cms-1.i386.rpm');
    } else {
	die "Unsupported linux version chosen !!\n";
    }

    eval {
# prepare a local dummy RPM DB and copy over the system wide DB
	if (!-e "$InstallRoot/RPMDB") {
	    (! system("mkdir $InstallRoot/RPMDB")) or die "Couldn't create $InstallRoot/RPMDB directory.. please check permissions !\n";
	} else {
	    system("rm $InstallRoot/RPMDB/\*");
	}
	(! system("cp -r /var/lib/rpm/\* $InstallRoot/RPMDB/")) or die 'No system-wide RPMDB found ? Expected it in /var/lib/rpm....\n';
	# get rid of the index files (caused troubl in the past)
	system("rm -f $InstallRoot/RPMDB/__db\*");

# get the initial RPMs needed from the web
	if (!-e "$InstallRoot/RPMs") {
	    (! system("mkdir $InstallRoot/RPMs")) or die "Couldn't create $InstallRoot/RPMs directory.. please check permissions !\n";
	} else {
	    system("rm $InstallRoot/RPMs/\*");
	    system("rm -rf $InstallRoot/lcg") if (-e "$InstallRoot/lcg");
	}
    
	foreach my $packet (@packetlist){
	    my $cmd = "wget -P $InstallRoot/RPMs -N $RPMSource/$versionTag/$packet";
	    (! system($cmd)) or die "Couldn't download all packets.... Aborting !!\n";
	}

# lets install the stuff if we succeded to download the RPMs
	my $RPMcmd="rpm --dbpath $InstallRoot/RPMDB --prefix $InstallRoot -i --nodeps --noscripts $InstallRoot/RPMs/\*";
	
	if (system($RPMcmd)) {
	    die "Installation of RPMs failed... will clean-up and bail out\n";
	}
    };

    if ($@) {
	print "Something went wrong with the RPM installation:\n$@\nCleaning up now!\n";
	system("rm -r $InstallRoot/RPMDB") if (-e "$InstallRoot/RPMDB");
	system("rm -r $InstallRoot/RPMs") if (-e "$InstallRoot/RPMs");
	return 0; # report failure
    }

# now finally provide a script to set some environment variables (has to be sourced later)
    my $file_h;
    open($file_h,">pool_setup.sh");
    print $file_h "export LD_LIBRARY_PATH=$ENV{LD_LIBRARY_PATH}:$InstallRoot/lcg/app/releases/PI/PI_1_2_5/$Linux_V/lib:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/lib:$InstallRoot/lcg/app/releases/SEAL/SEAL_1_4_3/$Linux_V/lib:$InstallRoot/lcg/external/xerces-c/2.3.0-1/$Xerces/lib\n";
    print $file_h "export SEAL_PLUGINS=$InstallRoot/lcg/app/releases/PI/PI_1_2_5/$Linux_V/lib/modules:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/lib/modules\n";
    print $file_h "export PATH=$ENV{PATH}:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/bin\n";
    close($file_h);

    open($file_h,">pool_setup.csh");
    print $file_h "setenv LD_LIBRARY_PATH $ENV{LD_LIBRARY_PATH}:$InstallRoot/lcg/app/releases/PI/PI_1_2_5/$Linux_V/lib:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/lib:$InstallRoot/lcg/app/releases/SEAL/SEAL_1_4_3/$Linux_V/lib:$InstallRoot/lcg/external/xerces-c/2.3.0-1/$Xerces/lib\n";
    print $file_h "setenv SEAL_PLUGINS $InstallRoot/lcg/app/releases/PI/PI_1_2_5/$Linux_V/lib/modules:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/lib/modules\n";
    print $file_h "setenv PATH $ENV{PATH}:$InstallRoot/lcg/app/releases/POOL/POOL_1_8_1/$Linux_V/bin\n";
    close($file_h);

    return 1; # report success
}

sub installScram {

    my $Shell = $ENV{SHELL};
    $Shell =~ s|^/.+/||;
    if ($Shell eq 'bash' || $Shell eq 'sh' || $Shell eq 'ksh' || $Shell eq 'zsh') {
	$Shell = 'sh';
    } elsif ($Shell eq 'csh' || $Shell eq 'tcsh') {
	$Shell = 'csh';
    } else {
	print "Didn't recognize your shell: $Shell\nAborting !!!!\n";
	return 0; # report failure
    }


    #look for lates-greatest OSCAR project in scram
    my @scramprojects = `scram list |grep OSCAR |grep -v "/"`;
    if (!scalar(@scramprojects) ) {
	print 'Hmmm... no OSCAR registered in Scram. Please check your scram setup !\n';
	return 0; # report failure
    }

    my $OSCAR = pop @scramprojects;
    chomp $OSCAR;
    $OSCAR =~ s|OSCAR?||;
    $OSCAR =~ s|\W*||g;
    $OSCAR =~ m|OSCAR|;
    my ($OSCAR_B, $OSCAR_V) = ($MATCH, $POSTMATCH);

    eval {
	my $file_h;
	open($file_h,">pool_setup.$Shell");
	print $file_h "eval \`scram setroot -$Shell $OSCAR_B $OSCAR_B$OSCAR_V\`\n";
	print $file_h "eval \`scram runtime -$Shell\`\n";
	close($file_h);
    };
    if ($@) {
	print "problems creating scram script:\n$@\nAborting !\n";
	return 0; #report failure
    }

    return 1; # report success
}
