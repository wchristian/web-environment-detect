use strictures;

package basic_test;

use Test::InDistDir;
use Test::More;
use Web::Environment::Detect 'detect';
use Test::Fatal 'exception';

# set up fake handlers
eval "{package Plack::Handler::$_;sub new{bless{},shift}sub run{__PACKAGE__}}"
  for        # in following, the planned behavior:
  "PSGI",    # return $_[1]
  "PCLI",    # Web::Simple::Application::_run_cli_test_request and related subs
  "FCGI",    # real handler normally
  "CGI",     # real handler normally
  ;
$INC{$_} = 1 for map "Plack/Handler/$_.pm", qw( PSGI PCLI FCGI CGI );

{

  package TestApp;
  use Moo;
  use Web::Environment::Detect 'run';
  with 'Web::Dispatch::ToApp';
  sub call { }
}

my $is_script = sub { TestApp->run };
is($is_script->(), 'Plack::Handler::PSGI', "PSGI when run as script");

{
  local @ARGV = (1);
  is(TestApp->run, 'Plack::Handler::PCLI', "CLI if env unclear and argv");
}

{
  local $ENV{PHP_FCGI_CHILDREN} = 1;
  is(TestApp->run, 'Plack::Handler::FCGI', "FCGI according to ENV");
}

{
  local $ENV{GATEWAY_INTERFACE} = 1;
  is(TestApp->run, 'Plack::Handler::CGI', "CGI according to ENV");
}

ok(!eval "detect();1", "otherwise die");

done_testing;
exit;

