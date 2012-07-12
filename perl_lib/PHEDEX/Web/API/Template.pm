# Change 'Tony' to match the link-name I give you, and 'Template' to match the name of
# the API you create (which must be the same as the name of the source-code file)
package PHEDEX::Web::API::Tony::Template;
use warnings;
use strict;
use PHEDEX::Core::SQL;
use PHEDEX::Web::Util;

sub duration{ return 12 * 3600; }
sub invoke {
# The $core is the data-service object, %h is the arguments
  my ($core,%h) = @_;
  my ($sql,$q,%p,@r,$k);

# Validate the input arguments. This basically means excluding '<' and '>', to prevent
# insertion of HTML tags. Leave this block of code as it is, we will replace it with a
# stricter validation when your API is accepted for release
  foreach $k ( keys %h ) {
    if ( ref($h{$k}) eq 'ARRAY' ) {
      foreach ( @{$h{$k}} ) {
        if ( m%[<>]% ) {
          return { error => "'$k' array contains an illegal value\n" };
        }
      }
    } else {
      if ( $h{$k} =~ m%[<>]% ) {
        return { error => "'$k' contains an illegal value\n" };
      }
    }
    $p{$k} = $h{$k};
  }
# %p now contains the 'laundered' version of %h. Use %p to get your arguments from here on
# Now your stuff starts...

# Insert your SQL here. This example simply retrieves information about the nodes in PhEDEx
  $sql = qq{
     select n.name,
            n.id,
            n.se_name se,
            n.kind, n.technology
       from t_adm_node n
       where
            not n.name like 'X%' 
  };

# Execute your SQL. Wrap in an eval to trap errors.
  eval { $q = PHEDEX::Core::SQL::execute_sql( $core, $sql, %p ); };

# If there was an error, return an object that indicates that fact, with some debug information
  if ( $@ ) {
    return { result => { error => 400, message => $@ }};
  };
# A better method of returning an error would be to use the http_error function, but that
# can make debugging difficult because you may not get the error message, depending on your
# client library:
# if ( $@ ) { die PHEDEX::Web::Util::http_error(400,'Something bad happened'); }

# As there was no error, pull out the data and return it. The return value from an API must
# be a hashref. So, we build an array of hashrefs for the nodes, and then return a hashref
# which contains a ref to that array. That's harder to explain than it is to do
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return { node => \@r };
}

# Perl modules should always end with '1;', to avoid compilation errors
1;
