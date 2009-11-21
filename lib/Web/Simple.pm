package Web::Simple;

use strict;
use warnings FATAL => 'all';

sub setup_all_strictures {
  strict->import;
  warnings->import(FATAL => 'all');
}

sub setup_dispatch_strictures {
  setup_all_strictures();
  warnings->unimport('syntax');
  warnings->import(FATAL => qw(
    ambiguous bareword digit parenthesis precedence printf
    prototype qw reserved semicolon
  ));
}

sub import {
  setup_dispatch_strictures();
  my ($class, $app_package) = @_;
  $class->_export_into($app_package);
}

sub _export_into {
  my ($class, $app_package) = @_;
  {
    no strict 'refs';
    *{"${app_package}::dispatch"} = sub {
      $app_package->_setup_dispatcher(@_);
    };
    *{"${app_package}::filter_response"} = sub (&) {
      $app_package->_construct_response_filter($_[0]);
    };
    *{"${app_package}::redispatch_to"} = sub {
      $app_package->_construct_redispatch($_[0]);
    };
    *{"${app_package}::default_config"} = sub {
      $app_package->_setup_default_config(@_);
    };
    *{"${app_package}::self"} = \${"${app_package}::self"};
    require Web::Simple::Application;
    unshift(@{"${app_package}::ISA"}, 'Web::Simple::Application');
  }
  (my $name = $app_package) =~ s/::/\//g;
  $INC{"${name}.pm"} = 'Set by "use Web::Simple;" invocation';
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

and creates a $self global variable in your application package, so you can
use $self in dispatch subs without violating strict (Web::Simple::Application
arranges for dispatch subroutines to have the correct $self in scope when
this happens).

Finally, import sets

  $INC{"NameOfApplication.pm"} = 'Set by "use Web::Simple;" invocation';

so that perl will not attempt to load the application again even if

  require NameOfApplication;

is encountered in other code.

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
you should only run default_config once - calling it a second time will
cause an exception to be thrown.

=head2 dispatch

  dispatch [
    sub (GET) {
      [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
    },
    sub () {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
    }
  ];

The dispatch subroutine calls NameOfApplication->_setup_dispatcher with
the subroutines passed to it, which then creates your Web::Simple
application's dispatcher from these subs. The prototype of the subroutine
is expected to be a Web::Simple dispatch specification (see
L</DISPATCH SPECIFICATIONS> below for more details), and the body of the
subroutine is the code to execute if the specification matches. See
L</DISPATCH STRATEGY> below for details on how the Web::Simple dispatch
system uses the return values of these subroutines to determine how to
continue, alter or abort dispatch.

Note that _setup_dispatcher creates a

  sub _dispatcher {
    return <root dispatcher object here>;
  }

method in your class so as with default_config, calling dispatch a second time
will result in an exception.

=head2 response_filter

  response_filter {
    # Hide errors from the user because we hates them, preciousss
    if (ref($_[1]) eq 'ARRAY' && $_[1]->[0] == 500) {
      $_[1] = [ 200, @{$_[1]}[1..$#{$_[1]}] ];
    }
    return $_[1];
  };

The response_filter subroutine is designed for use inside dispatch subroutines.

It creates and returns a special dispatcher that always matches, and calls
the block passed to it as a filter on the result of running the rest of the
current dispatch chain.

Thus the filter above runs further dispatch as normal, but if the result of
dispatch is a 500 (Internal Server Error) response, changes this to a 200 (OK)
response without altering the headers or body.

=head2 redispatch_to

  redispatch_to '/other/url';

The redispatch_to subroutine is designed for use inside dispatch subroutines.

It creates and returns a special dispatcher that always matches, and instead
of continuing dispatch re-delegates it to the start of the dispatch process,
but with the path of the request altered to the supplied URL.

Thus if you receive a POST to '/some/url' and return a redipstch to
'/other/url', the dispatch behaviour will be exactly as if the same POST
request had been made to '/other/url' instead.

=head1 DISPATCH STRATEGY

=head2 Description of the dispatcher object

Web::Simple::Dispatcher objects have three components:

=over 4

=item * match - an optional test if this dispatcher matches the request

=item * call - a routine to call if this dispatcher matches (or has no match)

=item * next - the next dispatcher to call

=back

When a dispatcher is invoked, it checks its match routine against the
request environment. The match routine may provide alterations to the
request as a result of matching, and/or arguments for the call routine.

If no match routine has been provided then Web::Simple treats this as
a success, and supplies the request environment to the call routine as
an argument.

Given a successful match, the call routine is now invoked in list context
with any arguments given to the original dispatch, plus any arguments
provided by the match result.

If this routine returns (), Web::Simple treats this identically to a failure
to match.

If this routine returns a Web::Simple::Dispatcher, the environment changes
are merged into the environment and the new dispatcher's next pointer is
set to our next pointer.

If this routine returns anything else, that is treated as the end of dispatch
and the value is returned.

On a failed match, Web::Simple invokes the next dispatcher with the same
arguments and request environment passed to the current one. On a successful
match that returned a new dispatcher, Web::Simple invokes the new dispatcher
with the same arguments but the modified request environment.

=head2 How Web::Simple builds dispatcher objects for you

In the case of the Web::Simple L</dispatch> export the match is constructed
from the subroutine prototype - i.e.

  sub (<match specification>) {
    <call code>
  }

and the 'next' pointer is populated with the next element of the array,
expect for the last element, which is given a next that will throw a 500
error if none of your dispatchers match. If you want to provide something
else as a default, a routine with no match specification always matches, so -

  sub () {
    [ 404, [ 'Content-type', 'text/plain' ], [ 'Error: Not Found' ] ]
  }

will produce a 404 result instead of a 500 by default. You can also override
the L<Web::Simple::Application/_build_final_dispatcher> method in your app.

Note that the code in the subroutine is executed as a -method- on your
application object, so if your match specification provides arguments you
should unpack them like so:

  sub (<match specification>) {
    my ($self, @args) = @_;
    ...
  }

=head2 Web::Simple match specifications

=head3 Method matches

  sub (GET ...) {

A match specification beginning with a capital letter matches HTTP requests
with that request method.

=head3 Path matches

  sub (/login) {

A match specification beginning with a / is a path match. In the simplest
case it matches a specific path. To match a path with a wildcard part, you
can do:

  sub (/user/*) {
    $self->handle_user($_[1])

This will match /user/<anything> where <anything> does not include a literal
/ character. The matched part becomes part of the match arguments. You can
also match more than one part:

  sub (/user/*/*) {
    my ($self, $user_1, $user_2) = @_;

  sub (/domain/*/user/*) {
    my ($self, $domain, $user) = @_;

and so on. To match an arbitrary number of parts, use -

  sub (/page/**) {

This will result in an element per /-separated part so matched. Note that
you can do

  sub (/page/**/edit) {

to match an arbitrary number of parts up to but not including some final
part.

=head3 Extension matches

  sub (.html) {

will match and strip .html from the path (assuming the subroutine itself
returns something, of course). This is normally used for rendering - e.g.

  sub (.html) {
    filter_response { $self->render_html($_[1]) }
  }

=head3 Combining matches

Matches may be combined with the + character - e.g.

  sub (GET+/user/*) {

Note that for legibility you are permitted to use whitespace -

  sub (GET + /user/*) {

but it will be ignored.

=cut

1;
