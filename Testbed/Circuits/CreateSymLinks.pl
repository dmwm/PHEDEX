#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Path;
use File::Copy;
use XML::Writer;
use IO::File;
use Data::UUID;

######## Options #########

# Master file related options
my $controllerMount = "/bulk/md";
my $controllerCount = 3;
my $masterFile = "master.root";
my $masterFileCount = 10;
my $masterFileSize = 50 * 1024**3;
my $createMasterFiles = 0;

# Node related declarations
my $nodeName = "sc1";
my $interfaces = 2;
my $forthIpOctet = "10";

# Dataset related options
my $blocksPerDataset = 1;
my $filesPerBlock = $controllerCount * $masterFileCount; 

# Management related stuff
my $createSymlinks = 0;
my $help = 0;

# Stupid way of checking if a mountpoint exists
sub checkMountPoint {
    my $mountToCheck = shift;
    my $procMountFile = "/proc/mounts";
    my @mountArray = ();
    
    open(FILE, $procMountFile) or die("Cannot read $procMountFile\n");
    while( my $line = <FILE>)  {
        push(@mountArray, $line);
    }
    close(FILE);

    foreach my $mount (@mountArray) {
        if ($mount =~ m/$mountToCheck/) {
            print "Mount $mountToCheck found\n";
            return 1; 
        }
    }
    
    print "Mount $mountToCheck not found\n";
    return 0;

}

GetOptions (# Master file related options
            "controllerMount=s"     => \$controllerMount,
            "controllerCount=i"     => \$controllerCount,
            
            "masterFile=s"      => \$masterFile,
            "masterFileCount=i" => \$masterFileCount,
            "masterFileSize=s"  => \$masterFileSize,

            # Node related options
            "nodeName=s"        => \$nodeName,
            "interfaces=i"      => \$interfaces,
            "forthIpOctet=i"    => \$forthIpOctet,
            
            # Dataset related options
            "blocksPerDataset=i"=> \$blocksPerDataset,
            "filesPerBlock=i"   => \$filesPerBlock,
            
            # Management related options
            "createMasterFiles" => \$createMasterFiles,
            "createSymlinks"    => \$createSymlinks,
            "help"              => \$help);

if ($help) {
    print "Available options are:\n";
    print "\n";
    print "Master file related options\n";
    print "\t -controllerMount      Defines the mount point of the controller (default is $controllerMount)\n";
    print "\t -controllerCount      Defines the number of controllers (default is $controllerCount)\n";
    print "\t -masterFile           Defines master file name (default is $masterFile)\n";
    print "\t -masterFileCount      Defines the number of master files (default is $masterFileCount)\n";
    print "\t -masterFileSize       Defines master file size (default is $masterFileSize)\n";
    print "\n";
    print "Dataset related options\n";
    print "\t -nodeName             Defines the node ID (default is $nodeName)\n";
    print "\t -interfaces           Defines the number of interfaces on a node (default is $interfaces)\n";
    print "\t -forthIpOctet         Defines the ip start of the node (default is $forthIpOctet)\n";
    print "\n";
    print "Node related options\n";
    print "\t -blocksPerDataset     Defines the number of blocks in a datast\n";
    print "\t -files                Defines the number of files in a block is the number of file given here times the number of master files\n";
    print "\n";
    print "Management related options\n";
    print "\t -createMasterFiles    Create master files? (default is $createMasterFiles)\n";
    print "\t -masterFileSize       Overrides the default master file size (of 20K). Specify in dd format\n";
    print "\t -createSymlinks       (flag) Creates the symlinks\n";
    exit 0;
}

# Create the master files if someone asks
if ($createMasterFiles) {
    # For all the controllers
    for (my $i = 1; $i <= $controllerCount; $i++) {
        my $mountPoint = $controllerMount.$i;
        
        # Check if the mount point exists
        print "Checking that $mountPoint exists\n";
        if (!checkMountPoint($mountPoint)) {
            print "Mount point $mountPoint does not exist. Exiting\n";
            exit 0;
        }

        # For all the master files which we want to create
        for (my $j = 0; $j < $masterFileCount; $j++) {
            my $bufferSize = int($masterFileSize / 1024);
            my $masterFileName = "$mountPoint/$masterFile.$j";
            print "Creating master file ";
            system("dd if=/dev/urandom of=$masterFileName bs=$bufferSize count=1024");
        }
    }
}

my (@datasets);

# For all the (network) interfaces
for (my $interface = 0; $interface < $interfaces; $interface++) {
    
    # Set dataset name
    my $datasetName = "/data/$nodeName-$interface-$forthIpOctet/RAW";
    print "Creating dataset: $datasetName\n";
    
    my $dataset;
    $dataset->{NAME} = $datasetName;
    $dataset->{XML} = "dataset-$nodeName-$interface-$forthIpOctet";
    
    push (@datasets, $dataset);
    
    for (my $blockCounter = 1; $blockCounter <= $blocksPerDataset; $blockCounter++) {
        
        # Set block name;
        my $ug = new Data::UUID;
        my $blockUID = $ug->to_string($ug->create());
        my $blockName = "$datasetName#$blockUID";
        my $block;
        $block->{NAME} = $blockName;
        $block->{ID} = substr("0000000".($blockCounter), -8);
        $block->{DATASET} = $dataset;
        
        # Add the block to the dataset
        push (@{$dataset->{BLOCKS}}, $block);
        
        for (my $fileCounter = 0; $fileCounter < $filesPerBlock; $fileCounter++) {
            my $fileID = substr("0000".($fileCounter + 1), -4);
            
            my $controllerIndex = ($fileCounter % $controllerCount) + 1;
            my $masterIndex = int($fileCounter % $masterFileCount);
            
            my $fileName = "file-$fileID-ctrl".$controllerIndex.".root";
            
            my $file;
            $file->{MASTER}             = "$controllerMount$controllerIndex/$masterFile.$masterIndex"; 
            $file->{SIZE}               = $masterFileSize;
            $file->{CONTROLLER_INDEX}   = $controllerIndex;
            $file->{NAME}               = $fileName;
            $file->{BLOCK}              = $block;
            $file->{DATASET}            = $dataset;
            
            push (@{$block->{FILES}}, $file);
        }
    }
}

foreach my $dataset (@datasets) {
    my $output = new IO::File(">$dataset->{XML}.xml");
    my $writer = new XML::Writer( OUTPUT => $output, DATA_MODE => 1, DATA_INDENT => 2);
    $writer->xmlDecl('UTF-8');
    $writer->startTag("data", "version" => "2.0");
    $writer->startTag("dbs", "name" => "SC14_DBS");
    
    # XML Dataset tag: 
    $writer->startTag("dataset", "name" => $dataset->{NAME}, "is-open" => "y");
    foreach my $block (@{$dataset->{BLOCKS}}) {
        
        $writer->startTag("block", "name" => $block->{NAME}, "is-open" => "y");
        my $path = "/store$dataset->{NAME}/000/$block->{ID}";
        
        if ($createSymlinks) {
            for (my $controllerIndex = 1; $controllerIndex <= $controllerCount; $controllerIndex++) {
                
                print "Creating $path\n";
                File::Path::make_path("$controllerMount$controllerIndex/ANSE".$block->{PATH}, { error => \my $err});
            }
        }

        foreach my $file (@{$block->{FILES}}) {
            $writer->startTag("file", "name" => "$path/$file->{NAME}", "bytes" => $file->{SIZE}, "checksum" => 0);
            symlink($file->{MASTER}, "$controllerMount$file->{CONTROLLER_INDEX}/ANSE/$path/$file->{NAME}") if $createSymlinks;
            print "$path/$file->{NAME} -> $file->{MASTER}\n";
            $writer->endTag();
        }
        $writer->endTag();
    }
    
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->end();
    $output->close();
}

exit 0;