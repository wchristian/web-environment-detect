package XML::Tags;

use strict;
use warnings FATAL => 'all';

my $IN_SCOPE = 0;

sub import {
  die "Can't import XML::Tags into a scope when already compiling one that uses it"
    if $IN_SCOPE;
  my ($class, @args) = @_;
  my $opts = shift(@args) if ref($args[0]) eq 'HASH';
  my $target = $class->_find_target(0, $opts);
  my @tags = $class->_find_tags(@args);
  my $unex = $class->_export_tags_into($target => @tags);
  $class->_install_unexporter($unex);
  $IN_SCOPE = 1;
}

sub _find_tags { shift; @_ }

sub _find_target {
  my ($class, $extra_levels, $opts) = @_;
  return $opts->{into} if defined($opts->{into});
  my $level = ($opts->{into_level} || 1) + $extra_levels;
  return (caller($level))[0];
}

{
  my $setup;

  sub _setup_glob_override {
    return if $setup;
    $setup = 1;
    no warnings 'redefine';
    *CORE::GLOBAL::glob = sub {
      for ($_[0]) {
        # unless it smells like </foo> or <foo bar="baz">
        return CORE::glob($_[0]) unless (/^\/\w+$/ || /^\w+\s+\w+="/);
      }
      return '<'.$_[0].'>';
    };
  }
}

sub _export_tags_into {
  my ($class, $into, @tags) = @_;
  foreach my $tag (@tags) {
    no strict 'refs';
    tie *{"${into}::${tag}"}, 'XML::Tags::TIEHANDLE', "<${tag}>";
  }
  my $orig = \&CORE::GLOBAL::glob || sub { CORE::glob($_[0]) };
  {
    no warnings 'redefine';
    *CORE::GLOBAL::glob = sub { '<'.$_[0].'>' };
  }
  return sub {
    foreach my $tag (@tags) {
      no strict 'refs';
      delete ${"${into}::"}{$tag}
    }
    $IN_SCOPE = 0;
  };
}

sub _install_unexporter {
  my ($class, $unex) = @_;
  $^H |= 0x120000; # localize %^H
  $^H{'XML::Tags::Unex'} = bless($unex, 'XML::Tags::Unex');
}

package XML::Tags::TIEHANDLE;

sub TIEHANDLE { my $str = $_[1]; bless \$str, $_[0] }
sub READLINE { ${$_[0]} }

package XML::Tags::Unex;

sub DESTROY { local $@; eval { $_[0]->(); 1 } || warn "ARGH: $@" }

1;
