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

   $p{':request_id'} = $h{REQUEST_ID};

   $sql = qq{ 
      select a.request,
               r.type,
               a.type,
               a.decision,
               a.parent,
               a.decide_before,
               a.default_decision,
               ar.role  
         from t_req_approval_plan a
         join t_req_request r on r.id = a.request
         join t_adm_role ar on ar.id = a.role
         where r.id = :request_id 
         order by a.request asc
    };

   $q = execute_sql( $self, $sql ,%p);

   while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
   #warn "dump results ", Data::Dumper->Dump([ \@r ]);
   return \@r;
}

sub myapproval {
   my ($self, %h) = @_;
   my ($sql,$q,@r,%p);

   $p{':request_id'} = $h{REQUEST_ID};

   $sql = qq{
      select a.request as "request id",
             r.type as "request type",
             a.decision as "decision name",
             s.name as "state name",
             ra.name as "action name",
             ar.role 
         from t_req_action_ability aa
         join t_req_request r on r.type = aa.request_type
         join t_req_action ra on ra.id = aa.action
         join t_req_transition t on t.current_state = r.state
         join t_req_state s on s.id = r.state
         join t_req_approval_plan a on a.request = r.id
         join t_adm_role ar on ar.id = aa.role 
         where r.id = :request_id
           and ar.id = 5 
           and a.decision = 'u'
           and t.action = aa.action
         order by a.request asc
    };

   $q = execute_sql( $self, $sql ,%p);
   while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
   return \@r;
}


1;
