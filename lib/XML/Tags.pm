package XML::Tags;

use strict;
use warnings FATAL => 'all';

use File::Glob ();

my $IN_SCOPE = 0;

sub import {
  die "Can't import XML::Tags into a scope when already compiling one that uses it"
    if $IN_SCOPE;
  my ($class, @args) = @_;
  my $opts = shift(@args) if ref($args[0]) eq 'HASH';
  my $target = $class->_find_target(0, $opts);
  my @tags = $class->_find_tags(@args);
  $class->_setup_glob_override;
  my $unex = $class->_export_tags_into($target => @tags);
  $class->_install_unexporter($unex);
  $IN_SCOPE = 1;
}

sub sanitize {
  map { # string == text -> HTML, scalarref == raw HTML, other == passthrough
    ref($_)
      ? (ref $_ eq 'SCALAR' ? $$_ : $_)
      : do { local $_ = $_; # copy
          s/&/&amp;/g; s/"/&quot/g; s/</&lt;/g; s/>/&gt;/g; $_;
        }
  } @_
}

sub _glob_glob { eval '\*CORE::GLOBAL::glob' }

sub _find_tags { shift; @_ }

sub _find_target {
  my ($class, $extra_levels, $opts) = @_;
  return $opts->{into} if defined($opts->{into});
  my $level = ($opts->{into_level} || 1) + $extra_levels;
  return (caller($level))[0];
}

sub _setup_glob_override {
  no warnings 'redefine';
  delete ${CORE::GLOBAL::}{glob};
  *{_glob_glob()} = sub {
    return \('<'.$_[0].'>');
  };
}

sub _export_tags_into {
  my ($class, $into, @tags) = @_;
  foreach my $tag (@tags) {
    no strict 'refs';
    tie *{"${into}::${tag}"}, 'XML::Tags::TIEHANDLE', \"<${tag}>";
  }
  return sub {
    foreach my $tag (@tags) {
      no strict 'refs';
      delete ${"${into}::"}{$tag}
    }
    delete ${CORE::GLOBAL::}{glob};
    *{_glob_glob()} = \&File::Glob::glob;
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
