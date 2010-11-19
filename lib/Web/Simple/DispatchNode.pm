package Web::Simple::DispatchNode;

use Moo;

extends 'Web::Dispatch::Node';

has _app_object => (is => 'ro', init_arg => 'app_object', required => 1);

around _curry => sub {
  my ($orig, $self) = (shift, shift);
  my $app = $self->_app_object;
  my $class = ref($app);
  my $inner = $self->$orig($app, @_);
  sub {
    no strict 'refs';
    local *{"${class}::self"} = \$app;
    $inner->(@_);
  }
};

1;
