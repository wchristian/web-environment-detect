use strict; use warnings FATAL => 'all';
use Test::More qw(no_plan);

{

  package Foo;

  sub foo {
    use XML::Tags qw(one two three);
    <one>, <two>, <three>;
  }

  sub bar {
    no warnings 'once'; # this is supposed to warn, it's broken
    <one>
  }

  sub baz {
    use XML::Tags qw(bar);
    </bar>;
  }

  sub quux {
    use HTML::Tags;
    <html>, <body id="spoon">, "YAY", </body>, </html>;
  }

  sub globbery {
    <t/globbery/*>;
  }
}

is(
  join(', ', XML::Tags::sanitize Foo::foo()),
  '<one>, <two>, <three>',
  'open tags ok'
);

ok(!eval { Foo::bar(); 1 }, 'Death on use of unimported tag');

is(
  join(', ', XML::Tags::sanitize Foo::baz()),
  '</bar>',
  'close tag ok'
);

is(
  join('', XML::Tags::sanitize Foo::quux),
  '<html><body id="spoon">YAY</body></html>',
  'HTML tags ok'
);

is(
  join(', ', Foo::globbery),
  't/globbery/one, t/globbery/two',
  'real glob re-installed ok'
);
