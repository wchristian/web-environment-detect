package Web::Simple;

use strict;
use warnings FATAL => 'all';

sub import {
  strict->import;
  warnings->import(FATAL => 'all');
  warnings->unimport('syntax');
  warnings->import(FATAL => qw(
    ambiguous bareword digit parenthesis precedence printf
    prototype qw reserved semicolon
  ));
  my ($class, $app_package) = @_;
  $class->_export_into($app_package);
}

sub _export_into {
  my ($class, $app_package) = @_;
  {
    no strict 'refs';
    *{"${app_package}::dispatch"} = sub {
      $app_package->_setup_dispatchables(@_);
    };
    *{"${app_package}::filter_response"} = sub (&) {
      $app_package->_construct_response_filter($_[0]);
    };
    *{"${app_package}::redispatch_to"} = sub {
      $app_package->_construct_redispatch($_[0]);
    };
    *{"${app_package}::default_config"} = sub {
      my @defaults = @_;
      *{"${app_package}::_default_config"} = sub { @defaults };
    };
    *{"${app_package}::self"} = \${"${app_package}::self"};
    require Web::Simple::Application;
    unshift(@{"${app_package}::ISA"}, 'Web::Simple::Application');
  }
}

=head1 NAME

Web::Simple - A quick and easy way to build simple web applications

=head1 WARNING

This is really quite new. If you're reading this from git, it means it's
really really new and we're still playing with things. If you're reading
this on CPAN, it means the stuff that's here we're probably happy with. But
only probably. So we may have to change stuff.

If we do find we have to change stuff we'll add a section explaining how to
switch your code across to the new version, and we'll do our best to make it
as painless as possible because we've got Web::Simple applications too. But
we can't promise not to change things at all. Not yet. Sorry.

=head1 SYNOPSIS

  #!/usr/bin/perl

  use Web::Simple 'HelloWorld';

  {
    package HelloWorld;

    dispatch [
      sub (GET) {
        [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
      },
      sub () {
        [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
      }
    ];
  }

  HelloWorld->run_if_script;

If you save this file into your cgi-bin as hello-world.cgi and then visit

  http://my.server.name/cgi-bin/hello-world.cgi/

you'll get the "Hello world!" string output to your browser. For more complex
examples and non-CGI deployment, see below.

=head1 WHY?

While I originally wrote Web::Simple as part of my Antiquated Perl talk for
Italian Perl Workshop 2009, I've found that having a bare minimum system for
writing web applications that doesn't drive me insane is rather nice.

The philosophy of Web::Simple is to keep to an absolute bare minimum, for
everything. It is not designed to be used for large scale applications;
the L<Catalyst> web framework already works very nicely for that and is
a far more mature, well supported piece of software.

However, if you have an application that only does a couple of things, and
want to not have to think about complexities of deployment, then Web::Simple
might be just the thing for you.

The Antiquated Perl talk can be found at L<http://www.shadowcat.co.uk/archive/conference-video/>.

=head1 DESCRIPTION

The only public interface the Web::Simple module itself provides is an
import based one -

  use Web::Simple 'NameOfApplication';

This imports 'strict' and 'warnings FATAL => "all"' into your code as well,
so you can skip the usual

  use strict;
  use warnings;

provided you 'use Web::Simple' at the top of the file. Note that we turn
on *fatal* warnings so if you have any warnings at any point from the file
that you did 'use Web::Simple' in, then your application will die. This is,
so far, considered a feature.

Calling the import also makes NameOfApplication isa Web::Simple::Application
- i.e. does the equivalent of

  {
    package NameOfApplication;
    use base qw(Web::Simple::Application);
  }

It also exports the following subroutines:

  default_config(
    key => 'value',
    ...
  );

  dispatch [ sub (...) { ... }, ... ];

  filter_response { ... };

  redispatch_to '/somewhere';

and creates the $self global variable in your application package, so you can
use $self in dispatch subs without violating strict (Web::Simple::Application
arranges for dispatch subroutines to have the correct $self in scope when
this happens).

=head1 EXPORTED SUBROUTINES

=head2 default_config

  default_config(
    one_key => 'foo',
    another_key => 'bar',
  );

  ...

  $self->config->{one_key} # 'foo'

This creates the default configuration for the application, by creating a

  sub _default_config {
     return (one_key => 'foo', another_key => 'bar');
  }

in the application namespace when executed. Note that this means that
you should only run default_config once - a second run will cause a warning
that you are override the _default_config method in your application, which
under Web::Simple will of course be fatal.

=head2 dispatch

  dispatch [
    sub (GET) {
      [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
    },
    sub () {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
    }
  ];

The dispatch subroutine calls NameOfApplication->_setup_dispatchables with
the subroutines passed to it, which then create's your Web::Simple
application's dispatcher from these subs. The prototype of the subroutine
is expected to be a Web::Simple dispatch specification (see
L</DISPATCH SPECIFICATIONS> below for more details), and the body of the
subroutine is the code to execute if the specification matches. See
L</DISPATCH STRATEGY> below for details on how the Web::Simple dispatch
system uses the return values of these subroutines to determine how to
continue, alter or abort dispatch.

Note that _setup_dispatchables creates a

  sub _dispatchables {
    return (<dispatchable objects here>);
  }

method in your class so as with default_config, calling dispatch a second time
will result in a fatal warning from your application.

=head2 response_filter

  response_filter {
    # Hide errors from the user because we hates them, preciousss
    if (ref($_[1]) eq 'ARRAY' && $_[1]->[0] == 500) {
      $_[1] = [ 200, @{$_[1]}[1..$#{$_[1]}] ];
    }
    return $_[1];
  };

The response_filter subroutine is designed for use inside dispatch subroutines.

It creates and returns a response filter object to the dispatcher,
encapsulating the block passed to it as the filter routine to call. See
L</DISPATCH STRATEGY> below for how a response filter affects dispatch.

1;

1;
