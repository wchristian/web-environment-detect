package Web::Simple::Application;

use Moo;

has 'config' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    +{ $self->default_config }
  },
  trigger => sub {
    my ($self, $value) = @_;
    my %default = $self->default_config;
    my @not = grep !exists $value->{$_}, keys %default;
    @{$value}{@not} = @default{@not};
  }
);

sub default_config { () }

has '_dispatcher' => (is => 'lazy');

sub _build__dispatcher {
  my $self = shift;
  require Web::Dispatch;
  require Web::Simple::DispatchNode;
  my $final = $self->_build_final_dispatcher;
  Web::Dispatch->new(
    app => sub { $self->dispatch_request(@_), $final },
    node_class => 'Web::Simple::DispatchNode',
    node_args => { app_object => $self }
  );
}

sub _build_final_dispatcher {
  [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
}

sub run_if_script {
  # ->to_psgi_app is true for require() but also works for plackup
  return $_[0]->to_psgi_app if caller(1);
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  $self->run(@_);
}

sub _run_cgi {
  my $self = shift;
  require Plack::Server::CGI;
  Plack::Server::CGI->run($self->to_psgi_app);
}

sub _run_fcgi {
  my $self = shift;
  require Plack::Server::FCGI;
  Plack::Server::FCGI->run($self->to_psgi_app);
}

sub to_psgi_app {
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  $self->_dispatcher->to_app;
}

sub run {
  my $self = shift;
  if ($ENV{PHP_FCGI_CHILDREN} || $ENV{FCGI_ROLE} || $ENV{FCGI_SOCKET_PATH}) {
    return $self->_run_fcgi;
  } elsif ($ENV{GATEWAY_INTERFACE}) {
    return $self->_run_cgi;
  }
  unless (@ARGV && $ARGV[0] =~ m{^/}) {
    return $self->_run_cli(@ARGV);
  }

  my $path = shift @ARGV;

  require HTTP::Request::Common;
  require Plack::Test;
  local *GET = \&HTTP::Request::Common::GET;

  my $request = GET($path);
  my $response;
  Plack::Test::test_psgi($self->to_psgi_app, sub { $response = shift->($request) });
  print $response->as_string;
}

sub _run_cli {
  my $self = shift;
  die $self->_cli_usage;
}

sub _cli_usage {
  "To run this script in CGI test mode, pass a URL path beginning with /:\n".
  "\n".
  "  $0 /some/path\n".
  "  $0 /\n"
}

1;

=head1 NAME

Web::Simple::Application - A base class for your Web-Simple application

=head1 DESCRIPTION

This is a base class for your L<Web::Simple> application.  You probably don't
need to construct this class yourself, since L<Web::Simple> does the 'heavy
lifting' for you in that regards.

=head1 METHODS

This class exposes the following public methods.

=head2 default_config

Merges with the C<config> initializer to provide configuration information for
your application.  For example:

  sub default_config {
    (
      title => 'Bloggery',
      posts_dir => $FindBin::Bin.'/posts',
    );
  }

Now, the C<config> attribute of C<$self>  will be set to a HashRef
containing keys 'title' and 'posts_dir'.

If you construct your application like:

  MyWebSimpleApp::Web->new(config=>{environment=>'dev'})

then C<config> will have a C<environment> key with a value of 'dev'.

=head2 run_if_script

In the case where you wish to run your L<Web::Simple> based application as a 
stand alone CGI application, you can simple do:

  ## my_web_simple_app.pl
  use MyWebSimpleApp::Web;
  MyWebSimpleApp::Web->run_if_script.

Or (even more simply) just inline the entire application:

  ## my_web_simple_app.pl
  #!/usr/bin/env perl
  use Web::Simple 'HelloWorld';

  {
    package HelloWorld;

    sub dispatch_request {
      sub (GET) {
        [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
      },
      sub () {
        [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
      }
    }
  }

  HelloWorld->run_if_script;

Additionally, you can treat the above script as though it were a standard PSGI
application file (*.psgi).  For example you can start up up with C<plackup>

  plackup my_web_simple_app.pl

Which means you can write a L<Web::Simple> application as a plain old CGI
application and seemlessly migrate to a L<Plack> based solution when you are
ready for that.

Lastly, L</run_if_script> will automatically detect and support a Fast CGI
environment.

=head2 to_psgi_app

Given a L<Web::Simple> application root namespace, return it in a form suitable
to run in inside a L<Plack> container, or in L<Plack::Builder> or in a C<*.psgi>
file:

  ## app.psgi
  use strictures 1;
  use Plack::Builder;
  use MyWebSimpleApp::Web;

  builder {
    ## enable middleware
    enable 'StackTrace';
    enable 'Debug';

    ## return application
    MyWebSimpleApp::Web->to_psgi_app;
  };

This could be run via C<plackup>, etc.  Please note the L<Plack::Builder> DSL
is optional, if you are enabling L<Plack::Middleware> internally in your
L<Web::Simple> application; your app.psgi could be as simple as:

  use MyWebSimpleApp::Web;
  MyWebSimpleApp::Web->to_psgi_app;

This means if you want to provide a 'default' set of middleware, one option is
to modify this method:

  use Web::Simple 'HelloWorld';
  use Plack::Builder;
 
  {
    package HelloWorld;

  
    around 'to_psgi_app', sub {
      my ($orig, $self) = (shift, shift);
      my $app = $self->$orig(@_); 
      builder {
        enable ...; ## whatever middleware you want
        $app;
      };
    };
  }

As always, mix and match the pieces you actually need and remember the 
L<Web::Simple> philosophy of trying to keep it as minimal and simple as possible.

=head2 run

Used for running your application under stand-alone CGI and FCGI modes. Also
useful for testing:

    my $app = MyWebSimpleApp::Web->new;
    my $c = HTTP::Request::AsCGI->new(@args)->setup;
    $app->run;

=head1 AUTHOR

Matt S. Trout <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

None required yet. Maybe this module is perfect (hahahahaha ...).

=head1 COPYRIGHT

Copyright (c) 2010 the Web::Simple L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
