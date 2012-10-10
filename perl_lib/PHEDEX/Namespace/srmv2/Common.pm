package PHEDEX::Namespace::srmv2::Common;
# Factor out some common functionality, specifically, the 'execute' routine
use File::Basename;
sub new
{
# Dummy new returns a valid but empty object, so the UNIVERSAL 'can' method
# can be used on it.
  return bless({},__PACKAGE__);
}

sub execute
{
# 'execute' will use the common 'Command' function to do the work, but on the
# base directory, not on the file itself. This lets it cache the results for
# an entire directory instead of having to go back to the SE for every file 
  my ($self,$ns,$file,$call) = @_;

  my ($dir,$result);
  $ns->proxy_check;
  return $ns->Command($call,$file);

}

1;
