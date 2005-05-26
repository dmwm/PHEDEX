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
   AuthDBPassword          edit_password_here
   AuthRole                site_cern
   AuthRolePassword        edit_password_here
   ConnectionLife          86400
   LogSQL                  off
   LogConnection           on

Now, as a check you are reading so far :) please send to the developer
list (cms-phedex-developers@cern.ch) the following information:
- Site name (the name of your directory under "Custom", or the name
  used after Tn_ in agents, e.g. "CERN")
- The e-mail address of the contact person for the site
- The DN for that person's grid certificate

We will create the roles and communicate the passwords as we receive
the information.  Just to be clear, this will only apply to the V2.2
system (aka "cmssg"), which is not available for use yet!  This does
not affect the production system we are using now (V2.1, aka "cms").

Tier-1 representatives please make sure your Tier-2 people get the
message in case they are not on the list.  (And if they are not,
please encourage them to subscribe!)

If you have any questions regarding this model, please ask on the list.
