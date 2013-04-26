package PHEDEX::Schema::AuthMap;
use strict;
use warnings;
use Data::Dumper;

our (%params,$OUT);
%params = (
		MAP	=> 'AuthMap.txt',
		DBPARAM	=> undef,
		VERBOSE	=> 0,
		DEBUG	=> 0,
	  );


sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {};
  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  bless $self, $class;

  if ( $self->{MAP} ) {
    $self->readAuthMap();
  }

  return $self;
}

sub readAuthMap() {
  my $self = shift;
  my ($role,@comments);
  my ($first,$second,$third);

  open AM, "<$self->{MAP}" or die "$self->{MAP}: $!\n";
  while ( <AM> ) {
    print if $self->{DEBUG};
    if ( m%^#% ) {
      push @comments,$_;
      next;
    }

    chomp;
    s%#.*$%%;
    s%^\s+%%;
    s%\s+$%%;
    next if m%^$%;

# TW The rest of it goes here...
    if ( ! m%^(\S+)\s+(\S+)(\s+(\S+))?$% ) {
      die "Malformed line: '$_'\n";
    }
    $first  = lc $1;
    $second = lc $2;
    $third  = $4;

    if ( $first eq 'admin' ) {
      die "Need account name and DBParam section for admin account\n" unless $third;
      $self->{ADMIN} = { ACCOUNT => $second, SECTION => $third };
    }

    if ( $first eq 'reader' ) {
      die "Need account name and DBParam section for reader account '$second'\n" unless $third;
      $self->{READER}{$second} = $third;
    }

    if ( $first eq 'role' ) {
      die "Need CMS role list for DB role '$second'\n" unless $third;
      map { $self->{ROLE}{$second}{$_} = 1 } split(',',$third);
    }
  }

# Some sanity checks...
  die "No 'Admin' found\n"   unless $self->{ADMIN};
  die "No 'Reader's found\n" unless $self->{READER};
  die "No 'Role's found\n"   unless $self->{ROLE};
}

1;
