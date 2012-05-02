package Web::Simple::DispatchNode;

use Moo;

extends 'Web::Dispatch::Node';

has _app_object => (is => 'ro', init_arg => 'app_object', required => 1);

# this ensures that the dispatchers get called as methods of the app itself
around _curry => sub {
  my ($orig, $self) = (shift, shift);
  my $code = $self->$orig($self->_app_object, @_);
  ref($_[0]) eq 'HASH'
    ? do { my $v = $_[0]; sub { local *_ = $v; &$code } }
    : $code
};

1;
