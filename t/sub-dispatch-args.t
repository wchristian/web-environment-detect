use strict;
use warnings FATAL => 'all';

use Data::Dump qw(dump);
use Test::More (
  eval { require HTTP::Request::AsCGI }
    ? 'no_plan'
    : (skip_all => 'No HTTP::Request::AsCGI')
);

{
    use Web::Simple 't::Web::Simple::SubDispatchArgs';
    package t::Web::Simple::SubDispatchArgs;

    sub dispatch_request {
        sub (/) {
            $_[0]->show_landing(@_);
        },
        sub(/...) {
            sub (GET + /user) {
                $_[0]->show_users(@_);
            },
            sub (/user/*) {
                sub (GET) {
                    $_[0]->show_user(@_);
                },
                sub (POST + %:id=&:@roles~) {
                    $_[0]->process_post(@_);
                }
            },
        }
    };

    sub show_landing {
        my ($self, @args) = @_;
        return [
            200, ['Content-Type' => 'application/perl' ],
            [Data::Dump::dump @args],
        ];
    }
    sub show_users {
        my ($self, @args) = @_;
        return [
            200, ['Content-Type' => 'application/perl' ],
            [Data::Dump::dump @args],
        ];
    }
    sub show_user {
        my ($self, @args) = @_;
        return [
            200, ['Content-Type' => 'application/perl' ],
            [Data::Dump::dump @args],
        ];
    }
    sub process_post {
        my ($self, @args) = @_;
        return [
            200, ['Content-Type' => 'application/perl' ],
            [Data::Dump::dump @args],
        ];
    }
}

ok my $app = t::Web::Simple::SubDispatchArgs->new,
  'made app';

sub run_request {
  my @args = (shift, SCRIPT_NAME=> $0);
  my $c = HTTP::Request::AsCGI->new(@args)->setup;
  $app->run;
  $c->restore;
  return $c->response;
}

use HTTP::Request::Common qw(GET POST);

ok my $get_landing = run_request(GET 'http://localhost/' ),
  'got landing';

cmp_ok $get_landing->code, '==', 200, 
  '200 on GET';

{
    my ($self, $env, @noextra) = eval $get_landing->content;
    is scalar(@noextra), 0, 'No extra stuff';
    is ref($self), 't::Web::Simple::SubDispatchArgs', 'got object';
    is ref($env), 'HASH', 'Got hashref';
    is $env->{SCRIPT_NAME}, $0, 'correct scriptname';
}

ok my $get_users = run_request(GET 'http://localhost/user'),
  'got user';

cmp_ok $get_users->code, '==', 200, 
  '200 on GET';

{
    my ($self, $env, @noextra) = eval $get_users->content;
    is scalar(@noextra), 0, 'No extra stuff';
    is ref($self), 't::Web::Simple::SubDispatchArgs', 'got object';
    is ref($env), 'HASH', 'Got hashref';
    is $env->{SCRIPT_NAME}, $0, 'correct scriptname';
}

ok my $get_user = run_request(GET 'http://localhost/user/42'),
  'got user';

cmp_ok $get_user->code, '==', 200, 
  '200 on GET';

{
    my ($self, $env, @noextra) = eval $get_user->content;
    is scalar(@noextra), 0, 'No extra stuff';
    is ref($self), 't::Web::Simple::SubDispatchArgs', 'got object';
    is ref($env), 'HASH', 'Got hashref';
    is $env->{SCRIPT_NAME}, $0, 'correct scriptname';
}

ok my $post_user = run_request(POST 'http://localhost/user/42', [id => '99'] ),
  'post user';

cmp_ok $post_user->code, '==', 200, 
  '200 on POST';

{
    my ($self, $params, $env, @noextra) = eval $post_user->content;
    is scalar(@noextra), 0, 'No extra stuff';
    is ref($self), 't::Web::Simple::SubDispatchArgs', 'got object';
    is ref($params), 'HASH', 'Got POST hashref';
    is $params->{id}, 99, 'got expected value for id';
    is ref($env), 'HASH', 'Got hashref';
    is $env->{SCRIPT_NAME}, $0, 'correct scriptname';
}

