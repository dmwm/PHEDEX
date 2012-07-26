package PHEDEX::Web::SQLSpace;

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

sub getSite {
   my ($self, %h) = @_;
   my ($sql,$q,@r);

   $sql = qq{ select name, id from t_adm_node };

   $q = execute_sql( $self, $sql );
   while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
   return \@r;
}

sub insertSpace {
   my ($self, %h) = @_;
   my ($sql,%p, %p_d,%p_site,%p_s,$q,$dir_id,$site_id,$strict,$space);
   my ($temp_id);
   #warn "dumping arguments in SQL.pm",Data::Dumper->Dump([ \%h ]);
   $strict  = defined $h{strict}  ? $h{strict}  : 1;
  
   $sql = qq{ select id from t_adm_node where name=:name };
   $p_site{':name'} = $h{node};
   $q = execute_sql( $self, $sql , %p_site);
   $site_id = $q->fetchrow_hashref(); 
   if (!$site_id) { 
      die PHEDEX::Web::Util::http_error(400,'Unknown node');
#     $p_site{':site_id'}=$site_id;
#     $sql = qq{insert into t_adm_node values (:name, t_adm_node.nextval) returning id into :site_id};
#     $p_site{':site_id'}=\$temp_id;
#     $q = execute_sql( $self, $sql , %p_site);
#     #$self->{DBH}->commit();
#     $site_id->{ID} = $temp_id + 0;
   }
   #warn "dumping site_id in SQL.pm",Data::Dumper->Dump([ $site_id ]);

   $sql = qq{ select id from t_directories where dir=:dir };
   $p_d{':dir'} = $h{dir};
   $q = execute_sql( $self, $sql, %p_d );
   $dir_id = $q->fetchrow_hashref();
   #warn "dumping dir_id in SQL.pm",Data::Dumper->Dump([ $dir_id ]);
   if (!$dir_id) {
     $sql = qq{insert into t_directories values (:dir, t_directories_sequence.nextval) returning id into :dir_id};
     $p_d{':dir_id'}=\$temp_id;
     $q = execute_sql( $self, $sql, %p_d );
     #$self->{DBH}->commit();
     $dir_id->{ID} = $temp_id + 0;
   }
   #warn "dumping dir_id in SQL.pm",Data::Dumper->Dump([ $dir_id ]);

   $sql = qq{ select space from t_space_usage where timestamp=:timestamp and site_id=:site_id and dir_id=:dir_id };
   $p_s{':timestamp'} = $h{time};
   $p_s{':site_id'} = $site_id->{ID};
   $p_s{':dir_id'} = $dir_id->{ID};
   $q = execute_sql( $self, $sql ,%p_s);
   $space = $q->fetchrow_hashref();
   #warn "dumping p_s in SQL.pm",Data::Dumper->Dump([ %p_s ]);

   if (!$space) {
      $sql = qq{insert into t_space_usage values (:timestamp, :site_id, :dir_id, :space)};
      $p_s{':space'} = $h{size};
   }
   elsif ($strict) {
      die "The record already exists\n";
   }
   else {
      $sql = qq{update t_space_usage set space=:space where timestamp=:timestamp and site_id=:site_id and dir_id=:dir_id};
      $p_s{':space'} = $h{size};
   }
   $q = execute_sql( $self, $sql ,%p_s);
   #warn "dumping insert result in SQL.pm",Data::Dumper->Dump([ \$q ]);
   $self->{DBH}->commit();
   return $q;
}


sub insertDirectory {
   my ($self, %h) = @_;
   my ($sql,$q,$dir_id,%p_d,@r);

   #$sql = qq{insert into t_space_usage values (:timestamp, :site_id, :dir_id, :space)};
   $sql = qq{ select id from t_directories where dir=:dir };
   $p_d{':dir'} = $h{dir};
   $q = execute_sql( $self, $sql, %p_d );
   $dir_id = $q->fetchrow_hashref();
   #warn "dumping dir_id in SQL.pm",Data::Dumper->Dump([ \$dir_id ]);


   return $q;
}

sub querySpace {
   my ($self, %h) = @_;
   my ($sql,$q,$row,%p,%p_d,$time,%warn,@r);
   my ($filter);
 
   build_multi_filters($self,\$filter,\%p,\%h, (
	node => 'sites.name',
      ));
   if ( !exists $h{time_since} && !exists $h{time_until} ) {
      $sql = qq { select max(timestamp) max_timestamp
                  from t_space_usage spaces
		  join t_adm_node sites on spaces.site_id = sites.id
		   where $filter };
      $q = execute_sql($self,$sql,%p)->fetchrow_hashref();
      $h{time_since} = $q->{MAX_TIMESTAMP};
   }
   if ( exists $h{time_since} ) {
      $filter .= ' and spaces.timestamp >= :time_since';
      $p{':time_since'} = $h{time_since};
   }
   if ( exists $h{time_until} ) {
      $filter .= ' and spaces.timestamp <= :time_until';
      $p{':time_until'} = $h{time_until};
   }
 
      $sql = qq{ select dirs.dir, spaces.timestamp, spaces.space, sites.name from t_space_usage spaces
              join t_directories dirs on dirs.id = spaces.dir_id
              join t_adm_node sites on sites.id = spaces.site_id
              where $filter 
              order by timestamp};

   $q = execute_sql( $self, $sql, %p );
   if ($q->fetchrow_hashref()) {
      while ($_ = $q->fetchrow_hashref()) {push @r, $_;}
      #warn "dumping space query in SQL.pm",Data::Dumper->Dump([ \@r ]);
   }
   else {
      if ((!$h{time_since})&&(!$h{time_until})) {
         die "No records are available for the site you specified\n"; 
      }
      else {
         die "No records are available for the site or the period you specified\n";
      }
   }

   return \@r;
}



1;
