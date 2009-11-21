package Web::Simple::Application;

use strict;
use warnings FATAL => 'all';

{
  package Web::Simple::Dispatcher;

  sub _is_dispatcher {
    ref($_[1])
      and "$_[1]" =~ /\w+=[A-Z]/
      and $_[1]->isa(__PACKAGE__);
  }

  sub next {
    @_ > 1
      ? $_[0]->{next} = $_[1]
      : shift->{next}
  }

  sub set_next {
    $_[0]->{next} = $_[1];
    $_[0]
  }

  sub dispatch {
    my ($self, $env, @args) = @_;
    my $next = $self->next;
    if (my ($env_delta, @match) = $self->_match_against($env)) {
      if (my ($result) = $self->_execute_with(@args, @match)) {
        if ($self->_is_dispatcher($result)) {
          $next = $result->set_next($next);
          $env = { %$env, %$env_delta };
        } else {
          return $result;
        }
      }
    }
    return $next->dispatch($env, @args);
  }

  sub _match_against {
     return ({}, $_[1]) unless $_[0]->{match};
     $_[0]->{match}->($_[1]);
  }

  sub _execute_with {
    $_[0]->{call}->(@_);
  }
}

sub new {
  my ($class, $data) = @_;
  my $config = { $class->_default_config, %{($data||{})->{config}||{}} };
  bless({ config => $config }, $class);
}

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

sub config {
  shift->{config};
}

sub _construct_response_filter {
  my $code = $_[1];
  $_[0]->_build_dispatcher({
    call => sub {
      my ($d, $self, $env) = (shift, shift, shift);
      $self->_run_with_self($code, $d->next->dispatch($env, $self, @_));
    },
  });
}

sub _construct_redispatch {
  my ($self, $new_path) = @_;
  $self->_build_dispatcher({
    call => sub {
      shift;
      my ($self, $env) = @_;
      $self->_dispatch({ %{$env}, PATH_INFO => $new_path })
    }
  })
}

sub _build_dispatch_parser {
  require Web::Simple::DispatchParser;
  return Web::Simple::DispatchParser->new;
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
  my ($class, $dispatch_subs) = @_;
  {
    no strict 'refs';
    if (${"${class}::_dispatcher"}{CODE}) {
      $class->_cannot_call_twice('_setup_dispatcher', 'dispatch');
    }
  }
  my $parser = $class->_build_dispatch_parser;
  my ($root, $last);
  foreach my $dispatch_sub (@$dispatch_subs) {
    my $proto = prototype $dispatch_sub;
    my $matcher = (
      defined($proto)
        ? $parser->parse_dispatch_specification($proto)
        : undef
    );
    my $new = $class->_build_dispatcher({
      match => $matcher,
      call => sub { shift;
        shift->_run_with_self($dispatch_sub, @_)
      },
    });
    $root ||= $new;
    $last = $last ? $last->next($new) : $new;
  }
  $last->next($class->_build_final_dispatcher);
  {
    no strict 'refs';
    *{"${class}::_dispatcher"} = sub { $root };
  }
}

sub _build_dispatcher {
  bless($_[1], 'Web::Simple::Dispatcher');
}

sub _build_final_dispatcher {
  shift->_build_dispatcher({
    call => sub {
      [
        500, [ 'Content-type', 'text/plain' ],
        [ 'The management apologises but we have no idea how to handle that' ]
      ]
    }
  })
}

sub _dispatch {
  my ($self, $env) = @_;
  $self->_dispatcher->dispatch($env, $self);
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

sub _run_cgi {
  my $self = shift;
  require Web::Simple::HackedPlack;
  Plack::Server::CGI->run(sub { $self->_dispatch(@_) });
}

sub run {
  my $self = shift;
  if ($ENV{GATEWAY_INTERFACE}) {
    return $self->_run_cgi;
  }
  my $path = shift(@ARGV) or die "No path passed - use $0 / for root";

  require HTTP::Request::AsCGI;
  require HTTP::Request::Common;
  local *GET = \&HTTP::Request::Common::GET;

  my $request = GET($path);
  my $c = HTTP::Request::AsCGI->new($request)->setup;
  $self->_run_cgi;
  $c->restore;
  print $c->response->as_string;
}

1;
