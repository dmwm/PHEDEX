In SC3, zips will be transferred instead of small EVD* files.
The zip itself will be published to file catalogue after the transfer. 
However, the EVD* files inside the zip also need to be published to your 
file catalogue. Utilities/ZipPublishHelper is created to help you on this.

Some tools of COBRA are employed by this script. Therefore, you need to 
have COBRA on your PHEDEX box. You can ask CMS SW manager to install ORCA 
on your grid system. Then, COBRA can be found in 
$VO_CMS_SW_DIR/Releases/COBRA/COBRA_X_X_X. 
Or you can install COBRA by yourself using XCMSInstall.

If you use CASTOR, STAGE_HOST and STAGE_POOL need to be set correctly in 
your enviroment, since COBRA will talk to your CASTOR directly. Also, you 
need to ensure that the PFNs you give to script are in the readable from 
by COBRA applications.

To embrace ZipPublishHelper into your FileDownloadPublish, please add the 
following line below "FCpublish".

$(dirname $0)/../../Utilities/ZipPublishHelper "$mycat" "$locpfn" \
    $VO_CMS_SW_DIR/Releases/COBRA/COBRA_8_5_0 || exit $?

If you use dCache and have problems, you can contact Jens.
