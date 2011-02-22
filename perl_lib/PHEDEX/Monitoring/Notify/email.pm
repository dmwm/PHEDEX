package PHEDEX::Monitoring::Notify::email;
use strict;
use warnings;
no strict 'refs';

sub new
{
  my ($proto,%h) = @_;
  my $class = ref($proto) || $proto;

  my $self = {
	       cmd	   => 'mail',
	       To	   => 'admin at site',
               Subject     => 'PhEDEx WatchDog Report',
             };

  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  $self -> set_email_address();

  return $self;

}

sub send_it {
  my ($self,$message) = @_;
  my $sendmail = $self->{cmd};
  my $to       = $self->{To};
  my $subject  = "$self->{Subject} for $self->{PHEDEX_SITE} site";

  open (MAIL,"|$sendmail $to -s '$subject'") || die "Can't open $sendmail $!\n";
  print MAIL $message;
  close(MAIL);
}

sub set_email_address
{
  my $self = shift;
  my $site_name = $self->{PHEDEX_SITE};
  my $sitedb_query = 'wget --no-check-certificate -o /dev/null -O - ' .
                     '"https://cmsweb.cern.ch/sitedb/json/index/CMSNametoAdmins?name=' . $site_name .
                     '&role=PhEDEx Contact"';
  my @email = ();
  open SITEDB, "$sitedb_query |" or die "Can't connect to sitedb $!\n";
  foreach (<SITEDB>) 
  {
    chomp;
    my @fields = split (',', $_);
    foreach (@fields) 
    { 
      m%email\S+\s+.(\S+).% or next;
      push (@email, $1);
    }
  }
  close SITEDB;
  $self->{To} = join(',',@email);
  print "Setting email address to $self->{To} for $self->{PHEDEX_SITE} site\n";
}


1;

