package Web::Simple::Application;

use Moo;

has 'config' => (is => 'ro', trigger => sub {
  my ($self, $value) = @_;
  my %default = $self->_default_config;
  my @not = grep !exists $value->{$_}, keys %default;
  @{$value}{@not} = @default{@not};
});

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
  # ->as_psgi_app is true for require() but also works for plackup
  return $_[0]->to_psgi_app if caller(1);
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  $self->run(@_);
}

sub _run_cgi {
  my $self = shift;
  require Plack::Server::CGI;
  Plack::Server::CGI->run($self->as_psgi_app);
}

sub _run_fcgi {
  my $self = shift;
  require Plack::Server::FCGI;
  Plack::Server::FCGI->run($self->as_psgi_app);
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
  Plack::Test::test_psgi($self->as_psgi_app, sub { $response = shift->($request) });
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
