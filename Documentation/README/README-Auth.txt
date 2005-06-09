* Role authentication in PhEDEx

** Introduction

This document describes the authentication model used with the V2.2
and later PhEDEx databases.  The overview is as follows:
  - All passwords will be changed
  - The cms_transfermgmt account will become admin only
  - The cms_transfermgmt_reader should be used for read-only access
  - The cms_transfermgmt_writer account is used for all updates,
    including agents running at the sites.

As an added twist, the *_writer account actually has no write access
to the database as such, only read access.  To gain write access, you
need to acquire a "role" that gives you write permissions to certain
tables (not all of them).  Each site will be given a different role,
and a unique password to go with it.  You will need to keep that
password secret, including not commit it into CVS, or otherwise
inadvertently make it public.  If you lose your password or
accidentally make it public, we can re-create your role without
disturbing the other ones.

A typical session would look like this:
  $ sqlplus cms_transfermgmt_writer/some_password@cmssg
  SQL> set role site_cern identified by another_password;
  SQL> -- you can make changes now

The agents will obviously support this automatically.  All agents in
V2.2 will take a single database-related option "-db", which is a of
the form FILE:SECTION.  The FILE is a name of the file with database
connection parameters, and SECTION will pick out a part of it (see
below).  We will provide you a skeleton file which has all the
necessary parameters except the real passwords.  The files look like
this:
   Section                 Production
   Interface               Oracle
   Database                cmssg
   AuthDBUsername          cms_transfermgmt_writer
   AuthDBPassword          FILL_ME_IN
   AuthRole                site_cern
   AuthRolePassword        FILL_ME_IN
   ConnectionLife          86400
   LogSQL                  off
   LogConnection           on


** User's process for registering for a role

Send the following information to the developer list
(cms-phedex-developers@cern.ch):

   - Site name (the name of your directory under "Custom", or the name
     used after Tn_ in agents, e.g. "CERN") 
   - The e-mail address of the contact person for the site 
   - The DN for that person's grid certificate 
   - The public key portion of your grid certificate:
     this is most likely stored as usercert.pem in your .globus
     directory

Download a copy of PHEDEX/Schema/DBParam.Site to your site, and copy
it *OUT OF THE CVS TREE!* Only modify the copy of DBParam- we would
like to ensure that no passwords get committed into CVS. As this file
contains plaintext password information, it should be treated with
similar care to your grid certificate files.

Wait to receive an encrypted file that contains the information you
need to access the TMDB. To decrypt the file you'll need to use
openssl with your public key (usercert.pem) and private key
(userkey.pem) files.

   openssl smime -decrypt			 \
	   -in <the encrypted file you received> \
	   -recip <your public key file>	 \
	   -inkey <your private key file>    

It will ask you for your password- your usual grid password- and then
write the decrypted file to stdout. This file will give you the passwords
you need to insert into your copied DBParam file.

You'll need to pass the location of this copied DBParam file to your
agents so that they can access the TMDB.


** Admin's process for registering a role

Receive an email containing the information in 1. above. Assuming then
that

   # PHEDEX_SITE=<the site name>
   # PHEDEX_EMAIL=<the user's email>
   # PHEDEX_DN=<user cert DN string>
   # PHEDEX_PUBLIC_KEY_FILE=<path to user's public key file>
   # PHEDEX_MASTER=<master account name>
   # PHEDEX_MASTER_PASS=<master account password>
   # PHEDEX_TMDB=<the TMDB tnsname, e.g. devdb>
   # PHEDEX_READER=<reader account>
   # PHEDEX_WRITER=<writer account>
   # PHEDEX_WRITER_PASS=<writer account apssword>

then, on lxgate10, to enter the new role into devdb

   cd /data/V2Nodes
   cp $PHEDEX_PUBLIC_KEY_FILE ./Keys/$PHEDEX_EMAIL
  
   ROLE_NAME=site_$PHEDEX_SITE
   ROLE_PASS=`PHEDEX/Utilities/WordMunger`

   OracleNewRole.sh $PHEDEX_MASTER/$PHEDEX_MASTER_PASS@$PHEDEX_TMDB \
       $ROLE_NAME      \
       $ROLE_PASS
   echo "insert into t_authorisation values" \
   	"(`date +%s`,'$ROLE_NAME','$PHEDEX_EMAIL','$PHEDEX_DN');" \
       | sqlplus -S $PHEDEX_MASTER/$PHEDEX_MASTER_PASS@$PHEDEX_TMDB
   OraclePrivs.sh $PHEDEX_MASTER/$PHEDEX_MASTER_PASS@$PHEDEX_TMDB \
       $PHEDEX_READER  \
       $PHEDEX_WRITER

   cat > DBParamInfo << "EOF"
   AuthDBPassword	$PHEDEX_WRITER_PASS
   AuthRole		$ROLE_NAME
   AuthRolePassword	$ROLE_PASS
   EOF       

   openssl smime -encrypt 
	   -in DBParamInfo
	   -out DBParamInfo.encrypted 
	   /data/V2Nodes/Keys/$PHEDEX_EMAIL

   rm DBParamInfo

You then need to email the remaining DBParamInfo.encrypted file to the
user who deals with it as described above.

