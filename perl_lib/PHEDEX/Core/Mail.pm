package PHEDEX::Core::Mail;

=head1 NAME

PHEDEX::Core::Mail - email notification module

=cut

use strict;
use warnings;
use RFC822Addr 'validlist'; # Mail::RFC822::Address really;

use base 'Exporter';
use PHEDEX::Web::SQL;

#my $TESTING = 0;
my $TESTING = 1;
#my $TESTING_MAIL = undef;
my $TESTING_MAIL = 'huangch@fnal.gov';

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = \%h;
  bless $self, $class;
  return $self;
}

BEGIN
{
};


# testing_mode() -- set, reset or inquire test_mode
#
# args:
#    mode:
#        "yes", "on": TRUE
#        "no", "off": FALSE
#        anything TRUE/FALSE

sub testing_mode
{
    my $mode = shift;

    if (defined $mode)
    {
        if (($mode eq "yes") || ($mode eq "on"))
        {
            $TESTING = 1;
        }
        elsif (($mode eq "no") || ($mode eq "off"))
        {
            $TESTING = 0;
        }
        else
        {
            if ($mode)
            {
                $TESTING = 1;
            }
            else
            {
                $TESTING = 0;
            }
        }
    }
    return $TESTING;
}

sub testing_mail
{
    my $mail = shift;

    if ($mail)
    {
        $TESTING_MAIL = $mail;
    }

    return $TESTING_MAIL;
}

sub send_email
{
    my (%args) = @_;

    # Required arguments
    foreach (qw(subject from to message)) {
	return 0 unless exists $args{$_};
    }

    # Make to and cc arrays unique
    foreach (qw(to cc)) {
	if (exists $args{$_} && ref $args{$_} eq 'ARRAY') {
	    my %unique;
	    $unique{$_} = 1 foreach @{$args{$_}};
	    $args{$_} = [keys %unique];
	}
    }

    # Ensure names are not duplicated from to to cc
    if (exists $args{cc} && ref $args{cc} eq 'ARRAY'
	&& ref $args{to} eq 'ARRAY') {
	my @uniquecc;
	foreach my $mail (@{$args{cc}}) {
	    push @uniquecc, $mail unless grep $_ eq $mail, @{$args{to}};	    
	}
	$args{cc} = [ @uniquecc ];
    } elsif (exists $args{cc} && ref $args{cc} eq 'ARRAY'
	     && ref $args{to} ne 'ARRAY') {
	$args{cc} = [ grep $_ ne $args{to}, @{$args{cc}} ];
    } elsif (exists $args{cc}
	     && ref $args{to} eq 'ARRAY') {
	delete $args{cc} if grep $_ eq $args{cc}, @{$args{to}};
    } elsif (exists $args{cc}) {
	delete $args{cc} if $args{cc} eq $args{to};
    }
    
    foreach (qw(from to cc replyto)) {
	if (exists $args{$_} && ref $args{$_} eq 'ARRAY') {
	    $args{$_} = join(', ', @{$args{$_}});
	} elsif ( exists $args{$_} && ! $args{$_} ) {
	    $args{$_} = '';
	}
    }
    
    foreach (qw(from to cc replyto)) {
	next unless exists $args{$_};
	return 0 unless &validlist($args{$_});
    }

    # For debugging without bothering people
    if ($TESTING) {
	$args{subject} = "TESTING:  $args{subject}";
	$args{message} .= "\n\nTO:  $args{to}\n\n"; $args{to} = $TESTING_MAIL;
	if ($args{cc}) {$args{message} .= "\n\nCC:  $args{cc}\n\n"; delete $args{cc};}
    }

    (open (MAIL, "| /usr/sbin/sendmail -t")
     && (print MAIL
 	 "Subject: $args{subject}\n",
 	 "From: $args{from}\n",
 	 (exists $args{replyto} ? "Reply-To:  $args{replyto}\n" : ''),
 	 "To: $args{to}\n",
 	 (exists $args{cc} ? "Cc: $args{cc}\n" : ''),
 	 "\n",
 	 $args{message},
 	 "\n" )
     && close(MAIL))
 	or do { return 0; };
    
    return %args;
}

sub send_request_create_email
{
    my ($self, $rid) = @_;
    # calling PHEDEX::Web::SQL::getRequestData()
    my $data = PHEDEX::Web::SQL::getRequestData($self, {'REQUEST' => $rid})->[0];
    # silently quit if there is no valid request
    if (not defined $data)
    {
        return;
    }

    # Get a list of the sites involved in this request
    my %node_sites = $$self{SECMOD}->getPhedexNodeToSiteMap();
    my (%sites);  # for unique list
    foreach my $sd (qw(DESTINATIONS MOVE_SOURCES))
    {
        foreach my $node1 (@{$$data{$sd}{'NODE'}})
        {
            my $node = $$node1{'NAME'};
            $sites{ $node_sites{ $node } } = 1 if exists $node_sites{ $node};
        }
    }

    # Get the list of Global admins
    my @global_admins = $$self{SECMOD}->getUsersWithRoleForGroup('Admin', 'phedex');

    # Get the list of Data Managers affected by this request
    my @data_managers;
    foreach my $site (keys %sites) {
	push @data_managers, $$self{SECMOD}->getUsersWithRoleForSite('Data Manager', $site);
    }

    # Get the list of Site Admins affected by this request
    my @site_admins;
    foreach my $site (keys %sites) {
	push @site_admins, $$self{SECMOD}->getUsersWithRoleForSite('Site Admin', $site);
    }

    # Make a simple list of the data
    my @datalist;
    foreach my $lvl (qw(DATASET BLOCK))
    {
        foreach my $item (@{$$data{'DATA'}{'DBS'}{$lvl}})
        {
            push @datalist, $$item{NAME};
        }
    }

    # Send an email to the requestor, the global admins, the data managers, and the site admins
    my $name = $$data{'REQUESTED_BY'}{'NAME'};
    my $email = $$data{'REQUESTED_BY'}{'EMAIL'};
    my $auth = "";
    if (exists $$data{'REQUESTED_BY'}{'DN'})
    {
        $auth = "DN:  ".$$data{'REQUESTED_BY'}{'DN'};
    }
    elsif (exists $$data{'REQUESTED_BY'}{'USERNAME'})
    {
        $auth = "Username:  ".$$data{'REQUESTED_BY'}{'USERNAME'};
    }
    my $instance = $$self{CONFIG}{INSTANCES}{$$self{DBID}}{TITLE};
    # ??? DON'T KNOW $request_type!!!
    my $request_type = $self->getRequestTitle($data);
    my @to;
    push @to, $$_{EMAIL} foreach (@global_admins, @data_managers);
    my @cc = ($email);
    push @cc, $$_{EMAIL} foreach @site_admins;
    # ??? WHAT IS 'page'?
    my $admin_url = $self->myurl('fullurl' => 1,
				 'secure' => 1,
				 'page' => 'Request::View',
				 'request' => $rid);
    # ??? WHAT IS special_message?
    my $special_message = $self->get_special_request_message($data);

    my $files = $$data{'DATA'}{'FILES'};
    my $bytes = &format_size($$data{'DATA'}{'BYTES'});
    
    my $comments = $$data{'DATA'}{'USERTEXT'}{'$T'} || '';
	
    my $message =<<ENDEMAIL;
Greetings PhEDEx Data Managers,

You may wish to take note of the following new request:

* Requestor:
   Name: $name
   E-mail: $email
   Authentication: $auth
   Host: $$data{'REQUESTED_BY'}{'HOST'}
   Agent: $$data{'REQUESTED_BY'}{'AGENT'}

ENDEMAIL

    my $group_name = $$data{'GROUP'} || 'undefined';
    $message .=<<ENDEMAIL;
* Group:
   $group_name

ENDEMAIL

    $message .=<<ENDEMAIL;
* Request:
   Type:
     $request_type
   Database:
     $instance
   DBS:
     $$data{'DATA'}{'DBS'}{'NAME'}
   Data:
ENDEMAIL

    $message .= join('', map( { "     $_\n" } @datalist));

# NOT DONE YET

    my $nodes_by_point = {};
    foreach my $node1 (@{$$data{'DESTINATIONS'}{'NODE'}})
    {
        $$nodes_by_point{'Destination Node'} ||= [];
        push @{$$nodes_by_point{'Destination Node'}}, $$node1{'NAME'};
    }
    foreach my $node1 (@{$$data{'MOVE_SOURCES'}{'NODE'}})
    {
        $$nodes_by_point{'Source Node'} ||= [];
        push @{$$nodes_by_point{'Source Node'}}, $$node1{'NAME'};
    }
    foreach my $point (sort keys %$nodes_by_point) {
	$message .= "   ${point}s:\n";
	foreach my $node (sort @{$$nodes_by_point{ $point }}) {
	    my $site = $node_sites{$node} || 'unknown';
	    $message .= "     $node (Site:  $site)\n"
	}
    }

    $message .=<<ENDEMAIL;
   Size:
     $files files, $bytes
   Comments:
     "$comments"

$special_message
 
This mail has also been sent to the requestor, the PhEDEx global
admins, and the site admins of the relevant sites.

Go to
  $admin_url
to handle this request.

Yours truly,
  PhEDEx Transfer Request Web Form
ENDEMAIL
    
send_email(subject => "PhEDEx $request_type ($instance instance)",
	   to => [ @to ],
	   cc => [ @cc ],
	   from => "PhEDEx Request Form <$$self{CONFIG}{FEEDBACK_MAIL}>",
	   message => $message)
or $self->alert("Sending request email to admins failed, sorry");

}

sub send_request_update_email
{
    my ($self, $rid, $node_actions, $comments) = @_;

    my $data = $self->getRequestData($rid);

    # Build list action descriptions
    my $action_desc = '';
    foreach my $node (keys %$node_actions) {
	my $action = $$node_actions{$node};
	if ($action eq 'null') {
	    next;
	} elsif ($action eq 'disapprove' || $action eq 'stopeval') {
	    $action_desc .= "$node => Disapproved";
	} elsif ($action eq 'approve') {
	    $action_desc .= "$node => Approved";
	}
	$action_desc .= "\n";
    }

    # A list of nodes that have been acted on
    my @action_nodes = sort grep($$node_actions{$_} ne 'null', keys %$node_actions);

    # Get a list of the sites involved in this request update
    my %node_sites = $$self{SECMOD}->getPhedexNodeToSiteMap();
    my %sites;  # for unique list
    foreach my $node (@action_nodes) {
	$sites{ $node_sites{$node} } = 1 if exists $node_sites{$node};
    }
    
    # Get the list of Data Managers affected by this request
    my @data_managers;
    foreach my $site (keys %sites) {
	push @data_managers, $$self{SECMOD}->getUsersWithRoleForSite('Data Manager', $site);
    }

    # Get the list of Site Admins affected by this request
    my @site_admins;
    foreach my $site (keys %sites) {
	push @site_admins, $$self{SECMOD}->getUsersWithRoleForSite('Site Admin', $site);
    }

    my $creator_name = $$data{'REQUESTED_BY'}{'NAME'};
    my $creator_email = $$data{'REQUESTED_BY'}{'EMAIL'};
    my $detail_url = $self->myurl(page => 'Request::View', request => $rid, fullurl => 1);
    my $admin_email = $$self{SECMOD}->getEmail();
    my $msg_comments = ($comments ? "\nThe person who handled this had the following comments:\n\n\"$comments\"\n" 
			: '');
    my @cc = map { $$_{EMAIL} } @data_managers, @site_admins;
    my $nodes_str = join(', ', sort grep($$node_actions{$_} ne 'null', keys %$node_actions));
    # ??? NO STATE INFO from PHEDEX::Web::SQL::getRequestData()
    my ($n, $n_pend, $n_appr, $n_dis) = (0, 0, 0, 0);
    foreach my $sd (qw(DESTINATIONS MOVE_SOURCES))
    {
        foreach my $node (@{$$data{$sd}{'NODE'}})
        {
            $n++;
            if (!$$node{'DECIDED_BY'}{'DECISION'}) { $n_pend++; }
            elsif ($$node{'DECIDED_BY'}{'DECISION'} eq 'y') { $n_appr++; }
            elsif ($$node{'DECIDED_BY'}{'DECISION'} eq 'n') { $n_dis++; }
        }
    }
    my ($state);
    if    ($n == $n_appr)  { $state = 'Approved'; }
    elsif ($n == $n_dis)   { $state = 'Disapproved'; }
    elsif ($n == $n_pend)  { $state = 'Pending approval'; }
    elsif ($n_appr !=0)    { $state = 'Partially approved'; }
    elsif ($n_dis !=0)     { $state = 'Partially disapproved'; }
    my $newstate = $state;

    my $message=<<ENDEMAIL;
Dear $creator_name,

Your request \#$rid has been acted on by $$self{USER_NAME} for $nodes_str.  The actions taken were:

$action_desc
$msg_comments
This request is now $newstate.

To review details of the request, please go to:

$detail_url

To inquire further about this request, you may reply to this email.

This message has also been CCed to the Data Managers and Site Admins of the sites involved.

Yours truly,
  PhEDEx transfer request webpage

ENDEMAIL

&send_email(subject => "PhEDEx Request Update (request \#$rid)",
	    to => [ $creator_email ],
	    cc => [ @cc ],
	    from => "PhEDEx Web Requests <$$self{CONFIG}{FEEDBACK_MAIL}>",
	    replyto => [ $admin_email ],
	    message => $message
	    ) or $self->alert("Sending request email to admins failed, sorry");;

    return 1;
}

1;
