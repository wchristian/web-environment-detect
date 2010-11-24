package Web::Dispatch::Wrapper;

use strictures 1;
use Exporter 'import';

our @EXPORT_OK = qw(dispatch_wrapper redispatch_to response_filter);

sub dispatch_wrapper (&) {
  my ($class, $code) = @_;
  bless(\$code, $class);
}

sub redispatch_to {
  my ($class, $new_path) = @_;
  $class->from_code(sub {
    $_[1]->({ %{$_[0]}, PATH_INFO => $new_path });
  });
}

sub response_filter (&) {
  my ($class, $code) = @_;
  $class->from_code(sub {
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
