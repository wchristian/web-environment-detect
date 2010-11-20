package Web::Simple::Application;

use Moo;

has 'config' => (is => 'ro', trigger => sub {
  my ($self, $value) = @_;
  my %default = $self->_default_config;
  my @not = grep !exists $value->{$_}, keys %default;
  @{$value}{@not} = @default{@not};
});

sub _setup_default_config {
  my $class = shift;
  {
    no strict 'refs';
    if (${"${class}::_default_config"}{CODE}) {
      $class->_cannot_call_twice('_setup_default_config', 'default_config');
    }
  }
  my @defaults = (@_, $class->_default_config);
  {
    no strict 'refs';
    *{"${class}::_default_config"} = sub { @defaults };
  }
}

sub _default_config { () }

sub _construct_response_filter {
  my ($class, $code) = @_;
  my $self = do { no strict 'refs'; ${"${class}::self"} };
  require Web::Dispatch::Wrapper;
  Web::Dispatch::Wrapper->from_code(sub {
    my @result = $_[1]->($_[0]);
    if (@result) {
      $self->_run_with_self($code, @result);
    } else {
      @result;
    }
  });
}

sub _construct_redispatch {
  my ($class, $new_path) = @_;
  require Web::Dispatch::Wrapper;
  Web::Dispatch::Wrapper->from_code(sub {
    $_[1]->({ %{$_[0]}, PATH_INFO => $new_path });
  });
}

sub _build_dispatch_parser {
  require Web::Dispatch::Parser;
  return Web::Dispatch::Parser->new;
}

sub _cannot_call_twice {
  my ($class, $method, $sub) = @_;
  my $error = "Cannot call ${method} twice for ${class}";
  if ($sub) {
    $error .= " - did you call Web::Simple's ${sub} export twice?";
  }
  die $error;
}

sub _setup_dispatcher {
  my ($class, $dispatcher) = @_;
  {
    no strict 'refs';
    if (${"${class}::_dispatcher"}{CODE}) {
      $class->_cannot_call_twice('_setup_dispatcher', 'dispatch');
    }
  }
  {
    no strict 'refs';
    *{"${class}::dispatch_request"} = $dispatcher;
  }
}

sub _build_final_dispatcher {
  [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
}

sub _run_with_self {
  my ($self, $run, @args) = @_;
  my $class = ref($self);
  no strict 'refs';
  local *{"${class}::self"} = \$self;
  $self->$run(@args);
}

sub run_if_script {
  # ->as_psgi_app is true for require() but also works for plackup
  return $_[0]->as_psgi_app if caller(1);
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

sub as_psgi_app {
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  require Web::Dispatch;
  require Web::Simple::DispatchNode;
  my $final = $self->_build_final_dispatcher;
  Web::Dispatch->new(
    app => sub { $self->dispatch_request(@_), $final },
    node_class => 'Web::Simple::DispatchNode',
    node_args => { app_object => $self }
  )->to_app;
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
