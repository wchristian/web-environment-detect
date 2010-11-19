package Web::Dispatch::Wrapper;

use strictures 1;

sub from_code {
  my ($class, $code) = @_;
  bless(\$code, $class);
}

sub wrap {
  my $code = ${$_[0]};
  my $app = $_[1];
  sub { $code->($_[0], $app) }
}

1;
