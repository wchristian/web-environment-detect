use strictures;

package Web::Environment::Detect;

# VERSION

# ABSTRACT: recognize the calling web environment from the process environment

use base 'Exporter';

our @EXPORT_OK = qw(detect);

sub detect {
  if (caller(2)) {
    return 'PSGI';
  } elsif (
    $ENV{PHP_FCGI_CHILDREN}
    || $ENV{FCGI_ROLE}
    || $ENV{FCGI_SOCKET_PATH}
    || (-S STDIN && !$ENV{GATEWAY_INTERFACE})
    # If STDIN is a socket, almost certainly FastCGI, except for mod_cgid
    ) {
    return 'FCGI';
  } elsif ($ENV{GATEWAY_INTERFACE}) {
    return 'CGI';
  } elsif (@ARGV) {
    return 'PCLI';
  }

  die "No environment detected";
}

1;

# COPYRIGHT
