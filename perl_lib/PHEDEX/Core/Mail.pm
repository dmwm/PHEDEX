package PHEDEX::Core::Mail;

=head1 NAME

PHEDEX::Core::Mail - email notification module

=cut

use strict;
use warnings;
use base 'Exporter';

my $TESTING = 0;
my $TESTING_MAIL = undef;

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

1;
