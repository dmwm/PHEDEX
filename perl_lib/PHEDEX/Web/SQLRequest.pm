package PHEDEX::Web::SQLRequest;

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';
use Carp;
use POSIX;
use Data::Dumper;
use PHEDEX::Core::Timing;

our @EXPORT = qw( );
our (%params);
%params = ( DBH	=> undef );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
## my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
  my $self  = $class->SUPER::new(@_);

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  bless $self, $class;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub viewApprovalPlan {
   my ($self, %h) = @_;
   my ($sql,$q,@r,%p);

   $p{':request_id'} = $h{request_id};

   $sql = qq{ 
      select a.request,
               r.type,
               a.type,
               d.decision,
               a.parent,
               a.decide_before,
               a.default_decision,
               i.name,
               i.email
         from t_req_approval_plan a
         join t_req_request r on r.id = a.request
         join t_req_decision d on d.id = a.decision
         join t_adm_client c on c.id = d.decided_by
         join t_adm_identity i on i.id = c.identity
         where r.id = :request_id 
         order by a.request asc
    };

   $q = execute_sql( $self, $sql ,%p);
   while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
   return \@r;
}

1;
