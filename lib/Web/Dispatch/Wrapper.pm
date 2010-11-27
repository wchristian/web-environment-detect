package Web::Dispatch::Wrapper;

use strictures 1;
use Exporter 'import';

our @EXPORT = qw(dispatch_wrapper redispatch_to response_filter);

sub dispatch_wrapper (&) {
  my ($code) = @_;
  __PACKAGE__->from_code($code);
}

sub from_code {
  my ($class, $code) = @_;
  bless(\$code, $class);
}

sub redispatch_to {
  my ($new_path) = @_;
  __PACKAGE__->from_code(sub {
    $_[1]->({ %{$_[0]}, PATH_INFO => $new_path });
  });
}

sub response_filter (&) {
  my ($code) = @_;
  __PACKAGE__->from_code(sub {
    my @result = $_[1]->($_[0]);
    if (@result) {
      $code->(@result);
    } else {
      ()
    }
  });
}

sub wrap {
  my $code = ${$_[0]};
  my $app = $_[1];
  sub { $code->($_[0], $app) }
}

1;
