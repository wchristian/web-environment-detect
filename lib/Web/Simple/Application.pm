package Web::Simple::Application;

use strict;
use warnings FATAL => 'all';

sub new {
  my ($class, $data) = @_;
  my $config = { $class->_default_config, %{($data||{})->{config}||{}} };
  bless({ config => $config }, $class);
}

sub config {
  shift->{config};
}

sub _construct_response_filter {
  bless($_[1], 'Web::Simple::ResponseFilter');
}

sub _is_response_filter {
  # simple blessed() hack
  "$_[1]" =~ /\w+=[A-Z]/
    and $_[1]->isa('Web::Simple::ResponseFilter');
}

sub _dispatch_parser {
  require Web::Simple::DispatchParser;
  return Web::Simple::DispatchParser->new;
}

sub _setup_dispatchables {
  my ($class, $dispatch_subs) = @_;
  my $parser = $class->_dispatch_parser;
  my @dispatchables;
  foreach my $dispatch_sub (@$dispatch_subs) {
    my $proto = prototype $dispatch_sub;
    my $matcher = (
      defined($proto)
        ? $parser->parse_dispatch_specification($proto)
        : sub { ({}) }
    );
    push @dispatchables, [ $matcher, $dispatch_sub ];
  }
  {
    no strict 'refs';
    *{"${class}::_dispatchables"} = sub { @dispatchables };
  }
}

sub handle_request {
  my ($self, $env) = @_;
  $self->_run_dispatch_for($env, [ $self->_dispatchables ]);
}

sub _run_dispatch_for {
  my ($self, $env, $dispatchables) = @_;
  my @disp = @$dispatchables;
  while (my $disp = shift @disp) {
    my ($match, $run) = @{$disp};
    if (my ($env_delta, @args) = $match->($env)) {
      my $new_env = { %$env, %$env_delta };
      if (my ($result) = $self->_run_with_self($run, @args)) {
        if ($self->_is_response_filter($result)) {
          return $self->_run_with_self(
            $result,
            $self->_run_dispatch_for($new_env, \@disp)
          );
        }
        return $result;
      }
    }
  }
  return [
    500, [ 'Content-type', 'text/plain' ],
    'The management apologises but we have no idea how to handle that'
  ];
}

sub _run_with_self {
  my ($self, $run, @args) = @_;
  my $class = ref($self);
  no strict 'refs';
  local *{"${class}::self"} = \$self;
  $self->$run(@args);
}

sub run_if_script {
  return 1 if caller(1); # 1 so we can be the last thing in the file
  my $class = shift;
  my $self = $class->new;
  $self->run(@_);
}

sub run {
  my $self = shift;
  unless ($ENV{GATEWAY_INTERFACE}) {
    die "mst is an idiot and didn't fix non-CGI yet";
  }
  require Web::Simple::HackedPlack;
  Plack::Server::CGI->run(sub { $self->handle_request(@_) });
}

1;
