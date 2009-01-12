package PHEDEX::Web::API::LinkStat;
#use warning;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Core::SQL;
use POSIX;
use Data::Dumper;

# str2time -- convert YYYY-MM-DD[_hh:mm:ss] to timestamp
sub str2time
{
    my $core = shift @_;
    my $str = shift @_;
    my @t = $str =~ m!(\d{4})-(\d{2})-(\d{2})([\s_](\d{2}):(\d{2}):(\d{2}))?!;
    if (not $t[3]) # no time information, assume 00:00:00
    {
        $t[4] = 0;
        $t[5] = 0;
        $t[6] = 0;
    }
    return POSIX::mktime($t[6], $t[5], $t[4], $t[2], $t[1]-1, $t[0]-1900);
}

sub duration { return 60 * 60; }
sub invoke { return linkstat(@_); }

sub linkstat
{
    my ($core, %h) = @_;

    my $r = getLinkStat($core, %h);
    return { linkStat => { status => $r } };
}

# should be moved into PHEDEX::Web::SQL
# get info from t_history_link_stats table
sub getLinkStat
{
    my ($core, %h) = @_;
    my $sql;

    # if summary is defined, show average and/or sum
    # otherwise, show individual timebin
    if (exists $h{summary})
    {
        $sql = qq {
        select
            n1.name as from_node,
            n2.name as to_node,
            avg(priority) as avg_priority,
            sum(pend_files) as sum_pend_files,
            sum(pend_bytes) as sum_pend_bytes,
            sum(wait_files) as sum_wait_files,
            sum(wait_bytes) as sum_wait_bytes,
            sum(cool_files) as sum_cool_files,
            sum(cool_bytes) as sum_cool_bytes,
            sum(ready_files) as sum_ready_files,
            sum(ready_bytes) as sum_ready_bytes,
            sum(xfer_files) as sum_xfer_files,
            sum(xfer_bytes) as sum_xfer_bytes,
            sum(confirm_files) as sum_confirm_files,
            sum(confirm_bytes) as sum_confirm_bytes,
            avg(confirm_weight) as avg_confirm_weight,
            avg(param_rate) as avg_param_rate,
            avg(param_latency) as avg_param_latency
        from
            t_history_link_stats,
            t_adm_node n1,
            t_adm_node n2
        where
            from_node = n1.id and
            to_node = n2.id };
    }
    else
    {
        $sql = qq {
        select
            timebin,
            n1.name as from_node,
            n2.name as to_node,
            priority,
            pend_files,
            pend_bytes,
            wait_files,
            wait_bytes,
            cool_files,
            cool_bytes,
            ready_files,
            ready_bytes,
            xfer_files,
            xfer_bytes,
            confirm_files,
            confirm_bytes,
            confirm_weight,
            param_rate,
            param_latency
        from
            t_history_link_stats,
            t_adm_node n1,
            t_adm_node n2
        where
            from_node = n1.id and
            to_node = n2.id };
    }


    my $where_stmt = "";
    my %param;
    my @r;
    my $timestamp;

    # from_node -- from-node in text
    # to_node -- to-node in text
    # <time> -- since, before, or interval
    #    since -- timebin >= since
    #    before -- timebin < before
    #    interval -- one of the followings
    #        last_hour
    #        last_12hours
    #        last_day
    #        last_7days
    #        last_30days
    #        last_180days

    if ($h{from_node})
    {
        $where_stmt .= qq { and\n            n1.name = :from_node};
        $param{':from_node'} = $h{from_node};
    }

    if ($h{to_node})
    {
        $where_stmt .= qq { and\n            n2.name = :to_node};
        $param{':to_Node'} = $h{to_node};
    }

    if ($h{interval})
    {
        # possible values:
        #    last_hour
        #    last_12hours
        #    last_day
        #    last_7days
        #    last_30days
        #    last_180days

        if ($h{interval} eq "last_hour")
        {
            $timestamp = time() - 3600;
        }
        elsif ($h{interval} eq "last_12hours")
        {
            $timestamp = time() - 43200;
        }
        elsif ($h{interval} eq "last_day")
        {
            $timestamp = time() - 86400;
        }
        elsif ($h{interval} eq "last_7days")
        {
            $timestamp = time() - 604800;
        }
        elsif ($h{interval} eq "last_30days")
        {
            $timestamp = time() - 2592000;
        }
        elsif ($h{interval} eq "last_180days")
        {
            $timestamp = time() - 15552000;
        }
        else
        {
            # defulat 1 hour
            $timestamp = time() - 3600;
        }

        $where_stmt .= qq { and\n            timebin >= :timestamp };
        $param{':timestamp'} = $timestamp;
   
    }
    else
    {
        if ($h{since})
        {
            $where_stmt .= qq { and\n            timebin >= :since};
            $param{':since'} = str2time($core, $h{since});
        }
    
        if ($h{before})
        {
            $where_stmt .= qq { and\n            timebin < :before};
            $param{':before'} = str2time($core, $h{before});
        }
    }

    # now take care of the where clause

    if ($where_stmt)
    {
        $sql .= $where_stmt;
    }
    else
    {
        # limit the number of record to 1000
        $sql .= qq { and\n            rownum <= 1000};
    }

    if (exists $h{summary})
    {
        $sql .= qq {\ngroup by n1.name, n2.name };
    }
    else
    {
        $sql .= qq {\norder by timebin desc};
    }

    # now execute the query
    my $q = PHEDEX::Core::SQL::execute_sql( $core, $sql, %param );
    while ( $_ = $q->fetchrow_hashref() )
    {
        # format the time stamp
        if (exists $_->{'TIMEBIN'})
        {
            $_->{'TIMEBIN'} = strftime("%Y-%m-%d %H:%M:%S", gmtime( $_->{'TIMEBIN'}));
        }
        push @r, $_;
    }

    # return $sql, %param;
    return \@r;
}

1;
