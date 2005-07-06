# set the catalogue contact strings
setenv MYSQL mysqlcatalog_mysql://phedex:phedex@cmslcgco04/phedexcat
setenv ORACLE relationalcatalog_oracle://raltest/pool_fc_test

# setup pool FC tools (POOL 1.6.5)
eval `scram setroot -csh OSCAR OSCAR_3_4_0`
eval `scram runtime -csh`

# setup Phedex Utilities

setenv PATH ${PATH}:/afs/cern.ch/user/r/rehn/scratch0/PHEDEX/Utilities
