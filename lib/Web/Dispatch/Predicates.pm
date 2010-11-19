package Web::Dispatch::Predicates;

use strictures 1;
use base qw(Exporter);

our @EXPORT = qw(match_and match_or match_method match_path match_path_strip);

sub match_and {
  my @match = @_;
  sub {
    my ($env) = @_;
    my $my_env = { %$env };
    my $new_env;
    my @got;
    foreach my $match (@match) {
      if (my @this_got = $match->($my_env)) {
	my %change_env = %{shift(@this_got)};
	@{$my_env}{keys %change_env} = values %change_env;
	@{$new_env}{keys %change_env} = values %change_env;
	push @got, @this_got;
      } else {
	return;
      }
    }
    return ($new_env, @got);
  }
}

sub match_or {
  my @match = @_;
  sub {
    foreach my $try (@match) {
      if (my @ret = $try->(@_)) {
        return @ret;
      }
    }
    return;
  }
}

sub match_method {
  my ($method) = @_;
  sub {
    my ($env) = @_;
    $env->{REQUEST_METHOD} eq $method ? {} : ()
  }
}

sub match_path {
  my ($re) = @_;
  sub {
    my ($env) = @_;
    if (my @cap = ($env->{PATH_INFO} =~ /$re/)) {
      $cap[0] = {}; return @cap;
    }
    return;
  }
}

sub match_path_strip {
  my ($re) = @_;
  sub {
    my ($env) = @_;
    if (my @cap = ($env->{PATH_INFO} =~ /$re/)) {
      $cap[0] = {
	SCRIPT_NAME => ($env->{SCRIPT_NAME}||'').$cap[0],
	PATH_INFO => pop(@cap),
      };
      return @cap;
    }
    return;
  }
}

1;
