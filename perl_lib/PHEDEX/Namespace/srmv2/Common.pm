package PHEDEX::Namespace::srmv2::Common;
# Factor out some common functionality, specifically, the 'execute' routine
use File::Basename;
use PHEDEX::Core::Catalogue ( qw / lfn2pfn / );
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
  my ($self,$ns,$file,$tfc,$call) = @_;

  my ($dir,$pfn,$result);
  $ns->proxy_check;
  $pfn = $tfc->lfn2pfn($file,$ns->Protocol());
  return $ns->Command($call,$pfn);

}

1;
