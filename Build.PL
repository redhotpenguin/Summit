#!perl

use Module::Build;
use lib './t/lib';
my $build = Module::Build->new(
	dist_version => 'rc4',
	module_name => 'Summit',
	license => 'redhotpenguin_llc',
	requires => {
		'perl' => '5.8.6',
		'Net::SMTP' => 2.29,
		'MIME::Tools' => 6.110,
	},
);

$build->create_build_script();
