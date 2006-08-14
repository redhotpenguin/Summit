use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use lib './lib';

my $data_dir = './t/data';

my $rfc_822 = "$data_dir/rfc822.msg";
die unless -e $rfc_822;

my $pkg;
BEGIN {
	$pkg = 'Summit::Message';
	use_ok($pkg);
}

use MIME::Parser;
my $p = MIME::Parser->new;
$p->output_to_core(1);

diag("test non_rfc822 message");
my $non_rfc822 = "$data_dir/non_rfc822.msg";
my $entity = $p->parse_open($non_rfc822);
my $test_msg = $pkg->new({
	headers => $entity->header_as_string, 
	body => $entity->body_as_string});
isa_ok($test_msg, $pkg);
my $test_url = 'http://prdf.clientsection.com/P3090176';
cmp_ok($test_msg->url, 'eq', $test_url, 'correct url extracted');
my $test_comment = "ping";
ok($test_msg->comment =~ m/$test_comment/i, 'correct comment extracted');

diag("test rfc822 message");
$entity = $p->parse_open($rfc_822);
ok($pkg->can('new'), "New method available");
my $msg = $pkg->new({headers => $entity->header_as_string, 
					 body => $entity->body_as_string});
isa_ok($msg, $pkg);
$test_url = 'http://prdf.clientsection.com/P3090176';
cmp_ok($msg->url, 'eq', $test_url, 'correct url extracted');
$test_comment = "this is where my post would be";
ok($msg->comment =~ m/$test_comment/, 'correct comment extracted');

diag("Test posting to basecamp");
my $login = 'fred';
my $pass = 'moyer';
$msg->basecamp_login($login);
$msg->basecamp_pass($pass);
my $posted;
$posted = $msg->post_to_basecamp;
ok($posted, 'Message posted to basecamp successfully');

diag("Test failed posting with bad username");
$msg->basecamp_login('foozaaz');
$posted = $msg->post_to_basecamp;
ok(!$posted, "posting with invalid login failed");
ok($msg->_comment_err_log =~ m/invalid/i, 'comment_err_log contains invalid');
ok($msg->_comment_err_msg =~ m/problem/i, 'comment_err_msg contains problem');

diag("Test failed posting with bad url");
$msg->{_url} = 'http://foobaz.redhotpenguin.com';
$posted = $msg->post_to_basecamp;
ok(!$posted, "posting with invalid url failed");
ok($msg->_comment_err_log =~ m/url/i, 'comment_err_log contains url');
ok($msg->_comment_err_msg =~ m/url/i, 'comment_err_msg contains url');

